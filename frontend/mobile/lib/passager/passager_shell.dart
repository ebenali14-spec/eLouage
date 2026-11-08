import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'accueil_passager_page.dart';
import 'mes_reservations_page.dart';
import 'notifications_page.dart';
import '../communs/login_page.dart';
import 'package:mobile/services/session_service.dart';
import 'package:mobile/services/notification_service.dart';

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
  int? _dernierNonLues; // null = first check, so no snackbar at startup
  Timer? _timer;

  final List<Widget> _pages = const [
    AccueilPassagerPage(nom: 'Passager'),
    MesReservationsPage(),
  ];
  final List<String> _titres = const [
    "Accueil",
    "Mes réservations"
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
    super.dispose();
  }

  // pause polling in the background, resume when the app comes back
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _verifier();
      _demarrerTimer();
    } else if (state == AppLifecycleState.paused) {
      _timer?.cancel();
    }
  }

  void _demarrerTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _verifier());
  }

  Future<void> _verifier() async {
    final n = await _notifService.nonLues();
    if (!mounted) return;

    if (_dernierNonLues != null && n > _dernierNonLues!) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Vous avez une nouvelle notification'),
          action: SnackBarAction(label: 'Voir', onPressed: _ouvrirNotifications),
        ),
      );
    }
    _dernierNonLues = n;
    setState(() => _nonLues = n);
  }

  Future<void> _ouvrirNotifications() async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const NotificationsPage()));
    _verifier(); // refresh the badge when coming back
  }

  Future<void> _deconnecter() async {
    _timer?.cancel();
    await SessionService.vider();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titres[_index]),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: _ouvrirNotifications,
            icon: Badge(
              isLabelVisible: _nonLues > 0,
              label: Text('$_nonLues'),
              child: const Icon(Icons.notifications_outlined),
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
      //gestion surbrillance
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        selectedItemColor: AppColors.primary,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Accueil'),
          BottomNavigationBarItem(
              icon: Icon(Icons.bookmark_add_outlined), label: 'Mes réservations'),
        ],
      ),
    );
  }
}