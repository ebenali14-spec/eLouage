import 'package:flutter/material.dart';
import '../services/attente_service.dart';

class AttentePage extends StatefulWidget {
  final String depart, destination;
  final DateTime date;
  const AttentePage({super.key, required this.depart,
    required this.destination, required this.date});

  @override
  State<AttentePage> createState() => _AttentePageState();
}

class _AttentePageState extends State<AttentePage> {
  final _service = AttenteService();

  // valeur envoyee au backend -> libelle affiche
  static const _plages = {
    'MATIN': 'Matin (avant 12h)',
    'APRES_MIDI': 'Après-midi (12h – 18h)',
    'SOIR': 'Soir (après 18h)',
  };

  final Set<String> _choisies = {};
  bool _envoi = false;

  String _formater(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  void _message(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  Future<void> _envoyer() async {
    setState(() => _envoi = true);
    try {
      final ligneId =
      await _service.trouverLigneId(widget.depart, widget.destination);
      if (ligneId == null) {
        throw Exception('Aucune ligne ${widget.depart} → ${widget.destination}.');
      }
      await _service.rejoindre(ligneId, widget.date, _choisies.toList());
      if (!mounted) return;
      _message('Vous êtes en liste d\'attente. Une place vous sera attribuée '
          'automatiquement dès qu\'un trajet compatible se libère.');
      Navigator.pop(context, true);
    } catch (e) {
      _message(e.toString().replaceFirst('Exception: ', ''));
    }
    if (mounted) setState(() => _envoi = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Liste d\'attente')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('${widget.depart} → ${widget.destination}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Date : ${_formater(widget.date)}'),
          const SizedBox(height: 24),
          const Text('À quelles heures pouvez-vous partir ?',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Vous pouvez en choisir plusieurs.',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          for (final e in _plages.entries)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(e.value),
              value: _choisies.contains(e.key),
              onChanged: _envoi
                  ? null
                  : (v) => setState(() {
                if (v == true) {
                  _choisies.add(e.key);
                } else {
                  _choisies.remove(e.key);
                }
              }),
            ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: (_choisies.isEmpty || _envoi) ? null : _envoyer,
            child: _envoi
                ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Rejoindre la liste d\'attente'),
          ),
        ],
      ),
    );
  }
}