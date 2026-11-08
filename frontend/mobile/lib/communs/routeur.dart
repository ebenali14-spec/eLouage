import 'package:flutter/material.dart';
import 'package:mobile/louagiste/louagiste_shell.dart';
import 'package:mobile/passager/passager_shell.dart';

// Renvoie l'espace correspondant au rôle, ou null (ex. ADMIN)
Widget? espacePourRole(String? role) {
  switch (role) {
    case 'PASSAGER':
      return const PassagerShell();
    case 'LOUAGISTE':
      return const LouagisteShell();
    default:
      return null;
  }
}