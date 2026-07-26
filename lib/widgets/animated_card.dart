import 'package:flutter/material.dart';

/// Enveloppe n'importe quel contenu de carte avec une légère apparition
/// en fondu/glissement au montage, et un effet de "soulèvement" (ombre +
/// léger déplacement) au survol de la souris. Aucune bordure — les cartes
/// se distinguent du fond uniquement par une nuance de noir plus claire.
class AnimatedCard extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final EdgeInsetsGeometry? margin;

  const AnimatedCard({super.key, required this.child, this.delay = Duration.zero, this.margin});

  @override
  State<AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard> {
  bool _visible = false;
  bool _hover = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;

    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.04),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOut,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              margin: widget.margin,
              transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: _hover
                    ? [BoxShadow(color: Colors.black.withOpacity(dark ? .5 : .10), blurRadius: 26, offset: const Offset(0, 14))]
                    : [BoxShadow(color: Colors.black.withOpacity(dark ? .3 : .05), blurRadius: 12, offset: const Offset(0, 5))],
                // Pas de bordure : les cartes se distinguent du fond
                // uniquement par une nuance de noir légèrement plus claire
                // (identité "flottante", sans contour), qui s'éclaircit
                // discrètement au survol.
                color: dark && _hover ? Color.alphaBlend(Colors.white.withOpacity(.03), cardColor) : cardColor,
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
