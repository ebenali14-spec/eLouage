import 'package:flutter/material.dart';
import '../models/trajet_resultat.dart';
import '../services/trajet_service.dart';
import '../theme/app_colors.dart';
import 'detail_trajet_page.dart';

class ResultatsPage extends StatefulWidget {
  final String depart, destination;
  final DateTime date;
  const ResultatsPage({super.key, required this.depart,
    required this.destination, required this.date});

  @override
  State<ResultatsPage> createState() => _ResultatsPageState();
}

class _ResultatsPageState extends State<ResultatsPage> {
  final _service = TrajetService();
  late Future<List<TrajetResultat>> _futur;

  Future<List<TrajetResultat>> _lancer() =>
      _service.rechercher(widget.depart, widget.destination, widget.date);

  @override
  void initState() {
    super.initState();
    _futur = _lancer();
  }

  String _formater(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Widget _carte(TrajetResultat t) {
    final complet = t.placesLibres == 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${t.villeDepart} → ${t.villeDestination}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Départ : ${t.stationDepart}'),
          Text('Arrivée : ${t.stationArrivee}'),
          Text('Date : ${_formater(t.date)}'),
          Text('Louagiste : ${t.louagisteNom} (${t.matricule})'),
          Text('Prix : ${t.prix.toStringAsFixed(1)} DT'),
          const SizedBox(height: 8),
          Text(
            complet ? 'Aucune place restante' : '${t.placesLibres} place(s) restante(s)',
            style: TextStyle(
                color: complet ? AppColors.error : AppColors.success,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: complet
                  ? null
                  : () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => DetailTrajetPage(trajet: t)),
                );
                if (!mounted) return;
                setState(() => _futur = _lancer()); // met à jour les places restantes
              },
              child: Text(complet ? 'Complet' : 'Réserver'),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.depart} → ${widget.destination}')),
      body: FutureBuilder<List<TrajetResultat>>(
        future: _futur,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Une erreur est survenue.'),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => setState(() => _futur = _lancer()),
                  child: const Text('Réessayer'),
                ),
              ]),
            );
          }
          final trajets = snapshot.data!;
          if (trajets.isEmpty) {
            return const Center(child: Text('Aucun trajet pour cette date.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: trajets.length,
            itemBuilder: (context, i) => _carte(trajets[i]),
          );
        },
      ),
    );
  }
}