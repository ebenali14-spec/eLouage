import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/config.dart';
import 'session_service.dart';

// US25 : consulter et modifier le profil du louagiste connecté.
// Le backend reconnaît le louagiste grâce au token
class ProfilLouagisteService {
  String get _url => '$baseUrl/api/louagistes/profil';

  // le token est ajouté dans l'en-tête de chaque requête
  Future<Map<String, String>> _entete() async {
    final token = await SessionService.getToken();
    return {if (token != null) 'Authorization': 'Bearer $token'};
  }

  String _erreur(http.Response res) {
    if (res.statusCode == 401) return 'Session expirée, reconnectez-vous.';
    if (res.statusCode == 403) return "Accès refusé : ce compte n'est pas un louagiste.";
    if (res.statusCode == 413) return 'Fichiers trop volumineux (25 Mo maximum au total).';
    try {
      final corps = jsonDecode(utf8.decode(res.bodyBytes));
      return corps['erreur'] ?? corps['message'] ?? 'Erreur ${res.statusCode}';
    } catch (_) {
      return 'Erreur ${res.statusCode}';
    }
  }

  // GET /api/louagistes/profil
  // -> {id, nom, prenom, email, telephone, role, statut, matricule, modele, documents: [...]}
  Future<Map<String, dynamic>> consulter() async {
    final res = await http
        .get(Uri.parse(_url), headers: await _entete())
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) throw Exception(_erreur(res));
    return Map<String, dynamic>.from(jsonDecode(utf8.decode(res.bodyBytes)));
  }

  // PUT /api/louagistes/profil (form-data)
  // champs   : les champs texte à envoyer (nom, prenom, email, ... ancienMotDePasse, nouveauMotDePasse)
  // fichiers : (cin, permis, carteGrise, autorisationTransport) -> chemin du fichier
  Future<Map<String, dynamic>> modifier({
    required Map<String, String> champs,
    Map<String, String> fichiers = const {},
  }) async {
    //form-data request,needed because the backend accepts files.
    final requete = http.MultipartRequest('PUT', Uri.parse(_url));
    requete.headers.addAll(await _entete()); // pas de Content-Type : Flutter l'ajoute tout seul
    requete.fields.addAll(champs);
    for (final e in fichiers.entries) {
      requete.files.add(await http.MultipartFile.fromPath(e.key, e.value));
    }
    final envoi = await requete.send().timeout(const Duration(seconds: 30));
    final res = await http.Response.fromStream(envoi);
    if (res.statusCode != 200) throw Exception(_erreur(res));
    return Map<String, dynamic>.from(jsonDecode(utf8.decode(res.bodyBytes)));
  }
}