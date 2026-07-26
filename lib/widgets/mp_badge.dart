import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Écusson circulaire "MP" — identité visuelle propre à Merco Plus,
/// alignée sur l'accent unique (vert) du reste de la plateforme.
class MpBadge extends StatelessWidget {
  final double size;
  const MpBadge({super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: MpColors.accent),
      child: Center(
        child: Text(
          'MP',
          style: GoogleFonts.oswald(
            color: Colors.black,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.36,
            letterSpacing: .5,
          ),
        ),
      ),
    );
  }
}
