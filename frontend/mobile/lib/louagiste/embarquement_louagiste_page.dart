import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:mobile/config/config.dart';
import 'package:mobile/services/trajet_service.dart';
class EmbarquementLouagistePage extends StatefulWidget {
  const EmbarquementLouagistePage({super.key});

  @override
  State<EmbarquementLouagistePage> createState() => _EmbarquementLouagistePageState();
}

class _EmbarquementLouagistePageState extends State<EmbarquementLouagistePage> {
  final _service = TrajetService();
  final int _louagisteId = LouagisteId;

  Map<String, dynamic>? _trajet;
  List<Map<String, dynamic>> _presents = [];
  final Set<int> _embarques = {}; // index des passagers cochés
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      _trajet = await _service.trajetDuJour(_louagisteId);
      if (_trajet != null) {
        _presents = await _service.getPresents(_trajet!['trajetId'], _louagisteId);
        _embarques.clear();
      }
    } catch (e) {
      _message(e.toString().replaceFirst('Exception: ', ''));
    }
    if (mounted) setState(() => _chargement = false);
  }

  void _message(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement) return const Center(child: CircularProgressIndicator());

    if (_trajet == null) {
      return const Center(child: Text('Aucun trajet prévu aujourd\'hui'));
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Passagers présents',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _charger,
              child: _presents.isEmpty
                  ? ListView(children: const [
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Aucun passager présent pour le moment'),
                ),
              ])
                  : ListView.builder(
                itemCount: _presents.length,
                itemBuilder: (context, i) => CheckboxListTile(
                  title: Text('${_presents[i]['nomPassager'] ?? 'Passager'}'),
                  value: _embarques.contains(i),
                  onChanged: (coche) => setState(() {
                    coche! ? _embarques.add(i) : _embarques.remove(i);
                  }),
                ),
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check),
              label: Text('Confirmer l\'embarquement (${_embarques.length})'),
              onPressed: _embarques.isEmpty
                  ? null
                  : () {
                // plus tard : endpoint de confirmation d'embarquement
              },
            ),
          ),
        ],
      ),
    );
  }
}