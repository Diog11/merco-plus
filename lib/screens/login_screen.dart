import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/mp_badge.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      // La navigation vers la plateforme est gérée automatiquement par
      // AuthGate (voir lib/screens/auth_gate.dart), qui écoute l'état
      // de connexion Firebase.
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _friendlyError(e.code));
    } catch (_) {
      setState(() => _error = "Une erreur est survenue. Réessayez.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'user-not-found':
        return "Aucun compte ne correspond à cet e-mail.";
      case 'wrong-password':
      case 'invalid-credential':
        return "E-mail ou mot de passe incorrect.";
      case 'invalid-email':
        return "Adresse e-mail invalide.";
      case 'too-many-requests':
        return "Trop de tentatives. Réessayez dans quelques minutes.";
      default:
        return "Connexion impossible ($code).";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MpColors.ink,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Theme(
            data: MpTheme.dark(),
            child: Container(
            width: 380,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: MpColors.graphite,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(.4), blurRadius: 30, offset: const Offset(0, 16))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: MpBadge(size: 56)),
                const SizedBox(height: 14),
                Text('MERCO PLUS',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.oswald(
                        fontWeight: FontWeight.w700, fontSize: 18, letterSpacing: 1, color: MpColors.textPrimaryDark)),
                const SizedBox(height: 4),
                Text('Connexion à la plateforme de gestion',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: MpColors.chromeC, fontSize: 12.5)),
                const SizedBox(height: 26),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'E-mail'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Mot de passe'),
                  onSubmitted: (_) => _login(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: MpColors.red, fontSize: 12.5)),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _loading ? null : _login,
                  child: _loading
                      ? const SizedBox(
                          height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Se connecter'),
                ),
                const SizedBox(height: 14),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const SignupScreen())),
                    child: const Text("Pas encore de compte ? Créer un compte"),
                  ),
                ),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }
}
