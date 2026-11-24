import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/auth_flow.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/account_type_picker.dart';
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
  final _adminCodeCtrl = TextEditingController();
  UserRole _role = UserRole.technicien; // par défaut : compte restreint
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  Future<void> _signup() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Indiquez votre nom complet.');
      return;
    }
    if (_role == UserRole.admin && _adminCodeCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Le code administrateur est obligatoire pour un compte Admin.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    AuthFlow.busy.value = true;
    AuthFlow.freshLogin = true; // il vient de saisir e-mail + mot de passe
    User? created;
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      created = cred.user;
      try {
        await FirestoreService.instance.createUserProfile(
          uid: created!.uid,
          name: name,
          email: _emailCtrl.text.trim(),
          role: _role,
          adminCode: _adminCodeCtrl.text.trim(),
        );
      } catch (e) {
        // Profil refusé (ex. mauvais code admin) : on supprime le compte tout
        // juste créé, pour ne pas laisser un compte sans rôle.
        try {
          await created?.delete();
        } catch (_) {
          await FirebaseAuth.instance.signOut();
        }
        final denied = e is FirebaseException && e.code == 'permission-denied';
        throw _SignupRefused(denied && _role == UserRole.admin
            ? 'Code administrateur incorrect. Le compte n\'a pas été créé.'
            : 'Impossible d\'enregistrer le profil. Réessayez.');
      }
      if (_role == UserRole.admin) {
        try {
          await AuthFlow.startAdminSession(created!.uid, _adminCodeCtrl.text.trim());
        } catch (_) {/* sans gravité : l'écran de code administrateur s'affichera */}
      }
      await FirebaseAuth.instance.currentUser?.updateDisplayName(name);
      // AuthGate lit le profil (rôle) et ouvre la bonne interface.
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on _SignupRefused catch (e) {
      AuthFlow.freshLogin = false;
      setState(() => _error = e.message);
    } on FirebaseAuthException catch (e) {
      AuthFlow.freshLogin = false;
      setState(() => _error = _friendlyError(e.code));
    } catch (_) {
      AuthFlow.freshLogin = false;
      setState(() => _error = "Une erreur est survenue. Réessayez.");
    } finally {
      AuthFlow.busy.value = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return "Un compte existe déjà avec cet e-mail.";
      case 'network-request-failed':
        return "Pas de connexion Internet : la connexion à la plateforme nécessite Internet.";
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
                const Center(child: MpBadge(size: 92)),
                const SizedBox(height: 10),
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
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe (6 caractères min.)',
                    suffixIcon: IconButton(
                      tooltip: _obscure ? 'Afficher le mot de passe' : 'Masquer le mot de passe',
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                AccountTypePicker(
                  role: _role,
                  adminCodeCtrl: _adminCodeCtrl,
                  onChanged: (r) => setState(() => _role = r),
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

class _SignupRefused implements Exception {
  final String message;
  _SignupRefused(this.message);
}
