import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Refonte complète, inspirée d'une identité "éditoriale" façon Nsomi
/// Jire : fond noir pur, aucune bordure de carte, une seule couleur
/// d'accent (vert). Le rouge/l'orange ne sont conservés que pour des
/// alertes fonctionnelles réelles (facture impayée, stock bas) — jamais
/// comme couleur décorative de l'interface.
class MpColors {
  static const black = Color(0xFF000000); // fond de page, pur
  static const surface = Color(0xFF0D0F11); // cartes — à peine plus clair que le fond, sans bordure
  static const surfaceHi = Color(0xFF15181B); // survol / éléments légèrement surélevés

  // Accent unique
  static const accent = Color(0xFF22C55E);
  static const accentDim = Color(0x2622C55E); // accent en fond translucide (badges, glow)

  // Alertes fonctionnelles uniquement (jamais décoratives)
  static const danger = Color(0xFFEF4444);
  static const dangerDim = Color(0x26EF4444);
  static const warning = Color(0xFFF59E0B);
  static const warningDim = Color(0x26F59E0B);

  // Texte
  static const textPrimaryDark = Color(0xFFF5F7F7);
  static const textPrimaryLight = Color(0xFF0A0C0D);
  static const muted = Color(0xFF8A9199);

  static const borderDark = Color(0x14FFFFFF); // liseré quasi invisible, réservé aux séparateurs de texte
  static const bgLight = Color(0xFFF7F8F7);
  static const cardLight = Color(0xFFFFFFFF);
  static const borderLight = Color(0xFFE7E9E7);

  // Alias conservés pour compatibilité avec du code existant (rétrocompatibilité
  // des noms utilisés ailleurs dans le projet).
  static const ink = black;
  static const graphite = surface;
  static const graphiteHi = surfaceHi;
  static const blue = accent;
  static const blueLight = accent;
  static const red = danger;
  static const redBg = dangerDim;
  static const green = accent;
  static const greenBg = accentDim;
  static const amber = warning;
  static const amberBg = warningDim;
  static const chromeC = muted;
}

/// Bascule sombre/clair partagée par toute l'application. Défaut : sombre.
final ValueNotifier<ThemeMode> mpThemeMode = ValueNotifier(ThemeMode.dark);

class MpTheme {
  static const _radius = 20.0;

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    final display = GoogleFonts.oswaldTextTheme(base.textTheme);
    final body = GoogleFonts.interTextTheme(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: MpColors.black,
      colorScheme: base.colorScheme.copyWith(
        brightness: Brightness.dark,
        primary: MpColors.accent,
        secondary: MpColors.accent,
        error: MpColors.danger,
        surface: MpColors.surface,
        onSurface: MpColors.textPrimaryDark,
      ),
      textTheme: body.copyWith(
        headlineLarge: display.headlineLarge?.copyWith(fontWeight: FontWeight.w700, color: MpColors.textPrimaryDark),
        headlineMedium: display.headlineMedium?.copyWith(fontWeight: FontWeight.w600, color: MpColors.textPrimaryDark),
        titleLarge: display.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: MpColors.textPrimaryDark, letterSpacing: 1.1),
        titleMedium: display.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: MpColors.textPrimaryDark),
        bodyMedium: body.bodyMedium?.copyWith(color: MpColors.textPrimaryDark),
        bodyLarge: body.bodyLarge?.copyWith(color: MpColors.textPrimaryDark),
        labelLarge: display.labelLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 1.2),
      ),
      cardColor: MpColors.surface,
      dividerColor: MpColors.borderDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: MpColors.black,
        foregroundColor: MpColors.textPrimaryDark,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: MpColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: MpColors.accent,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: MpColors.textPrimaryDark,
          side: const BorderSide(color: MpColors.borderDark),
          shape: const StadiumBorder(),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MpColors.surface,
        hintStyle: const TextStyle(color: MpColors.muted),
        labelStyle: const TextStyle(color: MpColors.muted),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MpColors.accent, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: MpColors.surfaceHi,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: MpColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
      ),
    );
  }

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    final display = GoogleFonts.oswaldTextTheme(base.textTheme);
    final body = GoogleFonts.interTextTheme(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: MpColors.bgLight,
      colorScheme: base.colorScheme.copyWith(
        brightness: Brightness.light,
        primary: MpColors.accent,
        secondary: MpColors.accent,
        error: MpColors.danger,
        surface: MpColors.cardLight,
        onSurface: MpColors.textPrimaryLight,
      ),
      textTheme: body.copyWith(
        headlineLarge: display.headlineLarge?.copyWith(fontWeight: FontWeight.w700, color: MpColors.textPrimaryLight),
        headlineMedium: display.headlineMedium?.copyWith(fontWeight: FontWeight.w600, color: MpColors.textPrimaryLight),
        titleLarge: display.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: MpColors.textPrimaryLight, letterSpacing: 1.1),
        titleMedium: display.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: MpColors.textPrimaryLight),
        bodyMedium: body.bodyMedium?.copyWith(color: MpColors.textPrimaryLight),
        bodyLarge: body.bodyLarge?.copyWith(color: MpColors.textPrimaryLight),
        labelLarge: display.labelLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 1.2),
      ),
      cardColor: MpColors.cardLight,
      dividerColor: MpColors.borderLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: MpColors.black, // navbar toujours noire, quel que soit le mode
        foregroundColor: MpColors.textPrimaryDark,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: MpColors.cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: MpColors.accent,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: MpColors.accent,
          side: const BorderSide(color: MpColors.borderLight),
          shape: const StadiumBorder(),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: const TextStyle(color: MpColors.muted),
        labelStyle: const TextStyle(color: MpColors.muted),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: MpColors.borderLight)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: MpColors.borderLight)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MpColors.accent, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: MpColors.cardLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
      ),
    );
  }
}
