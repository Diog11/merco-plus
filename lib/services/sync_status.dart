import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'auth_flow.dart';

/// Signale à l'écran une modification que le serveur n'a PAS acceptée
/// (affichée dans le bandeau en haut de l'application).
class SyncStatus {
  SyncStatus._();

  static final ValueNotifier<String?> error = ValueNotifier(null);

  static void report(Object e) {
    final code = e is FirebaseException ? e.code : '';
    if (code == 'permission-denied') {
      // Session administrateur expirée ou supprimée : on la renouvelle tout de suite.
      AuthFlow.refreshAdminSession();
      error.value = "Une modification n'a pas été acceptée par le serveur (session expirée) : "
          "elle a été annulée. La session vient d'être renouvelée — refaites la saisie.";
    } else if (code == 'unavailable' || code == 'deadline-exceeded' || code == 'cancelled') {
      // Problème de réseau : Firestore réessaiera tout seul, rien à signaler.
    } else {
      error.value = "Une modification n'a pas pu être enregistrée sur le serveur"
          "${code.isEmpty ? '' : ' ($code)'}. Vérifiez-la et refaites la saisie si besoin.";
    }
  }

  static void clear() => error.value = null;
}
