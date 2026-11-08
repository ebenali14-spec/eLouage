import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:mobile/services/notification_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _service = NotificationService();

  List<Map<String, dynamic>> _notifs = [];
  bool _chargement = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _charger();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _charger(silencieux: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _charger({bool silencieux = false}) async {
    try {
      final data = await _service.lister();
      if (!mounted) return;
      setState(() => _notifs = data);
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

  void _message(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _charger,
        child: _notifs.isEmpty
            ? ListView(children: const [
          SizedBox(height: 200),
          Center(child: Text('Aucune notification')),
        ])
            : ListView.separated(
          itemCount: _notifs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final n = _notifs[i];
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
                style: TextStyle(
                    fontWeight: lue ? FontWeight.normal : FontWeight.w600),
              ),
              subtitle: Text(_date(n['dateEnvoi'])),
            );
          },
        ),
      ),
    );
  }
}