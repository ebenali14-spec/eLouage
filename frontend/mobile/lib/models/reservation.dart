class Reservation {
  final int id, trajetId, numeroPlace;
  final DateTime dateTrajet, dateReservation;
  final String statut; // CONFIRMEE, PRESENTE, EMBARQUEE, ANNULEE
  final String? stationDepart, stationArrivee, villeDestination; // si le back les envoie
  final double? prix;

  Reservation({
    required this.id, required this.trajetId, required this.numeroPlace,
    required this.dateTrajet, required this.dateReservation, required this.statut,
    this.stationDepart, this.stationArrivee, this.villeDestination, this.prix,
  });

  factory Reservation.fromJson(Map<String, dynamic> j) => Reservation(
    id: j['id'],
    trajetId: j['trajetId'],
    numeroPlace: j['numeroPlace'],
    dateTrajet: DateTime.parse(j['dateTrajet']),
    dateReservation: DateTime.parse(j['dateReservation']),
    statut: j['statut'],
    stationDepart: j['stationDepart'] as String?,
    stationArrivee: j['stationArrivee'] as String?,
    villeDestination: j['villeDestination'] as String?,
    prix: (j['prix'] as num?)?.toDouble(),
  );
}