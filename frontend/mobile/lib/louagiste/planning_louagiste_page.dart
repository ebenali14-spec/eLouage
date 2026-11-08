import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:mobile/services/planning-service.dart';
import 'package:mobile/config/config.dart';

class PlanningLouagistePage extends StatefulWidget {
  const PlanningLouagistePage({super.key});

  @override
  State<PlanningLouagistePage> createState() => _PlanningLouagistePageState();
}

class _PlanningLouagistePageState extends State<PlanningLouagistePage> {
  //final _service = PlanningService();

  // TODO: final _service = PlanningService();
  // TODO: final int _louagisteId = LouagisteId;

  // TODO: charger depuis le service (lignes autorisées par l'admin)
  final Map<int, String> _lignes = {1: 'Tunis → Sousse', 2: 'Tunis → Sfax'};

  final List<String> _nomsJours = const [
    'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'
  ];

  late DateTime _lundi;
  // date -> {'ligneId': int?, 'heureArrivee': TimeOfDay?, 'allerRetour': bool}
  // allerRetour == false -> 1 trajet (aller seul), true -> 2 trajets
  final Map<String, Map<String, dynamic>> _plan = {};
  bool _chargement = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // accessible à tout moment : on part de la semaine en cours
    _lundi = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    _chargerSemaine();
  }

  List<DateTime> get _jours => List.generate(
      7, (i) => DateTime(_lundi.year, _lundi.month, _lundi.day + i));

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _affiche(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _heure(TimeOfDay? t) => t == null
      ? '--:--'
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Map<String, dynamic> _de(String date) => _plan.putIfAbsent(
      date,
          () => {'ligneId': null, 'heureArrivee': null, 'allerRetour': false});

  bool _jourComplet(Map<String, dynamic> p) =>
      p['ligneId'] != null && p['heureArrivee'] != null;

  bool _jourIncomplet(Map<String, dynamic> p) =>
      (p['ligneId'] != null) != (p['heureArrivee'] != null);

  bool get _pret =>
      _plan.values.any(_jourComplet) && !_plan.values.any(_jourIncomplet);

  Future<void> _chargerSemaine() async {
    setState(() {
      _chargement = true;
      _plan.clear();
    });
    // TODO: charger lignes autorisées + planning de la semaine depuis le service
    //       et remplir _plan (ligneId, heureArrivee, allerRetour) pour chaque date
    if (mounted) setState(() => _chargement = false);
  }

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
    // TODO: envoyer _plan au service. Pour chaque jour :
    //       allerRetour == false -> créer 1 trajet, true -> créer 2 trajets.
    //       Confirmation immédiate, pas de validation admin.
    _message('Planning confirmé');
  }

  void _message(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  @override
  Widget build(BuildContext context) {
    final jours = _jours;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 16),
          Expanded(
            child: _chargement
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
              itemCount: jours.length,
              itemBuilder: (context, i) {
                final date = _fmt(jours[i]);
                final p = _de(date);
                final aLigne = p['ligneId'] != null;
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
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(_nomsJours[i],
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold)),
                                  Text(date),
                                ],
                              ),
                            ),
                            if (aLigne || p['heureArrivee'] != null)
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
                                items: _lignes.entries
                                    .map((e) => DropdownMenuItem(
                                    value: e.key,
                                    child: Text(e.value)))
                                    .toList(),
                                onChanged: (id) =>
                                    setState(() => p['ligneId'] = id),
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.schedule, size: 18),
                              label: Text(_heure(p['heureArrivee'])),
                              onPressed:
                              aLigne ? () => _choisirHeure(p) : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Heure d\'arrivée à la station (1er trajet)',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(
                                  value: false, label: Text('Aller')),
                              ButtonSegment(
                                  value: true,
                                  label: Text('Aller-retour')),
                            ],
                            selected: {p['allerRetour'] == true},
                            onSelectionChanged: aLigne
                                ? (s) => setState(
                                    () => p['allerRetour'] = s.first)
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (!_chargement)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Confirmer ma semaine'),
                onPressed: _pret ? _valider : null,
              ),
            ),
        ],
      ),
    );
  }
}