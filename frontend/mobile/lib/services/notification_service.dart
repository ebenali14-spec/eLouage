import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mobile/config/config.dart';
import 'package:mobile/services/session_service.dart';

class NotificationService {
  // 10.0.2.2 = your PC's localhost, seen from the Android emulator.
  // On a real phone, use your PC's IP, or the same base URL as your other services.
  static const String _base = '$baseUrl/api';

  Future<Map<String, String>> _headers() async {
    final token = await SessionService.getToken();
    return {if (token != null) 'Authorization': 'Bearer $token'};
  }

  Future<List<Map<String, dynamic>>> lister() async {
    final id = await SessionService.getId();
    if (id == null) throw Exception('Session expirée, reconnectez-vous');
    final res = await http.get(
      Uri.parse('$_base/notifications?utilisateurId=$id'),
      headers: await _headers(),
    );
    if (res.statusCode != 200) {
      throw Exception('Impossible de charger les notifications');
    }
    return List<Map<String, dynamic>>.from(jsonDecode(utf8.decode(res.bodyBytes)));
  }

  Future<int> nonLues() async {
    final id = await SessionService.getId();
    if (id == null) return 0;
    try {
      final res = await http.get(
        Uri.parse('$_base/notifications/non-lues?utilisateurId=$id'),
        headers: await _headers(),
      );
      if (res.statusCode != 200) return 0;
      return (jsonDecode(res.body)['nonLues'] as num).toInt();
    } catch (_) {
      return 0; // no network: the badge simply stays at 0
    }
  }

  Future<void> marquerLue(int notifId) async {
    final id = await SessionService.getId();
    if (id == null) throw Exception('Session expirée, reconnectez-vous');
    final res = await http.put(
      Uri.parse('$_base/notifications/$notifId/lue?utilisateurId=$id'),
      headers: await _headers(),
    );
    if (res.statusCode != 200) {
      throw Exception('Impossible de marquer comme lue');
    }
  }
}