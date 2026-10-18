class TrajetResultat {
  final int trajetId;
  final DateTime date;
  final String villeDepart, stationDepart, villeDestination, stationArrivee;
  final String louagisteNom, matricule;
  final double prix;
  final int placesLibres;

  TrajetResultat({
    required this.trajetId, required this.date,
    required this.villeDepart, required this.stationDepart,
    required this.villeDestination, required this.stationArrivee,
    required this.louagisteNom, required this.matricule,
    required this.prix, required this.placesLibres,
  });

  factory TrajetResultat.fromJson(Map<String, dynamic> j) => TrajetResultat(
    trajetId: j['trajetId'],
    date: DateTime.parse(j['date']),
    villeDepart: j['villeDepart'],
    stationDepart: j['stationDepart'],
    villeDestination: j['villeDestination'],
    stationArrivee: j['stationArrivee'],
    louagisteNom: j['louagisteNom'],
    matricule: j['matricule'],
    prix: (j['prix'] as num).toDouble(),
    placesLibres: j['placesLibres'],
  );
}