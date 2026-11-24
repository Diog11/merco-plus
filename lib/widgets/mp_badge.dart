import 'package:flutter/material.dart';

/// Logo officiel Merco Plus (écusson + voiture + nom).
///
/// `size` = hauteur du logo. Par défaut la variante pour fonds sombres
/// (marine passé en blanc) ; `onLight: true` donne les couleurs d'origine
/// pour un fond clair.
class MpBadge extends StatelessWidget {
  final double size;
  final bool onLight;
  const MpBadge({super.key, this.size = 44, this.onLight = false});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      onLight ? 'assets/images/logo.png' : 'assets/images/logo_dark.png',
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => SizedBox(width: size, height: size),
    );
  }
}
