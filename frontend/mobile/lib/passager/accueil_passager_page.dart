import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AccueilPassagerPage extends StatelessWidget {
  final String nom;
  const AccueilPassagerPage({super.key, required this.nom});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bonjour $nom',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.search),
              label: const Text('Rechercher un trajet'),
              onPressed: () {
                // plus tard : Navigator.push vers la page de recherche
              },
            ),
          ),
        ],
      ),
    );
  }
}