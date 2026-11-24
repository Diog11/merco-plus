import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_card.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                width: 260,
                child: TextField(
                  decoration: const InputDecoration(hintText: 'Client, plaque ou n° de châssis…'),
                  onChanged: (v) => setState(() => _search = v.toLowerCase()),
                ),
              ),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _openClientDialog(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nouveau client'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<List<Client>>(
            stream: fs.watchClients(),
            builder: (context, snap) {
              if (snap.hasError) return Center(child: Text('Erreur Firestore : ${snap.error}', style: const TextStyle(color: MpColors.red, fontSize: 12), textAlign: TextAlign.center));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              var clients = snap.data!;
              if (_search.isNotEmpty) {
                clients = clients
                    .where((c) =>
                        c.name.toLowerCase().contains(_search) ||
                        c.vehicles.any((v) =>
                            v.plate.toLowerCase().contains(_search) || v.chassis.toLowerCase().contains(_search)))
                    .toList();
              }
              if (clients.isEmpty) {
                return const Center(child: Text('Aucun client. Ajoutez-en un pour commencer.'));
              }
              return AnimatedCard(
                child: ListView.separated(
                  itemCount: clients.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final c = clients[i];
                    return ListTile(
                      title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.phone.isEmpty ? 'Téléphone non renseigné' : c.phone),
                          if (c.vehicles.isEmpty)
                            const Text('Aucun véhicule', style: TextStyle(color: MpColors.muted, fontSize: 12)),
                          for (final v in c.vehicles)
                            InkWell(
                              onTap: () => _openVehicleDialog(context, c.id, existing: v),
                              child: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    const Icon(Icons.directions_car_outlined, size: 14, color: MpColors.muted),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        '${v.plate} · ${v.make} ${v.model}'
                                        '${v.chassis.isEmpty ? '' : ' · Châssis ${v.chassis}'}',
                                        style: const TextStyle(fontSize: 12.5),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.edit_outlined, size: 13, color: MpColors.muted),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      isThreeLine: c.vehicles.isNotEmpty,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Modifier le client',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _openClientDialog(context, existing: c),
                          ),
                          IconButton(
                            tooltip: 'Ajouter un véhicule',
                            icon: const Icon(Icons.directions_car_outlined),
                            onPressed: () => _openVehicleDialog(context, c.id),
                          ),
                          IconButton(
                            tooltip: 'Supprimer',
                            icon: const Icon(Icons.delete_outline, color: MpColors.red),
                            onPressed: () async {
                              final ok = await _confirm(context, 'Supprimer ce client et ses véhicules ?');
                              if (ok) await fs.deleteClient(c.id);
                            },
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

  Future<bool> _confirm(BuildContext context, String message) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmer')),
        ],
      ),
    );
    return res ?? false;
  }

  void _openClientDialog(BuildContext context, {Client? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final makeCtrl = TextEditingController();
    final modelCtrl = TextEditingController();
    final plateCtrl = TextEditingController();
    final chassisCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Nouveau client' : 'Modifier le client'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom du client')),
              const SizedBox(height: 10),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Téléphone')),
              if (existing == null) ...[
                const SizedBox(height: 16),
                const Text('Véhicule (optionnel)', style: TextStyle(color: MpColors.chromeC, fontSize: 12)),
                const SizedBox(height: 8),
                TextField(controller: makeCtrl, decoration: const InputDecoration(labelText: 'Marque')),
                const SizedBox(height: 10),
                TextField(controller: modelCtrl, decoration: const InputDecoration(labelText: 'Modèle')),
                const SizedBox(height: 10),
                TextField(controller: plateCtrl, decoration: const InputDecoration(labelText: 'Immatriculation')),
                const SizedBox(height: 10),
                TextField(
                  controller: chassisCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'N° de châssis (VIN)'),
                ),
              ] else
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('Pour modifier un véhicule, touchez-le dans la liste.',
                      style: TextStyle(color: MpColors.muted, fontSize: 12)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              if (existing != null) {
                await FirestoreService.instance
                    .updateClient(existing.id, nameCtrl.text.trim(), phoneCtrl.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
                return;
              }
              final id = await FirestoreService.instance.addClient(nameCtrl.text.trim(), phoneCtrl.text.trim());
              if (makeCtrl.text.trim().isNotEmpty) {
                await FirestoreService.instance.addVehicle(
                  id,
                  Vehicle(
                    id: '',
                    make: makeCtrl.text.trim(),
                    model: modelCtrl.text.trim(),
                    plate: plateCtrl.text.trim().isEmpty ? '—' : plateCtrl.text.trim(),
                    chassis: chassisCtrl.text.trim().toUpperCase(),
                  ),
                );
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _openVehicleDialog(BuildContext context, String clientId, {Vehicle? existing}) {
    final makeCtrl = TextEditingController(text: existing?.make ?? '');
    final modelCtrl = TextEditingController(text: existing?.model ?? '');
    final plateCtrl = TextEditingController(text: existing != null && existing.plate != '—' ? existing.plate : '');
    final chassisCtrl = TextEditingController(text: existing?.chassis ?? '');
    final kmCtrl = TextEditingController(text: '${existing?.km ?? 0}');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Ajouter un véhicule' : 'Modifier le véhicule'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: makeCtrl, decoration: const InputDecoration(labelText: 'Marque')),
              const SizedBox(height: 10),
              TextField(controller: modelCtrl, decoration: const InputDecoration(labelText: 'Modèle')),
              const SizedBox(height: 10),
              TextField(controller: plateCtrl, decoration: const InputDecoration(labelText: 'Immatriculation')),
              const SizedBox(height: 10),
              TextField(
                controller: chassisCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'N° de châssis (VIN)',
                  helperText: 'Généralement 17 caractères (carte grise / plaque sous le capot)',
                  helperMaxLines: 2,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: kmCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Kilométrage'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              final v = Vehicle(
                id: existing?.id ?? '',
                make: makeCtrl.text.trim(),
                model: modelCtrl.text.trim(),
                plate: plateCtrl.text.trim().isEmpty ? '—' : plateCtrl.text.trim(),
                km: int.tryParse(kmCtrl.text) ?? 0,
                chassis: chassisCtrl.text.trim().toUpperCase(),
              );
              if (existing == null) {
                await FirestoreService.instance.addVehicle(clientId, v);
              } else {
                await FirestoreService.instance.updateVehicle(clientId, v);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(existing == null ? 'Ajouter' : 'Enregistrer'),
          ),
        ],
      ),
    );
  }
}
