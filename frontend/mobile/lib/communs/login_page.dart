import 'package:flutter/material.dart';
import 'package:mobile/communs/routeur.dart';
import 'package:mobile/louagiste/louagiste_shell.dart';
import 'package:mobile/passager/inscription_page.dart';
import 'package:mobile/passager/passager_shell.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/services/session_service.dart';
import '../theme/app_colors.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _mdpCtrl = TextEditingController();
  final _auth = AuthService();

  bool _chargement = false;
  bool _masquer = true;
  String? _erreur;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _mdpCtrl.dispose();
    super.dispose();
  }

  Future<void> _seConnecter() async {
    if (_emailCtrl.text.trim().isEmpty || _mdpCtrl.text.isEmpty) {
      setState(() => _erreur = 'Email et mot de passe obligatoires.');
      return;
    }
    setState(() {
      _chargement = true;
      _erreur = null;
    });

    try {
      final role = await _auth.login(_emailCtrl.text, _mdpCtrl.text);
      if (!mounted) return;

      final espace = espacePourRole(role);
      if (espace != null) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => espace));
      } else {
        await SessionService.vider();
        setState(() => _erreur =
        "L'espace administrateur n'est pas disponible sur mobile.");
      }
    } on AuthException catch (e) {
      setState(() => _erreur = e.message);
    } catch (_) {
      // pas de réseau, serveur éteint, timeout...
      setState(() => _erreur = 'Serveur injoignable. Vérifiez la connexion.');
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('e-Louage',
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary)),
              const SizedBox(height: 32),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                    labelText: 'Email', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _mdpCtrl,
                obscureText: _masquer,
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                        _masquer ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _masquer = !_masquer),
                  ),
                ),
              ),
              if (_erreur != null) ...[
                const SizedBox(height: 12),
                Text(_erreur!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _chargement ? null : _seConnecter,
                  child: _chargement
                      ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Se connecter'),
                ),
              ),
              TextButton(
                onPressed: () async {
                  final email = await Navigator.push<String>(context,
                      MaterialPageRoute(builder: (_) => const InscriptionPage()));
                  if (email != null) _emailCtrl.text = email; // pré-remplit l'email
                },
                child: const Text('Nouveau passager ? Créer un compte'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}