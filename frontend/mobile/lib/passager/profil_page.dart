import 'package:flutter/material.dart';
import '../services/passager_service.dart';
import '../theme/app_colors.dart';

enum _Mode { consultation, edition, motDePasse }

class ProfilPage extends StatefulWidget {
  const ProfilPage({super.key});
  @override
  State<ProfilPage> createState() => _ProfilPageState();
}

class _ProfilPageState extends State<ProfilPage> {
  final _service = ProfilService();
  final _cleInfos = GlobalKey<FormState>();
  final _cleMdp = GlobalKey<FormState>();

  final _nom = TextEditingController();
  final _prenom = TextEditingController();
  final _email = TextEditingController();
  final _telephone = TextEditingController();
  final _ancien = TextEditingController();
  final _nouveau = TextEditingController();
  final _confirmation = TextEditingController();

  Map<String, dynamic> _profil = {};
  _Mode _mode = _Mode.consultation;
  bool _chargement = true, _envoi = false, _masquer = true;
  String? _erreurChargement;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    for (final c in [_nom, _prenom, _email, _telephone, _ancien, _nouveau, _confirmation]) {
      c.dispose();
    }
    super.dispose();
  }

  void _message(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> _charger() async {
    setState(() { _chargement = true; _erreurChargement = null; });
    try {
      _profil = await _service.consulter();
    } catch (e) {
      _erreurChargement = messageErreur(e);
    }
    if (mounted) setState(() => _chargement = false);
  }

  // ---------- changements de mode ----------
  void _ouvrirEdition() {
    _nom.text = '${_profil['nom'] ?? ''}';
    _prenom.text = '${_profil['prenom'] ?? ''}';
    _email.text = '${_profil['email'] ?? ''}';
    _telephone.text = '${_profil['telephone'] ?? ''}';
    setState(() => _mode = _Mode.edition);
  }

  void _ouvrirMotDePasse() {
    _ancien.clear();
    _nouveau.clear();
    _confirmation.clear();
    setState(() { _mode = _Mode.motDePasse; _masquer = true; });
  }

  void _annuler() => setState(() => _mode = _Mode.consultation);

  // ---------- enregistrement des informations ----------
  Future<void> _enregistrerInfos() async {
    if (!_cleInfos.currentState!.validate()) return;

    final champs = <String, dynamic>{};
    void diff(String cle, String valeur) {
      if (valeur.trim() != '${_profil[cle] ?? ''}') champs[cle] = valeur.trim();
    }
    diff('nom', _nom.text);
    diff('prenom', _prenom.text);
    diff('email', _email.text);
    diff('telephone', _telephone.text);

    if (champs.isEmpty) {
      _message('Aucune modification à enregistrer.');
      return;
    }
    await _envoyer(champs, 'Profil mis à jour.');
  }

  // ---------- changement du mot de passe ----------
  Future<void> _enregistrerMotDePasse() async {
    if (!_cleMdp.currentState!.validate()) return;
    await _envoyer({
      'ancienMotDePasse': _ancien.text,
      'nouveauMotDePasse': _nouveau.text,
    }, 'Mot de passe modifié.');
  }

  Future<void> _envoyer(Map<String, dynamic> champs, String succes) async {
    setState(() => _envoi = true);
    try {
      final maj = await _service.modifier(champs);
      if (!mounted) return;
      _profil = maj;
      _mode = _Mode.consultation;
      _message(succes);
    } catch (e) {
      _message(messageErreur(e));
    }
    if (mounted) setState(() => _envoi = false);
  }

  String? _obligatoire(String? v, String champ) =>
      (v == null || v.trim().isEmpty) ? '$champ obligatoire' : null;

  // ---------- widgets ----------
  Widget _entete() {
    final p = '${_profil['prenom'] ?? ''}';
    final n = '${_profil['nom'] ?? ''}';
    final initiales =
    '${p.isNotEmpty ? p[0] : ''}${n.isNotEmpty ? n[0] : ''}'.toUpperCase();
    return Column(children: [
      CircleAvatar(
        radius: 40,
        backgroundColor: AppColors.primary.withAlpha(30),
        child: Text(initiales,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold,
                color: AppColors.primary)),
      ),
      const SizedBox(height: 12),
      Text('$p $n',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
              color: AppColors.textPrimary)),
      const SizedBox(height: 4),
      const Text('Passager',
          style: TextStyle(color: AppColors.textSecondary)),
    ]);
  }

  Widget _ligneInfo(IconData icone, String label, String valeur) {
    return ListTile(
      leading: Icon(icone, color: AppColors.primary),
      title: Text(label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      subtitle: Text(valeur.isEmpty ? '—' : valeur,
          style: const TextStyle(fontSize: 16, color: AppColors.textPrimary)),
    );
  }

  // 1) consultation
  Widget _consultation() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _entete(),
        const SizedBox(height: 24),
        Card(
          child: Column(children: [
            _ligneInfo(Icons.person_outline, 'Prénom', '${_profil['prenom'] ?? ''}'),
            const Divider(height: 1),
            _ligneInfo(Icons.badge_outlined, 'Nom', '${_profil['nom'] ?? ''}'),
            const Divider(height: 1),
            _ligneInfo(Icons.email_outlined, 'E-mail', '${_profil['email'] ?? ''}'),
            const Divider(height: 1),
            _ligneInfo(Icons.phone_outlined, 'Téléphone', '${_profil['telephone'] ?? ''}'),
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
    );
  }

  // 2) édition des informations
  Widget _edition() {
    return Form(
      key: _cleInfos,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Modifier mes informations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          TextFormField(
            controller: _prenom,
            decoration: const InputDecoration(
                labelText: 'Prénom', border: OutlineInputBorder()),
            validator: (v) => _obligatoire(v, 'Prénom'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _nom,
            decoration: const InputDecoration(
                labelText: 'Nom', border: OutlineInputBorder()),
            validator: (v) => _obligatoire(v, 'Nom'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
                labelText: 'E-mail', border: OutlineInputBorder()),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'E-mail obligatoire';
              if (!v.contains('@')) return 'E-mail invalide';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _telephone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
                labelText: 'Téléphone', border: OutlineInputBorder()),
            validator: (v) => _obligatoire(v, 'Téléphone'),
          ),
          const SizedBox(height: 24),
          _boutons(onValider: _enregistrerInfos, libelle: 'Enregistrer'),
        ],
      ),
    );
  }

  // 3) changement du mot de passe
  Widget _motDePasse() {
    return Form(
      key: _cleMdp,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Changer le mot de passe',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          TextFormField(
            controller: _ancien,
            obscureText: _masquer,
            decoration: const InputDecoration(
                labelText: 'Ancien mot de passe', border: OutlineInputBorder()),
            validator: (v) => (v == null || v.isEmpty)
                ? "L'ancien mot de passe est obligatoire" : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _nouveau,
            obscureText: _masquer,
            decoration: InputDecoration(
              labelText: 'Nouveau mot de passe (8 caractères min.)',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_masquer ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _masquer = !_masquer),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Nouveau mot de passe obligatoire';
              if (v.length < 8) return 'Au moins 8 caractères';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirmation,
            obscureText: _masquer,
            decoration: const InputDecoration(
                labelText: 'Confirmer le nouveau mot de passe',
                border: OutlineInputBorder()),
            validator: (v) =>
            (v != _nouveau.text) ? 'Les mots de passe diffèrent' : null,
          ),
          const SizedBox(height: 24),
          _boutons(onValider: _enregistrerMotDePasse, libelle: 'Modifier'),
        ],
      ),
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
                ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
                : Text(libelle),
          ),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement) return const Center(child: CircularProgressIndicator());
    if (_erreurChargement != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_erreurChargement!),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _charger, child: const Text('Réessayer')),
        ]),
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