import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/mp_badge.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _signup() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      if (_nameCtrl.text.trim().isNotEmpty) {
        await cred.user?.updateDisplayName(_nameCtrl.text.trim());
      }
      // AuthGate détecte automatiquement la connexion et redirige
      // vers la plateforme — voir lib/screens/auth_gate.dart.
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
      case 'email-already-in-use':
        return "Un compte existe déjà avec cet e-mail.";
      case 'invalid-email':
        return "Adresse e-mail invalide.";
      case 'weak-password':
        return "Mot de passe trop court (6 caractères minimum).";
      case 'operation-not-allowed':
        return "La connexion par e-mail/mot de passe n'est pas encore activée dans Firebase "
            "(Authentication → Sign-in method → Email/Password).";
      default:
        return "Inscription impossible ($code).";
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
                Text('Créer un compte membre de l\'équipe',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: MpColors.chromeC, fontSize: 12.5)),
                const SizedBox(height: 26),
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nom complet'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'E-mail'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Mot de passe (6 caractères min.)'),
                  onSubmitted: (_) => _signup(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: MpColors.red, fontSize: 12.5)),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _loading ? null : _signup,
                  child: _loading
                      ? const SizedBox(
                          height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Créer le compte'),
                ),
                const SizedBox(height: 14),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text("Déjà un compte ? Se connecter"),
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
