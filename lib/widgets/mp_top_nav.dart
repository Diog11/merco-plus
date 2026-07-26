import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'mp_badge.dart';
import 'mp_sidebar.dart' show MpNavEntry;

/// Navbar horizontale unique, noire, sans bordure ni dégradé multicolore :
/// logo, liens de navigation, recherche, notifications, création rapide,
/// avatar et bascule de thème — une seule couleur d'accent (vert).
class MpTopNav extends StatelessWidget implements PreferredSizeWidget {
  final int index;
  final List<MpNavEntry> entries;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onCreateSelect;
  final int alertCount;
  final bool compact;

  const MpTopNav({
    super.key,
    required this.index,
    required this.entries,
    required this.onSelect,
    required this.onCreateSelect,
    this.alertCount = 0,
    this.compact = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(76);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final initials = _initials(user?.displayName ?? user?.email ?? '?');

    return Container(
      color: MpColors.black,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: [
          const MpBadge(size: 34),
          const SizedBox(width: 10),
          Text('MERCO PLUS',
              style: GoogleFonts.oswald(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(width: 26),
          if (!compact)
            Expanded(
              child: Row(
                children: [
                  for (int i = 0; i < entries.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: _NavLink(entry: entries[i], selected: i == index, onTap: () => onSelect(i)),
                    ),
                ],
              ),
            )
          else
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: PopupMenuButton<int>(
                  icon: const Icon(Icons.menu, color: Colors.white),
                  onSelected: onSelect,
                  itemBuilder: (context) => [
                    for (int i = 0; i < entries.length; i++) PopupMenuItem(value: i, child: Text(entries[i].label)),
                  ],
                ),
              ),
            ),
          if (!compact) ...[
            SizedBox(
              width: 240,
              height: 38,
              child: TextField(
                style: const TextStyle(color: Colors.white, fontSize: 12.5),
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 16, color: Colors.grey),
                  hintText: 'Rechercher…',
                  hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  filled: true,
                  fillColor: Colors.white.withOpacity(.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          PopupMenuButton<int>(
            onSelected: onCreateSelect,
            offset: const Offset(0, 44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 1, child: Text('Nouveau client')),
              PopupMenuItem(value: 2, child: Text('Nouvelle pièce')),
              PopupMenuItem(value: 3, child: Text('Nouveau devis')),
              PopupMenuItem(value: 4, child: Text('Nouvelle intervention')),
            ],
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: MpColors.accent, borderRadius: BorderRadius.circular(999)),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 15, color: Colors.black),
                  SizedBox(width: 6),
                  Text('Créer', style: TextStyle(color: Colors.black, fontSize: 12.5, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          _iconBadge(icon: Icons.notifications_outlined, count: alertCount),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: dark ? 'Thème clair' : 'Thème sombre',
            icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, color: Colors.grey, size: 18),
            onPressed: () => mpThemeMode.value = dark ? ThemeMode.light : ThemeMode.dark,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Se déconnecter',
            icon: const Icon(Icons.logout, color: Colors.grey, size: 18),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
          const SizedBox(width: 4),
          CircleAvatar(
            radius: 15,
            backgroundColor: MpColors.accent,
            child: Text(initials, style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _iconBadge({required IconData icon, required int count}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(icon, color: Colors.grey, size: 18),
          onPressed: () {},
        ),
        if (count > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              constraints: const BoxConstraints(minWidth: 14),
              decoration: BoxDecoration(color: MpColors.danger, borderRadius: BorderRadius.circular(20)),
              child: Text('$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
            ),
          ),
      ],
    );
  }

  String _initials(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'[\s@._]+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return trimmed[0].toUpperCase();
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }
}

class _NavLink extends StatefulWidget {
  final MpNavEntry entry;
  final bool selected;
  final VoidCallback onTap;
  const _NavLink({required this.entry, required this.selected, required this.onTap});

  @override
  State<_NavLink> createState() => _NavLinkState();
}

class _NavLinkState extends State<_NavLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected || _hover;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          margin: const EdgeInsets.only(right: 2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.selected ? MpColors.accent.withOpacity(.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.entry.icon, size: 15, color: active ? MpColors.accent : Colors.grey.shade500),
              const SizedBox(width: 7),
              Text(widget.entry.label,
                  style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w500,
                      color: active ? Colors.white : Colors.grey.shade500)),
            ],
          ),
        ),
      ),
    );
  }
}
