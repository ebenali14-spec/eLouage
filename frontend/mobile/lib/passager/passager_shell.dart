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
  int? _dernierNonLues; // null = first check, so no snackbar at startup
  int? _dernierRappels;
  Timer? _timer;        // periodic poll
  Timer? _rappelTimer;  // one-shot: fires 15 min before the next boarding

  final List<Widget> _pages = const [
    AccueilPassagerPage(nom: 'Passager'),
    MesReservationsPage(),
  ];
  final List<String> _titres = const ["Accueil", "Mes réservations"];

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

  // pause in the background, resume (and re-check) when the app comes back
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

  void _demarrerTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _verifier());
  }

  // plans a timer for the moment the next reminder window opens
  void _programmerRappel(List<Map<String, dynamic>> res) {
    _rappelTimer?.cancel();
    final quand = RappelGrace.prochainDeclenchement(res);
    if (quand == null) return;
    final delai = quand.difference(DateTime.now()) + const Duration(seconds: 1);
    _rappelTimer = Timer(delai, _verifier); // _verifier shows the snackbar
  }

  Future<void> _verifier() async {
    final n = await _notifService.nonLues();
    final res = await _notifService.reservations();
    final r = RappelGrace.actifs(res).length;
    if (!mounted) return;

    // --- debug temporaire : un seul message au premier passage ---
    if (_dernierRappels == null) {
      final id = await SessionService.getId();
      if (!mounted) return;
      final premiere = res.isEmpty
          ? ''
          : ' | ${res.first['statut']} ${res.first['heureArrivee']} '
          'etat=${RappelGrace.etat(res.first, DateTime.now())}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        duration: const Duration(seconds: 20),
        content: Text('user=$id | now=${DateTime.now().toString().substring(11, 19)} '
            '| res=${res.length}$premiere'),
      ));
    }
    // --- fin debug ---

    final nouveauServeur = _dernierNonLues != null && n > _dernierNonLues!;
    final nouveauRappel = _dernierRappels != null && r > _dernierRappels!;


    _dernierNonLues = n;
    _dernierRappels = r;
    setState(() {
      _nonLues = n;
      _rappels = r;
    });
    _programmerRappel(res);
  }

  Future<void> _ouvrirNotifications() async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const NotificationsPage()));
    _verifier(); // refresh the badge when coming back
  }

  Future<void> _deconnecter() async {
    _timer?.cancel();
    _rappelTimer?.cancel();
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