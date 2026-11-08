import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile/services/session_service.dart';
import '../theme/app_colors.dart';
import 'package:mobile/services/trajet_service.dart';
import 'package:mobile/services/heure_tunis.dart';

class EmbarquementLouagistePage extends StatefulWidget {
  const EmbarquementLouagistePage({super.key});

  @override
  State<EmbarquementLouagistePage> createState() =>
      _EmbarquementLouagistePageState();
}

class _EmbarquementLouagistePageState extends State<EmbarquementLouagistePage> {
  // le delai de grace se termine 15 min apres heureArrivee
  static const int _delaiGraceMin = 15;

  final _service = TrajetService();
  int? _louagisteId;

  List<Map<String, dynamic>> _trajets = [];   // all of today's trajets
  int? _trajetId;                             // selected trajet
  List<Map<String, dynamic>> _presents = [];
  List<Map<String, dynamic>> _nonPresents = [];
  final Set<int> _coches = {};
  final Set<int> _alertes = {};               // trajets already warned about
  bool _chargement = true;
  bool _envoi = false;
  Timer? _timer;   // recharge les donnees toutes les 15 s
  Timer? _tick;    // chrono : reconstruit l'ecran seulement quand la minute change
  int? _minAffichee;

  @override
  void initState() {
    super.initState();
    _charger();
    _timer = Timer.periodic(
        const Duration(seconds: 15), (_) => _charger(silencieux: true));
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      final t = _trajet;
      final m = t == null ? null : _minutesRestantes(t);
      if (m != _minAffichee && mounted) setState(() => _minAffichee = m);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  // ---------- helpers ----------
  Map<String, dynamic>? get _trajet {
    for (final t in _trajets) {
      if (t['trajetId'] == _trajetId) return t;
    }
    return null;
  }

  DateTime? _heure(Map<String, dynamic> t) =>
      HeureTunis.depuis(t['date'], t['heureArrivee']);

  bool _graceFinie(Map<String, dynamic> t) {
    final d = _heure(t);
    return d != null &&
        !HeureTunis.maintenant()
            .isBefore(d.add(const Duration(minutes: _delaiGraceMin)));
  }

  // minutes restantes (arrondi au-dessus), 0 si fini, null si pas d'heure
  int? _minutesRestantes(Map<String, dynamic> t) {
    final d = _heure(t);
    if (d == null) return null;
    final fin = d.add(const Duration(minutes: _delaiGraceMin));
    final reste = fin.difference(HeureTunis.maintenant());
    if (reste.inSeconds <= 0) return 0;
    return (reste.inSeconds / 60).ceil();
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

  // marque UN passager absent : sa place est donnee au 1er passager en attente compatible
  Future<void> _marquerAbsent(Map<String, dynamic> r) async {
    final louagisteId = _louagisteId;
    final tid = _trajetId;
    if (louagisteId == null || tid == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Marquer absent ?'),
        content: Text('${r['passagerNom'] ?? 'Ce passager'} '
            '(place ${r['numeroPlace']}) sera marqué absent '
            'et sa place sera libérée.'),
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
      final res =
      await _service.marquerAbsents(tid, louagisteId, [r['id'] as int]);
      final remp = (res['remplacants'] as List?)?.length ?? 0;
      _message(remp > 0
          ? 'Place libérée : un passager en attente a été confirmé.'
          : 'Place libérée : aucun passager en attente compatible.');
    } catch (e) {
      _message(e.toString().replaceFirst('Exception: ', ''));
    }
    await _charger(silencieux: true); // on recharge la liste dans tous les cas
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

  // chrono du delai de grace : vert, orange, rouge (un tiers chacun), puis "Temps ecoule"
  Widget _chrono(Map<String, dynamic> t) {
    final d = _heure(t);
    if (d == null) return const SizedBox.shrink();
    final now = HeureTunis.maintenant();
    final fin = d.add(const Duration(minutes: _delaiGraceMin));

    final Color couleur;
    final String texte;
    double? progres;

    if (now.isBefore(d)) {
      couleur = Colors.grey;
      texte = 'Le délai de grâce de $_delaiGraceMin min commence à \n ${_hhmm(t)}';
    } else if (!now.isBefore(fin)) {
      couleur = Colors.red;
      texte = 'Temps écoulé';
      progres = 1;
    } else {
      final ecoule = now.difference(d).inSeconds / 60; // en minutes
      final tiers = _delaiGraceMin / 3;
      couleur = ecoule < tiers
          ? Colors.green
          : (ecoule < 2 * tiers ? Colors.orange : Colors.red);
      texte = 'Temps restant : ${_minutesRestantes(t)} min';
      progres = ecoule / _delaiGraceMin;
    }
    // DEBUG temporaire
    final debug = 'now=${now.toString().substring(0, 19)}  '
        'début=${d.toString().substring(0, 19)}  '
        'fin=${fin.toString().substring(0, 19)}';
    print(debug);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: couleur.withOpacity(0.08),
        border: Border.all(color: couleur),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.timer_outlined, color: couleur),
            const SizedBox(width: 8),
             Text(texte,
                style: TextStyle(fontWeight: FontWeight.bold, color: couleur)),
          ]),
          if (progres != null) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progres,
              color: couleur,
              backgroundColor: couleur.withOpacity(0.15),
            ),
          ],
        ],
      ),
    );
  }

  // apres le delai : un bouton "Marquer absent" par passager qui n'a pas confirme sa presence
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
                  '${_nonPresents.length} passager(s) pas encore arrivé(s)',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.red),
                ),
              ),
            ]),
            const SizedBox(height: 4),
            const Text('Vous pouvez attendre encore ou marquer absent.'),
            for (final r in _nonPresents)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('${r['passagerNom'] ?? 'Passager'}'),
                subtitle: Text('Place ${r['numeroPlace']}'),
                trailing: OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: _envoi ? null : () => _marquerAbsent(r),
                  child: const Text('Marquer absent'),
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
          _chrono(t),
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