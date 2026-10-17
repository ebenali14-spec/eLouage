import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class StationLouagistePage extends StatefulWidget {
  const StationLouagistePage({super.key});

  @override
  State<StationLouagistePage> createState() => _StationLouagistePageState();
}

class _StationLouagistePageState extends State<StationLouagistePage> {
  bool _present = false;
  int? _position;

  void _declarerPresence() {
    setState(() {
      _present = true;
      _position = 3;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ma présence',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline),
              label: Text(_present ? 'Présence déclarée' : 'Je suis à la station'),
              onPressed: _present ? null : _declarerPresence,
            ),
          ),
          const SizedBox(height: 32),
          if (_position != null)
            Text('Votre place dans la file : n°$_position',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}