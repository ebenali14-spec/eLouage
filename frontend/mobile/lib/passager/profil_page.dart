import 'package:flutter/material.dart';
import '../services/passager_service.dart';
import '../theme/app_colors.dart';

class ProfilPage extends StatefulWidget {
  const ProfilPage({super.key});
  @override
  State<ProfilPage> createState() => _ProfilPageState();
}

class _ProfilPageState extends State<ProfilPage> {
  final _service = ProfilService();
  final _cle = GlobalKey<FormState>();

  final _nom = TextEditingController();
  final _prenom = TextEditingController();
  final _email = TextEditingController();
  final _telephone = TextEditingController();
  final _ancien = TextEditingController();
  final _nouveau = TextEditingController();
  final _confirmation = TextEditingController();

  Map<String, dynamic> _initial = {};
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
      final p = await _service.consulter();
      _remplir(p);
    } catch (e) {
      _erreurChargement = messageErreur(e);
    }
    if (mounted) setState(() => _chargement = false);
  }

  void _remplir(Map<String, dynamic> p) {
    _initial = p;
    _nom.text = '${p['nom'] ?? ''}';
    _prenom.text = '${p['prenom'] ?? ''}';
    _email.text = '${p['email'] ?? ''}';
    _telephone.text = '${p['telephone'] ?? ''}';
    _ancien.clear();
    _nouveau.clear();
    _confirmation.clear();
  }

  Future<void> _enregistrer() async {
    if (!_cle.currentState!.validate()) return;

    // on n'envoie que ce qui a changé (tous les champs sont optionnels côté back)
    final champs = <String, dynamic>{};
    void diff(String cle, String valeur) {
      if (valeur.trim() != '${_initial[cle] ?? ''}') champs[cle] = valeur.trim();
    }
    diff('nom', _nom.text);
    diff('prenom', _prenom.text);
    diff('email', _email.text);
    diff('telephone', _telephone.text);
    if (_nouveau.text.isNotEmpty) {
      champs['ancienMotDePasse'] = _ancien.text;
      champs['nouveauMotDePasse'] = _nouveau.text;
    }
    if (champs.isEmpty) {
      _message('Aucune modification à enregistrer.');
      return;
    }

    setState(() => _envoi = true);
    try {
      final maj = await _service.modifier(champs);
      if (!mounted) return;
      _remplir(maj);
      _message('Profil mis à jour.');
    } catch (e) {
      _message(messageErreur(e));
    }
    if (mounted) setState(() => _envoi = false);
  }

  String? _obligatoire(String? v, String champ) =>
      (v == null || v.trim().isEmpty) ? '$champ obligatoire' : null;

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

    return Form(
      key: _cle,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Mes informations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          TextFormField(
            controller: _prenom,
            decoration: const InputDecoration(labelText: 'Prénom', border: OutlineInputBorder()),
            validator: (v) => _obligatoire(v, 'Prénom'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _nom,
            decoration: const InputDecoration(labelText: 'Nom', border: OutlineInputBorder()),
            validator: (v) => _obligatoire(v, 'Nom'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'E-mail', border: OutlineInputBorder()),
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
            decoration: const InputDecoration(labelText: 'Téléphone', border: OutlineInputBorder()),
            validator: (v) => _obligatoire(v, 'Téléphone'),
          ),
          const SizedBox(height: 28),
          const Text('Changer le mot de passe',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          const Text('Laissez vide pour le conserver.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          TextFormField(
            controller: _ancien,
            obscureText: _masquer,
            decoration: const InputDecoration(
                labelText: 'Ancien mot de passe', border: OutlineInputBorder()),
            validator: (v) => (_nouveau.text.isNotEmpty && (v == null || v.isEmpty))
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
            validator: (v) => (v != null && v.isNotEmpty && v.length < 8)
                ? 'Au moins 8 caractères' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirmation,
            obscureText: _masquer,
            decoration: const InputDecoration(
                labelText: 'Confirmer le nouveau mot de passe',
                border: OutlineInputBorder()),
            validator: (v) => (v != _nouveau.text) ? 'Les mots de passe diffèrent' : null,
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _envoi ? null : _enregistrer,
              child: _envoi
                  ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Enregistrer'),
            ),
          ),
        ],
      ),
    );
  }
}