import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/config.dart';
import 'session_service.dart';

// US27 : les trajets du louagiste connecté, sa présence et son retour.
// La liste utilise le token ; la présence et le retour envoient l'id dans l'adresse.
class MesTrajetsService {
  String get _url => '$baseUrl/api/louagistes/mes-trajets';

  // le token est ajouté dans l'en-tête de chaque requête
  Future<Map<String, String>> _entete() async {
    final token = await SessionService.getToken();
    return {if (token != null) 'Authorization': 'Bearer $token'};
  }

  // transforme une erreur HTTP en texte lisible pour l'utilisateur
  String _erreur(http.Response res) {
    if (res.statusCode == 401) return 'Session expirée, reconnectez-vous.';
    if (res.statusCode == 403) {
      return "Accès refusé : ce compte n'est pas un louagiste.";
    }
    try {
      final corps = jsonDecode(utf8.decode(res.bodyBytes));
      return corps['message'] ?? corps['erreur'] ?? 'Erreur ${res.statusCode}';
    } catch (_) {
      return 'Erreur ${res.statusCode}';
    }
  }

  // GET /api/louagistes/mes-trajets
  Future<List<Map<String, dynamic>>> lister() async {
    final res = await http
        .get(Uri.parse(_url), headers: await _entete())
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) throw Exception(_erreur(res));
    return List<Map<String, dynamic>>.from(
        jsonDecode(utf8.decode(res.bodyBytes)));
  }

  // POST sans corps, utilisé par les deux actions ci-dessous
  Future<void> _posterUrl(String url) async {
    final res = await http
        .post(Uri.parse(url), headers: await _entete())
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200 &&
        res.statusCode != 201 &&
        res.statusCode != 204) {
      throw Exception(_erreur(res));
    }
  }

  // POST /api/trajets/{id}/check-in?louagisteId=...
  Future<void> declarerPresence(int trajetId) async {
    final id = await SessionService.getId();
    await _posterUrl('$baseUrl/api/trajets/$trajetId/check-in?louagisteId=$id');
  }

  // POST /api/trajets/{id}/retour?louagisteId=...
  Future<void> declarerRetour(int trajetId) async {
    final id = await SessionService.getId();
    await _posterUrl('$baseUrl/api/trajets/$trajetId/retour?louagisteId=$id');
  }

}