import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'mp_badge.dart';

/// Footer sobre affiché en bas du tableau de bord, dans l'esprit des
/// sites de référence (navbar + cartes + footer) mais avec l'identité
/// visuelle propre à Merco Plus.
class MpFooter extends StatelessWidget {
  const MpFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 28),
      decoration: const BoxDecoration(
        color: MpColors.ink,
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth > 700;
        final brand = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MpBadge(size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MERCO PLUS',
                      style: GoogleFonts.oswald(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 6),
                  Text(
                    "Diagnostic électronique, réparation mécanique, entretien\net vente de pièces détachées.",
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 11.5, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        );

        final contact = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('CONTACT',
                style: GoogleFonts.oswald(
                    color: Colors.grey.shade500, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            _row(Icons.location_on_outlined, 'Brazzaville, République du Congo'),
            const SizedBox(height: 6),
            _row(Icons.build_outlined, 'Diagnostic · Réparation · Entretien · Pièces'),
          ],
        );

        final legal = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('PLATEFORME',
                style: GoogleFonts.oswald(
                    color: Colors.grey.shade500, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Text('Usage interne — équipe Merco Plus', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
            const SizedBox(height: 6),
            Text('© ${DateTime.now().year} Merco Plus', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
          ],
        );

        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: brand),
              const SizedBox(width: 24),
              Expanded(child: contact),
              const SizedBox(width: 24),
              Expanded(child: legal),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            brand,
            const SizedBox(height: 20),
            contact,
            const SizedBox(height: 20),
            legal,
          ],
        );
      }),
    );
  }

  Widget _row(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(color: Colors.grey.shade400, fontSize: 12))),
      ],
    );
  }
}
