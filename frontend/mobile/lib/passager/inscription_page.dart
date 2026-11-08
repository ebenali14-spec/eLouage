import 'package:flutter/material.dart';
import 'package:mobile/services/auth_service.dart';
import '../theme/app_colors.dart';

class InscriptionPage extends StatefulWidget {
  const InscriptionPage({super.key});

  @override
  State<InscriptionPage> createState() => _InscriptionPageState();
}

class _InscriptionPageState extends State<InscriptionPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomCtrl = TextEditingController();
  final _prenomCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _mdpCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _auth = AuthService();

  bool _chargement = false;
  bool _masquer = true;
  String? _erreur;

  @override
  void dispose() {
    for (final c in [_nomCtrl, _prenomCtrl, _emailCtrl, _telCtrl, _mdpCtrl, _confirmCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _obligatoire(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null;

  Future<void> _sInscrire() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      await _auth.inscrirePassager(
        nom: _nomCtrl.text,
        prenom: _prenomCtrl.text,
        email: _emailCtrl.text,
        telephone: _telCtrl.text,
        motDePasse: _mdpCtrl.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Compte créé. Vous pouvez vous connecter.')));
      Navigator.pop(context, _emailCtrl.text.trim()); // renvoie l'email au login
    } on AuthException catch (e) {
      setState(() => _erreur = e.message);
    } catch (_) {
      setState(() => _erreur = 'Serveur injoignable. Vérifiez la connexion.');
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un compte')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nomCtrl,
                decoration: const InputDecoration(
                    labelText: 'Nom', border: OutlineInputBorder()),
                validator: _obligatoire,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _prenomCtrl,
                decoration: const InputDecoration(
                    labelText: 'Prénom', border: OutlineInputBorder()),
                validator: _obligatoire,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                    labelText: 'Email', border: OutlineInputBorder()),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Champ obligatoire';
                  if (!v.contains('@')) return 'Email invalide';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _telCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                    labelText: 'Téléphone', border: OutlineInputBorder()),
                validator: _obligatoire,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _mdpCtrl,
                obscureText: _masquer,
                decoration: InputDecoration(
                  labelText: 'Mot de passe (8 caractères min.)',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_masquer ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _masquer = !_masquer),
                  ),
                ),
                validator: (v) => (v == null || v.length < 8)
                    ? 'Au moins 8 caractères'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmCtrl,
                obscureText: _masquer,
                decoration: const InputDecoration(
                    labelText: 'Confirmer le mot de passe',
                    border: OutlineInputBorder()),
                validator: (v) =>
                v != _mdpCtrl.text ? 'Les mots de passe ne correspondent pas' : null,
              ),
              if (_erreur != null) ...[
                const SizedBox(height: 12),
                Text(_erreur!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _chargement ? null : _sInscrire,
                  style: ElevatedButton.styleFrom(
                      foregroundColor: AppColors.primary),
                  child: _chargement
                      ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text("S'inscrire"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}