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

  late final List<DateTime> _jours;
  final Map<String, int> _choix = {};      // date -> ligneId
  final Map<String, int> _trajetIds = {};  // date -> trajetId (une fois le planning créé)
  bool _planningExiste = false;
  bool _chargement = true;

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _texteErreur(Object e) => e.toString().replaceFirst('Exception: ', '');

  @override
  void initState() {
    super.initState();
    // lundi de la semaine prochaine
    final now = DateTime.now();
    final lundi = DateTime(now.year, now.month, now.day)
        .add(Duration(days: 8 - now.weekday));
    _jours = List.generate(7, (i) => lundi.add(Duration(days: i)));
    _charger();
  }

  Future<void> _charger() async {
    try {
      final lignes = await _service.getLignesAutorisees(_louagisteId);
      _lignes = {
        for (final l in lignes) l['id'] as int: l['villeDestination'] as String
      };
      final planning = await _service.getPlanning(_louagisteId, _fmt(_jours.first));
      if (planning != null) _remplirDepuis(planning);
    } catch (e) {
      _message(_texteErreur(e));
    }
    if (mounted) setState(() => _chargement = false);
  }

  void _remplirDepuis(Map<String, dynamic> planning) {
    _planningExiste = true;
    for (final j in planning['jours']) {
      _choix[j['date']] = j['ligneId'];
      _trajetIds[j['date']] = j['trajetId'];
    }
  }

  Future<void> _valider() async {
    try {
      final planning = await _service.remplirPlan(
          _louagisteId, _fmt(_jours.first), _choix);
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
    try {
      await _service.changerLigne(_trajetIds[date]!, _louagisteId, ligneId);
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
    if (_chargement) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ma semaine',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _jours.length,
              itemBuilder: (context, i) {
                final date = _fmt(_jours[i]);
                return ListTile(
                  title: Text(_nomsJours[i]),
                  subtitle: Text(date),
                  trailing: DropdownButton<int>(
                    value: _choix[date],
                    hint: const Text('Choisir'),
                    items: _lignes.entries
                        .map((e) => DropdownMenuItem(
                        value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (id) => _changer(date, id!),
                  ),
                );
              },
            ),
          ),
          if (!_planningExiste)
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