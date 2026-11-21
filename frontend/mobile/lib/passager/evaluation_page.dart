import 'package:flutter/material.dart';
import '../services/passager_service.dart';
import '../theme/app_colors.dart';

class EvaluationPage extends StatefulWidget {
  const EvaluationPage({super.key});
  @override
  State<EvaluationPage> createState() => _EvaluationPageState();
}

class _EvaluationPageState extends State<EvaluationPage> {
  final _service = EvaluationService();
  final _commentaire = TextEditingController();

  List<Map<String, dynamic>> _trajets = [];
  int? _trajetId;
  int _note = 0;
  bool _chargement = true, _envoi = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _commentaire.dispose();
    super.dispose();
  }

  void _message(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> _charger() async {
    try {
      final t = await _service.trajetsEvaluables();
      if (!mounted) return;
      setState(() => _trajets = t);
    } catch (e) {
      _message(messageErreur(e));
    }
    if (mounted) setState(() => _chargement = false);
  }

  Future<void> _envoyer() async {
    if (_trajetId == null) return _message('Choisissez un trajet.');
    if (_note == 0) return _message('Choisissez une note de 1 à 5.');

    setState(() => _envoi = true);
    try {
      await _service.evaluer(_trajetId!, _note, _commentaire.text);
      if (!mounted) return;
      _message('Merci pour votre évaluation !');
      _trajetId = null;
      _note = 0;
      _commentaire.clear();
      await _charger();
    } catch (e) {
      _message(messageErreur(e));
    }
    if (mounted) setState(() => _envoi = false);
  }

  String _libTrajet(Map<String, dynamic> t) =>
      '${t['destination'] ?? 'Trajet'} · ${formaterDate(t['date'])} · ${t['louagiste']}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Évaluer un louagiste')),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : _trajets.isEmpty
          ? const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Aucun trajet à évaluer.\n'
                'Vous pouvez évaluer un louagiste après un trajet où vous avez embarqué.',
            textAlign: TextAlign.center,
          ),
        ),
      )
          : ListView(
        padding: const EdgeInsets.all(24),
        children: [
          DropdownButtonFormField<int>(
            value: _trajetId,
            isExpanded: true,
            decoration: const InputDecoration(
                labelText: 'Trajet', border: OutlineInputBorder()),
            items: [
              for (final t in _trajets)
                DropdownMenuItem(
                  value: t['trajetId'] as int, // ici la clé est trajetId
                  child: Text(_libTrajet(t), overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => _trajetId = v),
          ),
          const SizedBox(height: 24),
          const Text('Votre note',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  iconSize: 40,
                  onPressed: _envoi ? null : () => setState(() => _note = i),
                  icon: Icon(
                    i <= _note ? Icons.star : Icons.star_border,
                    color: AppColors.accent,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _commentaire,
            maxLines: 4,
            maxLength: 1000,
            decoration: const InputDecoration(
                labelText: 'Commentaire (facultatif)',
                alignLabelWithHint: true,
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _envoi ? null : _envoyer,
              child: _envoi
                  ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Envoyer mon évaluation'),
            ),
          ),
        ],
      ),
    );
  }
}