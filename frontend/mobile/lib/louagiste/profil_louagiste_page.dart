import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/profil_louagiste_service.dart';
import '../theme/app_colors.dart';

enum _Mode { consultation, edition, motDePasse }

// US25 : le louagiste consulte puis modifie son profil + voit ses évaluations
class ProfilLouagistePage extends StatefulWidget {
  const ProfilLouagistePage({super.key});

  @override
  State<ProfilLouagistePage> createState() => _ProfilLouagistePageState();
}

class _ProfilLouagistePageState extends State<ProfilLouagistePage> {
  final _service = ProfilLouagisteService();
  final _cleInfos = GlobalKey<FormState>();
  final _cleMdp = GlobalKey<FormState>();

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
  static const _typeVersChamp = {
    'CIN': 'cin',
    'PERMIS': 'permis',
    'CARTE_GRISE': 'carteGrise',
    'AUTORISATION_TRANSPORT': 'autorisationTransport',
  };

  Map<String, dynamic> _profil = {};
  Map<String, String> _docsActuels = {};
  final Map<String, PlatformFile> _nouveauxFichiers = {};
  String _statut = '';

  _Mode _mode = _Mode.consultation;
  bool _chargement = true, _envoi = false, _masquer = true;
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

  String _s(String cle) => '${_profil[cle] ?? ''}';

  String _formaterDate(dynamic iso) {
    final d = DateTime.tryParse('$iso');
    if (d == null) return '';
    String p(int x) => x.toString().padLeft(2, '0');
    return '${p(d.day)}/${p(d.month)}/${d.year}';
  }

  void _remplir(Map<String, dynamic> p) {
    _profil = p;
    _statut = '${p['statut'] ?? ''}';
    _docsActuels = {};
    for (final d in ((p['documents'] as List?) ?? const [])) {
      final champ = _typeVersChamp['${d['type']}'];
      if (champ != null) _docsActuels[champ] = '${d['nomOriginal'] ?? ''}';
    }
  }

  // ---------- chargement ----------
  Future<void> _charger() async {
    setState(() { _chargement = true; _erreur = null; });
    try {
      _remplir(await _service.consulter());
    } catch (e) {
      _erreur = _texte(e);
    }
    if (mounted) setState(() => _chargement = false);
  }

  // ---------- changements de mode ----------
  void _ouvrirEdition() {
    _nomCtrl.text = _s('nom');
    _prenomCtrl.text = _s('prenom');
    _emailCtrl.text = _s('email');
    _telCtrl.text = _s('telephone');
    _matriculeCtrl.text = _s('matricule');
    _modeleCtrl.text = _s('modele');
    _nouveauxFichiers.clear();
    setState(() { _mode = _Mode.edition; _erreur = null; });
  }

  void _ouvrirMotDePasse() {
    _ancienCtrl.clear();
    _nouveauCtrl.clear();
    _confirmCtrl.clear();
    setState(() { _mode = _Mode.motDePasse; _masquer = true; _erreur = null; });
  }

  void _annuler() {
    _nouveauxFichiers.clear();
    setState(() { _mode = _Mode.consultation; _erreur = null; });
  }

  // ---------- documents ----------
  Future<void> _choisir(String champ) async {
    final resultat = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (resultat == null) return;
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

  // ---------- enregistrements ----------
  Future<void> _enregistrerInfos() async {
    if (!_cleInfos.currentState!.validate()) return;
    await _envoyer(
      champs: {
        'nom': _nomCtrl.text.trim(),
        'prenom': _prenomCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'telephone': _telCtrl.text.trim(),
        'matricule': _matriculeCtrl.text.trim(),
        'modele': _modeleCtrl.text.trim(),
      },
      fichiers: {
        for (final e in _nouveauxFichiers.entries) e.key: e.value.path!
      },
      succes: 'Profil mis à jour',
    );
  }

  Future<void> _enregistrerMotDePasse() async {
    if (!_cleMdp.currentState!.validate()) return;
    await _envoyer(
      champs: {
        // valeurs actuelles, inchangées
        'nom': _s('nom'),
        'prenom': _s('prenom'),
        'email': _s('email'),
        'telephone': _s('telephone'),
        'matricule': _s('matricule'),
        'modele': _s('modele'),
        'ancienMotDePasse': _ancienCtrl.text,
        'nouveauMotDePasse': _nouveauCtrl.text,
      },
      fichiers: const {},
      succes: 'Mot de passe modifié',
    );
  }

  Future<void> _envoyer({
    required Map<String, String> champs,
    required Map<String, String> fichiers,
    required String succes,
  }) async {
    setState(() { _envoi = true; _erreur = null; });
    try {
      final profil = await _service.modifier(champs: champs, fichiers: fichiers);
      _remplir(profil);
      _nouveauxFichiers.clear();
      _mode = _Mode.consultation;
      _message(succes);
    } catch (e) {
      _erreur = _texte(e); // ex: "Ancien mot de passe incorrect."
    }
    if (mounted) setState(() => _envoi = false);
  }

  // ---------- widgets communs ----------
  Widget _titre(String texte) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 12),
    child: Text(texte,
        style: const TextStyle(
            fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
  );

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

  Widget _ligneInfo(IconData icone, String label, String valeur) => ListTile(
    leading: Icon(icone, color: AppColors.primary),
    title: Text(label,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
    subtitle: Text(valeur.isEmpty ? '—' : valeur,
        style: const TextStyle(fontSize: 16, color: AppColors.textPrimary)),
  );

  Widget _etoiles(num note, {double taille = 18}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 1; i <= 5; i++)
        Icon(i <= note.round() ? Icons.star : Icons.star_border,
            size: taille, color: Colors.amber),
    ],
  );

  Widget _pastilleStatut() {
    late final String texte;
    late final Color couleur;
    switch (_statut) {
      case 'ACTIF':
        texte = 'Compte actif';
        couleur = AppColors.success;
        break;
      case 'SUSPENDU':
        texte = 'Compte suspendu';
        couleur = AppColors.error;
        break;
      default:
        texte = 'En attente de validation';
        couleur = AppColors.warning;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: couleur.withAlpha(35),
        border: Border.all(color: couleur),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(texte,
          style: TextStyle(color: couleur, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _boutons({required VoidCallback onValider, required String libelle}) {
    return Row(children: [
      Expanded(
        child: SizedBox(
          height: 48,
          child: OutlinedButton(
            onPressed: _envoi ? null : _annuler,
            child: const Text('Annuler'),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _envoi ? null : onValider,
            child: _envoi
                ? const SizedBox(
                height: 20, width: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
                : Text(libelle),
          ),
        ),
      ),
    ]);
  }

  Widget _blocErreur() => _erreur == null
      ? const SizedBox.shrink()
      : Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(_erreur!, style: const TextStyle(color: Colors.red)),
  );

  // ---------- 1) consultation ----------
  Widget _entete() {
    final p = _s('prenom');
    final n = _s('nom');
    final initiales =
    '${p.isNotEmpty ? p[0] : ''}${n.isNotEmpty ? n[0] : ''}'.toUpperCase();
    return Column(children: [
      CircleAvatar(
        radius: 40,
        backgroundColor: AppColors.primary.withAlpha(30),
        child: Text(initiales,
            style: const TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primary)),
      ),
      const SizedBox(height: 12),
      Text('$p $n',
          style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      const SizedBox(height: 4),
      const Text('Louagiste', style: TextStyle(color: AppColors.textSecondary)),
      const SizedBox(height: 8),
      _pastilleStatut(),
    ]);
  }

  Widget _consultation() {
    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _entete(),
          const SizedBox(height: 24),
          Card(
            child: Column(children: [
              _ligneInfo(Icons.person_outline, 'Prénom', _s('prenom')),
              const Divider(height: 1),
              _ligneInfo(Icons.badge_outlined, 'Nom', _s('nom')),
              const Divider(height: 1),
              _ligneInfo(Icons.email_outlined, 'Email', _s('email')),
              const Divider(height: 1),
              _ligneInfo(Icons.phone_outlined, 'Téléphone', _s('telephone')),
            ]),
          ),
          _titre('Mon véhicule'),
          Card(
            child: Column(children: [
              _ligneInfo(Icons.confirmation_number_outlined, 'Matricule', _s('matricule')),
              const Divider(height: 1),
              _ligneInfo(Icons.local_taxi_outlined, 'Modèle', _s('modele')),
            ]),
          ),
          _titre('Mes documents'),
          Card(
            child: Column(children: [
              for (final e in _documents.entries) ...[
                ListTile(
                  leading: Icon(
                    _docsActuels.containsKey(e.key)
                        ? Icons.check_circle
                        : Icons.error_outline,
                    color: _docsActuels.containsKey(e.key)
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                  title: Text(e.value),
                  subtitle: Text(_docsActuels[e.key] ?? 'Aucun fichier',
                      overflow: TextOverflow.ellipsis),
                ),
                if (e.key != _documents.keys.last) const Divider(height: 1),
              ],
            ]),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Modifier le profil'),
              onPressed: _ouvrirEdition,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.lock_outline),
              label: const Text('Changer le mot de passe'),
              onPressed: _ouvrirMotDePasse,
            ),
          ),
        ],
      ),
    );
  }

  // ---------- 2) édition ----------
  Widget _edition() {
    return Form(
      key: _cleInfos,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _titre('Modifier mes informations'),
          _champ(_prenomCtrl, 'Prénom'),
          _champ(_nomCtrl, 'Nom'),
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
          const SizedBox(height: 12),
          _blocErreur(),
          _boutons(onValider: _enregistrerInfos, libelle: 'Enregistrer'),
        ],
      ),
    );
  }

  // ---------- 3) mot de passe ----------
  Widget _motDePasse() {
    return Form(
      key: _cleMdp,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _titre('Changer le mot de passe'),
          _champ(_ancienCtrl, 'Ancien mot de passe',
              secret: _masquer,
              validator: (v) => (v == null || v.isEmpty)
                  ? "Entrez votre ancien mot de passe" : null),
          _champ(_nouveauCtrl, 'Nouveau mot de passe (8 caractères min.)',
              secret: _masquer,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Nouveau mot de passe obligatoire';
                if (v.length < 8) return 'Au moins 8 caractères';
                return null;
              },
              suffixe: IconButton(
                icon: Icon(_masquer ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _masquer = !_masquer),
              )),
          _champ(_confirmCtrl, 'Confirmer le nouveau mot de passe',
              secret: _masquer,
              validator: (v) => v != _nouveauCtrl.text
                  ? 'Les mots de passe ne correspondent pas' : null),
          const SizedBox(height: 4),
          _blocErreur(),
          _boutons(onValider: _enregistrerMotDePasse, libelle: 'Modifier'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement) return const Center(child: CircularProgressIndicator());

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

    switch (_mode) {
      case _Mode.edition:
        return _edition();
      case _Mode.motDePasse:
        return _motDePasse();
      case _Mode.consultation:
        return _consultation();
    }
  }
}