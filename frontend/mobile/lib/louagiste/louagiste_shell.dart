import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'planning_louagiste_page.dart';
import 'station_louagiste_page.dart';
import 'embarquement_louagiste_page.dart';
import '../communs/login_page.dart';
import 'package:mobile/services/session_service.dart';

class LouagisteShell extends StatefulWidget {
  const LouagisteShell({super.key});

  @override
  State<LouagisteShell> createState() => _LouagisteShellState();
}

class _LouagisteShellState extends State<LouagisteShell> {

  int _index = 0;

  final List<Widget> _pages = const [
    PlanningLouagistePage(),
    StationLouagistePage(),
    EmbarquementLouagistePage(),
  ];
  final List<String> _titres = const [
    "Mon planning",
    "Station",
    "Embarquement",
  ];
  Future<void> _deconnecter() async {
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
            icon: const Icon(Icons.logout),
            tooltip: 'Déconnexion',
            onPressed: _deconnecter,
          ),
        ],
      ), body: _pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        selectedItemColor: AppColors.primary,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month), label: 'Planning'),
          BottomNavigationBarItem(
              icon: Icon(Icons.location_on_outlined), label: 'Station'),
          BottomNavigationBarItem(
              icon: Icon(Icons.people_outline), label: 'Embarquement'),
        ],
      ),
    );
  }
}
