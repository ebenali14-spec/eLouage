import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config//config.dart';
import '../models/etat_places.dart';

class ReservationException implements Exception {
  final int code;
  final String message;
  ReservationException(this.code, this.message);
}

class ReservationService {
  Future<void> reserver(int trajetId, int numeroPlace) async {
    final reponse = await http
        .post(
      Uri.parse('$baseUrl/api/reservations'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'trajetId': trajetId,
        'passagerId': passagerId,
        'numeroPlace': numeroPlace,
      }),
    )
        .timeout(const Duration(seconds: 10));
    if (reponse.statusCode != 201 && reponse.statusCode != 200) {
      throw ReservationException(reponse.statusCode, _message(reponse));
    }
  }

  // Spring n'envoie le texte de l'erreur que si le back l'a activé : sinon ''
  String _message(http.Response r) {
    try {
      final m = jsonDecode(utf8.decode(r.bodyBytes))['message'];
      return m is String ? m : '';
    } catch (_) {
      return '';
    }
  }
}