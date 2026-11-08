import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mobile/services/auth_service.dart';
import '../theme/app_colors.dart';

class InscriptionLouagistePage extends StatefulWidget {
  const InscriptionLouagistePage({super.key});

  @override
  State<InscriptionLouagistePage> createState() =>
      _InscriptionLouagistePageState();
}

class _InscriptionLouagistePageState extends State<InscriptionLouagistePage> {
  final _formKey = GlobalKey<FormState>();
  final _nomCtrl = TextEditingController();
  final _prenomCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _mdpCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _matriculeCtrl = TextEditingController();
  final _modeleCtrl = TextEditingController();
  final _auth = AuthService();

  // clé = nom du champ attendu par le backend
  static const _documents = {
    'cin': 'Carte d\'identité (CIN)',
    'permis': 'Permis de conduire',
    'carteGrise': 'Carte grise',
    'autorisationTransport': 'Autorisation de transport',
  };
  final Map<String, PlatformFile> _fichiers = {};

  bool _chargement = false;
  bool _masquer = true;
  String? _erreur;

  @override
  void dispose() {
    for (final c in [_nomCtrl, _prenomCtrl, _emailCtrl, _telCtrl, _mdpCtrl,
      _confirmCtrl, _matriculeCtrl, _modeleCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _obligatoire(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null;

  Widget _champ(TextEditingController ctrl, String label,
      {String? Function(String?)? validator,
        TextInputType? type,
        bool secret = false,
        Widget? suffixe}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: type,
        obscureText: secret,
        decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            suffixIcon: suffixe),
        validator: validator ?? _obligatoire,
      ),
    );
  }

  Future<void> _choisir(String cle) async {
    final resultat = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (resultat == null) return; // l'utilisateur a annulé
    final fichier = resultat.files.single;
    if (fichier.size > 5 * 1024 * 1024) {
      setState(() => _erreur = 'Fichier trop lourd (5 Mo maximum).');
      return;
    }
    setState(() {
      _fichiers[cle] = fichier;
      _erreur = null;
    });
  }

  Future<void> _sInscrire() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fichiers.length < _documents.length) {
      setState(() => _erreur = 'Les 4 documents sont obligatoires.');
      return;
    }
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      await _auth.inscrireLouagiste(
        nom: _nomCtrl.text,
        prenom: _prenomCtrl.text,
        email: _emailCtrl.text,
        telephone: _telCtrl.text,
        motDePasse: _mdpCtrl.text,
        matricule: _matriculeCtrl.text,
        modele: _modeleCtrl.text,
        cinPath: _fichiers['cin']!.path!,
        permisPath: _fichiers['permis']!.path!,
        carteGrisePath: _fichiers['carteGrise']!.path!,
        autorisationPath: _fichiers['autorisationTransport']!.path!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        duration: Duration(seconds: 5),
        content: Text(
            "Compte créé. Il sera activé après validation par l'administrateur."),
      ));
      Navigator.pop(context, _emailCtrl.text.trim());
    } on AuthException catch (e) {
      setState(() => _erreur = e.message);
    }  catch (e, trace) {
  debugPrint('ERREUR inscription louagiste : $e');
  debugPrint('$trace');
  setState(() => _erreur = 'Serveur injoignable. Vérifiez la connexion.');
} finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inscription louagiste')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _champ(_nomCtrl, 'Nom'),
              _champ(_prenomCtrl, 'Prénom'),
              _champ(_emailCtrl, 'Email',
                  type: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Champ obligatoire';
                    if (!v.contains('@')) return 'Email invalide';
                    return null;
                  }),
              _champ(_telCtrl, 'Téléphone', type: TextInputType.phone),
              _champ(_mdpCtrl, 'Mot de passe (8 caractères min.)',
                  secret: _masquer,
                  validator: (v) =>
                  (v == null || v.length < 8) ? 'Au moins 8 caractères' : null,
                  suffixe: IconButton(
                    icon: Icon(_masquer ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _masquer = !_masquer),
                  )),
              _champ(_confirmCtrl, 'Confirmer le mot de passe',
                  secret: _masquer,
                  validator: (v) => v != _mdpCtrl.text
                      ? 'Les mots de passe ne correspondent pas'
                      : null),
              const SizedBox(height: 8),
              const Text('Votre véhicule',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              _champ(_matriculeCtrl, 'Matricule'),
              _champ(_modeleCtrl, 'Modèle'),
              const SizedBox(height: 8),
              const Text('Documents (PDF, JPG ou PNG, 5 Mo max)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              for (final e in _documents.entries)
                Card(
                  child: ListTile(
                    title: Text(e.value),
                    subtitle: Text(
                      _fichiers[e.key]?.name ?? 'Aucun fichier choisi',
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Icon(
                      _fichiers.containsKey(e.key)
                          ? Icons.check_circle
                          : Icons.upload_file,
                      color: _fichiers.containsKey(e.key)
                          ? Colors.green
                          : AppColors.primary,
                    ),
                    onTap: () => _choisir(e.key),
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
                  onPressed: _chargement ? null : _sInscrire,
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