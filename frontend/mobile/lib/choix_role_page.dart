import 'package:flutter/material.dart';
import 'package:mobile/louagiste/louagiste_shell.dart';
import 'theme/app_colors.dart';
import 'passager/passager_shell.dart';

class ChoixRolePage extends StatelessWidget {
  const ChoixRolePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('e-Louage',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold,
                      color: AppColors.primary)),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) => const PassagerShell()));
                  },
                  child: const Text('Espace passager'),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(
                        builder: (context) => const LouagisteShell()));
                  },
                  child: const Text('Espace louagiste'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}