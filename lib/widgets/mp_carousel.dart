import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Carrousel horizontal générique : fait défiler n'importe quelle liste
/// de widgets (images, cartes d'info...) avec flèches de navigation et
/// indicateurs à points. Utilisé pour la galerie de l'atelier, et
/// réutilisable pour d'autres sections à l'avenir.
class MpCarousel extends StatefulWidget {
  final List<Widget> items;
  final double height;
  final double viewportFraction;

  const MpCarousel({
    super.key,
    required this.items,
    this.height = 220,
    this.viewportFraction = .42,
  });

  @override
  State<MpCarousel> createState() => _MpCarouselState();
}

class _MpCarouselState extends State<MpCarousel> {
  late final PageController _controller;
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: widget.viewportFraction);
    _controller.addListener(() {
      setState(() => _page = _controller.page ?? 0);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final target = (_page.round() + delta).clamp(0, widget.items.length - 1);
    _controller.animateToPage(target, duration: const Duration(milliseconds: 320), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.items.length,
            itemBuilder: (context, i) {
              final delta = (_page - i).abs();
              final scale = 1 - (delta * .08).clamp(0.0, .12);
              final opacity = 1 - (delta * .35).clamp(0.0, .55);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Transform.scale(
                  scale: scale,
                  child: Opacity(opacity: opacity, child: widget.items[i]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _arrow(Icons.chevron_left, () => _go(-1)),
            const SizedBox(width: 10),
            for (int i = 0; i < widget.items.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _page.round() == i ? 20 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: _page.round() == i ? MpColors.blue : Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            const SizedBox(width: 10),
            _arrow(Icons.chevron_right, () => _go(1)),
          ],
        ),
      ],
    );
  }

  Widget _arrow(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Theme.of(context).dividerColor)),
        child: Icon(icon, size: 18),
      ),
    );
  }
}
