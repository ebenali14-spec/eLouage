import 'package:flutter/material.dart';
import '../services/passager_service.dart';
import '../theme/app_colors.dart';

class PlaintePage extends StatefulWidget {
  const PlaintePage({super.key});
  @override
  State<PlaintePage> createState() => _PlaintePageState();
}

class _PlaintePageState extends State<PlaintePage>
    with SingleTickerProviderStateMixin {
  final _service = PlainteService();
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final _cle = GlobalKey<FormState>();
  final _description = TextEditingController();

  static const _types = {
    'RETARD': 'Retard',
    'COMPORTEMENT': 'Comportement',
    'VEHICULE': 'Véhicule',
    'SECURITE': 'Sécurité',
    'AUTRE': 'Autre',
  };

  List<Map<String, dynamic>> _trajets = [];
  List<Map<String, dynamic>> _plaintes = [];
  int? _trajetId;
  String? _type;
  bool _chargement = true, _envoi = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _description.dispose();
    super.dispose();
  }

  void _message(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> _charger() async {
    try {
      final r = await Future.wait([_service.trajetsSignalables(), _service.mesPlaintes()]);
      if (!mounted) return;
      setState(() { _trajets = r[0]; _plaintes = r[1]; });
    } catch (e) {
      _message(messageErreur(e));
    }
    if (mounted) setState(() => _chargement = false);
  }

  Future<void> _envoyer() async {
    if (!_cle.currentState!.validate()) return;
    setState(() => _envoi = true);
    try {
      await _service.deposer(_trajetId!, _type!, _description.text.trim());
      if (!mounted) return;
      _message('Votre plainte a été envoyée.');
      _trajetId = null;
      _type = null;
      _description.clear();
      await _charger();
      if (mounted) _tabs.animateTo(1);
    } catch (e) {
      _message(messageErreur(e));
    }
    if (mounted) setState(() => _envoi = false);
  }

  String _libTrajet(Map<String, dynamic> t) =>
      '${t['ligne'] ?? 'Trajet'} · ${formaterDate(t['date'])}';

  Widget _formulaire() {
    if (_trajets.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Aucun trajet à signaler pour le moment.\n'
                'Vous pouvez déposer une plainte pour un trajet déjà effectué '
                '(une seule plainte par trajet).',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Form(
      key: _cle,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          DropdownButtonFormField<int>(
            value: _trajetId,
            isExpanded: true,
            decoration: const InputDecoration(
                labelText: 'Trajet concerné', border: OutlineInputBorder()),
            items: [
              for (final t in _trajets)
                DropdownMenuItem(
                  value: t['id'] as int,
                  child: Text(_libTrajet(t), overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => _trajetId = v),
            validator: (v) => v == null ? 'Choisissez un trajet' : null,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _type,
            decoration: const InputDecoration(
                labelText: 'Type de problème', border: OutlineInputBorder()),
            items: [
              for (final e in _types.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => setState(() => _type = v),
            validator: (v) => v == null ? 'Choisissez un type' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _description,
            maxLines: 6,
            maxLength: 1000,
            decoration: const InputDecoration(
                labelText: 'Description',
                alignLabelWithHint: true,
                border: OutlineInputBorder()),
            validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Décrivez le problème' : null,
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _envoi ? null : _envoyer,
              child: _envoi
                  ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Envoyer la plainte'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mesPlaintes() {
    if (_plaintes.isEmpty) {
      return const Center(child: Text("Vous n'avez déposé aucune plainte."));
    }
    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _plaintes.length,
        itemBuilder: (_, i) {
          final p = _plaintes[i];
          final lue = p['statut'] == 'LUE';
          final couleur = lue ? AppColors.success : AppColors.warning;
          final trajet = (p['trajet'] ?? {}) as Map;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text('${p['reference']}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: couleur.withAlpha(35),
                      border: Border.all(color: couleur),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(lue ? 'Lue par l\'administration' : 'Envoyée',
                        style: TextStyle(color: couleur, fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                ]),
                const SizedBox(height: 8),
                Text('${trajet['ligne'] ?? ''} · ${formaterDate(trajet['date'])}'),
                Text('Type : ${_types[p['type']] ?? p['type']}'),
                const SizedBox(height: 6),
                Text('${p['description']}',
                    style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                Text('Déposée le ${formaterDate(p['dateDepot'])}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ]),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Déposer une plainte'),
        bottom: TabBar(controller: _tabs, tabs: const [
          Tab(text: 'Nouvelle plainte'),
          Tab(text: 'Mes plaintes'),
        ]),
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(controller: _tabs, children: [_formulaire(), _mesPlaintes()]),
    );
  }
}