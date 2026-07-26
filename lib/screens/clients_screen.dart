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
                  decoration: const InputDecoration(hintText: 'Rechercher un client ou une plaque…'),
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
                        c.vehicles.any((v) => v.plate.toLowerCase().contains(_search)))
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
                      subtitle: Text(
                        c.vehicles.isEmpty
                            ? 'Aucun véhicule · ${c.phone}'
                            : '${c.vehicles.map((v) => "${v.plate} (${v.make} ${v.model})").join(", ")}\n${c.phone}',
                      ),
                      isThreeLine: c.vehicles.isNotEmpty,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
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

  void _openClientDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final makeCtrl = TextEditingController();
    final modelCtrl = TextEditingController();
    final plateCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouveau client'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom du client')),
              const SizedBox(height: 10),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Téléphone')),
              const SizedBox(height: 16),
              const Text('Véhicule (optionnel)', style: TextStyle(color: MpColors.chromeC, fontSize: 12)),
              const SizedBox(height: 8),
              TextField(controller: makeCtrl, decoration: const InputDecoration(labelText: 'Marque')),
              const SizedBox(height: 10),
              TextField(controller: modelCtrl, decoration: const InputDecoration(labelText: 'Modèle')),
              const SizedBox(height: 10),
              TextField(controller: plateCtrl, decoration: const InputDecoration(labelText: 'Immatriculation')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final id = await FirestoreService.instance.addClient(nameCtrl.text.trim(), phoneCtrl.text.trim());
              if (makeCtrl.text.trim().isNotEmpty) {
                await FirestoreService.instance.addVehicle(
                  id,
                  Vehicle(
                    id: '',
                    make: makeCtrl.text.trim(),
                    model: modelCtrl.text.trim(),
                    plate: plateCtrl.text.trim().isEmpty ? '—' : plateCtrl.text.trim(),
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

  void _openVehicleDialog(BuildContext context, String clientId) {
    final makeCtrl = TextEditingController();
    final modelCtrl = TextEditingController();
    final plateCtrl = TextEditingController();
    final kmCtrl = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ajouter un véhicule'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: makeCtrl, decoration: const InputDecoration(labelText: 'Marque')),
            const SizedBox(height: 10),
            TextField(controller: modelCtrl, decoration: const InputDecoration(labelText: 'Modèle')),
            const SizedBox(height: 10),
            TextField(controller: plateCtrl, decoration: const InputDecoration(labelText: 'Immatriculation')),
            const SizedBox(height: 10),
            TextField(
              controller: kmCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Kilométrage'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              await FirestoreService.instance.addVehicle(
                clientId,
                Vehicle(
                  id: '',
                  make: makeCtrl.text.trim(),
                  model: modelCtrl.text.trim(),
                  plate: plateCtrl.text.trim().isEmpty ? '—' : plateCtrl.text.trim(),
                  km: int.tryParse(kmCtrl.text) ?? 0,
                ),
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }
}
