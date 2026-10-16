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
  final _service = PlanningService();

  // plus tard : vient de la connexion
  final int _louagisteId = LouagisteId;

  Map<int, String> _lignes = {};

  final List<String> _nomsJours = const [
    'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'
  ];

  late DateTime _lundi; // lundi de la semaine affichée
  final Map<String, int> _choix = {};      // date -> ligneId
  final Map<String, int> _trajetIds = {};  // date -> trajetId
  bool _planningExiste = false;
  bool _chargement = true;
  int _requete = 0; // ignore les réponses en retard

  DateTime get _aujourdhui {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  List<DateTime> get _jours => List.generate(
      7, (i) => DateTime(_lundi.year, _lundi.month, _lundi.day + i));

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _affiche(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _texteErreur(Object e) => e.toString().replaceFirst('Exception: ', '');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // départ : lundi de la semaine prochaine
    _lundi = DateTime(now.year, now.month, now.day + 8 - now.weekday);
    _chargerSemaine();
  }

  Future<void> _chargerSemaine() async {
    final id = ++_requete;
    setState(() {
      _chargement = true;
      _choix.clear();
      _trajetIds.clear();
      _planningExiste = false;
    });
    try {
      if (_lignes.isEmpty) {
        final lignes = await _service.getLignesAutorisees(_louagisteId);
        _lignes = {
          for (final l in lignes) l['id'] as int: l['villeDestination'] as String
        };
      }
      final planning = await _service.getPlanning(_louagisteId, _fmt(_lundi));
      if (id != _requete) return;
      if (planning != null) _remplirDepuis(planning);
    } catch (e) {
      if (id == _requete) _message(_texteErreur(e));
    }
    if (mounted && id == _requete) setState(() => _chargement = false);
  }

  void _remplirDepuis(Map<String, dynamic> planning) {
    _planningExiste = true;
    for (final j in planning['jours']) {
      _choix[j['date']] = j['ligneId'];
      _trajetIds[j['date']] = j['trajetId'];
    }
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
    // on ramène la date choisie au lundi de sa semaine
    _lundi = DateTime(date.year, date.month, date.day - (date.weekday - 1));
    _chargerSemaine();
  }

  Future<void> _valider() async {
    try {
      final planning =
      await _service.remplirPlan(_louagisteId, _fmt(_lundi), _choix);
      setState(() => _remplirDepuis(planning));
      _message('Planning confirmé');
    } catch (e) {
      _message(_texteErreur(e));
    }
  }

  Future<void> _changer(String date, int ligneId) async {
    if (!_planningExiste) {
      setState(() => _choix[date] = ligneId);
      return;
    }
    final trajetId = _trajetIds[date];
    if (trajetId == null) {
      _message('Aucun trajet ce jour-là');
      return;
    }
    try {
      await _service.changerLigne(trajetId, _louagisteId, ligneId);
      setState(() => _choix[date] = ligneId);
      _message('Ligne modifiée');
    } catch (e) {
      _message(_texteErreur(e));
    }
  }

  void _message(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  @override
  Widget build(BuildContext context) {
    final jours = _jours;
    final semainePassee = jours.last.isBefore(_aujourdhui);

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
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
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
                final passe = jours[i].isBefore(_aujourdhui);
                return ListTile(
                  title: Text(_nomsJours[i]),
                  subtitle: Text(date),
                  trailing: DropdownButton<int>(
                    value: _choix[date],
                    hint: Text(passe ? '—' : 'Choisir'),
                    items: _lignes.entries
                        .map((e) => DropdownMenuItem(
                        value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: passe ? null : (id) => _changer(date, id!),
                  ),
                );
              },
            ),
          ),
          if (!_chargement && !_planningExiste && semainePassee)
            const Center(child: Text('Aucun planning cette semaine')),
          if (!_chargement && !_planningExiste && !semainePassee)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Valider ma semaine'),
                onPressed: _choix.isEmpty ? null : _valider,
              ),
            ),
        ],
      ),
    );
  }
}