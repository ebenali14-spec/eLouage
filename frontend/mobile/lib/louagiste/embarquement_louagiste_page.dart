import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile/services/session_service.dart';
import '../theme/app_colors.dart';
import 'package:mobile/services/trajet_service.dart';

class EmbarquementLouagistePage extends StatefulWidget {
  const EmbarquementLouagistePage({super.key});

  @override
  State<EmbarquementLouagistePage> createState() =>
      _EmbarquementLouagistePageState();
}

class _EmbarquementLouagistePageState extends State<EmbarquementLouagistePage> {
  // grace ends this many minutes after heureArrivee (0 = at heureArrivee)
  static const int _delaiGraceMin = 0;

  final _service = TrajetService();
  int? _louagisteId;

  List<Map<String, dynamic>> _trajets = [];   // all of today's trajets
  int? _trajetId;                             // selected trajet
  List<Map<String, dynamic>> _presents = [];
  List<Map<String, dynamic>> _nonPresents = [];
  final Set<int> _coches = {};
  final Set<int> _absents = {};
  final Set<int> _vus = {};
  final Set<int> _alertes = {};               // trajets already warned about
  bool _chargement = true;
  bool _envoi = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _charger();
    _timer = Timer.periodic(
        const Duration(seconds: 15), (_) => _charger(silencieux: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ---------- helpers ----------
  Map<String, dynamic>? get _trajet {
    for (final t in _trajets) {
      if (t['trajetId'] == _trajetId) return t;
    }
    return null;
  }

  DateTime? _heure(Map<String, dynamic> t) {
    if (t['heureArrivee'] == null) return null;
    final h = '${t['heureArrivee']}';
    return DateTime.tryParse('${t['date']}T${h.length == 5 ? '$h:00' : h}');
  }

  bool _graceFinie(Map<String, dynamic> t) {
    final d = _heure(t);
    return d != null &&
        DateTime.now().isAfter(d.add(const Duration(minutes: _delaiGraceMin)));
  }

  String _hhmm(Map<String, dynamic> t) =>
      '${t['heureArrivee'] ?? ''}'.padRight(5).substring(0, 5);

  String _route(Map<String, dynamic> t) =>
      '${t['villeDepart'] ?? ''} → ${t['villeDestination'] ?? ''}';

  // first trajet whose grace is not over, otherwise the last one
  int? _trajetParDefaut(List<Map<String, dynamic>> l) {
    if (l.isEmpty) return null;
    for (final t in l) {
      if (!_graceFinie(t)) return t['trajetId'] as int;
    }
    return l.last['trajetId'] as int;
  }

  void _choisir(int id) {
    setState(() {
      _trajetId = id;
      _coches.clear();
      _absents.clear();
      _vus.clear();
      _presents = [];
      _nonPresents = [];
    });
    _charger(silencieux: true);
  }

  // ---------- loading ----------
  Future<void> _charger({bool silencieux = false}) async {
    try {
      final id = await SessionService.getId();
      if (id == null) {
        if (!silencieux) _message('Session introuvable, reconnectez-vous.');
        if (mounted) setState(() => _chargement = false);
        return;
      }
      _louagisteId = id;
      final trajets = await _service.trajetsDuJour(id);
      var choisi = _trajetId;
      if (choisi == null || !trajets.any((t) => t['trajetId'] == choisi)) {
        choisi = _trajetParDefaut(trajets);
      }

      List<Map<String, dynamic>> presents = [];
      List<Map<String, dynamic>> non = [];
      if (choisi != null) {
        presents = await _service.getPresents(choisi, id);
        non = await _service.getNonPresents(choisi, id);
      }
      if (!mounted) return;
      setState(() {
        _trajets = trajets;
        _trajetId = choisi;
        _presents = presents;
        _nonPresents = non;
        _coches.removeWhere((c) => !presents.any((p) => p['id'] == c));
        final ids = non.map((r) => r['id'] as int).toSet();
        _absents.removeWhere((a) => !ids.contains(a));
        for (final i in ids) {
          if (_vus.add(i)) _absents.add(i); // pre-check each new absentee once
        }
      });

      // warn once per trajet when the grace delay ends with absentees
      final t = _trajet;
      if (t != null &&
          _graceFinie(t) &&
          _nonPresents.isNotEmpty &&
          _alertes.add(t['trajetId'] as int)) {
        _message("${_nonPresents.length} passager(s) n'ont pas confirmé "
            'leur présence : délai de grâce terminé');
      }
    } catch (e) {
      if (!silencieux) _message(e.toString().replaceFirst('Exception: ', ''));
    }
    if (mounted && _chargement) setState(() => _chargement = false);
  }

  // ---------- actions ----------
  Future<void> _confirmer() async {
    final louagisteId = _louagisteId;
    if (louagisteId == null) {
      _message('Session introuvable, reconnectez-vous.');
      return;
    }
    setState(() => _envoi = true);
    int ok = 0;
    String? erreur;
    for (final id in _coches.toList()) {
      try {
        await _service.confirmerEmbarquement(id, louagisteId);
        ok++;
      } catch (e) {
        erreur = e.toString().replaceFirst('Exception: ', '');
      }
    }
    _message(erreur == null
        ? 'Embarquement confirmé ($ok)'
        : '$ok confirmé(s), erreur : $erreur');
    await _charger();
    if (mounted) setState(() => _envoi = false);
  }

  Future<void> _libererPlaces() async {
    final louagisteId = _louagisteId;
    final tid = _trajetId;
    if (louagisteId == null || tid == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Libérer les places ?'),
        content: Text('${_absents.length} passager(s) seront marqués absents '
            'et leur place sera libérée.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Annuler')),
          ElevatedButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Confirmer')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _envoi = true);
    try {
      final r = await _service.marquerAbsents(tid, louagisteId, _absents.toList());
      final liberees = (r['placesLiberees'] as List?)?.length ?? 0;
      final remp = (r['remplacants'] as List?)?.length ?? 0;
      _message('$liberees place(s) libérée(s), $remp remplaçant(s) confirmé(s)');
      _vus.clear();
      await _charger();
    } catch (e) {
      _message(e.toString().replaceFirst('Exception: ', ''));
    }
    if (mounted) setState(() => _envoi = false);
  }

  void _message(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  // ---------- widgets ----------
  Widget _selecteur() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final t in _trajets)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: Icon(
                    t['retour'] == true
                        ? Icons.keyboard_return
                        : Icons.arrow_forward,
                    size: 16),
                label: Text('${_hhmm(t)}  ${_route(t)}'),
                selected: t['trajetId'] == _trajetId,
                onSelected: (_) => _choisir(t['trajetId'] as int),
              ),
            ),
        ],
      ),
    );
  }

  Widget _blocAbsents() {
    return Card(
      color: Colors.red.withOpacity(0.06),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Colors.red),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.person_off_outlined, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_nonPresents.length} passager(s) absent(s) après le délai de grâce',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.red),
                ),
              ),
            ]),
            const SizedBox(height: 4),
            const Text("Décochez ceux qui viennent d'arriver."),
            for (final r in _nonPresents)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('${r['passagerNom'] ?? 'Passager'}'),
                subtitle: Text('Place ${r['numeroPlace']}'),
                value: _absents.contains(r['id']),
                onChanged: (c) => setState(() {
                  final id = r['id'] as int;
                  c! ? _absents.add(id) : _absents.remove(id);
                }),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, foregroundColor: Colors.white),
                icon: const Icon(Icons.event_seat_outlined),
                label: Text('Marquer absents et libérer (${_absents.length})'),
                onPressed: (_absents.isEmpty || _envoi) ? null : _libererPlaces,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement) return const Center(child: CircularProgressIndicator());

    final t = _trajet;
    if (t == null) {
      return const Center(child: Text("Aucun trajet prévu aujourd'hui"));
    }

    final afficherAbsents = _graceFinie(t) && _nonPresents.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Embarquement',
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          _selecteur(),
          const SizedBox(height: 8),
          Text(
            '${t['retour'] == true ? 'Retour' : 'Aller'} · ${_hhmm(t)} · ${_route(t)}',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _charger,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (afficherAbsents) ...[
                    _blocAbsents(),
                    const SizedBox(height: 16),
                  ],
                  const Text('Passagers présents',
                      style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  if (_presents.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Aucun passager présent pour le moment'),
                    ),
                  for (final r in _presents)
                    CheckboxListTile(
                      title: Text('${r['passagerNom'] ?? 'Passager'}'),
                      subtitle:
                      Text('Place ${r['numeroPlace']} · ${r['statut']}'),
                      value: _coches.contains(r['id']),
                      onChanged: (coche) => setState(() {
                        final id = r['id'] as int;
                        coche! ? _coches.add(id) : _coches.remove(id);
                      }),
                    ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check),
                label: Text("Confirmer l'embarquement (${_coches.length})"),
                onPressed: (_coches.isEmpty || _envoi) ? null : _confirmer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}