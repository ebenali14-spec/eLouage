import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/config.dart';
import 'session_service.dart';

class AttenteService {
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

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // id de la ligne dont le depart et la destination sont ceux choisis (sens exact)
  // renvoie null si aucune ligne
  Future<int?> trouverLigneId(String depart, String destination) async {
    final uri = Uri.parse('$baseUrl/api/lignes/trouver').replace(
      queryParameters: {'depart': depart, 'destination': destination},
    );
    final res = await http
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) throw Exception(_erreur(res));
    final liste = jsonDecode(utf8.decode(res.bodyBytes)) as List;
    if (liste.isEmpty) return null;
    return liste.first['id'] as int;
  }

  // plages : MATIN, APRES_MIDI, SOIR
  Future<void> rejoindre(int ligneId, DateTime date, List<String> plages) async {
    final passagerId = await SessionService.getId();
    if (passagerId == null) throw Exception('Session expirée, reconnectez-vous');
    final res = await http
        .post(
      Uri.parse('$baseUrl/api/reservations/attente'),
      headers: await _headers(),
      body: jsonEncode({
        'passagerId': passagerId,
        'ligneId': ligneId,
        'date': _fmt(date),
        'plages': plages,
      }),
    )
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 201) throw Exception(_erreur(res));
  }
}