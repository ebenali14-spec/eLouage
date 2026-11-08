
class RappelGrace {
  static const int minutesAvant = 15;

  // Date and time when the louagiste arrives at the departure station.
  static DateTime? heureArrivee(Map<String, dynamic> reservation) {
    final date = reservation['dateTrajet']?.toString();
    final heure = reservation['heureArrivee']?.toString();

    if (date == null || date.isEmpty ||
        heure == null || heure.isEmpty) {
      return null;
    }

    final heureNormalisee =
    heure.length == 5 ? '$heure:00' : heure;

    return DateTime.tryParse('${date}T$heureNormalisee');
  }

  // Returns the current reminder state.
  static String? etat(
      Map<String, dynamic> reservation,
      DateTime maintenant,
      ) {
    final statut = reservation['statut']?.toString();

    if (statut == 'ABSENT') return 'absent';

    if (statut != 'CONFIRMEE') return null;

    final arrivee = heureArrivee(reservation);

    if (arrivee == null) return null;

    final debutRappel = arrivee.subtract(
      const Duration(minutes: minutesAvant),
    );

    if (maintenant.isBefore(debutRappel)) {
      return null;
    }

    if (maintenant.isBefore(arrivee)) {
      return 'rappel';
    }

    return 'depasse';
  }

  // Returns reservations currently in the reminder period.
  static List<Map<String, dynamic>> actifs(
      List<Map<String, dynamic>> reservations,
      ) {
    final maintenant = DateTime.now();

    return reservations.where((reservation) {
      return etat(reservation, maintenant) != null;
    }).toList();
  }

  // Finds the next reminder time.
  static DateTime? prochainDeclenchement(
      List<Map<String, dynamic>> reservations,
      ) {
    final maintenant = DateTime.now();

    DateTime? prochain;

    for (final reservation in reservations) {
      if (reservation['statut']?.toString() != 'CONFIRMEE') {
        continue;
      }

      final arrivee = heureArrivee(reservation);

      if (arrivee == null) continue;

      final debutRappel = arrivee.subtract(
        const Duration(minutes: minutesAvant),
      );

      if (debutRappel.isAfter(maintenant)) {
        if (prochain == null || debutRappel.isBefore(prochain)) {
          prochain = debutRappel;
        }
      }
    }

    return prochain;
  }
}
