import 'package:flutter/material.dart';
import '../services/localisation_service.dart';
import 'resultats_page.dart';

class RecherchePage extends StatefulWidget {
  const RecherchePage({super.key});
  @override
  State<RecherchePage> createState() => _RecherchePageState();
}

class _RecherchePageState extends State<RecherchePage> {
  final _service = LocalisationService();
  List<String>? _villes;
  bool _erreur = false;
  String? _depart, _destination;
  DateTime? _date;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() { _erreur = false; _villes = null; });
    try {
      final v = await _service.getVilles();
      if (!mounted) return;
      setState(() => _villes = v);
    } catch (e) {
      if (!mounted) return;
      setState(() => _erreur = true);
    }
  }

  Future<void> _choisirDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year, now.month, now.day), // pas avant aujourd'hui
      lastDate: now.add(const Duration(days: 60)),
    );
    if (d != null) setState(() => _date = d);
  }

  String _formater(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Widget _liste(String label, String? valeur, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: valeur,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: _villes!.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final memeVille = _depart != null && _depart == _destination;
    final pret = _depart != null && _destination != null && _date != null && !memeVille;

    Widget corps;
    if (_erreur) {
      corps = Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Impossible de charger les villes.'),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _charger, child: const Text('Réessayer')),
        ]),
      );
    } else if (_villes == null) {
      corps = const Center(child: CircularProgressIndicator());
    } else {
      corps = ListView(padding: const EdgeInsets.all(24), children: [
        _liste('Ville de départ', _depart, (v) => setState(() => _depart = v)),
        const SizedBox(height: 16),
        _liste('Ville de destination', _destination, (v) => setState(() => _destination = v)),
        if (memeVille)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Le départ et la destination doivent être différents.',
                style: TextStyle(color: Colors.red)),
          ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          icon: const Icon(Icons.calendar_today),
          label: Text(_date == null ? 'Choisir une date' : _formater(_date!)),
          onPressed: _choisirDate,
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: pret
              ? () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ResultatsPage(
                  depart: _depart!, destination: _destination!, date: _date!),
            ),
          )
              : null,
          child: const Text('Rechercher'),
        ),
      ]);
    }

    return Scaffold(appBar: AppBar(title: const Text('Rechercher un trajet')), body: corps);
  }
}