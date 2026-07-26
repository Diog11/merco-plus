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
