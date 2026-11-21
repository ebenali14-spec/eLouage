import '../services/heure_tunis.dart';

class Reservation {
  static const int delaiPropositionMin = 1; // = Reservation.DELAI_PROPOSITION_MIN du back

  final int id, numeroPlace;
  final int? trajetId; // null = liste d'attente (US19)
  final DateTime dateTrajet, dateReservation;
  // CONFIRMEE, PRESENTE, EMBARQUEE, ANNULEE, ABSENT, EN_ATTENTE, PROPOSEE
  final String statut;
  final String? stationDepart, stationArrivee, villeDestination, heureArrivee;
  final double? prix;
  final DateTime? dateProposition;

  Reservation({
    required this.id,
    required this.trajetId,
    required this.numeroPlace,
    required this.dateTrajet,
    required this.dateReservation,
    required this.statut,
    this.stationDepart,
    this.stationArrivee,
    this.villeDestination,
    this.heureArrivee,
    this.prix,
    this.dateProposition,
  });

  bool get enAttente => statut == 'EN_ATTENTE';
  bool get proposee => statut == 'PROPOSEE';

  // temps restant pour répondre à la proposition (null si pas une proposition)
  Duration? get tempsRestant {
    if (!proposee || dateProposition == null) return null;
    final fin = dateProposition!.add(const Duration(minutes: delaiPropositionMin));
    return fin.difference(HeureTunis.maintenant());
  }

  // "2026-11-20T10:15:30.123456" -> mêmes chiffres, marqués UTC comme HeureTunis
  static DateTime? _tunis(dynamic v) {
    if (v == null) return null;
    final d = DateTime.tryParse('$v');
    if (d == null) return null;
    return DateTime.utc(d.year, d.month, d.day, d.hour, d.minute, d.second);
  }

  factory Reservation.fromJson(Map<String, dynamic> j) => Reservation(
    id: j['id'],
    trajetId: j['trajetId'] as int?,
    numeroPlace: (j['numeroPlace'] as num?)?.toInt() ?? 0,
    dateTrajet: DateTime.parse(j['dateTrajet']),
    dateReservation: DateTime.parse(j['dateReservation']),
    statut: j['statut'],
    stationDepart: j['stationDepart'] as String?,
    stationArrivee: j['stationArrivee'] as String?,
    villeDestination: j['villeDestination'] as String?,
    heureArrivee: j['heureArrivee'] as String?,
    prix: (j['prix'] as num?)?.toDouble(),
    dateProposition: _tunis(j['dateProposition']),
  );
}