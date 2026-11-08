import 'dart:convert';
import 'package:flutter/material.dart';
import 'login_page.dart';
import 'routeur.dart';
import 'package:mobile/services/session_service.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _decider();
  }

  Future<void> _decider() async {
    final token = await SessionService.getToken();
    final role = await SessionService.getRole();

    Widget destination = const LoginPage();
    if (token != null && !_expire(token)) {
      destination = espacePourRole(role) ?? const LoginPage();
    } else {
      await SessionService.vider(); // token absent ou expiré
    }

    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => destination));
  }

  // Le token JWT = en-tête.contenu.signature ; "exp" est dans le contenu
  bool _expire(String token) {
    try {
      final contenu = token.split('.')[1];
      final json = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(contenu))));
      final exp = json['exp'] as int;
      return DateTime.now().millisecondsSinceEpoch ~/ 1000 >= exp;
    } catch (_) {
      return true; // token illisible = on considère expiré
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}