import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Nécessaire pour que les formats de date/nombre en français
  // (ex. "juil.", NumberFormat 'fr_FR') fonctionnent correctement —
  // sans ça, DateFormat('MMM', 'fr_FR') lève une LocaleDataException.
  await initializeDateFormatting('fr_FR', null);

  // IMPORTANT : firebase_options.dart (voir ce fichier) contient des valeurs
  // d'exemple. Générez les vraies valeurs pour votre projet Firebase avec :
  //   flutterfire configure
  // avant de lancer l'application pour de vrai — voir README.md.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // MODE HORS LIGNE : cache local des données (IndexedDB). Les écrans continuent
  // de fonctionner sans Internet ; les modifications attendent puis partent
  // automatiquement au retour de la connexion.
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (_) {/* ex. persistance indisponible (navigation privée) : mode en ligne seulement */}

  // Session limitée à l'onglet : fermer l'onglet / le navigateur déconnecte,
  // et il faut ressaisir e-mail + mot de passe. (Web uniquement.)
  if (kIsWeb) {
    try {
      await FirebaseAuth.instance.setPersistence(Persistence.SESSION);
    } catch (_) {/* sans gravité : la déconnexion à l'absence reste active */}
  }

  runApp(const MercoPlusApp());
}

class MercoPlusApp extends StatelessWidget {
  const MercoPlusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: mpThemeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Merco Plus — Gestion',
          debugShowCheckedModeBanner: false,
          theme: MpTheme.light(),
          darkTheme: MpTheme.dark(),
          themeMode: mode,
          home: const AuthGate(),
        );
      },
    );
  }
}
