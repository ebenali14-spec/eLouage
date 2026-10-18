class TrajetResultat {
  final int trajetId;
  final DateTime date;
  final String villeDepart, villeDestination, louagisteNom, matricule;
  final double prix;
  final int placesLibres;

  TrajetResultat({
    required this.trajetId, required this.date,
    required this.villeDepart, required this.villeDestination,
    required this.louagisteNom, required this.matricule,
    required this.prix, required this.placesLibres,
  });

  factory TrajetResultat.fromJson(Map<String, dynamic> j) => TrajetResultat(
    trajetId: j['trajetId'],
    date: DateTime.parse(j['date']),
    villeDepart: j['villeDepart'],
    villeDestination: j['villeDestination'],
    louagisteNom: j['louagisteNom'],
    matricule: j['matricule'],
    prix: (j['prix'] as num).toDouble(),
    placesLibres: j['placesLibres'],
  );
}