import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_card.dart';
import '../widgets/kpi_card.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  String _search = '';
  final _fmt = NumberFormat.decimalPattern('fr_FR');

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
                decoration: const InputDecoration(hintText: 'Rechercher une référence…'),
                onChanged: (v) => setState(() => _search = v.toLowerCase()),
              ),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _openStockDialog(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nouvelle pièce'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<List<StockItem>>(
            stream: fs.watchStock(),
            builder: (context, snap) {
              if (snap.hasError) return Center(child: Text('Erreur Firestore : ${snap.error}', style: const TextStyle(color: MpColors.red, fontSize: 12), textAlign: TextAlign.center));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              var items = snap.data!;
              if (_search.isNotEmpty) {
                items = items
                    .where((s) => s.ref.toLowerCase().contains(_search) || s.name.toLowerCase().contains(_search))
                    .toList();
              }
              if (items.isEmpty) {
                return const Center(child: Text('Aucune pièce en stock. Ajoutez-en une pour commencer.'));
              }
              return AnimatedCard(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final s = items[i];
                    return ListTile(
                      onTap: () => _openStockDialog(context, existing: s),
                      title: Text('${s.name}  ·  ${s.ref}'),
                      subtitle: Text(
                          '${s.loc.isEmpty ? "Emplacement non précisé" : s.loc} · ${s.supplier.isEmpty ? "—" : s.supplier} · ${_fmt.format(s.price)} FCFA / unité'),
                      leading: s.isLow ? StatusTag.red('${s.qty}') : StatusTag.green('${s.qty}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => fs.adjustStock(s.id, s.qty, -1),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () => fs.adjustStock(s.id, s.qty, 1),
                          ),
                          IconButton(
                            tooltip: 'Modifier',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _openStockDialog(context, existing: s),
                          ),
                          IconButton(
                            tooltip: 'Supprimer',
                            icon: const Icon(Icons.delete_outline, color: MpColors.red),
                            onPressed: () => fs.deleteStockItem(s.id),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _openStockDialog(BuildContext context, {StockItem? existing}) {
    final refCtrl = TextEditingController(text: existing?.ref ?? '');
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final qtyCtrl = TextEditingController(text: '${existing?.qty ?? 0}');
    final minCtrl = TextEditingController(text: '${existing?.min ?? 2}');
    final priceCtrl = TextEditingController(text: '${existing?.price ?? 0}');
    final locCtrl = TextEditingController(text: existing?.loc ?? '');
    final supplierCtrl = TextEditingController(text: existing?.supplier ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Nouvelle pièce' : 'Modifier la pièce'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: refCtrl, decoration: const InputDecoration(labelText: 'Référence')),
              const SizedBox(height: 10),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Désignation')),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: TextField(
                        controller: qtyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Quantité'))),
                const SizedBox(width: 10),
                Expanded(
                    child: TextField(
                        controller: minCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Seuil min.'))),
              ]),
              const SizedBox(height: 10),
              TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Prix unitaire (FCFA)')),
              const SizedBox(height: 10),
              TextField(controller: locCtrl, decoration: const InputDecoration(labelText: 'Emplacement')),
              const SizedBox(height: 10),
              TextField(controller: supplierCtrl, decoration: const InputDecoration(labelText: 'Fournisseur')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              if (refCtrl.text.trim().isEmpty || nameCtrl.text.trim().isEmpty) return;
              final item = StockItem(
                id: existing?.id ?? '',
                ref: refCtrl.text.trim(),
                name: nameCtrl.text.trim(),
                qty: int.tryParse(qtyCtrl.text) ?? 0,
                min: int.tryParse(minCtrl.text) ?? 0,
                price: int.tryParse(priceCtrl.text) ?? 0,
                loc: locCtrl.text.trim(),
                supplier: supplierCtrl.text.trim(),
              );
              if (existing == null) {
                await FirestoreService.instance.addStockItem(item);
              } else {
                await FirestoreService.instance.updateStockItem(item);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}
