import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'home_shell.dart';
import 'login_screen.dart';

/// Point d'entrée de l'application côté navigation : affiche l'écran de
/// connexion tant qu'aucun utilisateur Firebase n'est authentifié, puis
/// bascule automatiquement vers la plateforme (HomeShell) une fois connecté.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: MpColors.ink,
            body: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }
        if (snap.hasData) return const HomeShell();
        return const LoginScreen();
      },
    );
  }
}
