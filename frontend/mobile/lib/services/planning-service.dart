import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/config.dart';

class PlanningService {
  static const Map<String, String> _headers = {'Content-Type': 'application/json'};

  String get _url => '$baseUrl/api/plannings';

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
        .get(Uri.parse('$_url?louagisteId=$louagisteId&semaine=$semaine'))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) return jsonDecode(utf8.decode(res.bodyBytes));
    return null;
  }

  Future<Map<String, dynamic>> remplirPlan(
      int louagisteId, String debutSemaine, Map<String, int> lignesParJour) async {
    final res = await http
        .post(
      Uri.parse(_url),
      headers: _headers,
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
      headers: _headers,
      body: jsonEncode({'louagisteId': louagisteId, 'ligneId': ligneId}),
    )
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) throw Exception(_erreur(res));
  }

  Future<List<Map<String, dynamic>>> getLignesAutorisees(int louagisteId) async {
    final res = await http
        .get(Uri.parse('$baseUrl/api/louagistes/$louagisteId/lignes'))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) throw Exception(_erreur(res));
    return List<Map<String, dynamic>>.from(jsonDecode(utf8.decode(res.bodyBytes)));
  }
}