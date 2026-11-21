import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/profil_louagiste_service.dart';
import '../theme/app_colors.dart';

// US25 : le louagiste consulte et modifie son profil
class ProfilLouagistePage extends StatefulWidget {
  const ProfilLouagistePage({super.key});

  @override
  State<ProfilLouagistePage> createState() => _ProfilLouagistePageState();
}

class _ProfilLouagistePageState extends State<ProfilLouagistePage> {
  final _service = ProfilLouagisteService();
  final _formKey = GlobalKey<FormState>();

  // champs du formulaire
  final _nomCtrl = TextEditingController();
  final _prenomCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _matriculeCtrl = TextEditingController();
  final _modeleCtrl = TextEditingController();
  final _ancienCtrl = TextEditingController();
  final _nouveauCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  // clé = nom du champ attendu par le backend (comme à l'inscription)
  static const _documents = {
    'cin': "Carte d'identité (CIN)",
    'permis': 'Permis de conduire',
    'carteGrise': 'Carte grise',
    'autorisationTransport': 'Autorisation de transport',
  };
  // type renvoyé par le backend -> nom du champ
  static const _typeVersChamp = {
    'CIN': 'cin',
    'PERMIS': 'permis',
    'CARTE_GRISE': 'carteGrise',
    'AUTORISATION_TRANSPORT': 'autorisationTransport',
  };

  Map<String, String> _docsActuels = {}; //nom du fichier déjà enregistré
  final Map<String, PlatformFile> _nouveauxFichiers = {}; // fichiers choisis pour remplacer

  String _statut = '';
  bool _chargement = true;
  bool _envoi = false;
  bool _masquer = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    for (final c in [_nomCtrl, _prenomCtrl, _emailCtrl, _telCtrl, _matriculeCtrl,
      _modeleCtrl, _ancienCtrl, _nouveauCtrl, _confirmCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  // ---------- aides ----------
  String _texte(Object e) {
    if (e is TimeoutException || e is SocketException) {
      return 'Serveur injoignable. Vérifiez la connexion.';
    }
    return e.toString().replaceFirst('Exception: ', '');
  }

  void _message(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  String? _obligatoire(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null;

  // met les données du backend dans le formulaire
  void _remplir(Map<String, dynamic> p) {
    _nomCtrl.text = '${p['nom'] ?? ''}';
    _prenomCtrl.text = '${p['prenom'] ?? ''}';
    _emailCtrl.text = '${p['email'] ?? ''}';
    _telCtrl.text = '${p['telephone'] ?? ''}';
    _matriculeCtrl.text = '${p['matricule'] ?? ''}';
    _modeleCtrl.text = '${p['modele'] ?? ''}';
    _statut = '${p['statut'] ?? ''}';
    _docsActuels = {};
    for (final d in ((p['documents'] as List?) ?? const [])) {
      final champ = _typeVersChamp['${d['type']}'];
      if (champ != null) _docsActuels[champ] = '${d['nomOriginal'] ?? ''}';
    }
  }

  // consulter
  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      _remplir(await _service.consulter());
    } catch (e) {
      _erreur = _texte(e);
    }
    if (mounted) setState(() => _chargement = false);
  }

  //  modifier
  Future<void> _choisir(String champ) async {
    final resultat = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (resultat == null) return; // annulé
    final fichier = resultat.files.single;
    if (fichier.size > 5 * 1024 * 1024) {
      setState(() => _erreur = 'Fichier trop lourd (5 Mo maximum).');
      return;
    }
    setState(() {
      _nouveauxFichiers[champ] = fichier;
      _erreur = null;
    });
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _envoi = true;
      _erreur = null;
    });
    try {
      final champs = <String, String>{
        'nom': _nomCtrl.text.trim(),
        'prenom': _prenomCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'telephone': _telCtrl.text.trim(),
        'matricule': _matriculeCtrl.text.trim(),
        'modele': _modeleCtrl.text.trim(),
      };
      // le mot de passe n'est envoyé que si le louagiste veut le changer
      if (_nouveauCtrl.text.isNotEmpty) {
        champs['ancienMotDePasse'] = _ancienCtrl.text;
        champs['nouveauMotDePasse'] = _nouveauCtrl.text;
      }
      final fichiers = <String, String>{
        for (final e in _nouveauxFichiers.entries) e.key: e.value.path!
      };

      final profil = await _service.modifier(champs: champs, fichiers: fichiers);
      _remplir(profil); // le backend renvoie le profil à jour
      _ancienCtrl.clear();
      _nouveauCtrl.clear();
      _confirmCtrl.clear();
      _nouveauxFichiers.clear();
      _message('Profil mis à jour');
    } catch (e) {
      _erreur = _texte(e); // ex: "Ancien mot de passe incorrect."
    }
    if (mounted) setState(() => _envoi = false);
  }

  // affichage
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

  Widget _titre(String texte) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 12),
    child: Text(texte,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
  );

  @override
  Widget build(BuildContext context) {
    if (_chargement) return const Center(child: CircularProgressIndicator());

    // le profil n'a pas pu être chargé : message + bouton pour réessayer
    if (_statut.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_erreur ?? 'Profil introuvable',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _charger, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Statut du compte : $_statut',
                style: const TextStyle(color: AppColors.textSecondary)),
            _titre('Mes informations'),
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

            _titre('Mon véhicule'),
            _champ(_matriculeCtrl, 'Matricule'),
            _champ(_modeleCtrl, 'Modèle'),

            _titre('Mes documents (touchez pour remplacer)'),
            for (final e in _documents.entries)
              Card(
                child: ListTile(
                  title: Text(e.value),
                  subtitle: Text(
                    _nouveauxFichiers[e.key] != null
                        ? 'Nouveau : ${_nouveauxFichiers[e.key]!.name}'
                        : (_docsActuels[e.key] ?? 'Aucun fichier'),
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Icon(
                    _nouveauxFichiers.containsKey(e.key)
                        ? Icons.check_circle
                        : Icons.upload_file,
                    color: _nouveauxFichiers.containsKey(e.key)
                        ? Colors.green
                        : AppColors.primary,
                  ),
                  onTap: () => _choisir(e.key),
                ),
              ),

            _titre('Changer mon mot de passe (facultatif)'),
            _champ(_ancienCtrl, 'Ancien mot de passe',
                secret: _masquer,
                validator: (v) =>
                (_nouveauCtrl.text.isNotEmpty && (v == null || v.isEmpty))
                    ? "Entrez votre ancien mot de passe"
                    : null),
            _champ(_nouveauCtrl, 'Nouveau mot de passe (8 caractères min.)',
                secret: _masquer,
                validator: (v) => (v != null && v.isNotEmpty && v.length < 8)
                    ? 'Au moins 8 caractères'
                    : null,
                suffixe: IconButton(
                  icon: Icon(_masquer ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _masquer = !_masquer),
                )),
            _champ(_confirmCtrl, 'Confirmer le nouveau mot de passe',
                secret: _masquer,
                validator: (v) => v != _nouveauCtrl.text
                    ? 'Les mots de passe ne correspondent pas'
                    : null),

            if (_erreur != null) ...[
              const SizedBox(height: 4),
              Text(_erreur!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _envoi ? null : _enregistrer,
                child: _envoi
                    ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Enregistrer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}