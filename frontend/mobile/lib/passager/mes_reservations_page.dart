import 'package:flutter/material.dart';
import '../models/reservation.dart';
import '../services/reservation_service.dart';
import '../theme/app_colors.dart';

class MesReservationsPage extends StatefulWidget {
  const MesReservationsPage({super.key});
  @override
  State<MesReservationsPage> createState() => _MesReservationsPageState();
}

class _MesReservationsPageState extends State<MesReservationsPage> {
  final _service = ReservationService();
  late Future<List<Reservation>> _futur;
  int? _enCours; // id de la réservation en cours de traitement

  @override
  void initState() {
    super.initState();
    _futur = _service.getReservations();
  }

  void _message(String texte) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));

  Color _couleur(String statut) {
    switch (statut) {
      case 'CONFIRMEE': return AppColors.info;
      case 'PRESENTE': return AppColors.warning;
      case 'EMBARQUEE': return AppColors.success;
      default: return AppColors.error; // ANNULEE
    }
  }

  String _libelle(String statut) {
    switch (statut) {
      case 'CONFIRMEE': return 'Confirmée';
      case 'PRESENTE': return 'Présente';
      case 'EMBARQUEE': return 'Embarquée';
      default: return 'Annulée';
    }
  }

  String _formater(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  // Exécute une action, affiche le résultat, puis recharge la liste depuis le back
  Future<void> _agir(Reservation r, Future<void> Function() action, String succes) async {
    setState(() => _enCours = r.id);
    try {
      await action();
      if (!mounted) return;
      _message(succes);
    } on ReservationException catch (e) {
      if (!mounted) return;
      _message(e.message.isNotEmpty ? e.message : 'Action impossible (erreur ${e.code}).');
    } catch (_) {
      if (!mounted) return;
      _message('Impossible de joindre le serveur.');
    } finally {
      if (mounted) {
        setState(() {
          _enCours = null;
          _futur = _service.getReservations();
        });
      }
    }
  }

  Future<void> _confirmerAnnulation(Reservation r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Annuler la réservation ?'),
        content: Text('La place ${r.numeroPlace} sera libérée.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Non')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Oui, annuler')),
        ],
      ),
    );
    if (ok == true) {
      _agir(r, () => _service.annuler(r.id), 'Réservation annulée.');
    }
  }

  Widget _carte(Reservation r) {
    final now = DateTime.now();
    final aujourdhui = DateTime(now.year, now.month, now.day);
    final confirmee = r.statut == 'CONFIRMEE';
    final peutPresence = confirmee && r.dateTrajet == aujourdhui;
    final peutAnnuler = confirmee || r.statut == 'PRESENTE';final occupe = _enCours == r.id;
    final couleur = _couleur(r.statut);

    final titre = (r.stationDepart != null && r.stationArrivee != null)
        ? '${r.stationDepart} → ${r.stationArrivee}'
        : 'Trajet n°${r.trajetId}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Text(titre,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: couleur.withAlpha(35),
                border: Border.all(color: couleur),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(_libelle(r.statut),
                  style: TextStyle(color: couleur, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 8),
          Text('Date du trajet : ${_formater(r.dateTrajet)}'),
          Text('Place : ${r.numeroPlace}'),
          if (r.villeDestination != null) Text('Destination : ${r.villeDestination}'),
          if (r.prix != null) Text('Prix : ${r.prix!.toStringAsFixed(1)} DT'),
          Text('Réservé le : ${_formater(r.dateReservation)}'),
          if (peutPresence || peutAnnuler) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [

              if (peutPresence && peutAnnuler)
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue, // ou ta couleur bleue : AppColors.primary
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.location_on),
                    label: const Text('Je suis à la station'),
                    onPressed: occupe
                        ? null
                        : () => _agir(r, () => _service.signalerPresence(r.id),
                        'Présence signalée.'),
                  ),
                ),
              if (peutAnnuler)
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error, // rouge
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: occupe ? null : () => _confirmerAnnulation(r),
                    child: const Text('Annuler'),
                  ),
                ),
            ]),
          ],
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Reservation>>(
      future: _futur,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Impossible de charger vos réservations.'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => setState(() => _futur = _service.getReservations()),
                child: const Text('Réessayer'),
              ),
            ]),
          );
        }
        final liste = snapshot.data!;
        return RefreshIndicator(
          onRefresh: () async {
            final f = _service.getReservations();
            setState(() => _futur = f);
            try { await f; } catch (_) {}
          },
          child: liste.isEmpty
              ? ListView(children: const [
            SizedBox(height: 120),
            Center(child: Text('Vous n\'avez aucune réservation.')),
          ])
              : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: liste.length,
            itemBuilder: (context, i) => _carte(liste[i]),
          ),
        );
      },
    );
  }
}