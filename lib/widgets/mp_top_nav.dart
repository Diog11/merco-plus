import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/auth_flow.dart';
import 'mp_badge.dart';
import 'mp_sidebar.dart' show MpNavEntry;

/// Navbar horizontale unique, noire, une seule couleur d'accent (vert).
///
/// Elle s'adapte à la largeur disponible SANS jamais cacher un bouton :
///  - large    : icône + libellé pour chaque onglet
///  - moyen    : onglet actif avec libellé, les autres en icône (info-bulle au survol)
///  - étroit   : menu déroulant (≡) qui liste tous les onglets
/// Les actions de droite (Créer, alertes, thème, déconnexion, avatar) restent
/// toujours visibles.
class MpTopNav extends StatelessWidget implements PreferredSizeWidget {
  final int index;
  final List<MpNavEntry> entries;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onCreateSelect;
  final int alertCount;
  final String userName;
  final String roleLabel;
  final bool showCreate;

  const MpTopNav({
    super.key,
    required this.index,
    required this.entries,
    required this.onSelect,
    required this.onCreateSelect,
    this.alertCount = 0,
    this.userName = '',
    this.roleLabel = '',
    this.showCreate = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(76);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;
    final initials = _initials(userName.isNotEmpty ? userName : (user?.displayName ?? user?.email ?? '?'));

    return Container(
      color: MpColors.black,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth;
        final showTheme = w >= 470;
        final showBell = w >= 420 && showCreate;
        final showAvatar = w >= 380;
        final showSearch = showCreate && w >= 1650;

        return Row(
          children: [
            const MpBadge(size: 46),
            const SizedBox(width: 18),
            Expanded(
              child: LayoutBuilder(builder: (context, nc) {
                final room = nc.maxWidth;
                final needFull = entries.length * 165.0;
                final needCondensed = entries.length * 44.0 + 120;
                if (room >= needFull) return _links(iconOnlyInactive: false);
                if (room >= needCondensed) return _links(iconOnlyInactive: true);
                return Align(
                  alignment: Alignment.centerLeft,
                  child: PopupMenuButton<int>(
                    tooltip: 'Menu',
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onSelected: onSelect,
                    itemBuilder: (context) => [
                      for (int i = 0; i < entries.length; i++)
                        PopupMenuItem(
                          value: i,
                          child: Row(children: [
                            Icon(entries[i].icon, size: 16, color: i == index ? MpColors.accent : MpColors.muted),
                            const SizedBox(width: 10),
                            Text(entries[i].label),
                          ]),
                        ),
                    ],
                  ),
                );
              }),
            ),
            if (showSearch) ...[
              SizedBox(
                width: 220,
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
            if (showCreate)
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
                  padding: const EdgeInsets.symmetric(horizontal: 14),
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
            if (showBell) _iconBadge(icon: Icons.notifications_outlined, count: alertCount),
            if (showTheme)
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
              onPressed: () => AuthFlow.signOut(),
            ),
            if (showAvatar) ...[
              const SizedBox(width: 4),
              Tooltip(
                message: roleLabel.isEmpty ? userName : '$userName · $roleLabel',
                child: CircleAvatar(
                  radius: 15,
                  backgroundColor: MpColors.accent,
                  child: Text(initials,
                      style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ],
        );
      }),
    );
  }

  Widget _links({required bool iconOnlyInactive}) {
    // FittedBox : filet de sécurité — si la place est plus juste que prévu,
    // les onglets rétrécissent au lieu de déborder ou d'être masqués.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
        for (int i = 0; i < entries.length; i++)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _NavLink(
              entry: entries[i],
              selected: i == index,
              iconOnly: iconOnlyInactive && i != index,
              onTap: () => onSelect(i),
            ),
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
  final bool iconOnly;
  final VoidCallback onTap;
  const _NavLink({required this.entry, required this.selected, required this.onTap, this.iconOnly = false});

  @override
  State<_NavLink> createState() => _NavLinkState();
}

class _NavLinkState extends State<_NavLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected || _hover;
    final link = MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 38,
          padding: EdgeInsets.symmetric(horizontal: widget.iconOnly ? 11 : 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.selected ? MpColors.accent.withOpacity(.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.entry.icon, size: 16, color: active ? MpColors.accent : Colors.grey.shade500),
              if (!widget.iconOnly) ...[
                const SizedBox(width: 7),
                Text(widget.entry.label,
                    maxLines: 1,
                    softWrap: false,
                    style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w500,
                        color: active ? Colors.white : Colors.grey.shade500)),
              ],
            ],
          ),
        ),
      ),
    );
    return widget.iconOnly ? Tooltip(message: widget.entry.label, child: link) : link;
  }
}
