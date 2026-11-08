import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/config.dart';
import 'session_service.dart';

class AuthException implements Exception {
  final int code;
  final String message;
  AuthException(this.code, this.message);
}

class AuthService {
  // Renvoie le rôle ("PASSAGER", "LOUAGISTE" ou "ADMIN") si la connexion réussit
  Future<String> login(String email, String motDePasse) async {
    final reponse = await http
        .post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.trim(),
        'motDePasse': motDePasse,
      }),
    )
        .timeout(const Duration(seconds: 10));

    if (reponse.statusCode != 200) {
      throw AuthException(reponse.statusCode, _message(reponse));
    }

    final data = jsonDecode(utf8.decode(reponse.bodyBytes));
    await SessionService.sauvegarder(
      token: data['token'],
      role: data['role'],
      id: data['id'],
    );
    return data['role'];
  }




  Future<void> inscrirePassager({
    required String nom,
    required String prenom,
    required String email,
    required String telephone,
    required String motDePasse,
  }) async {
    final reponse = await http
        .post(
      Uri.parse('$baseUrl/api/auth/inscription/passager'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'nom': nom.trim(),
        'prenom': prenom.trim(),
        'email': email.trim(),
        'telephone': telephone.trim(),
        'motDePasse': motDePasse,
      }),
    )
        .timeout(const Duration(seconds: 10));

    if (reponse.statusCode != 200 && reponse.statusCode != 201) {
      throw AuthException(reponse.statusCode,
          _message(reponse, "Inscription impossible. Vérifiez les champs."));
    }
  }

  String _message(http.Response r,
      [String defaut = 'Connexion impossible. Vérifiez vos identifiants.']) {
    try {
      final m = jsonDecode(utf8.decode(r.bodyBytes))['message'];
      if (m is String && m.isNotEmpty) return m;
    } catch (_) {}
    return defaut;
  }

}