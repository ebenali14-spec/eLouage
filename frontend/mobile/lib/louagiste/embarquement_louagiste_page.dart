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
  final Set<int> _coches = {}; // ids des réservations cochées
  bool _chargement = true;
  bool _envoi = false;

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
        _coches.clear();
      }
    } catch (e) {
      _message(e.toString().replaceFirst('Exception: ', ''));
    }
    if (mounted) setState(() => _chargement = false);
  }

  Future<void> _confirmer() async {
    setState(() => _envoi = true);
    int ok = 0;
    String? erreur;
    for (final id in _coches.toList()) {
      try {
        await _service.confirmerEmbarquement(id, _louagisteId);
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
                itemBuilder: (context, i) {
                  final r = _presents[i];
                  final id = r['id'] as int;
                  return CheckboxListTile(
                    title: Text('${r['passagerNom'] ?? 'Passager'}'),
                    subtitle: Text('Place ${r['numeroPlace']} · ${r['statut']}'),
                    value: _coches.contains(id),
                    onChanged: (coche) => setState(() {
                      coche! ? _coches.add(id) : _coches.remove(id);
                    }),
                  );
                },
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check),
              label: Text('Confirmer l\'embarquement (${_coches.length})'),
              onPressed: (_coches.isEmpty || _envoi) ? null : _confirmer,
            ),
          ),
        ],
      ),
    );
  }
}