import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
import '../services/print_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_card.dart';
import '../widgets/kpi_card.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  String _search = '';
  int _filter = 0; // 0 tous · 1 devis · 2 factures impayées · 3 factures payées
  final _fmt = NumberFormat.decimalPattern('fr_FR');
  final _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SizedBox(
              width: 260,
              child: TextField(
                decoration: const InputDecoration(hintText: 'Rechercher un client…'),
                onChanged: (v) => setState(() => _search = v.toLowerCase()),
              ),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _openDocDialog(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nouveau devis'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<List<Client>>(
            stream: fs.watchClients(),
            builder: (context, clientsSnap) {
              final clients = clientsSnap.data ?? [];
              Client? clientOf(String id) {
                for (final c in clients) {
                  if (c.id == id) return c;
                }
                return null;
              }

              return StreamBuilder<List<DocumentRecord>>(
                stream: fs.watchDocuments(),
                builder: (context, snap) {
                  if (snap.hasError) return Center(child: Text('Erreur Firestore : ${snap.error}', style: const TextStyle(color: MpColors.red, fontSize: 12), textAlign: TextAlign.center));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  final all = snap.data!;
                  final unpaid = all.where((d) => d.type == DocType.facture && d.status == DocStatus.impaye).toList();
                  final paid = all.where((d) => d.type == DocType.facture && d.status == DocStatus.paye).toList();
                  final quotes = all.where((d) => d.type == DocType.devis).toList();
                  final cashedIn = paid.fold<int>(0, (a, d) => a + d.total);
                  final toCollect = unpaid.fold<int>(0, (a, d) => a + d.remaining);

                  var docs = switch (_filter) {
                    1 => quotes,
                    2 => unpaid,
                    3 => paid,
                    _ => all,
                  };
                  if (_search.isNotEmpty) {
                    docs = docs.where((d) => (clientOf(d.clientId)?.name ?? '').toLowerCase().contains(_search)).toList();
                  }
                  // Les factures payées : les plus récemment encaissées d'abord.
                  if (_filter == 3) {
                    docs = [...docs]..sort((a, b) => (b.paidAt ?? b.date).compareTo(a.paidAt ?? a.date));
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _chip(0, 'Tous', all.length),
                          _chip(1, 'Devis', quotes.length),
                          _chip(2, 'Factures impayées', unpaid.length),
                          _chip(3, 'Factures payées', paid.length),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 24,
                        runSpacing: 6,
                        children: [
                          Text('Encaissé : ${_fmt.format(cashedIn)} FCFA',
                              style: const TextStyle(color: MpColors.accent, fontWeight: FontWeight.w700, fontSize: 13)),
                          Text('Reste à encaisser : ${_fmt.format(toCollect)} FCFA',
                              style: TextStyle(
                                  color: toCollect > 0 ? MpColors.danger : MpColors.muted,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: docs.isEmpty
                            ? Center(
                                child: Text(switch (_filter) {
                                1 => 'Aucun devis.',
                                2 => 'Aucune facture impayée.',
                                3 => 'Aucune facture payée pour le moment.',
                                _ => 'Aucun devis ni facture. Ajoutez-en un pour commencer.',
                              }))
                            : AnimatedCard(
                                child: ListView.separated(
                                  itemCount: docs.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                  itemBuilder: (context, i) {
                                    final d = docs[i];
                                    final c = clientOf(d.clientId);
                                    Vehicle? v;
                                    if (c != null) {
                                      for (final veh in c.vehicles) {
                                        if (veh.id == d.vehicleId) v = veh;
                                      }
                                    }
                                    final isPaid = d.type == DocType.facture && d.status == DocStatus.paye;
                                    final payInfo = isPaid && d.paidAt != null
                                        ? '  ·  Payée le ${_dateFmt.format(d.paidAt!)}'
                                            '${kPayMethods[d.payMethod] == null ? '' : ' (${kPayMethods[d.payMethod]})'}'
                                        : '';
                                    final narrow = MediaQuery.of(context).size.width < 700;
                                    final shortState = narrow && d.type == DocType.facture
                                        ? (d.status == DocStatus.paye ? '  ·  Payée' : '  ·  Impayée')
                                        : '';
                                    final extra = StringBuffer();
                                    if (d.discount > 0) {
                                      extra.write('  ·  Remise ${d.discountType == 'percent' ? '${d.discountValue} %' : '${_fmt.format(d.discount)} FCFA'}');
                                    }
                                    if (d.type == DocType.facture && d.deposit > 0) {
                                      extra.write('  ·  Acompte ${_fmt.format(d.deposit)} FCFA');
                                      if (!isPaid) extra.write('  ·  Reste ${_fmt.format(d.remaining)} FCFA');
                                    }
                                    return ListTile(
                                      onTap: () => _openDocDialog(context, existing: d),
                                      title: Text('#${d.num}  ·  ${c?.name ?? "—"}${v != null ? " · ${v.plate}" : ""}'),
                                      subtitle: Text('${_dateFmt.format(d.date)}  ·  ${_fmt.format(d.total)} FCFA${d.tvaRate > 0 ? ' TTC' : ''}$extra$shortState$payInfo'),
                                      leading: d.type == DocType.facture
                                          ? StatusTag.grey('Facture')
                                          : StatusTag.amber('Devis'),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (!narrow) ...[_statusTag(d), const SizedBox(width: 4)],
                                          IconButton(
                                            tooltip: 'Imprimer',
                                            visualDensity: VisualDensity.compact,
                                            icon: const Icon(Icons.print_outlined, size: 20),
                                            onPressed: () => _print(context, d, c, v),
                                          ),
                                          PopupMenuButton<String>(
                                            onSelected: (action) async {
                                              switch (action) {
                                                case 'modifier':
                                                  _openDocDialog(context, existing: d);
                                                  break;
                                                case 'imprimer':
                                                  _print(context, d, c, v);
                                                  break;
                                                case 'facturer':
                                                  await fs.convertToInvoice(d.id);
                                                  break;
                                                case 'payee':
                                                  final method = await _askPayMethod(context, d);
                                                  if (method != null) await fs.markPaid(d.id, method: method);
                                                  break;
                                                case 'suppr':
                                                  await fs.deleteDocument(d.id);
                                                  break;
                                              }
                                            },
                                            itemBuilder: (ctx) => [
                                              const PopupMenuItem(value: 'modifier', child: Text('Modifier')),
                                              const PopupMenuItem(value: 'imprimer', child: Text('Imprimer')),
                                              if (d.type == DocType.devis)
                                                const PopupMenuItem(value: 'facturer', child: Text('Convertir en facture')),
                                              if (d.type == DocType.facture && d.status == DocStatus.impaye)
                                                const PopupMenuItem(value: 'payee', child: Text('Marquer payée')),
                                              const PopupMenuItem(value: 'suppr', child: Text('Supprimer')),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _chip(int value, String label, int count) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: selected,
      showCheckmark: false,
      selectedColor: MpColors.accent.withOpacity(.18),
      labelStyle: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: selected ? MpColors.accent : MpColors.muted),
      onSelected: (_) => setState(() => _filter = value),
    );
  }

  /// Demande le mode de paiement avant d'encaisser la facture.
  Future<String?> _askPayMethod(BuildContext context, DocumentRecord d) {
    String method = 'especes';
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        return AlertDialog(
          title: Text('Encaisser la facture #${d.num}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (d.deposit > 0) ...[
                Text('Total : ${_fmt.format(d.total)} FCFA   ·   Acompte déjà versé : ${_fmt.format(d.deposit)} FCFA',
                    style: const TextStyle(color: MpColors.muted, fontSize: 12.5)),
                const SizedBox(height: 4),
              ],
              Text('${_fmt.format(d.deposit > 0 ? (d.total - d.deposit < 0 ? 0 : d.total - d.deposit) : d.total)} FCFA',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 4),
              const Text('Ce montant sera ajouté au brouillard de caisse du jour.',
                  style: TextStyle(color: MpColors.muted, fontSize: 12)),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: method,
                decoration: const InputDecoration(labelText: 'Mode de paiement'),
                items: kPayMethods.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setLocal(() => method = v ?? 'especes'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, method), child: const Text('Encaisser')),
          ],
        );
      }),
    );
  }

  Widget _statusTag(DocumentRecord d) {
    if (d.type == DocType.devis) return StatusTag.grey('En attente de validation');
    return d.status == DocStatus.paye ? StatusTag.green('Payée') : StatusTag.red('Impayée');
  }

  void _openDocDialog(BuildContext context, {DocumentRecord? existing}) {
    showDialog(
      context: context,
      builder: (ctx) => _DocDialog(existing: existing),
    );
  }

  void _print(BuildContext context, DocumentRecord d, Client? c, Vehicle? v) {
    final ok = PrintService.printDocument(doc: d, client: c, vehicle: v);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Le navigateur a bloqué la fenêtre d'impression : autorisez les pop-up pour ce site, puis recommencez."),
      ));
    }
  }
}

class _DocDialog extends StatefulWidget {
  final DocumentRecord? existing; // non nul : modification d'un document existant
  const _DocDialog({this.existing});

  @override
  State<_DocDialog> createState() => _DocDialogState();
}

class _LineDraft {
  final TextEditingController descCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;
  _LineDraft({String desc = '', int qty = 1, int price = 0})
      : descCtrl = TextEditingController(text: desc),
        qtyCtrl = TextEditingController(text: '$qty'),
        priceCtrl = TextEditingController(text: '$price');
}

class _DocDialogState extends State<_DocDialog> {
  // Flux créé une seule fois (et non à chaque reconstruction).
  late final Stream<List<Client>> _clientsStream = FirestoreService.instance.watchClients();
  late DocType _type = widget.existing?.type ?? DocType.devis;
  late String? _clientId = (widget.existing?.clientId.isEmpty ?? true) ? null : widget.existing!.clientId;
  late String? _vehicleId = (widget.existing?.vehicleId.isEmpty ?? true) ? null : widget.existing!.vehicleId;
  late final List<_LineDraft> _lines = (widget.existing == null || widget.existing!.lines.isEmpty)
      ? [_LineDraft()]
      : widget.existing!.lines.map((l) => _LineDraft(desc: l.desc, qty: l.qty, price: l.price)).toList();

  late bool _tva = (widget.existing?.tvaRate ?? 0) > 0;
  late bool _cad = (widget.existing?.cadRate ?? 0) > 0 && (widget.existing?.tvaRate ?? 0) > 0;

  // Remise : '' (aucune) | 'percent' | 'amount' — saisie dans _discCtrl.
  late String _discType = (widget.existing?.discountType.isEmpty ?? true) ? 'percent' : widget.existing!.discountType;
  late final TextEditingController _discCtrl = TextEditingController(
      text: (widget.existing?.discountValue ?? 0) > 0 ? '${widget.existing!.discountValue}' : '');
  late final TextEditingController _depCtrl = TextEditingController(
      text: (widget.existing?.deposit ?? 0) > 0 ? '${widget.existing!.deposit}' : '');

  final _money = NumberFormat.decimalPattern('fr_FR');

  List<LineItem> _draftLines() => _lines
      .map((l) => LineItem(
            desc: l.descCtrl.text.trim(),
            qty: int.tryParse(l.qtyCtrl.text) ?? 0,
            price: int.tryParse(l.priceCtrl.text) ?? 0,
          ))
      .toList();

  int get _tvaRate => _tva ? kTvaRate : 0;
  int get _cadRate => (_tva && _cad) ? kCadRate : 0;

  /// Les lignes saisies sont des montants HORS TAXES ; TVA = 18 % du HT,
  /// CAD = 5 % du montant de la TVA ; TTC = HT + TVA + CAD.
  int get _discValue => int.tryParse(_discCtrl.text.trim()) ?? 0;
  String get _discTypeSaved => _discValue > 0 ? _discType : '';
  int get _depValue => int.tryParse(_depCtrl.text.trim()) ?? 0;

  DocTotals get _totals => DocTotals.of(_draftLines(),
      tvaRate: _tvaRate, cadRate: _cadRate, discountType: _discTypeSaved, discountValue: _discValue);

  /// Acompte retenu : jamais supérieur au total TTC, et seulement pour une facture.
  int get _depositSaved {
    if (_type != DocType.facture) return 0;
    final ttc = _totals.ttc;
    return _depValue > ttc ? ttc : _depValue;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Client>>(
      stream: _clientsStream,
      builder: (context, snap) {
        final clients = snap.data ?? [];
        final selectedClient = clients.where((c) => c.id == _clientId).firstOrNull;
        // Calculé à chaque reconstruction : la liste des véhicules suit le client choisi.
        final vehicles = selectedClient?.vehicles ?? <Vehicle>[];
        final vehicleValue = vehicles.any((v) => v.id == _vehicleId) ? _vehicleId : null;

        return AlertDialog(
          title: Text(widget.existing == null
              ? 'Nouveau devis'
              : (_type == DocType.facture
                  ? 'Modifier la facture #${widget.existing!.num}'
                  : 'Modifier le devis #${widget.existing!.num}')),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Builder(builder: (context) {
                final setLocal = (VoidCallback fn) => setState(fn);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (snap.hasError)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text('Impossible de charger les clients : ${snap.error}',
                            style: const TextStyle(color: MpColors.danger, fontSize: 12)),
                      )
                    else if (!snap.hasData)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: LinearProgressIndicator(minHeight: 2),
                      )
                    else if (clients.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: Text('Aucun client enregistré : créez-en un dans l\'onglet « Clients & véhicules ».',
                            style: TextStyle(color: MpColors.warning, fontSize: 12)),
                      ),
                    if (widget.existing != null &&
                        widget.existing!.type == DocType.facture &&
                        widget.existing!.status == DocStatus.paye)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: Text('Facture déjà encaissée : le brouillard de caisse sera mis à jour avec le nouveau total et l\'acompte.',
                            style: TextStyle(color: MpColors.warning, fontSize: 12)),
                      ),
                    Row(children: [
                      Expanded(
                        child: DropdownButtonFormField<DocType>(
                          value: _type,
                          decoration: const InputDecoration(labelText: 'Type de document'),
                          items: const [
                            DropdownMenuItem(value: DocType.devis, child: Text('Devis')),
                            DropdownMenuItem(value: DocType.facture, child: Text('Facture')),
                          ],
                          onChanged: widget.existing != null ? null : (v) => setLocal(() => _type = v ?? DocType.devis),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedClient != null ? _clientId : null,
                      decoration: const InputDecoration(labelText: 'Client'),
                      items: clients.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                      onChanged: (v) => setLocal(() {
                        _clientId = v;
                        _vehicleId = null;
                      }),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: vehicleValue,
                      decoration: InputDecoration(
                        labelText: 'Véhicule',
                        helperText: _clientId == null
                            ? 'Choisissez d\'abord un client'
                            : (vehicles.isEmpty ? 'Ce client n\'a pas encore de véhicule (onglet Clients)' : null),
                      ),
                      items: vehicles
                          .map((v) => DropdownMenuItem(value: v.id, child: Text('${v.plate} — ${v.make} ${v.model}')))
                          .toList(),
                      onChanged: vehicles.isEmpty ? null : (v) => setLocal(() => _vehicleId = v),
                    ),
                    const SizedBox(height: 16),
                    const Text('Lignes (main-d\'œuvre / pièces)',
                        style: TextStyle(color: MpColors.chromeC, fontSize: 12)),
                    const SizedBox(height: 8),
                    for (int i = 0; i < _lines.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: _lines[i].descCtrl,
                                decoration: const InputDecoration(hintText: 'Description'),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: TextField(
                                controller: _lines[i].qtyCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(hintText: 'Qté'),
                                onChanged: (_) => setLocal(() {}),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: _lines[i].priceCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(hintText: 'Prix unit.'),
                                onChanged: (_) => setLocal(() {}),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: _lines.length > 1
                                  ? () => setLocal(() => _lines.removeAt(i))
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    TextButton.icon(
                      onPressed: () => setLocal(() => _lines.add(_LineDraft())),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Ajouter une ligne'),
                    ),
                    const Divider(),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text('Appliquer la TVA ($kTvaRate %)'),
                      value: _tva,
                      onChanged: (v) => setLocal(() {
                        _tva = v;
                        if (!v) _cad = false;
                      }),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text('Appliquer la CAD ($kCadRate % du montant de la TVA)'),
                      subtitle: _tva ? null : const Text('Activez d\'abord la TVA', style: TextStyle(fontSize: 11)),
                      value: _cad,
                      onChanged: _tva ? (v) => setLocal(() => _cad = v) : null,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _discCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Remise',
                              helperText: _discType == 'percent' ? 'En pourcentage du HT' : 'Montant en FCFA',
                            ),
                            onChanged: (_) => setLocal(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: SegmentedButton<String>(
                            showSelectedIcon: false,
                            style: const ButtonStyle(visualDensity: VisualDensity.compact),
                            segments: const [
                              ButtonSegment(value: 'percent', label: Text('%')),
                              ButtonSegment(value: 'amount', label: Text('FCFA')),
                            ],
                            selected: {_discType},
                            onSelectionChanged: (v) => setLocal(() => _discType = v.first),
                          ),
                        ),
                      ],
                    ),
                    if (_type == DocType.facture) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _depCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Acompte versé (FCFA)',
                          helperText: _depValue > _totals.ttc && _totals.ttc > 0
                              ? 'Supérieur au total : il sera limité à ${_money.format(_totals.ttc)} FCFA'
                              : 'Inscrit automatiquement dans le brouillard de caisse',
                        ),
                        onChanged: (_) => setLocal(() {}),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Builder(builder: (context) {
                      final t = _totals;
                      Widget row(String label, int v, {bool bold = false}) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1.5),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(label,
                                    style: TextStyle(
                                        fontSize: bold ? 15 : 12.5,
                                        fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                                        color: bold ? null : MpColors.muted)),
                                Text('${_money.format(v)} FCFA',
                                    style: TextStyle(fontSize: bold ? 16 : 12.5, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          );
                      return Column(children: [
                        if (t.discount > 0) row('Sous-total', t.gross),
                        if (t.discount > 0)
                          row(_discType == 'percent' ? 'Remise ($_discValue %)' : 'Remise', -t.discount),
                        row('Total HT', t.ht),
                        if (_tvaRate > 0) row('TVA ($kTvaRate %)', t.tva),
                        if (_cadRate > 0) row('CAD ($kCadRate % de la TVA)', t.cad),
                        if (_tvaRate > 0) const Divider(height: 10),
                        row(_tvaRate > 0 ? 'Total TTC' : 'Total', t.ttc, bold: _depositSaved == 0),
                        if (_depositSaved > 0) ...[
                          row('Acompte versé', -_depositSaved),
                          const Divider(height: 10),
                          row('Reste à payer', t.ttc - _depositSaved, bold: true),
                        ],
                      ]);
                    }),
                  ],
                );
              }),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                if (_clientId == null) return;
                final lines = _lines
                    .where((l) => l.descCtrl.text.trim().isNotEmpty)
                    .map((l) => LineItem(
                          desc: l.descCtrl.text.trim(),
                          qty: int.tryParse(l.qtyCtrl.text) ?? 0,
                          price: int.tryParse(l.priceCtrl.text) ?? 0,
                        ))
                    .toList();
                if (lines.isEmpty) return;
                if (widget.existing == null) {
                  await FirestoreService.instance.addDocument(
                    type: _type,
                    clientId: _clientId!,
                    vehicleId: snap.hasData ? (vehicleValue ?? '') : (_vehicleId ?? ''),
                    lines: lines,
                    tvaRate: _tvaRate,
                    cadRate: _cadRate,
                    discountType: _discTypeSaved,
                    discountValue: _discValue,
                    deposit: _depositSaved,
                  );
                } else {
                  await FirestoreService.instance.updateDocument(
                    widget.existing!,
                    clientId: _clientId!,
                    vehicleId: snap.hasData ? (vehicleValue ?? '') : (_vehicleId ?? ''),
                    lines: lines,
                    tvaRate: _tvaRate,
                    cadRate: _cadRate,
                    discountType: _discTypeSaved,
                    discountValue: _discValue,
                    deposit: _depositSaved,
                  );
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
