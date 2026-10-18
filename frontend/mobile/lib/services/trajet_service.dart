import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/config.dart';
import '../models/trajet_resultat.dart';
import '../models/etat_places.dart';

class TrajetService {
  // côté passager

  Future<List<TrajetResultat>> rechercher(
      String depart, String destination, DateTime date) async {
    final uri = Uri.parse('$baseUrl/api/lignes/recherche').replace(
      queryParameters: {
        'depart': depart,
        'destination': destination,
        'date': date.toIso8601String().substring(0, 10), // yyyy-MM-dd
      },
    );
    final reponse = await http.get(uri).timeout(const Duration(seconds: 10));
    if (reponse.statusCode != 200) {
      throw Exception('Erreur ${reponse.statusCode}');
    }
    final liste = jsonDecode(utf8.decode(reponse.bodyBytes)) as List;
    return liste.map((e) => TrajetResultat.fromJson(e)).toList();
  }

  Future<EtatPlaces> getEtatPlaces(int trajetId) async {
    final reponse = await http
        .get(Uri.parse('$baseUrl/api/lignes/trajets/$trajetId/places'))
        .timeout(const Duration(seconds: 10));
    if (reponse.statusCode != 200) throw Exception('Erreur ${reponse.statusCode}');
    return EtatPlaces.fromJson(jsonDecode(utf8.decode(reponse.bodyBytes)));
  }

  // côté louagiste

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _erreur(http.Response res) {
    try {
      final corps = jsonDecode(utf8.decode(res.bodyBytes));
      return corps['message'] ?? 'Erreur ${res.statusCode}';
    } catch (_) {
      return 'Erreur ${res.statusCode}';
    }
  }

  // trajet d'aujourd'hui, pris dans le planning de la semaine en cours
  // renvoie null s'il n'y a pas de trajet aujourd'hui
  Future<Map<String, dynamic>?> trajetDuJour(int louagisteId) async {
    final aujourdhui = _fmt(DateTime.now());
    final res = await http
        .get(Uri.parse(
        '$baseUrl/api/plannings?louagisteId=$louagisteId&semaine=$aujourdhui'))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return null;
    final planning = jsonDecode(utf8.decode(res.bodyBytes));
    for (final j in planning['jours']) {
      if (j['date'] == aujourdhui) return Map<String, dynamic>.from(j);
    }
    return null;
  }

  Future<void> checkIn(int trajetId, int louagisteId) async {
    final res = await http
        .post(Uri.parse(
        '$baseUrl/api/trajets/$trajetId/check-in?louagisteId=$louagisteId'))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(_erreur(res));
    }
  }

  Future<List<Map<String, dynamic>>> getFile(int ligneId) async {
    final res = await http
        .get(Uri.parse(
        '$baseUrl/api/trajets/file?ligneId=$ligneId&date=${_fmt(DateTime.now())}'))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) throw Exception(_erreur(res));
    return List<Map<String, dynamic>>.from(jsonDecode(utf8.decode(res.bodyBytes)));
  }

  Future<List<Map<String, dynamic>>> getPresents(int trajetId, int louagisteId) async {
    final res = await http
        .get(Uri.parse(
        '$baseUrl/api/trajets/$trajetId/presents?louagisteId=$louagisteId'))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) throw Exception(_erreur(res));
    return List<Map<String, dynamic>>.from(jsonDecode(utf8.decode(res.bodyBytes)));
  }
}