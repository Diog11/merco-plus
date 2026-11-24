import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../screens/cash_screen.dart' show showCashEntryDialog;
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import 'animated_card.dart';

/// Bilan de caisse du jour, pour le tableau de bord : report, entrées,
/// sorties, solde de clôture et derniers mouvements.
class CashTodayCard extends StatefulWidget {
  final VoidCallback? onOpen;
  const CashTodayCard({super.key, this.onOpen});

  @override
  State<CashTodayCard> createState() => _CashTodayCardState();
}

class _CashTodayCardState extends State<CashTodayCard> {
  late final Stream<List<CashEntry>> _stream = FirestoreService.instance.watchCash();
  final _fmt = NumberFormat.decimalPattern('fr_FR');
  final _timeFmt = DateFormat('HH:mm');
  final _dayFmt = DateFormat('EEEE d MMMM', 'fr_FR');

  @override
  Widget build(BuildContext context) {
    return AnimatedCard(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: StreamBuilder<List<CashEntry>>(
          stream: _stream,
          builder: (context, snap) {
            if (snap.hasError) {
              return Text('Caisse indisponible : ${snap.error}',
                  style: const TextStyle(color: MpColors.danger, fontSize: 12));
            }
            if (!snap.hasData) {
              return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator(color: MpColors.accent)));
            }
            final today = DateTime.now();
            final s = CashDaySummary.of(snap.data!, today);
            final last = s.entries.reversed.take(4).toList();

            Widget stat(String label, int value, {Color? color}) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label.toUpperCase(),
                        style: GoogleFonts.oswald(fontSize: 11, letterSpacing: 1.2, color: MpColors.muted)),
                    const SizedBox(height: 6),
                    Text('${_fmt.format(value)} FCFA',
                        style: GoogleFonts.robotoMono(fontSize: 17, fontWeight: FontWeight.w600, color: color)),
                  ],
                );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('CAISSE DU JOUR',
                        style: GoogleFonts.oswald(fontSize: 14, letterSpacing: 1.4, fontWeight: FontWeight.w600)),
                    Text(_dayFmt.format(today), style: const TextStyle(color: MpColors.muted, fontSize: 12)),
                    ElevatedButton.icon(
                      onPressed: () => showCashEntryDialog(context, type: CashType.entree),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Entrée'),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: MpColors.danger, side: const BorderSide(color: MpColors.danger)),
                      onPressed: () => showCashEntryDialog(context, type: CashType.sortie),
                      icon: const Icon(Icons.remove, size: 16),
                      label: const Text('Sortie'),
                    ),
                    if (widget.onOpen != null)
                      TextButton(onPressed: widget.onOpen, child: const Text('Ouvrir le brouillard →')),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 36,
                  runSpacing: 14,
                  children: [
                    stat('Report', s.opening),
                    stat('Entrées', s.totalIn, color: MpColors.accent),
                    stat('Sorties', s.totalOut, color: s.totalOut > 0 ? MpColors.danger : null),
                    stat('Solde de clôture', s.closing, color: s.closing < 0 ? MpColors.danger : MpColors.accent),
                  ],
                ),
                const SizedBox(height: 16),
                if (last.isEmpty)
                  const Text('Aucun mouvement aujourd\'hui.', style: TextStyle(color: MpColors.muted, fontSize: 12.5))
                else
                  ...last.map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(children: [
                          Text(_timeFmt.format(e.date), style: const TextStyle(color: MpColors.muted, fontSize: 12)),
                          const SizedBox(width: 12),
                          Expanded(child: Text(e.label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                          Text('${e.isIn ? '+' : '−'}${_fmt.format(e.amount)}',
                              style: GoogleFonts.robotoMono(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: e.isIn ? MpColors.accent : MpColors.danger)),
                        ]),
                      )),
              ],
            );
          },
        ),
      ),
    );
  }
}
