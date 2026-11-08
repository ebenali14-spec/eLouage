
import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'package:mobile/services/notification_service.dart';
import 'package:mobile/services/rappel_grace.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() =>
      _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _service = NotificationService();

  List<Map<String, dynamic>> _notifs = [];
  List<Map<String, dynamic>> _reservations = [];

  bool _chargement = true;

  Timer? _rechargeTimer;
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();

    _charger();

    // Reload server notifications and reservations every 15 seconds.
    _rechargeTimer = Timer.periodic(
      const Duration(seconds: 15),
          (_) => _charger(silencieux: true),
    );

    // Refresh countdowns every second.
    _tickTimer = Timer.periodic(
      const Duration(seconds: 1),
          (_) {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  @override
  void dispose() {
    _rechargeTimer?.cancel();
    _tickTimer?.cancel();

    super.dispose();
  }

  // Load notifications and reservations.
  Future<void> _charger({
    bool silencieux = false,
  }) async {
    try {
      final data = await _service.lister();
      final reservations = await _service.reservations();

      if (!mounted) return;

      setState(() {
        _notifs = data;
        _reservations = reservations;
      });
    } catch (e) {
      if (!silencieux) {
        _message(
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    }

    if (mounted && _chargement) {
      setState(() {
        _chargement = false;
      });
    }
  }

  // Mark a server notification as read.
  Future<void> _ouvrir(
      Map<String, dynamic> notification,
      ) async {
    if (notification['lu'] == true) return;

    try {
      await _service.marquerLue(
        notification['id'] as int,
      );

      if (!mounted) return;

      setState(() {
        notification['lu'] = true;
      });
    } catch (e) {
      _message(
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  // Confirm the passenger's presence.
  Future<void> _confirmer(
      Map<String, dynamic> reservation,
      ) async {
    try {
      await _service.confirmerPresence(
        reservation['id'] as int,
      );

      if (!mounted) return;

      _message('Présence confirmée');

      await _charger(silencieux: true);
    } catch (e) {
      _message(
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void _message(String texte) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texte),
      ),
    );
  }

  // ---------- Grace reminders ----------

  List<Map<String, dynamic>> get _rappels {
    final maintenant = DateTime.now();

    final resultat = <Map<String, dynamic>>[];

    for (final reservation in _reservations) {
      final etat = RappelGrace.etat(
        reservation,
        maintenant,
      );

      if (etat == null) continue;

      resultat.add({
        ...reservation,
        '_etat': etat,
        '_depart': RappelGrace.heureArrivee(reservation),
      });
    }

    return resultat;
  }

  // Format the countdown until the louagiste arrives.
  String _compte(DateTime arrivee) {
    final difference = arrivee.difference(DateTime.now());

    if (difference.isNegative) {
      return '00:00';
    }

    final minutes = difference.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');

    final secondes = difference.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');

    return '$minutes:$secondes';
  }

  // Build a reminder card.
  Widget _carteRappel(
      Map<String, dynamic> reservation,
      ) {
    final etat = reservation['_etat'];

    final Color couleur;
    final String titre;
    final String texte;

    if (etat == 'rappel') {
      couleur = Colors.orange;
      titre = 'Rappel de présence';

      texte =
      'Le louagiste arrive à la station dans '
          '${_compte(reservation['_depart'] as DateTime)}. '
          'Veuillez confirmer votre présence. '
          'Le rappel est envoyé 15 minutes avant son arrivée.';
    } else if (etat == 'depasse') {
      couleur = Colors.red;
      titre = 'Heure d’arrivée dépassée';

      texte =
      'L’heure prévue d’arrivée du louagiste est passée. '
          'Si vous êtes toujours autorisé à embarquer, '
          'vous pouvez essayer de confirmer votre présence.';
    } else {
      couleur = Colors.red;
      titre = 'Marqué absent';

      texte =
      'Vous avez été marqué absent. '
          'Votre place a été libérée.';
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      color: couleur.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: couleur),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  color: couleur,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    titre,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: couleur,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text(texte),

            // Keep the existing confirmation action.
            if (etat == 'rappel' || etat == 'depasse') ...[
              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text(
                    'Confirmer ma présence',
                  ),
                  onPressed: () => _confirmer(reservation),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------- Server notifications ----------

  IconData _icone(String? type) {
    switch (type) {
      case 'RAPPEL_GRACE':
        return Icons.timer_outlined;

      case 'DISPONIBILITE':
        return Icons.event_seat_outlined;

      case 'RESERVATION':
        return Icons.bookmark_outline;

      case 'DEPART':
        return Icons.directions_bus_outlined;

      default:
        return Icons.notifications_active;
    }
  }

  String _date(dynamic iso) {
    final date = DateTime.tryParse('$iso');

    if (date == null) return '';

    String p(int x) => x.toString().padLeft(2, '0');

    return '${p(date.day)}/${p(date.month)}/${date.year} '
        '${p(date.hour)}:${p(date.minute)}';
  }

  Widget _tuileNotif(
      Map<String, dynamic> notification,
      ) {
    final lue = notification['lu'] == true;

    return ListTile(
      onTap: () => _ouvrir(notification),

      tileColor: lue
          ? null
          : AppColors.primary.withOpacity(0.06),

      leading: Icon(
        _icone(notification['type'] as String?),
        color: lue ? Colors.grey : AppColors.primary,
      ),

      title: Text(
        '${notification['message'] ?? ''}',
        style: TextStyle(
          fontWeight: lue
              ? FontWeight.normal
              : FontWeight.w600,
        ),
      ),

      subtitle: Text(
        _date(notification['dateEnvoi']),
      ),
    );
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    final rappels = _rappels;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),

      body: _chargement
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : RefreshIndicator(
        onRefresh: _charger,

        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),

          children: [
            // Reminder cards appear before server notifications.
            for (final rappel in rappels)
              _carteRappel(rappel),

            if (rappels.isNotEmpty)
              const SizedBox(height: 12),

            if (_notifs.isEmpty && rappels.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 200),
                child: Center(
                  child: Text('Aucune notification'),
                ),
              ),

            for (int i = 0; i < _notifs.length; i++) ...[
              if (i > 0)
                const Divider(height: 1),

              _tuileNotif(_notifs[i]),
            ],
          ],
        ),
      ),
    );
  }
}
