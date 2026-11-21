import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../services/mes_trajets_service.dart';
import '../theme/app_colors.dart';

// US27: le louagiste voit ses trajets, déclare sa présence et son retour
class MesTrajetsPage extends StatefulWidget {
  const MesTrajetsPage({super.key});

  @override
  State<MesTrajetsPage> createState() => _MesTrajetsPageState();
}

class _MesTrajetsPageState extends State<MesTrajetsPage> {
  final _service = MesTrajetsService();

  List<Map<String, dynamic>> _liste = []; // les trajets reçus du backend
  final Set<int> _enCours = {}; // trajets dont une action est en cours d'envoi
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  //  aides
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

  // "08:30:00" ou "2026-11-20T08:30:00" -> "08:30" ; null -> "-"
  String _hhmm(dynamic v) {
    final s = '${v ?? ''}';
    final heure = s.contains('T') ? s.split('T')[1] : s;
    return heure.length >= 5 ? heure.substring(0, 5) : '-';
  }

  // "2026-11-20" -> "20/11"
  String _jour(dynamic v) {
    final s = '${v ?? ''}';
    if (s.length < 10) return s;
    return '${s.substring(8, 10)}/${s.substring(5, 7)}';
  }

  //  chargement
  Future<void> _charger({bool silencieux = false}) async {
    if (!silencieux) {
      setState(() {
        _chargement = true;
        _erreur = null;
      });
    }
    try {
      final liste = await _service.lister();
      if (!mounted) return;
      _liste = liste;
      _erreur = null;
    } catch (e) {
      _erreur = _texte(e);
    }
    if (mounted) setState(() => _chargement = false);
  }

  // meme logique pour la présence et le retour : on envoie la demande , puis on recharge la liste
  Future<void> _agir(
      int trajetId, Future<void> Function(int) action, String succes) async {
    setState(() => _enCours.add(trajetId));
    try {
      await action(trajetId);
      _message(succes);
      await _charger(silencieux: true);
    } catch (e) {
      _message(_texte(e)); // ex: message de refus du backend
    }
    if (mounted) setState(() => _enCours.remove(trajetId));
  }

  // affichage
  Widget _carte(Map<String, dynamic> item) {
    final t = Map<String, dynamic>.from(item['trajet'] as Map);
    final id = t['id'] as int;
    final present = t['present'] == true;
    final retour = t['retour'] == true;
    final retourDeclare = item['retourDeclare'] == true;
    final passagers = (item['passagers'] as List?) ?? const [];
    final occupe = _enCours.contains(id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // date + heure + type
            Row(
              children: [
                Text('${_jour(t['date'])} · ${_hhmm(t['heureArrivee'])}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                Text(retour ? 'Retour' : 'Aller',
                    style: const TextStyle(color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 4),
            Text('Vers ${t['villeDestination'] ?? ''}'),
            Text('Matricule : ${t['matricule'] ?? '-'}',
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 8),

            // état de la présence
            if (present)
              Text(
                  'Présent depuis ${_hhmm(item['heureCheckIn'])} · '
                      "fin du délai de grâce à ${_hhmm(item['finGrace'])}",
                  style: const TextStyle(color: Colors.green))
            else
              const Text('Présence non déclarée',
                  style: TextStyle(color: Colors.orange)),
            Text('${item['nbPassagers'] ?? 0} passager(s) · '
                '${t['placesLibres'] ?? 0} place(s) libre(s)'),

            // liste des passagers (repliable)
            if (passagers.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Voir les passagers'),
                children: [
                  for (final p in passagers)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('${p['passagerNom'] ?? 'Passager'}'),
                      subtitle: Text('Place ${p['numeroPlace']} · ${p['statut']}'),
                    ),
                ],
              ),

            // boutons
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (!present)
                  ElevatedButton(
                    onPressed: occupe
                        ? null
                        : () => _agir(id, _service.declarerPresence,
                        'Présence déclarée'),
                    child: const Text('Déclarer ma présence'),
                  ),
                if (present && !retour && !retourDeclare)
                  OutlinedButton(
                    onPressed: occupe
                        ? null
                        : () => _agir(
                        id, _service.declarerRetour, 'Retour déclaré'),
                    child: const Text('Déclarer le retour'),
                  ),
                if (retourDeclare)
                  const Chip(label: Text('Retour déclaré')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes trajets')),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _charger,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_erreur != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_erreur!,
                    style: const TextStyle(color: Colors.red)),
              ),
            if (_erreur == null && _liste.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: Text('Aucun trajet à venir.')),
              ),
            for (final item in _liste) _carte(item),
          ],
        ),
      ),
    );
  }
}