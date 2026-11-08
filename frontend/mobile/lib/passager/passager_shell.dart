
import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'accueil_passager_page.dart';
import 'mes_reservations_page.dart';
import 'notifications_page.dart';
import '../communs/login_page.dart';

import 'package:mobile/services/session_service.dart';
import 'package:mobile/services/notification_service.dart';
import 'package:mobile/services/rappel_grace.dart';

class PassagerShell extends StatefulWidget {
  const PassagerShell({super.key});

  @override
  State<PassagerShell> createState() => _PassagerShellState();
}

class _PassagerShellState extends State<PassagerShell>
    with WidgetsBindingObserver {
  final _notifService = NotificationService();

  int _index = 0;
  int _nonLues = 0;
  int _rappels = 0;

  // null means that the first server notification check
  // has not happened yet.
  int? _dernierNonLues;

  Timer? _timer;
  Timer? _rappelTimer;

  // Prevent the same reservation from showing the reminder
  // SnackBar repeatedly during this app session.
  final Set<int> _rappelsDejaSignales = {};

  // Prevent overlapping API checks.
  bool _verificationEnCours = false;

  final List<Widget> _pages = const [
    AccueilPassagerPage(nom: 'Passager'),
    MesReservationsPage(),
  ];

  final List<String> _titres = [
    'Accueil',
    'Mes réservations',
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _verifier();
    _demarrerTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _timer?.cancel();
    _rappelTimer?.cancel();

    super.dispose();
  }

  // Pause checks in the background and restart them
  // when the application returns to the foreground.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _verifier();
      _demarrerTimer();
    } else if (state == AppLifecycleState.paused) {
      _timer?.cancel();
      _rappelTimer?.cancel();
    }
  }

  // Check the server every 30 seconds.
  void _demarrerTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(
      const Duration(seconds: 30),
          (_) => _verifier(),
    );
  }

  // Schedule a one-shot timer for the next reminder.
  void _programmerRappel(
      List<Map<String, dynamic>> reservations,
      ) {
    _rappelTimer?.cancel();

    final quand = RappelGrace.prochainDeclenchement(
      reservations,
    );

    if (quand == null) return;

    var delai = quand.difference(DateTime.now());

    if (delai.isNegative) {
      delai = Duration.zero;
    }

    // Add one second to ensure the reminder window has started.
    _rappelTimer = Timer(
      delai + const Duration(seconds: 1),
      _verifier,
    );
  }

  // Check unread notifications and reservations.
  Future<void> _verifier() async {
    if (_verificationEnCours) return;

    _verificationEnCours = true;

    try {
      final n = await _notifService.nonLues();
      final reservations =
      await _notifService.reservations();

      if (!mounted) return;

      final maintenant = DateTime.now();

      // Find reservations whose 15-minute reminder is active.
      final rappelsEnCours = reservations.where((r) {
        return RappelGrace.etat(r, maintenant) == 'rappel';
      }).toList();

      // Detect reminders that have not yet been displayed.
      final nouveauxRappels =
      <Map<String, dynamic>>[];

      for (final reservation in rappelsEnCours) {
        final id = int.tryParse(
          '${reservation['id']}',
        );

        if (id != null &&
            _rappelsDejaSignales.add(id)) {
          nouveauxRappels.add(reservation);
        }
      }

      // Detect new server notifications.
      final nouveauServeur =
          _dernierNonLues != null &&
              n > _dernierNonLues!;

      // Display a reminder or a server notification.
      if (nouveauxRappels.isNotEmpty) {
        final message = nouveauxRappels.length == 1
            ? 'Rappel : votre louagiste arrive à la station '
            'dans moins de 15 minutes. Confirmez votre présence.'
            : 'Rappel : plusieurs louagistes arrivent bientôt. '
            'Confirmez vos présences.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Voir',
              onPressed: _ouvrirNotifications,
            ),
          ),
        );
      } else if (nouveauServeur) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Vous avez une nouvelle notification',
            ),
            action: SnackBarAction(
              label: 'Voir',
              onPressed: _ouvrirNotifications,
            ),
          ),
        );
      }

      // Save the latest notification count.
      _dernierNonLues = n;

      // Update the notification badge.
      setState(() {
        _nonLues = n;
        _rappels = RappelGrace.actifs(reservations).length;
      });

      // Schedule the next reminder.
      _programmerRappel(reservations);
    } finally {
      _verificationEnCours = false;
    }
  }

  Future<void> _ouvrirNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const NotificationsPage(),
      ),
    );

    // Refresh the badge when returning from NotificationsPage.
    _verifier();
  }

  Future<void> _deconnecter() async {
    _timer?.cancel();
    _rappelTimer?.cancel();

    await SessionService.vider();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginPage(),
      ),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _nonLues + _rappels;

    return Scaffold(
      appBar: AppBar(
        title: Text(_titres[_index]),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: _ouvrirNotifications,
            icon: Badge(
              isLabelVisible: total > 0,
              label: Text('$total'),
              child: const Icon(
                Icons.notifications_outlined,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Déconnexion',
            onPressed: _deconnecter,
          ),
        ],
      ),

      body: _pages[_index],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        selectedItemColor: AppColors.primary,
        onTap: (i) {
          setState(() {
            _index = i;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark_add_outlined),
            label: 'Mes réservations',
          ),
        ],
      ),
    );
  }
}
