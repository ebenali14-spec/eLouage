class PlaceEtat {
  final int numero;
  final bool libre;
  PlaceEtat(this.numero, this.libre);
  factory PlaceEtat.fromJson(Map<String, dynamic> j) => PlaceEtat(j['numero'], j['libre']);
}

class EtatPlaces {
  final int placesLibres;
  final List<PlaceEtat> places;
  EtatPlaces(this.placesLibres, this.places);
  factory EtatPlaces.fromJson(Map<String, dynamic> j) => EtatPlaces(
      j['placesLibres'],
      (j['places'] as List).map((p) => PlaceEtat.fromJson(p)).toList());
}