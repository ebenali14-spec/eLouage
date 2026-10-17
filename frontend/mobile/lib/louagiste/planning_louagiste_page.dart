import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
class PlanningLouagistePage extends StatefulWidget {
  const PlanningLouagistePage({super.key});

  @override
  State<PlanningLouagistePage> createState() => _PlanningLouagistePageState();
}

class _PlanningLouagistePageState extends State<PlanningLouagistePage> {
  final List<String> _jours = const [
    'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'
  ];
  // plus tard : vient du backend (lignes autorisées du louagiste)
  final List<String> _lignesAutorisees = const [
    'Tunis - Sousse', 'Tunis - Nabeul', 'Tunis - Bizerte'
  ];

  // jour -> ligne choisie (une seule par jour)
  final Map<String, String> _choix = {};

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ma semaine',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: _jours.map((jour) {
                return ListTile(
                  title: Text(jour),
                  trailing: DropdownButton<String>(
                    value: _choix[jour],
                    hint: const Text('Choisir'),
                    items: _lignesAutorisees
                        .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                        .toList(),
                    onChanged: (ligne) {
                      setState(() => _choix[jour] = ligne!);
                      // plus tard : envoyer au backend, confirmation immédiate
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Présence confirmée : $jour')),
                      );
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}