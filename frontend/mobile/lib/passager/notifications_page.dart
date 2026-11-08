import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:mobile/services/notification_service.dart';
import 'package:mobile/services/rappel_grace.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _service = NotificationService();

  List<Map<String, dynamic>> _notifs = [];
  List<Map<String, dynamic>> _reservations = [];
  bool _chargement = true;
  Timer? _rechargeTimer;
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    _charger();
    // reload server notifications and reservations every 15 s
    _rechargeTimer = Timer.periodic(
        const Duration(seconds: 15), (_) => _charger(silencieux: true));
    // refresh the countdown every second
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _rechargeTimer?.cancel();
    _tickTimer?.cancel();
    super.dispose();
  }

  Future<void> _charger({bool silencieux = false}) async {
    try {
      final data = await _service.lister();
      final res = await _service.reservations();
      if (!mounted) return;
      setState(() {
        _notifs = data;
        _reservations = res;
      });
    } catch (e) {
      if (!silencieux) _message(e.toString().replaceFirst('Exception: ', ''));
    }
    if (mounted && _chargement) setState(() => _chargement = false);
  }

  Future<void> _ouvrir(Map<String, dynamic> n) async {
    if (n['lu'] == true) return;
    try {
      await _service.marquerLue(n['id'] as int);
      if (!mounted) return;
      setState(() => n['lu'] = true);
    } catch (e) {
      _message(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _confirmer(Map<String, dynamic> r) async {
    try {
      await _service.confirmerPresence(r['id'] as int);
      _message('Présence confirmée');
      await _charger(silencieux: true);
    } catch (e) {
      _message(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _message(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  // ---------- grace reminders (computed live) ----------
  List<Map<String, dynamic>> get _rappels {
    final now = DateTime.now();
    final out = <Map<String, dynamic>>[];
    for (final r in _reservations) {
      final etat = RappelGrace.etat(r, now);
      if (etat == null) continue;
      out.add({...r, '_etat': etat, '_depart': RappelGrace.depart(r)});
    }
    return out;
  }

  String _compte(DateTime depart) {
    final d = depart.difference(DateTime.now());
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _carteRappel(Map<String, dynamic> r) {
    final etat = r['_etat'];
    final Color couleur;
    final String titre;
    final String texte;

    if (etat == 'rappel') {
      couleur = Colors.orange;
      titre = 'Rappel de grâce';
      texte = 'Votre trajet part dans ${_compte(r['_depart'])}. '
          'Confirmez votre présence avant le départ, sinon vous serez marqué '
          'absent et votre place sera libérée.';
    } else if (etat == 'depasse') {
      couleur = Colors.red;
      titre = 'Délai dépassé';
      texte = "Vous n'avez pas confirmé votre présence : "
          "vous risquez d'être marqué absent.";
    } else {
      couleur = Colors.red;
      titre = 'Marqué absent';
      texte = 'Vous avez été marqué absent, votre place a été libérée.';
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      color: couleur.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: couleur),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.timer_outlined, color: couleur),
              const SizedBox(width: 8),
              Text(titre,
                  style: TextStyle(fontWeight: FontWeight.bold, color: couleur)),
            ]),
            const SizedBox(height: 8),
            Text(texte),
            if (etat == 'rappel' || etat == 'depasse') ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Confirmer ma présence'),
                  onPressed: () => _confirmer(r),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------- server notifications ----------
  IconData _icone(String? type) {
    switch (type) {
      case 'RAPPEL_GRACE':
        return Icons.timer_outlined;
      case 'DISPONIBILITE':
        return Icons.event_seat_outlined;
      case 'RESERVATION':
        return Icons.bookmark_outline;
      case 'DEPART':
        return Icons.directions_bus_outlined;
      default:
        return Icons.notifications_active;
    }
  }

  String _date(dynamic iso) {
    final d = DateTime.tryParse('$iso');
    if (d == null) return '';
    String p(int x) => x.toString().padLeft(2, '0');
    return '${p(d.day)}/${p(d.month)}/${d.year} ${p(d.hour)}:${p(d.minute)}';
  }

  Widget _tuileNotif(Map<String, dynamic> n) {
    final lue = n['lu'] == true;
    return ListTile(
      onTap: () => _ouvrir(n),
      tileColor: lue ? null : AppColors.primary.withOpacity(0.06),
      leading: Icon(
        _icone(n['type'] as String?),
        color: lue ? Colors.grey : AppColors.primary,
      ),
      title: Text(
        '${n['message'] ?? ''}',
        style: TextStyle(fontWeight: lue ? FontWeight.normal : FontWeight.w600),
      ),
      subtitle: Text(_date(n['dateEnvoi'])),
    );
  }

  // ---------- build ----------
  @override
  Widget build(BuildContext context) {
    final rappels = _rappels;

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _charger,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            for (final r in rappels) _carteRappel(r),
            if (rappels.isNotEmpty) const SizedBox(height: 12),
            if (_notifs.isEmpty && rappels.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 200),
                child: Center(child: Text('Aucune notification')),
              ),
            for (int i = 0; i < _notifs.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              _tuileNotif(_notifs[i]),
            ],
          ],
        ),
      ),
    );
  }
}