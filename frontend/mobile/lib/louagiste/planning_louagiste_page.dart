import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:mobile/services/planning-service.dart';
import 'package:mobile/services/session_service.dart';

class PlanningLouagistePage extends StatefulWidget {
  const PlanningLouagistePage({super.key});

  @override
  State<PlanningLouagistePage> createState() => _PlanningLouagistePageState();
}

class _PlanningLouagistePageState extends State<PlanningLouagistePage> {
  final _service = PlanningService();
  int? _louagisteId;

  // id ligne -> "DEPART → ARRIVEE" (utilise en mode lecture pour changer de ligne)
  Map<int, String> _lignes = {};

  final List<String> _nomsJours = const [
    'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'
  ];

  late DateTime _lundi;
  // creation mode: date -> {'ligneId', 'heureArrivee', 'allerRetour'}
  final Map<String, Map<String, dynamic>> _plan = {};
  // read-only mode: date -> trajets returned by the backend
  final Map<String, List<Map<String, dynamic>>> _trajets = {};
  // US21 : date -> lignes autorisees avec compteurs
  final Map<String, List<Map<String, dynamic>>> _etat = {};
  bool _planningExiste = false;
  bool _chargement = true;
  bool _envoi = false;
  int _requete = 0; // ignores late responses

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // start on next Monday, the first week that can still be created
    _lundi = DateTime(now.year, now.month, now.day + 8 - now.weekday);
    _chargerSemaine();
  }

  // ---------- helpers ----------
  DateTime get _aujourdhui {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  // le backend ferme la semaine apres son dimanche (dateCloture = lundi + 6)
  bool get _semaineCloturee =>
      _aujourdhui.isAfter(DateTime(_lundi.year, _lundi.month, _lundi.day + 6));

  List<DateTime> get _jours => List.generate(
      7, (i) => DateTime(_lundi.year, _lundi.month, _lundi.day + i));

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _affiche(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _heure(TimeOfDay? t) => t == null
      ? '--:--'
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _texteErreur(Object e) => e.toString().replaceFirst('Exception: ', '');

  Map<String, dynamic> _de(String date) => _plan.putIfAbsent(
      date, () => {'ligneId': null, 'heureArrivee': null, 'allerRetour': false});

  bool _jourComplet(Map<String, dynamic> p) =>
      p['ligneId'] != null && p['heureArrivee'] != null;

  bool _jourIncomplet(Map<String, dynamic> p) =>
      (p['ligneId'] != null) != (p['heureArrivee'] != null);

  bool get _pret =>
      !_envoi &&
          _plan.values.any(_jourComplet) &&
          !_plan.values.any(_jourIncomplet);

  // ---------- regle US21 ----------
  // si au moins une ligne est sous le minimum et au moins une autre l'a atteint,
  // seules les lignes sous le minimum sont autorisees (cas 2)
  bool _restreint(List<Map<String, dynamic>> etat) {
    final sous = etat.where((e) => e['sousMinimum'] == true).length;
    return sous > 0 && sous < etat.length;
  }

  bool _ligneChoisissable(
      List<Map<String, dynamic>> etat, Map<String, dynamic> l) =>
      !_restreint(etat) || l['sousMinimum'] == true;

  // ---------- loading ----------
  Future<void> _chargerSemaine() async {
    final id = ++_requete;
    setState(() {
      _chargement = true;
      _plan.clear();
      _trajets.clear();
      _etat.clear();
      _planningExiste = false;
    });
    try {
      _louagisteId ??= await SessionService.getId();
      if (_louagisteId == null) throw Exception('Session expirée, reconnectez-vous');

      if (_lignes.isEmpty) {
        final l = await _service.getLignesAvecInscrits(
            _louagisteId!, _fmt(_lundi));
        _lignes = {
          for (final x in l) x['id'] as int: '${x['depart']} → ${x['arrivee']}'
        };
      }
      final planning = await _service.getPlanning(_louagisteId!, _fmt(_lundi));
      if (id != _requete) return;
      if (planning != null) {
        _remplirDepuis(planning);
      } else if (!_semaineCloturee) {
        // US21 : compteurs de chaque jour encore modifiable
        final jours = _jours.where((d) => !d.isBefore(_aujourdhui)).toList();
        final res = await Future.wait(jours.map(
                (d) => _service.getLignesAvecInscrits(_louagisteId!, _fmt(d))));
        if (id != _requete) return;
        for (var i = 0; i < jours.length; i++) {
          _etat[_fmt(jours[i])] = res[i];
        }
      }
    } catch (e) {
      if (id == _requete) _message(_texteErreur(e));
    }
    if (mounted && id == _requete) setState(() => _chargement = false);
  }

  // planning['jours'] = [{trajetId, date, ligneId, villeDepart, villeDestination,
  //                       present, retour, heureArrivee}]
  void _remplirDepuis(Map<String, dynamic> planning) {
    _planningExiste = true;
    for (final j in (planning['jours'] as List)) {
      final t = Map<String, dynamic>.from(j);
      _trajets.putIfAbsent('${t['date']}', () => []).add(t);
    }
  }

  // ---------- actions ----------
  void _semaine(int delta) {
    _lundi = DateTime(_lundi.year, _lundi.month, _lundi.day + 7 * delta);
    _chargerSemaine();
  }

  Future<void> _choisirDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _lundi,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );
    if (date == null) return;
    _lundi = DateTime(date.year, date.month, date.day - (date.weekday - 1));
    _chargerSemaine();
  }

  Future<void> _choisirHeure(Map<String, dynamic> p) async {
    final t = await showTimePicker(
      context: context,
      initialTime: p['heureArrivee'] ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (t == null) return;
    setState(() => p['heureArrivee'] = t);
  }

  void _viderJour(Map<String, dynamic> p) {
    setState(() {
      p['ligneId'] = null;
      p['heureArrivee'] = null;
      p['allerRetour'] = false;
    });
  }

  Future<void> _valider() async {
    setState(() => _envoi = true);
    try {
      final corps = <String, Map<String, dynamic>>{};
      _plan.forEach((date, p) {
        if (_jourComplet(p)) {
          corps[date] = {
            'ligneId': p['ligneId'],
            'allerRetour': p['allerRetour'] == true,
            'heureArrivee': _heure(p['heureArrivee'] as TimeOfDay),
          };
        }
      });
      await _service.remplirPlan(_louagisteId!, _fmt(_lundi), corps);
      _message('Planning confirmé');
      await _chargerSemaine(); // switches to read-only mode
    } catch (e) {
      _message(_texteErreur(e));
    }
    if (mounted) setState(() => _envoi = false);
  }

  Future<void> _changerLigne(Map<String, dynamic> t, int ligneId) async {
    try {
      await _service.changerLigne(t['trajetId'] as int, _louagisteId!, ligneId);
      _message('Ligne modifiée');
      await _chargerSemaine(); // the return follows the aller
    } catch (e) {
      _message(_texteErreur(e));
    }
  }

  void _message(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  // ---------- creation card (one day) ----------
  Widget _carteJour(int i, DateTime jour) {
    final date = _fmt(jour);
    final p = _de(date);
    final etat = _etat[date] ?? [];
    final aLigne = p['ligneId'] != null;
    // semaine cloturee, ou jour deja passe (refuse par le backend)
    final bloque = _semaineCloturee || jour.isBefore(_aujourdhui);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_nomsJours[i],
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(date),
                    ],
                  ),
                ),
                if (!bloque && (aLigne || p['heureArrivee'] != null))
                  IconButton(
                    tooltip: 'Vider ce jour',
                    icon: const Icon(Icons.close),
                    onPressed: () => _viderJour(p),
                  ),
              ],
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: p['ligneId'],
                    hint: const Text('Choisir une ligne'),
                    items: etat
                        .map((l) => DropdownMenuItem<int>(
                      value: l['id'] as int,
                      enabled: _ligneChoisissable(etat, l),
                      child: Text(
                        '${l['depart']} → ${l['arrivee']}  '
                            '(${l['nbLouagistesInscrits']}/${l['minimumLouagistes']})',
                        style: TextStyle(
                            color: _ligneChoisissable(etat, l)
                                ? null
                                : Colors.grey),
                      ),
                    ))
                        .toList(),
                    onChanged:
                    bloque ? null : (id) => setState(() => p['ligneId'] = id),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.schedule, size: 18),
                  label: Text(_heure(p['heureArrivee'])),
                  onPressed: (!bloque && aLigne) ? () => _choisirHeure(p) : null,
                ),
              ],
            ),
            if (!bloque && _restreint(etat))
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Certaines lignes n\'ont pas atteint leur minimum de louagistes : '
                      'choisissez l\'une d\'elles.',
                  style: TextStyle(fontSize: 12, color: Colors.orange),
                ),
              ),
            const SizedBox(height: 4),
            const Text(
              "Heure d'arrivée à la station (1er trajet)",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Aller')),
                  ButtonSegment(value: true, label: Text('Aller-retour')),
                ],
                selected: {p['allerRetour'] == true},
                onSelectionChanged: (!bloque && aLigne)
                    ? (s) => setState(() => p['allerRetour'] = s.first)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- read-only card (one day) ----------
  Widget _carteLecture(int i, DateTime jour) {
    final date = _fmt(jour);
    final liste = _trajets[date] ?? [];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_nomsJours[i],
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(date),
            const Divider(),
            if (liste.isEmpty)
              const Text('Repos', style: TextStyle(color: Colors.grey)),
            for (final t in liste) _ligneTrajet(t),
          ],
        ),
      ),
    );
  }

  Widget _ligneTrajet(Map<String, dynamic> t) {
    final retour = t['retour'] == true;
    final present = t['present'] == true;
    final heure = '${t['heureArrivee'] ?? ''}'.padRight(5).substring(0, 5);
    final ligneId = t['ligneId'];
    final route = '${t['villeDepart'] ?? ''} → ${t['villeDestination'] ?? ''}';

    // the backend refuses a change after check-in or on a closed week
    final modifiable = !retour && !present && !_semaineCloturee;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(retour ? Icons.keyboard_return : Icons.arrow_forward,
                size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(heure,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(route,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                ),
                if (modifiable)
                  DropdownButton<int>(
                    isExpanded: true,
                    isDense: true,
                    value: _lignes.containsKey(ligneId) ? ligneId as int : null,
                    hint: const Text('Changer de ligne'),
                    items: _lignes.entries
                        .map((e) => DropdownMenuItem(
                        value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (id) {
                      if (id != null && id != ligneId) _changerLigne(t, id);
                    },
                  ),
              ],
            ),
          ),
          if (present)
            const Text('Présent',
                style: TextStyle(fontSize: 12, color: Colors.green)),
          if (retour)
            const Text('Retour',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  // ---------- build ----------
  @override
  Widget build(BuildContext context) {
    final jours = _jours;
    final afficherBouton = !_chargement && !_planningExiste && !_semaineCloturee;

    return Column(
      children: [
        // fixed: week selector + status
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => _semaine(-1),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: _choisirDate,
                      child: Text(
                        'Semaine du ${_affiche(_lundi)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => _semaine(1),
                  ),
                ],
              ),
              if (!_chargement && _planningExiste)
                const Text('Planning confirmé',
                    style: TextStyle(
                        color: Colors.green, fontWeight: FontWeight.w600)),
              if (!_chargement && !_planningExiste && _semaineCloturee)
                const Text('Semaine clôturée : aucun planning enregistré.',
                    style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),

        // scrollable: only the 7 days
        Expanded(
          child: _chargement
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Column(
              children: [
                for (int i = 0; i < jours.length; i++)
                  _planningExiste
                      ? _carteLecture(i, jours[i])
                      : _carteJour(i, jours[i]),
              ],
            ),
          ),
        ),

        // fixed: confirm button (creation mode on an open week only)
        if (afficherBouton)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: Text(_envoi ? 'Envoi...' : 'Confirmer ma semaine'),
                  onPressed: _pret ? _valider : null,
                ),
              ),
            ),
          ),
      ],
    );
  }
}