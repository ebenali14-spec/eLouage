class Reservation {
  final int id, numeroPlace;
  final int? trajetId;
  final DateTime dateTrajet, dateReservation;
  final String statut; // CONFIRMEE, PRESENTE, EMBARQUEE, ANNULEE
  final String? stationDepart, stationArrivee, villeDestination; // si le back les envoie
  final double? prix;

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
    this.prix,
  });

  bool get enAttente => statut == 'EN_ATTENTE';

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
    prix: (j['prix'] as num?)?.toDouble(),
  );
}