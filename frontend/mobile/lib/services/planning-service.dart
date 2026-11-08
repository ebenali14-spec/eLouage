import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/config.dart';
import 'session_service.dart';

class PlanningService {
  String get _url => '$baseUrl/api/plannings';

  Future<Map<String, String>> _headers() async {
    final token = await SessionService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  String _erreur(http.Response res) {
    try {
      final corps = jsonDecode(utf8.decode(res.bodyBytes));
      return corps['message'] ?? 'Erreur ${res.statusCode}';
    } catch (_) {
      return 'Erreur ${res.statusCode}';
    }
  }

  // renvoie null si aucun planning pour cette semaine
  Future<Map<String, dynamic>?> getPlanning(int louagisteId, String semaine) async {
    final res = await http
        .get(Uri.parse('$_url?louagisteId=$louagisteId&semaine=$semaine'),
        headers: await _headers())
        .timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) return jsonDecode(utf8.decode(res.bodyBytes));
    // a real auth/server problem must not look like "no planning"
    if (res.statusCode == 401 || res.statusCode == 403 || res.statusCode >= 500) {
      throw Exception(_erreur(res));
    }
    return null;
  }

  // lignesParJour: date -> {ligneId, allerRetour, heureArrivee "HH:mm"}
  Future<Map<String, dynamic>> remplirPlan(int louagisteId, String debutSemaine,
      Map<String, Map<String, dynamic>> lignesParJour) async {
    final res = await http
        .post(
      Uri.parse(_url),
      headers: await _headers(),
      body: jsonEncode({
        'louagisteId': louagisteId,
        'dateDebutSemaine': debutSemaine,
        'lignesParJour': lignesParJour,
      }),
    )
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 201) throw Exception(_erreur(res));
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  Future<void> changerLigne(int trajetId, int louagisteId, int ligneId) async {
    final res = await http
        .put(
      Uri.parse('$_url/trajets/$trajetId/ligne'),
      headers: await _headers(),
      body: jsonEncode({'louagisteId': louagisteId, 'ligneId': ligneId}),
    )
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) throw Exception(_erreur(res));
  }

  // lignes autorisees sans compteurs ({id, villeDestination})
  Future<List<Map<String, dynamic>>> getLignesAutorisees(int louagisteId) async {
    final res = await http
        .get(Uri.parse('$baseUrl/api/louagistes/$louagisteId/lignes'),
        headers: await _headers())
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) throw Exception(_erreur(res));
    return List<Map<String, dynamic>>.from(jsonDecode(utf8.decode(res.bodyBytes)));
  }

  // US21 : lignes autorisees + nb de louagistes deja inscrits pour une date
  // [{id, depart, arrivee, minimumLouagistes, nbLouagistesInscrits, sousMinimum}]
  Future<List<Map<String, dynamic>>> getLignesAvecInscrits(
      int louagisteId, String date) async {
    final res = await http
        .get(
        Uri.parse(
            '$baseUrl/api/louagistes/$louagisteId/lignes/inscrits?date=$date'),
        headers: await _headers())
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) throw Exception(_erreur(res));
    return List<Map<String, dynamic>>.from(jsonDecode(utf8.decode(res.bodyBytes)));
  }
}