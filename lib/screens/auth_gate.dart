import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/auth_flow.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import 'admin_code_screen.dart';
import 'home_shell.dart';
import 'login_screen.dart';
import 'profile_setup_screen.dart';

/// Durée maximale hors de l'application avant déconnexion automatique.
/// Passez à Duration.zero pour déconnecter dès qu'on quitte l'onglet/l'appli.
const Duration kAwayLogoutAfter = Duration(minutes: 2);

/// Point d'entrée côté navigation :
///  - pas connecté            -> écran de connexion
///  - connecté, sans profil   -> "Compléter mon profil" (choix du type de compte)
///  - connecté + profil       -> HomeShell, selon le rôle (Admin / Technicien)
///
/// Déconnexion automatique : (1) la session Firebase n'est conservée que pour
/// l'onglet en cours (voir main.dart) — fermer l'onglet/le navigateur déconnecte ;
/// (2) si l'application reste en arrière-plan plus de [kAwayLogoutAfter],
/// on est déconnecté au retour et on doit ressaisir e-mail + mot de passe.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  DateTime? _leftAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden || state == AppLifecycleState.paused) {
      _leftAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final left = _leftAt;
      _leftAt = null;
      if (left != null &&
          FirebaseAuth.instance.currentUser != null &&
          !AuthFlow.offline.value && // hors ligne : on ne déconnecte pas (reconnexion impossible)
          DateTime.now().difference(left) >= kAwayLogoutAfter) {
        AuthFlow.signOut(reason: 'Session terminée : vous avez quitté l\'application. Reconnectez-vous.');
      } else {
        AuthFlow.refreshAdminSession(); // retour rapide : on prolonge la session admin
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthFlow.busy,
      builder: (context, busy, _) {
        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snap) {
            if (busy || snap.connectionState == ConnectionState.waiting) return const _Loader();
            final user = snap.data;
            if (user == null) return const LoginScreen();
            return _ProfileGate(key: ValueKey(user.uid), user: user);
          },
        );
      },
    );
  }
}

/// Charge le profil `users/{uid}` du compte connecté, puis choisit l'interface.
class _ProfileGate extends StatefulWidget {
  final User user;
  const _ProfileGate({super.key, required this.user});

  @override
  State<_ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<_ProfileGate> {
  late final Stream<AppUser?> _profile = FirestoreService.instance.watchUser(widget.user.uid);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: _profile,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            backgroundColor: MpColors.ink,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Impossible de lire votre profil (${snap.error}).',
                        textAlign: TextAlign.center, style: const TextStyle(color: MpColors.red)),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: () => AuthFlow.signOut(),
                      child: const Text('Se déconnecter'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        if (snap.connectionState == ConnectionState.waiting) return const _Loader();
        final profile = snap.data;
        if (profile == null) return ProfileSetupScreen(user: widget.user);
        // Compte Admin : e-mail + mot de passe exigés à CHAQUE ouverture de l'application.
        // Une session restaurée automatiquement (actualisation de la page...) est refusée.
        if (profile.isAdmin && !AuthFlow.freshLogin) {
          WidgetsBinding.instance.addPostFrameCallback((_) =>
              AuthFlow.signOut(reason: 'Compte administrateur : reconnectez-vous avec votre e-mail et votre mot de passe.'));
          return const _Loader();
        }
        if (profile.isAdmin) {
          // ... puis code administrateur, vérifié par le serveur, à chaque connexion.
          return ValueListenableBuilder<bool>(
            valueListenable: AuthFlow.adminVerified,
            builder: (context, ok, _) => ok ? HomeShell(user: profile) : AdminCodeScreen(user: profile),
          );
        }
        return HomeShell(user: profile);
      },
    );
  }
}

class _Loader extends StatelessWidget {
  const _Loader();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: MpColors.ink,
      body: Center(child: CircularProgressIndicator(color: MpColors.accent)),
    );
  }
}
