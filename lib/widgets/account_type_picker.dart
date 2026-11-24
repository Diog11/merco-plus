import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

/// Choix du type de compte : Admin (accès total) ou Technicien (restreint).
/// Le type "Admin" demande un code d'invitation, vérifié côté serveur par
/// les règles Firestore — voir firestore.rules.
class AccountTypePicker extends StatefulWidget {
  final UserRole role;
  final ValueChanged<UserRole> onChanged;
  final TextEditingController adminCodeCtrl;

  const AccountTypePicker({
    super.key,
    required this.role,
    required this.onChanged,
    required this.adminCodeCtrl,
  });

  @override
  State<AccountTypePicker> createState() => _AccountTypePickerState();
}

class _AccountTypePickerState extends State<AccountTypePicker> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Type de compte', style: TextStyle(color: MpColors.muted, fontSize: 12)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _Tile(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Admin',
                subtitle: 'Accès total',
                selected: widget.role == UserRole.admin,
                onTap: () => widget.onChanged(UserRole.admin),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Tile(
                icon: Icons.engineering_outlined,
                title: 'Technicien',
                subtitle: 'Mes interventions',
                selected: widget.role == UserRole.technicien,
                onTap: () => widget.onChanged(UserRole.technicien),
              ),
            ),
          ],
        ),
        if (widget.role == UserRole.admin) ...[
          const SizedBox(height: 14),
          TextField(
            controller: widget.adminCodeCtrl,
            obscureText: _obscure,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'Code administrateur',
              helperText: 'Fourni par le gérant — sans ce code, le compte Admin est refusé.',
              helperMaxLines: 2,
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Afficher le code' : 'Masquer le code',
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
        ] else ...[
          const SizedBox(height: 8),
          const Text(
            'Un technicien voit uniquement les interventions qui lui sont attribuées.',
            style: TextStyle(color: MpColors.muted, fontSize: 11.5),
          ),
        ],
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? MpColors.accent.withOpacity(.14) : MpColors.surfaceHi,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? MpColors.accent : Colors.transparent, width: 1.2),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: selected ? MpColors.accent : MpColors.muted),
            const SizedBox(height: 6),
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: selected ? Colors.white : MpColors.textPrimaryDark)),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: MpColors.muted)),
          ],
        ),
      ),
    );
  }
}
