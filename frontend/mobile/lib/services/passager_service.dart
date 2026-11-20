import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/config.dart';
import 'session_service.dart';

class ApiException implements Exception {
  final int code;
  final String message;
  ApiException(this.code, this.message);
  @override
  String toString() => message;
}

String messageErreur(Object e) =>
    e is ApiException ? e.message : 'Impossible de joindre le serveur.';

// "2026-11-20" -> "20/11/2026"
String formaterDate(dynamic iso) {
  final d = DateTime.tryParse('$iso');
  if (d == null) return '';
  String p(int x) => x.toString().padLeft(2, '0');
  return '${p(d.day)}/${p(d.month)}/${d.year}';
}

class _Api {
  static const _delai = Duration(seconds: 10);

  static Future<Map<String, String>> _headers() async {
    final token = await SessionService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<dynamic> get(String chemin) async => _traiter(await http
      .get(Uri.parse('$baseUrl$chemin'), headers: await _headers())
      .timeout(_delai));

  static Future<dynamic> post(String chemin, Map<String, dynamic> body) async =>
      _traiter(await http
          .post(Uri.parse('$baseUrl$chemin'),
          headers: await _headers(), body: jsonEncode(body))
          .timeout(_delai));

  static Future<dynamic> put(String chemin, Map<String, dynamic> body) async =>
      _traiter(await http
          .put(Uri.parse('$baseUrl$chemin'),
          headers: await _headers(), body: jsonEncode(body))
          .timeout(_delai));

  static dynamic _traiter(http.Response r) {
    dynamic corps;
    try {
      final texte = utf8.decode(r.bodyBytes);
      corps = texte.isEmpty ? null : jsonDecode(texte);
    } catch (_) {}

    if (r.statusCode >= 200 && r.statusCode < 300) return corps;
    if (r.statusCode == 401) {
      throw ApiException(401, 'Session expirée, reconnectez-vous.');
    }
    var message = 'Erreur ${r.statusCode}';
    if (corps is Map) {
      final m = corps['message'] ?? corps['erreur']; // 2 formats côté back
      if (m is String && m.isNotEmpty) message = m;
    }
    throw ApiException(r.statusCode, message);
  }
}

List<Map<String, dynamic>> _liste(dynamic d) =>
    List<Map<String, dynamic>>.from(d as List);

// ---------- US26 ----------
class ProfilService {
  Future<Map<String, dynamic>> consulter() async =>
      Map<String, dynamic>.from(await _Api.get('/api/passagers/profil'));

  Future<Map<String, dynamic>> modifier(Map<String, dynamic> champs) async =>
      Map<String, dynamic>.from(await _Api.put('/api/passagers/profil', champs));
}

// ---------- US24 ----------
class PlainteService {
  Future<List<Map<String, dynamic>>> trajetsSignalables() async =>
      _liste(await _Api.get('/api/passagers/plaintes/trajets'));

  Future<List<Map<String, dynamic>>> mesPlaintes() async =>
      _liste(await _Api.get('/api/passagers/plaintes'));

  Future<void> deposer(int trajetId, String type, String description) =>
      _Api.post('/api/passagers/plaintes', {
        'trajetId': trajetId,
        'type': type,
        'description': description,
      });
}

// ---------- US23 ----------
class EvaluationService {
  Future<List<Map<String, dynamic>>> trajetsEvaluables() async =>
      _liste(await _Api.get('/api/passagers/evaluations/trajets'));

  Future<Map<String, dynamic>> evaluer(
      int trajetId, int note, String? commentaire) async =>
      Map<String, dynamic>.from(await _Api.post('/api/passagers/evaluations', {
        'trajetId': trajetId,
        'note': note,
        if (commentaire != null && commentaire.trim().isNotEmpty)
          'commentaire': commentaire.trim(),
      }));
}