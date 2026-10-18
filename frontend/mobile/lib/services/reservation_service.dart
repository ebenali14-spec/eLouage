import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config//config.dart';
import '../models/etat_places.dart';
import '../models/reservation.dart';
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

  Future<List<Reservation>> getReservations() async {
    final reponse = await http
        .get(Uri.parse('$baseUrl/api/reservations?passagerId=$passagerId'))
        .timeout(const Duration(seconds: 10));
    if (reponse.statusCode != 200) {
      throw ReservationException(reponse.statusCode, _message(reponse));
    }
    final liste = jsonDecode(utf8.decode(reponse.bodyBytes)) as List;
    return liste.map((e) => Reservation.fromJson(e)).toList();
  }

  Future<void> _put(String chemin) async {
    final reponse = await http
        .put(Uri.parse('$baseUrl$chemin'))
        .timeout(const Duration(seconds: 10));
    if (reponse.statusCode != 200) {
      throw ReservationException(reponse.statusCode, _message(reponse));
    }
  }

  Future<void> annuler(int id) =>
      _put('/api/reservations/$id/annulation?passagerId=$passagerId');

  Future<void> signalerPresence(int id) =>
      _put('/api/reservations/$id/presence?passagerId=$passagerId');
}