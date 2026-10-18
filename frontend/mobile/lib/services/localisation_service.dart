import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/config.dart';

class LocalisationService {
  Future<List<String>> getVilles() async {
    final reponse = await http
        .get(Uri.parse('$baseUrl/api/localisations'))
        .timeout(const Duration(seconds: 20)); // le 1er appel interroge l'API publique
    if (reponse.statusCode != 200) {
      throw Exception('Erreur ${reponse.statusCode}');
    }
    final liste = jsonDecode(utf8.decode(reponse.bodyBytes)) as List;
    final villes = liste.map((e) => e['ville'] as String).toList();
    villes.sort();
    return villes;
  }
}