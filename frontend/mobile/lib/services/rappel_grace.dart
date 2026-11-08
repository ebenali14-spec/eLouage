class RappelGrace {
  static const int minutesAvant = 15;

  /// Boarding date and time of a reservation (null if unknown)
  static DateTime? depart(Map<String, dynamic> r) {
    final date = r['dateTrajet'];
    final heure = r['heureArrivee'];
    if (date == null || heure == null) return null;
    final h = '$heure'.length == 5 ? '$heure:00' : '$heure';
    return DateTime.tryParse('${date}T$h');
  }

  /// 'rappel' (inside the 15 min), 'depasse' (time passed, not confirmed),
  /// 'absent', or null (nothing to show)
  static String? etat(Map<String, dynamic> r, DateTime now) {
    final statut = r['statut'];
    if (statut == 'ABSENT') return 'absent';
    if (statut != 'CONFIRMEE') return null;
    final d = depart(r);
    if (d == null) return null;
    if (now.isBefore(d.subtract(const Duration(minutes: minutesAvant)))) {
      return null;
    }
    return now.isBefore(d) ? 'rappel' : 'depasse';
  }

  /// Reservations that need an alert right now
  static List<Map<String, dynamic>> actifs(List<Map<String, dynamic>> res) {
    final now = DateTime.now();
    return res.where((r) => etat(r, now) != null).toList();
  }

  /// When the next reminder window opens (null if none is coming)
  static DateTime? prochainDeclenchement(List<Map<String, dynamic>> res) {
    final now = DateTime.now();
    DateTime? best;
    for (final r in res) {
      if (r['statut'] != 'CONFIRMEE') continue;
      final d = depart(r);
      if (d == null) continue;
      final debut = d.subtract(const Duration(minutes: minutesAvant));
      if (!debut.isAfter(now)) continue; // already open or passed
      if (best == null || debut.isBefore(best)) best = debut;
    }
    return best;
  }
}