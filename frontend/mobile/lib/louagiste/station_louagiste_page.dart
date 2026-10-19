import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:mobile/services/trajet_service.dart';
import 'package:mobile/config/config.dart';
class StationLouagistePage extends StatefulWidget {
  const StationLouagistePage({super.key});

  @override
  State<StationLouagistePage> createState() => _StationLouagistePageState();
}

class _StationLouagistePageState extends State<StationLouagistePage> {
  final _service = TrajetService();
  final int _louagisteId = LouagisteId;

  Map<String, dynamic>? _trajet; // trajet d'aujourd'hui
  List<Map<String, dynamic>> _file = [];
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
        _file = await _service.getFile(_trajet!['ligneId']);
      }
    } catch (e) {
      _message('Serveur injoignable');
    }
    if (mounted) setState(() => _chargement = false);
  }

  Future<void> _declarerPresence() async {
    try {
      await _service.checkIn(_trajet!['trajetId'], _louagisteId);
      await _charger(); // la place est calculée par le backend
      _message('Présence déclarée');
    } catch (e) {
      _message(e.toString().replaceFirst('Exception: ', ''));
    }
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

    final maPlace = _file.indexWhere((f) => f['louagisteId'] == _louagisteId);
    final present = maPlace != -1;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            present ? 'Votre place : ${maPlace + 1}' : 'Vous n\'êtes pas dans la file',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 24),
          if (!present)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.location_on),
                label: const Text('Je suis arrivé à la station'),
                onPressed: _declarerPresence,
              ),
            ),
          const SizedBox(height: 24),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _charger,
              child: ListView.builder(
                itemCount: _file.length,
                itemBuilder: (context, i) => ListTile(
                  leading: CircleAvatar(child: Text('${i + 1}')),
                  title: Text('${_file[i]['nomLouagiste'] ?? 'Louagiste'}'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}