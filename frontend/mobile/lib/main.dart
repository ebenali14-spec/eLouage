import 'package:flutter/material.dart';
import 'package:mobile/communs/login_page.dart';
import 'package:mobile/communs/splash_page.dart';
import 'theme/app_colors.dart';
//import './communs/splash_page.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'e-Louage',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        scaffoldBackgroundColor: AppColors.background,
      ),
      home: const SplashPage(),
    );
  }
}