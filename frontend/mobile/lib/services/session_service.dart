import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionService {
  static const _storage = FlutterSecureStorage();

  static const _kToken = 'token';
  static const _kRole = 'role';
  static const _kId = 'id';

  // Appelé après un login réussi
  static Future<void> sauvegarder({
    required String token,
    required String role,
    required int id,
  }) async {
    await _storage.write(key: _kToken, value: token);
    await _storage.write(key: _kRole, value: role);
    await _storage.write(key: _kId, value: id.toString());
  }

  static Future<String?> getToken() => _storage.read(key: _kToken);
  static Future<String?> getRole() => _storage.read(key: _kRole);

  static Future<int?> getId() async {
    final v = await _storage.read(key: _kId);
    return v == null ? null : int.tryParse(v);
  }

  // Déconnexion : on efface tout
  static Future<void> vider() => _storage.deleteAll();
}