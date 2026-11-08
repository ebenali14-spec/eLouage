// Heure de Tunis (UTC+1, sans changement d'heure), indépendante du fuseau de l'appareil.
// Les DateTime renvoyés sont marqués UTC : leurs chiffres (jour, heure...) sont
// ceux de l'horloge murale de Tunis, et on peut les comparer entre eux sans risque.
class HeureTunis {
  static const Duration _decalage = Duration(hours: 1);

  // "maintenant" à Tunis
  static DateTime maintenant() => DateTime.now().toUtc().add(_decalage);

  // date "2026-11-09" + heure "00:25" ou "00:25:00" -> DateTime à Tunis (null si absent)
  static DateTime? depuis(dynamic date, dynamic heure) {
    if (date == null || heure == null) return null;
    try {
      final d = '$date'.split('-');
      final h = '$heure'.split(':');
      return DateTime.utc(int.parse(d[0]), int.parse(d[1]), int.parse(d[2]),
          int.parse(h[0]), int.parse(h[1]));
    } catch (_) {
      return null;
    }
  }
}