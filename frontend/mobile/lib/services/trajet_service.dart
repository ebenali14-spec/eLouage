import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/config.dart';
import '../models/trajet_resultat.dart';

class TrajetService {
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
}