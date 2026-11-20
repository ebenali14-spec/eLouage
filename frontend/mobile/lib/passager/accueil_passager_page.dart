import 'package:flutter/material.dart';
import 'package:mobile/services/trajet_service.dart';
import '../theme/app_colors.dart';
import 'recherche_page.dart';
import 'plainte_page.dart';
import 'evaluation_page.dart';

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
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => const RecherchePage()));
              },
            )),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.star_outline),
                label: const Text('Évaluer un louagiste'),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const EvaluationPage())),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.report_gmailerrorred_outlined),
                label: const Text('Déposer une plainte'),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PlaintePage())),
              ),
            ),

        ],
      ),
    );
  }
}