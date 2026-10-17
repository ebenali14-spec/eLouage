import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class StationLouagistePage extends StatefulWidget {
  const StationLouagistePage({super.key});

  @override
  State<StationLouagistePage> createState() => _StationLouagistePageState();
}

class _StationLouagistePageState extends State<StationLouagistePage> {
  final List<String> _file = ['Louagiste A', 'Louagiste B'];
  bool _present = false;

  void _declarerPresence() {
    setState(() {
      _file.add('Moi');
      _present = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _present
                ? 'Votre place : ${_file.indexOf('Moi') + 1}'
                : 'Vous n\'êtes pas dans la file',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 24),
          if (!_present)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.location_on),
                label: const Text('Je suis arrivé à la station'),
                onPressed: _declarerPresence,
              ),
            ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: _file.length,
              itemBuilder: (context, i) => ListTile(
                leading: CircleAvatar(child: Text('${i + 1}')),
                title: Text(_file[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}