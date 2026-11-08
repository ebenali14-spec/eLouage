import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AccueilLouagistePage extends StatelessWidget {
  final String nom;
  final void Function(int) onNavigate;

  const AccueilLouagistePage({
    super.key,
    required this.nom,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bonjour $nom',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.calendar_month),
              label: const Text('Voir mon planning'),
              onPressed: () => onNavigate(1),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.people_outline),
              label: const Text("Gérer l'embarquement"),
              onPressed: () => onNavigate(2),
            ),
          ),
        ],
      ),
    );
  }
}