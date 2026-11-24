import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/auth_flow.dart';
import '../services/sync_status.dart';
import '../theme/app_theme.dart';

/// Bandeau d'état de la connexion. Invisible quand tout va bien ; affiche
/// « Hors ligne » quand Internet est coupé, puis « Synchronisation… » au retour
/// de la connexion, le temps que les modifications en attente partent.
///
/// L'état est déduit des métadonnées Firestore (données lues depuis le cache ou
/// depuis le serveur) sur le profil de l'utilisateur connecté.
class ConnectionBanner extends StatefulWidget {
  final String uid;
  const ConnectionBanner({super.key, required this.uid});

  @override
  State<ConnectionBanner> createState() => _ConnectionBannerState();
}

class _ConnectionBannerState extends State<ConnectionBanner> {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  Timer? _debounce;
  bool _offline = false;
  bool _syncing = false;
  Timer? _errTimer;

  void _onSyncError() {
    if (!mounted) return;
    setState(() {});
    _errTimer?.cancel();
    if (SyncStatus.error.value != null) {
      _errTimer = Timer(const Duration(seconds: 25), SyncStatus.clear);
    }
  }

  @override
  void initState() {
    super.initState();
    SyncStatus.error.addListener(_onSyncError);
    _sub = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .snapshots(includeMetadataChanges: true)
        .listen((snap) {
      if (snap.metadata.isFromCache) {
        // Au démarrage, les premières données viennent toujours du cache :
        // on attend 3 s avant de conclure qu'on est vraiment hors ligne.
        _debounce ??= Timer(const Duration(seconds: 3), () => _setOffline(true));
      } else {
        _debounce?.cancel();
        _debounce = null;
        _setOffline(false);
      }
    }, onError: (_) {});
  }

  void _setOffline(bool value) {
    if (!mounted || value == _offline) return;
    setState(() => _offline = value);
    AuthFlow.offline.value = value;
    if (!value) {
      setState(() => _syncing = true);
      FirebaseFirestore.instance
          .waitForPendingWrites()
          .timeout(const Duration(seconds: 30), onTimeout: () {})
          .whenComplete(() {
        if (mounted) setState(() => _syncing = false);
      });
    }
  }

  @override
  void dispose() {
    SyncStatus.error.removeListener(_onSyncError);
    _errTimer?.cancel();
    _sub?.cancel();
    _debounce?.cancel();
    AuthFlow.offline.value = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final err = SyncStatus.error.value;
    final errorBar = err == null
        ? const SizedBox.shrink()
        : Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: MpColors.danger.withOpacity(.18),
            child: Row(
              children: [
                const Icon(Icons.error_outline, size: 16, color: MpColors.danger),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(err,
                      style: const TextStyle(color: MpColors.danger, fontSize: 12.5, fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 16, color: MpColors.danger),
                  onPressed: SyncStatus.clear,
                ),
              ],
            ),
          );
    if (!_offline && !_syncing) return errorBar;
    final offline = _offline;
    final color = offline ? MpColors.warning : MpColors.accent;
    final statusBar = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: color.withOpacity(.16),
      child: Row(
        children: [
          Icon(offline ? Icons.cloud_off_outlined : Icons.sync, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              offline
                  ? 'Hors ligne — vos modifications sont enregistrées sur cet appareil et partiront automatiquement au retour d\'Internet.'
                  : 'Connexion rétablie — synchronisation des modifications…',
              style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    return Column(mainAxisSize: MainAxisSize.min, children: [errorBar, statusBar]);
  }
}
