import 'dart:async';

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

  List<Reservation> _liste = [];
  bool _chargement = true, _erreur = false;
  int? _enCours; // id de la réservation en cours de traitement

  Timer? _tick;     // met à jour le compte à rebours chaque seconde
  Timer? _refresh;  // recharge la liste depuis le back

  @override
  void initState() {
    super.initState();
    _charger();

    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _liste.any((r) => r.proposee)) setState(() {});
    });
    // une proposition peut arriver à tout moment (annulation d'un autre passager...)
    _refresh = Timer.periodic(
        const Duration(seconds: 15), (_) => _charger(silencieux: true));
  }

  @override
  void dispose() {
    _tick?.cancel();
    _refresh?.cancel();
    super.dispose();
  }

  Future<void> _charger({bool silencieux = false}) async {
    if (!silencieux) {
      setState(() { _chargement = true; _erreur = false; });
    }
    try {
      final l = await _service.getReservations();
      if (!mounted) return;
      setState(() { _liste = l; _erreur = false; });
    } catch (_) {
      if (!silencieux && mounted) setState(() => _erreur = true);
    }
    if (mounted && _chargement) setState(() => _chargement = false);
  }

  void _message(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  Color _couleur(String statut) {
    switch (statut) {
      case 'CONFIRMEE': return AppColors.info;
      case 'PRESENTE': return AppColors.warning;
      case 'EMBARQUEE': return AppColors.success;
      case 'PROPOSEE': return AppColors.warning;
      case 'EN_ATTENTE': return AppColors.secondary;
      default: return AppColors.error; // ANNULEE, ABSENT
    }
  }

  String _libelle(String statut) {
    switch (statut) {
      case 'CONFIRMEE': return 'Confirmée';
      case 'PRESENTE': return 'Présente';
      case 'EMBARQUEE': return 'Embarquée';
      case 'PROPOSEE': return 'Place proposée';
      case 'EN_ATTENTE': return 'En attente';
      case 'ABSENT': return 'Absent';
      default: return 'Annulée';
    }
  }

  String _formater(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _compte(Duration d) {
    if (d.isNegative) return '00:00';
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _heure(String? h) => (h != null && h.length >= 5) ? h.substring(0, 5) : '';

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
      await _charger(silencieux: true);
      if (mounted) setState(() => _enCours = null);
    }
  }

  Future<void> _confirmerAnnulation(Reservation r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(r.enAttente ? 'Quitter la liste d\'attente ?' : 'Annuler la réservation ?'),
        content: Text(r.enAttente
            ? 'Vous ne serez plus proposé pour une place.'
            : 'La place ${r.numeroPlace} sera libérée.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Non')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Oui')),
        ],
      ),
    );
    if (ok == true) {
      _agir(r, () => _service.annuler(r.id),
          r.enAttente ? 'Vous avez quitté la liste d\'attente.' : 'Réservation annulée.');
    }
  }

  Future<void> _confirmerRefus(Reservation r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Refuser la place ?'),
        content: const Text(
            'La place sera proposée au passager suivant et vous '
                'quitterez la liste d\'attente. Vous devrez vous réinscrire.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Non')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Oui, refuser')),
        ],
      ),
    );
    if (ok == true) {
      _agir(r, () => _service.refuserProposition(r.id), 'Proposition refusée.');
    }
  }

  // ---------- Carte spéciale : une place est proposée (US19) ----------
  Widget _carteProposition(Reservation r) {
    final occupe = _enCours == r.id;
    final reste = r.tempsRestant ?? Duration.zero;
    final expiree = reste.isNegative || reste == Duration.zero;
    final couleur = expiree ? AppColors.error : AppColors.warning;

    final titre = (r.stationDepart != null && r.stationArrivee != null)
        ? '${r.stationDepart} → ${r.stationArrivee}'
        : (r.villeDestination != null ? 'Vers ${r.villeDestination}' : 'Trajet n°${r.trajetId}');

    return Card(
      color: couleur.withAlpha(20),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: couleur, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.event_seat, color: couleur),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Une place vous est proposée !',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold, color: couleur)),
            ),
          ]),
          const SizedBox(height: 10),
          Text(titre,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Date : ${_formater(r.dateTrajet)}'
              '${_heure(r.heureArrivee).isNotEmpty ? ' · ${_heure(r.heureArrivee)}' : ''}'),
          Text('Place n°${r.numeroPlace}'),
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.timer_outlined, size: 18, color: couleur),
            const SizedBox(width: 6),
            Text(
              expiree
                  ? 'Délai dépassé, la place va être proposée à un autre passager.'
                  : 'Répondez dans ${_compte(reste)}',
              style: TextStyle(fontWeight: FontWeight.w600, color: couleur),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  minimumSize: const Size.fromHeight(44),
                ),
                onPressed: (occupe || expiree) ? null : () => _confirmerRefus(r),
                child: const Text('Refuser'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(44),
                ),
                onPressed: (occupe || expiree)
                    ? null
                    : () => _agir(r, () => _service.accepterProposition(r.id),
                    'Place confirmée !'),
                child: occupe
                    ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Accepter'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  // ---------- Carte normale ----------
  Widget _carte(Reservation r) {
    if (r.proposee) return _carteProposition(r);

    final now = DateTime.now();
    final aujourdhui = DateTime(now.year, now.month, now.day);
    final confirmee = r.statut == 'CONFIRMEE';
    final peutPresence = confirmee && r.dateTrajet == aujourdhui;
    final peutAnnuler = confirmee || r.statut == 'PRESENTE' || r.enAttente;
    final occupe = _enCours == r.id;
    final couleur = _couleur(r.statut);

    final titre = r.enAttente
        ? 'Liste d\'attente${r.villeDestination != null ? ' → ${r.villeDestination}' : ''}'
        : (r.stationDepart != null && r.stationArrivee != null)
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
          Text(r.enAttente
              ? 'Date souhaitée : ${_formater(r.dateTrajet)}'
              : 'Date du trajet : ${_formater(r.dateTrajet)}'),
          if (r.enAttente)
            const Text('Une place vous sera proposée dès qu\'elle se libère.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary))
          else
            Text('Place : ${r.numeroPlace}'),
          if (r.villeDestination != null && !r.enAttente)
            Text('Destination : ${r.villeDestination}'),
          if (r.prix != null) Text('Prix : ${r.prix!.toStringAsFixed(1)} DT'),
          Text('Réservé le : ${_formater(r.dateReservation)}'),
          if (peutPresence || peutAnnuler) ...[
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              if (peutPresence)
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.location_on),
                    label: const Text('Je suis à la station'),
                    onPressed: occupe
                        ? null
                        : () => _agir(r, () => _service.signalerPresence(r.id),
                        'Présence signalée.'),
                  ),
                ),
              if (peutPresence && peutAnnuler) const SizedBox(width: 12),
              if (peutAnnuler)
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: occupe ? null : () => _confirmerAnnulation(r),
                    child: Text(r.enAttente ? 'Quitter la liste' : 'Annuler'),
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
    if (_chargement) return const Center(child: CircularProgressIndicator());

    if (_erreur) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Impossible de charger vos réservations.'),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _charger, child: const Text('Réessayer')),
        ]),
      );
    }

    // les propositions en premier : elles sont urgentes
    final liste = [..._liste]..sort((a, b) {
      if (a.proposee == b.proposee) return 0;
      return a.proposee ? -1 : 1;
    });

    return RefreshIndicator(
      onRefresh: () => _charger(silencieux: true),
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
  }
}