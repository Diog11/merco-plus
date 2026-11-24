import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../services/auth_flow.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/account_type_picker.dart';
import '../widgets/mp_badge.dart';

/// Affiché quand un compte connecté n'a pas encore de profil (rôle) :
/// typiquement un compte créé avant l'arrivée des types Admin / Technicien.
class ProfileSetupScreen extends StatefulWidget {
  final User user;
  const ProfileSetupScreen({super.key, required this.user});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  late final _nameCtrl = TextEditingController(text: widget.user.displayName ?? '');
  final _adminCodeCtrl = TextEditingController();
  UserRole _role = UserRole.technicien;
  bool _loading = false;
  String? _error;

  Future<void> _save() async {
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
    try {
      await FirestoreService.instance.createUserProfile(
        uid: widget.user.uid,
        name: name,
        email: widget.user.email ?? '',
        role: _role,
        adminCode: _adminCodeCtrl.text.trim(),
      );
      if (_role == UserRole.admin) {
        try {
          await AuthFlow.startAdminSession(widget.user.uid, _adminCodeCtrl.text.trim());
        } catch (_) {/* sans gravité : l'écran de code administrateur s'affichera */}
      }
      await widget.user.updateDisplayName(name);
      // AuthGate détecte le nouveau profil et ouvre la bonne interface.
    } on FirebaseException catch (e) {
      setState(() => _error = e.code == 'permission-denied' && _role == UserRole.admin
          ? 'Code administrateur incorrect.'
          : 'Enregistrement impossible (${e.code}).');
    } catch (_) {
      setState(() => _error = 'Une erreur est survenue. Réessayez.');
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
              decoration: BoxDecoration(
                color: MpColors.graphite,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: MpBadge(size: 84)),
                  const SizedBox(height: 14),
                  Text('COMPLÉTER MON PROFIL',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.oswald(
                          fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: 1, color: MpColors.textPrimaryDark)),
                  const SizedBox(height: 4),
                  Text(widget.user.email ?? '',
                      textAlign: TextAlign.center, style: const TextStyle(color: MpColors.chromeC, fontSize: 12.5)),
                  const SizedBox(height: 22),
                  TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nom complet')),
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
                    onPressed: _loading ? null : _save,
                    child: _loading
                        ? const SizedBox(
                            height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Valider'),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton(
                      onPressed: () => AuthFlow.signOut(),
                      child: const Text('Se déconnecter'),
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
