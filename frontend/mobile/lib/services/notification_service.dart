
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mobile/config/config.dart';
import 'package:mobile/services/session_service.dart';

class NotificationService {
  static const String _base = '$baseUrl/api';

  Future<Map<String, String>> _headers() async {
    final token = await SessionService.getToken();

    return {
      if (token != null)
        'Authorization': 'Bearer $token',
    };
  }

  String _erreur(
      http.Response response,
      String defaut,
      ) {
    try {
      return jsonDecode(
        utf8.decode(response.bodyBytes),
      )['message'] ??
          defaut;
    } catch (_) {
      return defaut;
    }
  }

  // Get all server notifications for the connected user.
  Future<List<Map<String, dynamic>>> lister() async {
    final id = await SessionService.getId();

    if (id == null) {
      throw Exception('Session expirée, reconnectez-vous');
    }

    final response = await http.get(
      Uri.parse(
        '$_base/notifications?utilisateurId=$id',
      ),
      headers: await _headers(),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Impossible de charger les notifications',
      );
    }

    return List<Map<String, dynamic>>.from(
      jsonDecode(utf8.decode(response.bodyBytes)),
    );
  }

  // Get the number of unread notifications.
  Future<int> nonLues() async {
    final id = await SessionService.getId();

    if (id == null) return 0;

    try {
      final response = await http.get(
        Uri.parse(
          '$_base/notifications/non-lues?utilisateurId=$id',
        ),
        headers: await _headers(),
      );

      if (response.statusCode != 200) return 0;

      return (
          jsonDecode(
            utf8.decode(response.bodyBytes),
          )['nonLues'] as num
      ).toInt();
    } catch (_) {
      return 0;
    }
  }

  // Mark a notification as read.
  Future<void> marquerLue(int notifId) async {
    final id = await SessionService.getId();

    if (id == null) {
      throw Exception('Session expirée, reconnectez-vous');
    }

    final response = await http.put(
      Uri.parse(
        '$_base/notifications/$notifId/lue?utilisateurId=$id',
      ),
      headers: await _headers(),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Impossible de marquer comme lue',
      );
    }
  }

  // Get the passenger's reservations.
  // The response contains dateTrajet, heureArrivee and statut.
  Future<List<Map<String, dynamic>>> reservations() async {
    final id = await SessionService.getId();

    if (id == null) return [];

    try {
      final response = await http.get(
        Uri.parse(
          '$_base/reservations?passagerId=$id',
        ),
        headers: await _headers(),
      );

      if (response.statusCode != 200) {
        return [];
      }

      return List<Map<String, dynamic>>.from(
        jsonDecode(
          utf8.decode(response.bodyBytes),
        ),
      );
    } catch (_) {
      return [];
    }
  }

  // Confirm the passenger's presence.
  Future<void> confirmerPresence(int reservationId) async {
    final id = await SessionService.getId();

    if (id == null) {
      throw Exception('Session expirée, reconnectez-vous');
    }

    final response = await http.put(
      Uri.parse(
        '$_base/reservations/$reservationId/presence?passagerId=$id',
      ),
      headers: await _headers(),
    );

    if (response.statusCode != 200) {
      throw Exception(
        _erreur(
          response,
          'Impossible de confirmer la présence',
        ),
      );
    }
  }
}
