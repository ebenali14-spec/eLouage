import 'package:flutter/material.dart';
import '../models/etat_places.dart';
import '../models/trajet_resultat.dart';
import '../services/reservation_service.dart';
import '../services/trajet_service.dart';
import '../theme/app_colors.dart';

class DetailTrajetPage extends StatefulWidget {
  final TrajetResultat trajet;
  const DetailTrajetPage({super.key, required this.trajet});

  @override
  State<DetailTrajetPage> createState() => _DetailTrajetPageState();
}

class _DetailTrajetPageState extends State<DetailTrajetPage> {
  final _trajetService = TrajetService();
  final _reservationService = ReservationService();
  late Future<EtatPlaces> _futur;
  int? _placeChoisie;
  bool _envoi = false;

  @override
  void initState() {
    super.initState();
    _futur = _trajetService.getEtatPlaces(widget.trajet.trajetId);
  }

  void _recharger() {
    setState(() {
      _placeChoisie = null;
      _futur = _trajetService.getEtatPlaces(widget.trajet.trajetId);
    });
  }

  void _message(String texte) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  Future<void> _reserver() async {
    setState(() => _envoi = true);
    try {
      await _reservationService.reserver(widget.trajet.trajetId, _placeChoisie!);
      if (!mounted) return;
      _message('Place $_placeChoisie réservée avec succès !');
      Navigator.pop(context, true);
    } on ReservationException catch (e) {
      if (!mounted) return;
      if (e.message.isNotEmpty) {
        _message(e.message);
      } else if (e.code == 409) {
        _message('Réservation impossible : la place vient d\'être prise '
            'ou vous avez déjà réservé ce trajet.');
      } else {
        _message('Réservation impossible (erreur ${e.code}).');
      }
      if (e.code == 409) _recharger();
    } catch (_) {
      if (!mounted) return;
      _message('Impossible de joindre le serveur.');
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  String _formater(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Widget _infos() {
    final t = widget.trajet;
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
        ]),
      ),
    );
  }

  Widget _chauffeur() {
    return SizedBox(
      width: 72,
      child: Column(children: [
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(
              color: AppColors.textSecondary, borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.airline_seat_recline_normal, color: Colors.white),
        ),
        const SizedBox(height: 4),
        const Text('Chauffeur', style: TextStyle(fontSize: 12)),
      ]),
    );
  }

  Widget _siege(PlaceEtat p) {
    final choisie = _placeChoisie == p.numero;
    final Color fond = !p.libre
        ? Colors.grey.shade400
        : choisie ? AppColors.primary : AppColors.success;
    return GestureDetector(
      onTap: p.libre ? () => setState(() => _placeChoisie = p.numero) : null,
      child: SizedBox(
        width: 72,
        child: Column(children: [
          Container(
            width: 60, height: 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fond,
              borderRadius: BorderRadius.circular(10),
              border: choisie ? Border.all(color: AppColors.textPrimary, width: 3) : null,
            ),
            child: Text('${p.numero}',
                style: const TextStyle(
                    color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 4),
          Text(p.libre ? '' : 'Réservée',
              style: const TextStyle(fontSize: 12, color: AppColors.error)),
        ]),
      ),
    );
  }

  Widget _rangee(List<Widget> sieges) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: sieges),
  );

  Widget _schema(EtatPlaces etat) {
    final par = {for (final p in etat.places) p.numero: p};
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.textSecondary, width: 2),
      ),
      child: Column(children: [
        _rangee([_chauffeur(), _siege(par[1]!), _siege(par[2]!)]),
        const Divider(height: 24),
        _rangee([_siege(par[3]!), _siege(par[4]!), _siege(par[5]!)]),
        _rangee([_siege(par[6]!), _siege(par[7]!), _siege(par[8]!)]),
      ]),
    );
  }

  Widget _legende() {
    Widget pastille(Color c, String texte) => Row(children: [
      Container(width: 14, height: 14,
          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 6),
      Text(texte, style: const TextStyle(fontSize: 12)),
    ]);
    return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      pastille(AppColors.success, 'Libre'),
      pastille(AppColors.primary, 'Ma place'),
      pastille(Colors.grey.shade400, 'Réservée'),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Réserver une place')),
      body: FutureBuilder<EtatPlaces>(
        future: _futur,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Impossible de charger les places.'),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: _recharger, child: const Text('Réessayer')),
              ]),
            );
          }
          final etat = snapshot.data!;
          return Column(children: [
            Expanded(
              child: ListView(padding: const EdgeInsets.all(16), children: [
                _infos(),
                const SizedBox(height: 16),
                Text('${etat.placesLibres} place(s) libre(s) — choisissez la vôtre',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                _schema(etat),
                const SizedBox(height: 16),
                _legende(),
              ]),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_placeChoisie == null || _envoi) ? null : _reserver,
                    child: _envoi
                        ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_placeChoisie == null
                        ? 'Choisissez une place'
                        : 'Réserver la place $_placeChoisie'),
                  ),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}