import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/config.dart';
import 'session_service.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
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


  Future<void> inscrireLouagiste({
    required String nom,
    required String prenom,
    required String email,
    required String telephone,
    required String motDePasse,
    required String matricule,
    required String modele,
    required String cinPath,
    required String permisPath,
    required String carteGrisePath,
    required String autorisationPath,
  }) async {
    final requete = http.MultipartRequest(
        'POST', Uri.parse('$baseUrl/api/auth/inscription/louagiste'));

    // champs texte : mêmes noms que les @RequestParam du backend
    requete.fields.addAll({
      'nom': nom.trim(),
      'prenom': prenom.trim(),
      'email': email.trim(),
      'telephone': telephone.trim(),
      'motDePasse': motDePasse,
      'matricule': matricule.trim(),
      'modele': modele.trim(),
    });

    // fichiers : fromPath lit le fichier sur le téléphone et en envoie le contenu
    requete.files.add(await http.MultipartFile.fromPath('cin', cinPath));
    requete.files.add(await http.MultipartFile.fromPath('permis', permisPath));
    requete.files.add(await http.MultipartFile.fromPath('carteGrise', carteGrisePath));
    requete.files.add(await http.MultipartFile.fromPath('autorisationTransport', autorisationPath));

    final envoi = await requete.send().timeout(const Duration(seconds: 30));
    final reponse = await http.Response.fromStream(envoi);

    if (reponse.statusCode != 200 && reponse.statusCode != 201) {
      throw AuthException(
          reponse.statusCode, _messageInscriptionLouagiste(reponse));   }
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
  // Messages d'erreur de l'inscription louagiste uniquement
  String _messageInscriptionLouagiste(http.Response r) {
    try {
      final m = jsonDecode(utf8.decode(r.bodyBytes))['message'];
      if (m is String && m.isNotEmpty) return m; // message du backend
    } catch (_) {}
    if (r.statusCode == 413) {
      return 'Fichiers trop volumineux (25 Mo maximum au total).';
    }
    return "Inscription impossible. Vérifiez les champs et les documents.";
  }

}