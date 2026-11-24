import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
import '../services/print_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_card.dart';
import '../widgets/kpi_card.dart';

/// Brouillard de caisse : toutes les entrées et sorties d'argent, jour par
/// jour, avec solde reporté, totaux et solde de clôture.
class CashScreen extends StatefulWidget {
  const CashScreen({super.key});

  @override
  State<CashScreen> createState() => _CashScreenState();
}

class _CashScreenState extends State<CashScreen> {
  late final Stream<List<CashEntry>> _stream = FirestoreService.instance.watchCash();
  DateTime _day = DateTime.now();

  final _fmt = NumberFormat.decimalPattern('fr_FR');
  final _dayFmt = DateFormat('EEEE d MMMM yyyy', 'fr_FR');
  final _timeFmt = DateFormat('HH:mm');

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  bool get _isToday => _sameDay(_day, DateTime.now());

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  void _shift(int days) => setState(() => _day = DateTime(_day.year, _day.month, _day.day + days));

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CashEntry>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
              child: Text('Erreur Firestore : ${snap.error}',
                  style: const TextStyle(color: MpColors.danger, fontSize: 12), textAlign: TextAlign.center));
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: MpColors.accent));
        final sum = CashDaySummary.of(snap.data!, _day);

        return ListView(
          children: [
            _header(sum),
            const SizedBox(height: 18),
            _kpis(sum),
            const SizedBox(height: 14),
            _byMethod(sum),
            const SizedBox(height: 18),
            _journal(sum),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------- en-tête
  Widget _header(CashDaySummary sum) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        IconButton(tooltip: 'Jour précédent', icon: const Icon(Icons.chevron_left), onPressed: () => _shift(-1)),
        Text(_cap(_dayFmt.format(_day)), style: GoogleFonts.oswald(fontSize: 18, fontWeight: FontWeight.w600)),
        IconButton(
            tooltip: 'Jour suivant',
            icon: const Icon(Icons.chevron_right),
            onPressed: _isToday ? null : () => _shift(1)),
        if (!_isToday) TextButton(onPressed: () => setState(() => _day = DateTime.now()), child: const Text("Aujourd'hui")),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: () => showCashEntryDialog(context, type: CashType.entree, forDay: _day),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Entrée'),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
              foregroundColor: MpColors.danger, side: const BorderSide(color: MpColors.danger)),
          onPressed: () => showCashEntryDialog(context, type: CashType.sortie, forDay: _day),
          icon: const Icon(Icons.remove, size: 18),
          label: const Text('Sortie'),
        ),
        OutlinedButton.icon(
          onPressed: () {
            if (!PrintService.printCashDay(sum)) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text("Le navigateur a bloqué la fenêtre d'impression : autorisez les pop-up pour ce site, puis recommencez."),
              ));
            }
          },
          icon: const Icon(Icons.print_outlined, size: 18),
          label: const Text('Imprimer'),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- chiffres clés
  Widget _kpis(CashDaySummary s) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 900 ? 4 : (c.maxWidth > 520 ? 2 : 1);
      final w = (c.maxWidth - (cols - 1) * 14) / cols;
      Widget tile(String label, int value, String sub, IconData icon, {bool warn = false}) => SizedBox(
            width: w,
            child: AnimatedCard(
              child: KpiCard(label: label, value: _fmt.format(value), sub: sub, icon: icon, warn: warn),
            ),
          );
      return Wrap(spacing: 14, runSpacing: 14, children: [
        tile('Solde reporté', s.opening, 'FCFA · solde de la veille', Icons.history, warn: s.opening < 0),
        tile('Entrées du jour', s.totalIn, 'FCFA encaissés', Icons.south_west),
        tile('Sorties du jour', s.totalOut, 'FCFA dépensés', Icons.north_east, warn: s.totalOut > 0),
        tile('Solde de clôture', s.closing, 'FCFA = report + entrées − sorties', Icons.account_balance_wallet_outlined,
            warn: s.closing < 0),
      ]);
    });
  }

  Widget _byMethod(CashDaySummary s) {
    if (s.entries.isEmpty) return const SizedBox.shrink();
    final chips = <Widget>[];
    kPayMethods.forEach((key, label) {
      final used = s.entries.any((e) => e.method == key);
      if (!used) return;
      final n = s.netForMethod(key);
      chips.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: MpColors.surfaceHi, borderRadius: BorderRadius.circular(999)),
        child: Text('$label : ${n >= 0 ? '+' : '−'}${_fmt.format(n.abs())} FCFA',
            style: TextStyle(fontSize: 12, color: n >= 0 ? MpColors.accent : MpColors.danger)),
      ));
    });
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('Par mode de paiement (net du jour) :', style: TextStyle(color: MpColors.muted, fontSize: 12)),
        ...chips,
      ],
    );
  }

  // ---------------------------------------------------------------- journal
  Widget _journal(CashDaySummary s) {
    final mono = GoogleFonts.robotoMono(fontSize: 12.5, fontWeight: FontWeight.w600);
    return AnimatedCard(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth > 760;
          final rows = <Widget>[];
          var running = s.opening;

          // ligne de report
          rows.add(_line(
            wide: wide,
            time: '',
            label: 'Solde reporté de la veille',
            category: '',
            method: '',
            inAmount: '',
            outAmount: '',
            balance: _fmt.format(running),
            muted: true,
            mono: mono,
          ));

          for (final e in s.entries) {
            running += e.signed;
            rows.add(const Divider(height: 1));
            rows.add(_line(
              wide: wide,
              time: _timeFmt.format(e.date),
              label: e.label,
              category: e.category,
              method: kPayMethods[e.method] ?? e.method,
              inAmount: e.isIn ? '+${_fmt.format(e.amount)}' : '',
              outAmount: e.isIn ? '' : '−${_fmt.format(e.amount)}',
              balance: _fmt.format(running),
              mono: mono,
              onDelete: e.source == 'manuel' ? () => _confirmDelete(e) : null,
              onEdit: e.source == 'manuel' ? () => showCashEntryDialog(context, type: e.type, existing: e) : null,
              auto: e.source != 'manuel',
            ));
          }

          rows.add(const Divider(height: 22, thickness: 1.2));
          rows.add(_line(
            wide: wide,
            time: '',
            label: 'TOTAUX DU JOUR',
            category: '',
            method: '',
            inAmount: '+${_fmt.format(s.totalIn)}',
            outAmount: '−${_fmt.format(s.totalOut)}',
            balance: _fmt.format(s.closing),
            mono: mono,
            bold: true,
          ));

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('BROUILLARD DE CAISSE',
                  style: GoogleFonts.oswald(fontSize: 13, letterSpacing: 1.4, color: MpColors.muted)),
              const SizedBox(height: 12),
              if (wide) ...[_headRow(), const Divider(height: 14)],
              ...rows,
              if (s.entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text('Aucun mouvement ce jour-là. Les factures encaissées apparaissent ici automatiquement.',
                      style: TextStyle(color: MpColors.muted, fontSize: 12.5)),
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _headRow() {
    const st = TextStyle(fontSize: 11, color: MpColors.muted, letterSpacing: 1);
    Widget h(String t, int flex, {TextAlign a = TextAlign.left}) =>
        Expanded(flex: flex, child: Text(t.toUpperCase(), textAlign: a, style: st));
    return Row(children: [
      h('Heure', 10),
      h('Libellé', 40),
      h('Catégorie', 24),
      h('Mode', 18),
      h('Entrée', 20, a: TextAlign.right),
      h('Sortie', 20, a: TextAlign.right),
      h('Solde', 22, a: TextAlign.right),
      const SizedBox(width: 70),
    ]);
  }

  Widget _line({
    required bool wide,
    required String time,
    required String label,
    required String category,
    required String method,
    required String inAmount,
    required String outAmount,
    required String balance,
    required TextStyle mono,
    bool muted = false,
    bool bold = false,
    bool auto = false,
    VoidCallback? onDelete,
    VoidCallback? onEdit,
  }) {
    final labelStyle = TextStyle(
        fontSize: 13,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
        color: muted ? MpColors.muted : null);
    final inStyle = mono.copyWith(color: MpColors.accent);
    final outStyle = mono.copyWith(color: MpColors.danger);
    const small = BoxConstraints(minWidth: 32, minHeight: 32);
    final delBtn = SizedBox(
      width: 70,
      child: (onDelete == null && onEdit == null && !auto)
          ? null
          : Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onEdit != null)
                  IconButton(
                      tooltip: 'Modifier',
                      padding: EdgeInsets.zero,
                      constraints: small,
                      icon: const Icon(Icons.edit_outlined, size: 16, color: MpColors.muted),
                      onPressed: onEdit),
                if (onDelete != null)
                  IconButton(
                      tooltip: 'Supprimer',
                      padding: EdgeInsets.zero,
                      constraints: small,
                      icon: const Icon(Icons.delete_outline, size: 16, color: MpColors.muted),
                      onPressed: onDelete),
                if (auto)
                  const Tooltip(
                      message: 'Écriture automatique (facture payée) — modifiez la facture pour la changer',
                      child: Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.bolt, size: 14, color: MpColors.muted))),
              ],
            ),
    );

    if (wide) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Expanded(flex: 10, child: Text(time, style: const TextStyle(fontSize: 12, color: MpColors.muted))),
          Expanded(flex: 40, child: Text(label, style: labelStyle, overflow: TextOverflow.ellipsis)),
          Expanded(flex: 24, child: Text(category, style: const TextStyle(fontSize: 12, color: MpColors.muted))),
          Expanded(flex: 18, child: Text(method, style: const TextStyle(fontSize: 12, color: MpColors.muted))),
          Expanded(flex: 20, child: Text(inAmount, textAlign: TextAlign.right, style: inStyle)),
          Expanded(flex: 20, child: Text(outAmount, textAlign: TextAlign.right, style: outStyle)),
          Expanded(flex: 22, child: Text(balance, textAlign: TextAlign.right, style: mono)),
          delBtn,
        ]),
      );
    }
    // Écran étroit : deux lignes par mouvement.
    final amount = inAmount.isNotEmpty ? inAmount : outAmount;
    final sub = [time, category, method].where((t) => t.isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: labelStyle),
            if (sub.isNotEmpty) Text(sub, style: const TextStyle(fontSize: 11.5, color: MpColors.muted)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (amount.isNotEmpty) Text(amount, style: inAmount.isNotEmpty ? inStyle : outStyle),
          Text('Solde ${balance}', style: const TextStyle(fontSize: 11, color: MpColors.muted)),
        ]),
        delBtn,
      ]),
    );
  }

  Future<void> _confirmDelete(CashEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text('Supprimer « ${e.label} » (${_fmt.format(e.amount)} FCFA) ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok == true) await FirestoreService.instance.deleteCashEntry(e.id);
  }
}

/// Fenêtre de saisie d'une entrée ou d'une sortie de caisse.
/// [forDay] : jour concerné (par défaut aujourd'hui).
Future<void> showCashEntryDialog(BuildContext context,
    {required CashType type, DateTime? forDay, CashEntry? existing}) {
  return showDialog(context: context, builder: (ctx) => _CashEntryDialog(type: type, forDay: forDay, existing: existing));
}

class _CashEntryDialog extends StatefulWidget {
  final CashType type;
  final DateTime? forDay;
  final CashEntry? existing; // non nul : modification d'une écriture
  const _CashEntryDialog({required this.type, this.forDay, this.existing});

  @override
  State<_CashEntryDialog> createState() => _CashEntryDialogState();
}

class _CashEntryDialogState extends State<_CashEntryDialog> {
  late final _labelCtrl = TextEditingController(text: widget.existing?.label ?? '');
  late final _amountCtrl = TextEditingController(text: widget.existing == null ? '' : '${widget.existing!.amount}');
  late String _category = widget.existing != null && widget.existing!.category.isNotEmpty
      ? widget.existing!.category
      : (widget.type == CashType.entree ? kCashInCategories : kCashOutCategories).first;
  late String _method = widget.existing != null && kPayMethods.containsKey(widget.existing!.method)
      ? widget.existing!.method
      : 'especes';
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _labelCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final label = _labelCtrl.text.trim();
    final amount = int.tryParse(_amountCtrl.text.replaceAll(RegExp(r'[\s.]'), '')) ?? 0;
    if (label.isEmpty) {
      setState(() => _error = 'Indiquez un libellé.');
      return;
    }
    if (amount <= 0) {
      setState(() => _error = 'Indiquez un montant supérieur à 0.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final now = DateTime.now();
    final day = widget.forDay ?? now;
    final when = DateTime(day.year, day.month, day.day, now.hour, now.minute);
    try {
      final entry = CashEntry(
        id: widget.existing?.id ?? '',
        type: widget.type,
        amount: amount,
        label: label,
        category: _category,
        method: _method,
        date: widget.existing?.date ?? when,
        source: widget.existing?.source ?? 'manuel',
        docId: widget.existing?.docId ?? '',
      );
      if (widget.existing == null) {
        await FirestoreService.instance.addCashEntry(entry);
      } else {
        await FirestoreService.instance.updateCashEntry(entry);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() {
        _saving = false;
        _error = 'Enregistrement impossible : $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIn = widget.type == CashType.entree;
    final baseCats = isIn ? kCashInCategories : kCashOutCategories;
    // Une ancienne catégorie qui ne figure plus dans la liste reste sélectionnable.
    final cats = baseCats.contains(_category) ? baseCats : [_category, ...baseCats];
    final editing = widget.existing != null;
    return AlertDialog(
      title: Text(editing
          ? (isIn ? 'Modifier l\'entrée de caisse' : 'Modifier la sortie de caisse')
          : (isIn ? 'Nouvelle entrée de caisse' : 'Nouvelle sortie de caisse')),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _labelCtrl,
                autofocus: true,
                decoration: InputDecoration(labelText: isIn ? 'Libellé (ex. Vente huile moteur)' : 'Libellé (ex. Achat plaquettes)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Montant (FCFA)'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Catégorie'),
                items: cats.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _category = v ?? cats.first),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _method,
                decoration: const InputDecoration(labelText: 'Mode de paiement'),
                items: kPayMethods.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                onChanged: (v) => setState(() => _method = v ?? 'especes'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: MpColors.danger, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(onPressed: _saving ? null : _save, child: Text(editing ? 'Enregistrer' : (isIn ? 'Enregistrer l\'entrée' : 'Enregistrer la sortie'))),
      ],
    );
  }
}
