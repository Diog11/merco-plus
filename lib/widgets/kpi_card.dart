import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final bool warn;
  final IconData? icon;

  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.sub,
    this.warn = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyMedium?.color;
    final accent = warn ? MpColors.danger : MpColors.accent;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label.toUpperCase(),
                  style: GoogleFonts.oswald(fontSize: 11, letterSpacing: 1.2, color: MpColors.muted)),
              if (icon != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: accent.withOpacity(.14), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, size: 15, color: accent),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(value,
              style: GoogleFonts.robotoMono(
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                  color: warn ? MpColors.danger : textColor)),
          const SizedBox(height: 6),
          Text(sub, style: const TextStyle(fontSize: 11.5, color: MpColors.muted)),
        ],
      ),
    );
  }
}

class StatusTag extends StatelessWidget {
  final String text;
  final Color fg;
  final Color bg;
  const StatusTag({super.key, required this.text, required this.fg, required this.bg});

  factory StatusTag.red(String text) => StatusTag(text: text, fg: MpColors.red, bg: MpColors.redBg);
  factory StatusTag.green(String text) => StatusTag(text: text, fg: MpColors.green, bg: MpColors.greenBg);
  factory StatusTag.amber(String text) => StatusTag(text: text, fg: MpColors.amber, bg: MpColors.amberBg);
  factory StatusTag.grey(String text) => StatusTag(text: text, fg: MpColors.chromeC, bg: MpColors.chromeC.withOpacity(.15));

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text,
          style: GoogleFonts.oswald(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}
