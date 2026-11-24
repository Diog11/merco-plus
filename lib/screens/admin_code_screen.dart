import 'dart:async';

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../services/auth_flow.dart';
import '../theme/app_theme.dart';
import '../widgets/mp_badge.dart';

/// Deuxième étape obligatoire pour un compte Admin, à CHAQUE connexion :
/// après l'e-mail et le mot de passe, saisie du code administrateur.
class AdminCodeScreen extends StatefulWidget {
  final AppUser user;
  const AdminCodeScreen({super.key, required this.user});

  @override
  State<AdminCodeScreen> createState() => _AdminCodeScreenState();
}

class _AdminCodeScreenState extends State<AdminCodeScreen> {
  final _codeCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Saisissez le code administrateur.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthFlow.startAdminSession(widget.user.uid, code);
      // AuthGate bascule automatiquement vers la plateforme.
    } on FirebaseException catch (e) {
      if (mounted) {
        setState(() => _error = e.code == 'permission-denied'
            ? 'Code administrateur incorrect.'
            : 'Vérification impossible (${e.code}).');
      }
    } on TimeoutException {
      if (mounted) {
        setState(() => _error = 'Connexion Internet requise : le code est vérifié par le serveur. Réessayez une fois connecté.');
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Une erreur est survenue. Réessayez.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MpColors.ink,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
          child: Theme(
            data: MpTheme.dark(),
            child: Container(
              width: 380,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(color: MpColors.graphite, borderRadius: BorderRadius.circular(10)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: MpBadge(size: 84)),
                  const SizedBox(height: 14),
                  Text('VÉRIFICATION ADMINISTRATEUR',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.oswald(
                          fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: 1, color: MpColors.textPrimaryDark)),
                  const SizedBox(height: 6),
                  Text('Bonjour ${widget.user.name.isEmpty ? widget.user.email : widget.user.name}.\n'
                      'Saisissez le code administrateur pour accéder à la plateforme.',
                      textAlign: TextAlign.center, style: const TextStyle(color: MpColors.chromeC, fontSize: 12.5)),
                  const SizedBox(height: 22),
                  TextField(
                    controller: _codeCtrl,
                    autofocus: true,
                    obscureText: _obscure,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: 'Code administrateur',
                      suffixIcon: IconButton(
                        tooltip: _obscure ? 'Afficher le code' : 'Masquer le code',
                        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    onSubmitted: (_) => _verify(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: MpColors.red, fontSize: 12.5)),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _loading ? null : _verify,
                    child: _loading
                        ? const SizedBox(
                            height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Valider'),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton(onPressed: () => AuthFlow.signOut(), child: const Text('Se déconnecter')),
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
