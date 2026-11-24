import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// État d'authentification partagé par les écrans de connexion.
class AuthFlow {
  AuthFlow._();

  /// Une inscription est en cours (compte Firebase créé mais profil pas encore
  /// écrit). AuthGate patiente pour ne pas afficher "Compléter mon profil" par erreur.
  static final ValueNotifier<bool> busy = ValueNotifier(false);

  /// Vrai seulement si l'utilisateur vient de saisir lui-même son e-mail et son
  /// mot de passe DANS CE CHARGEMENT de l'application. Une session simplement
  /// restaurée par le navigateur (actualisation de la page, etc.) ne compte pas :
  /// un compte Admin est alors déconnecté et doit s'authentifier à nouveau.
  static bool freshLogin = false;

  /// Vrai quand l'admin a saisi son code administrateur (vérifié par le serveur).
  static final ValueNotifier<bool> adminVerified = ValueNotifier(false);

  /// Vrai quand l'appareil n'a plus de connexion (mis à jour par le bandeau
  /// « Hors ligne »). Hors ligne, la déconnexion automatique est suspendue :
  /// se reconnecter exige Internet, on ne veut pas bloquer l'atelier.
  static final ValueNotifier<bool> offline = ValueNotifier(false);

  /// Message à afficher sur l'écran de connexion (ex. session terminée).
  static String? notice;

  static Timer? _beat;
  static String _uid = '';
  static String _code = '';

  /// Ouvre la session administrateur : écrit `adminSessions/{uid}` avec le code.
  /// Les règles Firestore comparent ce code au code secret (config/adminInvite) :
  /// un mauvais code => permission-denied. Tant que la session n'est pas valide,
  /// AUCUNE donnée du garage n'est lisible, même avec le bon e-mail/mot de passe.
  static Future<void> startAdminSession(String uid, String code) async {
    // Vérification par le serveur : Internet obligatoire (TimeoutException sinon).
    await _writeSession(uid, code).timeout(const Duration(seconds: 8));
    _uid = uid;
    _code = code;
    adminVerified.value = true;
    _beat?.cancel();
    // La session serveur est valable 12 h (une journée de travail, même si Internet
    // est coupé) et renouvelée toutes les 10 min tant que l'application est ouverte.
    _beat = Timer.periodic(const Duration(minutes: 10), (_) => refreshAdminSession());
  }

  /// Chaque type d'appareil a SA session : `<uid>_d` (ordinateur) ou `<uid>_m`
  /// (téléphone). Ainsi, quitter l'application sur le téléphone ne coupe plus
  /// les droits d'écriture de l'ordinateur (et inversement).
  static String _sessionId(String uid) {
    var mobile = false;
    try {
      final ua = web.window.navigator.userAgent.toLowerCase();
      mobile = ua.contains('mobi') ||
          ua.contains('android') ||
          ua.contains('iphone') ||
          ua.contains('ipad') ||
          web.window.innerWidth < 800;
    } catch (_) {}
    return '${uid}_${mobile ? 'm' : 'd'}';
  }

  static Future<void> _writeSession(String uid, String code) {
    return FirebaseFirestore.instance
        .collection('adminSessions')
        .doc(_sessionId(uid))
        .set({'code': code, 'at': FieldValue.serverTimestamp()});
  }

  /// Renouvelle la session (minuteur, retour au premier plan).
  static Future<void> refreshAdminSession() async {
    if (_uid.isEmpty || _code.isEmpty) return;
    try {
      await _writeSession(_uid, _code).timeout(const Duration(seconds: 5));
    } catch (_) {/* réseau coupé : on réessaiera au prochain tour */}
  }

  static Future<void> signOut({String? reason}) async {
    _beat?.cancel();
    _beat = null;
    // Ferme la session administrateur côté serveur (au mieux).
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && adminVerified.value) {
      try {
        await FirebaseFirestore.instance.collection('adminSessions').doc(_sessionId(uid)).delete();
      } catch (_) {}
    }
    _uid = '';
    _code = '';
    adminVerified.value = false;
    freshLogin = false;
    if (reason != null) notice = reason;
    await FirebaseAuth.instance.signOut();
  }

  static String? takeNotice() {
    final n = notice;
    notice = null;
    return n;
  }
}
