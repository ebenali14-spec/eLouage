import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class EmbarquementLouagistePage extends StatefulWidget {
  const EmbarquementLouagistePage({super.key});

  @override
  State<EmbarquementLouagistePage> createState() => _EmbarquementLouagistePageState();
}

class _EmbarquementLouagistePageState extends State<EmbarquementLouagistePage> {
  final List<String> _passagers = const ['Ahmed', 'Sarra', 'Yassine'];
  final Set<String> _presents = {};

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Passagers',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: _passagers.map((nom) {
                return CheckboxListTile(
                  title: Text(nom),
                  value: _presents.contains(nom),
                  onChanged: (coche) => setState(() {
                    coche! ? _presents.add(nom) : _presents.remove(nom);
                  }),
                );
              }).toList(),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check),
              label: Text('Confirmer l\'embarquement (${_presents.length})'),
              onPressed: _presents.isEmpty
                  ? null
                  : () {

              },
            ),
          ),
        ],
      ),
    );
  }
}