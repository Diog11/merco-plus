import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_card.dart';
import '../widgets/kpi_card.dart';

class AtelierScreen extends StatelessWidget {
  const AtelierScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: () => _openJobDialog(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Nouvelle intervention'),
          ),
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

              return StreamBuilder<List<RepairJob>>(
                stream: fs.watchJobs(),
                builder: (context, snap) {
                  final jobs = snap.data ?? [];
                  return LayoutBuilder(builder: (context, constraints) {
                    final wide = constraints.maxWidth > 800;
                    final columns = [
                      _column(context, 'En attente', JobStatus.attente, jobs, clientOf),
                      _column(context, 'En cours', JobStatus.cours, jobs, clientOf),
                      _column(context, 'Terminé', JobStatus.termine, jobs, clientOf),
                    ];
                    return wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: columns
                                .map((c) => Expanded(child: Padding(padding: const EdgeInsets.all(6), child: c)))
                                .toList(),
                          )
                        : ListView(children: columns.map((c) => Padding(padding: const EdgeInsets.all(6), child: c)).toList());
                  });
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _column(BuildContext context, String label, JobStatus status, List<RepairJob> jobs,
      Client? Function(String) clientOf) {
    final items = jobs.where((j) => j.status == status).toList();
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? MpColors.graphiteHi.withOpacity(.4)
            : Theme.of(context).scaffoldBackgroundColor,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: MpColors.chromeC)),
              Text('${items.length}', style: const TextStyle(color: MpColors.chromeC)),
            ],
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Aucune intervention.', style: TextStyle(color: MpColors.chromeC, fontSize: 12)),
            )
          else
            ...items.map((j) {
              final c = clientOf(j.clientId);
              Vehicle? v;
              if (c != null) {
                for (final veh in c.vehicles) {
                  if (veh.id == j.vehicleId) v = veh;
                }
              }
              return AnimatedCard(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c?.name ?? '—', style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(v != null ? '${v.plate} — ${v.make} ${v.model}' : 'Véhicule non précisé',
                          style: const TextStyle(fontSize: 11.5, color: MpColors.chromeC)),
                      const SizedBox(height: 6),
                      Text(j.desc, style: const TextStyle(fontSize: 12.5)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          StatusTag.grey(j.tech),
                          DropdownButton<JobStatus>(
                            value: j.status,
                            underline: const SizedBox(),
                            style: TextStyle(fontSize: 11.5, color: Theme.of(context).textTheme.bodyMedium?.color),
                            items: const [
                              DropdownMenuItem(value: JobStatus.attente, child: Text('En attente')),
                              DropdownMenuItem(value: JobStatus.cours, child: Text('En cours')),
                              DropdownMenuItem(value: JobStatus.termine, child: Text('Terminé')),
                            ],
                            onChanged: (v) {
                              if (v != null) FirestoreService.instance.changeJobStatus(j.id, v);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  void _openJobDialog(BuildContext context) {
    showDialog(context: context, builder: (ctx) => const _JobDialog());
  }
}

class _JobDialog extends StatefulWidget {
  const _JobDialog();

  @override
  State<_JobDialog> createState() => _JobDialogState();
}

class _JobDialogState extends State<_JobDialog> {
  String? _clientId;
  String? _vehicleId;
  final _descCtrl = TextEditingController();
  final _techCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Client>>(
      stream: FirestoreService.instance.watchClients(),
      builder: (context, snap) {
        final clients = snap.data ?? [];
        final selected = clients.where((c) => c.id == _clientId).toList();
        final vehicles = selected.isNotEmpty ? selected.first.vehicles : <Vehicle>[];

        return StatefulBuilder(builder: (context, setLocal) {
          return AlertDialog(
            title: const Text('Nouvelle intervention'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                    items: vehicles
                        .map((v) => DropdownMenuItem(value: v.id, child: Text('${v.plate} — ${v.make} ${v.model}')))
                        .toList(),
                    onChanged: (v) => setLocal(() => _vehicleId = v),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Description des travaux'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _techCtrl,
                    decoration: const InputDecoration(labelText: 'Technicien assigné'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
              ElevatedButton(
                onPressed: () async {
                  if (_clientId == null || _descCtrl.text.trim().isEmpty) return;
                  await FirestoreService.instance.addJob(RepairJob(
                    id: '',
                    clientId: _clientId!,
                    vehicleId: _vehicleId ?? '',
                    desc: _descCtrl.text.trim(),
                    tech: _techCtrl.text.trim().isEmpty ? 'Non assigné' : _techCtrl.text.trim(),
                    status: JobStatus.attente,
                  ));
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Créer'),
              ),
            ],
          );
        });
      },
    );
  }
}
