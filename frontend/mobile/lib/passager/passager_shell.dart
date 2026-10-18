import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'accueil_passager_page.dart';
import 'mes_reservations_page.dart';

class PassagerShell extends StatefulWidget {
  const PassagerShell({super.key});

  @override
  State<PassagerShell> createState() => _PassagerShellState();
}

class _PassagerShellState extends State<PassagerShell> {
 // the only thing that changes inside la classe entiere which makes it statefulll
  int _index = 0;

  final List<Widget> _pages = const [
    AccueilPassagerPage(nom: 'Passager'),
    MesReservationsPage(),
  ];
  final List<String> _titres= const [
    "Accueil",
    "Mes réservations"
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titres[_index])),
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