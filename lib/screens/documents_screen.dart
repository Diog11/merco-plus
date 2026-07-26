import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
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
                  var docs = snap.data!;
                  if (_search.isNotEmpty) {
                    docs = docs.where((d) => (clientOf(d.clientId)?.name ?? '').toLowerCase().contains(_search)).toList();
                  }
                  if (docs.isEmpty) {
                    return const Center(child: Text('Aucun devis ni facture. Ajoutez-en un pour commencer.'));
                  }
                  return AnimatedCard(
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
                        return ListTile(
                          title: Text('#${d.num}  ·  ${c?.name ?? "—"}${v != null ? " · ${v.plate}" : ""}'),
                          subtitle: Text('${_dateFmt.format(d.date)}  ·  ${_fmt.format(d.total)} FCFA'),
                          leading: d.type == DocType.facture
                              ? StatusTag.grey('Facture')
                              : StatusTag.amber('Devis'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _statusTag(d),
                              const SizedBox(width: 8),
                              PopupMenuButton<String>(
                                onSelected: (v) async {
                                  switch (v) {
                                    case 'facturer':
                                      await fs.convertToInvoice(d.id);
                                      break;
                                    case 'payee':
                                      await fs.markPaid(d.id);
                                      break;
                                    case 'suppr':
                                      await fs.deleteDocument(d.id);
                                      break;
                                  }
                                },
                                itemBuilder: (ctx) => [
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
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _statusTag(DocumentRecord d) {
    if (d.type == DocType.devis) return StatusTag.grey('En attente de validation');
    return d.status == DocStatus.paye ? StatusTag.green('Payée') : StatusTag.red('Impayée');
  }

  void _openDocDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const _DocDialog(),
    );
  }
}

class _DocDialog extends StatefulWidget {
  const _DocDialog();

  @override
  State<_DocDialog> createState() => _DocDialogState();
}

class _LineDraft {
  final descCtrl = TextEditingController();
  final qtyCtrl = TextEditingController(text: '1');
  final priceCtrl = TextEditingController(text: '0');
}

class _DocDialogState extends State<_DocDialog> {
  DocType _type = DocType.devis;
  String? _clientId;
  String? _vehicleId;
  final List<_LineDraft> _lines = [_LineDraft()];

  int get _total => _lines.fold(0, (a, l) {
        final qty = int.tryParse(l.qtyCtrl.text) ?? 0;
        final price = int.tryParse(l.priceCtrl.text) ?? 0;
        return a + qty * price;
      });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Client>>(
      stream: FirestoreService.instance.watchClients(),
      builder: (context, snap) {
        final clients = snap.data ?? [];
        final selectedClient = clients.where((c) => c.id == _clientId).firstOrNull;

        return AlertDialog(
          title: const Text('Nouveau devis'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: StatefulBuilder(builder: (context, setLocal) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: DropdownButtonFormField<DocType>(
                          value: _type,
                          decoration: const InputDecoration(labelText: 'Type de document'),
                          items: const [
                            DropdownMenuItem(value: DocType.devis, child: Text('Devis')),
                            DropdownMenuItem(value: DocType.facture, child: Text('Facture')),
                          ],
                          onChanged: (v) => setLocal(() => _type = v ?? DocType.devis),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _clientId,
                      decoration: const InputDecoration(labelText: 'Client'),
                      items: clients.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                      onChanged: (v) => setLocal(() {
                        _clientId = v;
                        _vehicleId = null;
                      }),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _vehicleId,
                      decoration: const InputDecoration(labelText: 'Véhicule'),
                      items: (selectedClient?.vehicles ?? [])
                          .map((v) => DropdownMenuItem(value: v.id, child: Text('${v.plate} — ${v.make} ${v.model}')))
                          .toList(),
                      onChanged: (v) => setLocal(() => _vehicleId = v),
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
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text('Total : ${_total.toString()} FCFA',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    ),
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
                await FirestoreService.instance.addDocument(
                  type: _type,
                  clientId: _clientId!,
                  vehicleId: _vehicleId ?? '',
                  lines: lines,
                );
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
