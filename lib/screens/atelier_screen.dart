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
                      _column(context, 'En attente', JobStatus.attente, jobs, clientOf, bounded: wide),
                      _column(context, 'En cours', JobStatus.cours, jobs, clientOf, bounded: wide),
                      _column(context, 'Terminé', JobStatus.termine, jobs, clientOf, bounded: wide),
                    ];
                    return wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
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
      Client? Function(String) clientOf,
      {required bool bounded}) {
    final items = jobs.where((j) => j.status == status).toList();

    final cards = items.map((j) {
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
              Row(
                children: [
                  Expanded(
                    child: Text(c?.name ?? (j.clientName.isEmpty ? '—' : j.clientName),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    tooltip: 'Modifier',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    icon: const Icon(Icons.edit_outlined, size: 16, color: MpColors.muted),
                    onPressed: () => _openJobDialog(context, existing: j),
                  ),
                  IconButton(
                    tooltip: 'Supprimer',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    icon: const Icon(Icons.delete_outline, size: 16, color: MpColors.muted),
                    onPressed: () => _confirmDelete(context, j),
                  ),
                ],
              ),
              Text(v != null ? '${v.plate} — ${v.make} ${v.model}' : (j.vehicleLabel.isEmpty ? 'Véhicule non précisé' : j.vehicleLabel),
                  style: const TextStyle(fontSize: 11.5, color: MpColors.chromeC)),
              const SizedBox(height: 6),
              Text(j.desc, style: const TextStyle(fontSize: 12.5)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(child: StatusTag.grey(j.tech)),
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
    }).toList();

    const empty = Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Text('Aucune intervention.', style: TextStyle(color: MpColors.chromeC, fontSize: 12)),
    );

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
        mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
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
          // Colonne à hauteur fixe (grand écran) : la liste défile, plus de débordement.
          if (bounded)
            Expanded(child: items.isEmpty ? empty : ListView(children: cards))
          else if (items.isEmpty)
            empty
          else
            ...cards,
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, RepairJob j) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text('Supprimer cette intervention ?\n« ${j.desc} »'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok == true) await FirestoreService.instance.deleteJob(j.id);
  }

  void _openJobDialog(BuildContext context, {RepairJob? existing}) {
    showDialog(context: context, builder: (ctx) => _JobDialog(existing: existing));
  }
}

class _JobDialog extends StatefulWidget {
  final RepairJob? existing; // non nul : modification d'une intervention
  const _JobDialog({this.existing});

  @override
  State<_JobDialog> createState() => _JobDialogState();
}

class _JobDialogState extends State<_JobDialog> {
  // Les flux sont créés UNE seule fois (et non à chaque reconstruction),
  // sinon la liste se réinitialisait dès qu'on touchait un champ.
  late final Stream<List<Client>> _clientsStream = FirestoreService.instance.watchClients();
  late final Stream<List<AppUser>> _techStream = FirestoreService.instance.watchTechnicianAccounts();
  late final Stream<List<Technician>> _recStream = FirestoreService.instance.watchTechnicians();

  late String? _clientId = (widget.existing?.clientId.isEmpty ?? true) ? null : widget.existing!.clientId;
  late String? _vehicleId = (widget.existing?.vehicleId.isEmpty ?? true) ? null : widget.existing!.vehicleId;
  // Choix du technicien : '' = non assigné · 'u:<uid>' = compte technicien ·
  // 'r:<id>' = fiche de l'écran Techniciens (sans compte) · 'n:<nom>' = nom d'une ancienne intervention.
  late String _techKey = (widget.existing?.technicianUid.isNotEmpty ?? false)
      ? 'u:${widget.existing!.technicianUid}'
      : ((widget.existing != null && widget.existing!.tech.isNotEmpty && widget.existing!.tech != 'Non assigné')
          ? 'n:${widget.existing!.tech}'
          : '');
  late final _descCtrl = TextEditingController(text: widget.existing?.desc ?? '');

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Client>>(
      stream: _clientsStream,
      builder: (context, snap) {
        final clients = snap.data ?? [];
        final Client? selected = clients.where((c) => c.id == _clientId).cast<Client?>().firstWhere((_) => true, orElse: () => null);
        // Calculé ICI, à chaque reconstruction : la liste des véhicules suit
        // donc toujours le client choisi.
        final vehicles = selected?.vehicles ?? <Vehicle>[];
        final vehicleValue = vehicles.any((v) => v.id == _vehicleId) ? _vehicleId : null;

        return StreamBuilder<List<AppUser>>(
          stream: _techStream,
          builder: (context, techSnap) {
           return StreamBuilder<List<Technician>>(
            stream: _recStream,
            builder: (context, recSnap) {
            final accounts = techSnap.data ?? [];
            final records = recSnap.data ?? [];
            String norm(String s) => s.trim().toLowerCase();
            String accountLabel(AppUser t) => t.name.isEmpty ? t.email : t.name;
            // Tous les techniciens : comptes (ils voient leurs interventions sur leur
            // téléphone) + fiches de l'écran « Techniciens » qui n'ont pas de compte.
            final accountNames = accounts.map((t) => norm(accountLabel(t))).toSet();
            final options = <_TechOption>[
              for (final t in accounts) _TechOption('u:${t.uid}', accountLabel(t), t.uid, true),
              for (final r in records)
                if (!accountNames.contains(norm(r.name))) _TechOption('r:${r.id}', r.name, '', false),
            ];
            var key = _techKey;
            if (key.startsWith('n:')) {
              final name = norm(key.substring(2));
              final match = options.where((o) => norm(o.name) == name);
              if (match.isNotEmpty) key = match.first.key;
            }
            final selectedTech = options.where((o) => o.key == key).isEmpty ? null : options.firstWhere((o) => o.key == key);
            final techValue = selectedTech == null ? '' : key;

            return AlertDialog(
              title: Text(widget.existing == null ? 'Nouvelle intervention' : 'Modifier l\'intervention'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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
                      DropdownButtonFormField<String>(
                        value: selected != null ? _clientId : null,
                        decoration: const InputDecoration(labelText: 'Client'),
                        items: clients.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                        onChanged: (v) => setState(() {
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
                            .map((v) => DropdownMenuItem(
                                value: v.id, child: Text('${v.plate} — ${v.make} ${v.model}')))
                            .toList(),
                        onChanged: vehicles.isEmpty ? null : (v) => setState(() => _vehicleId = v),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _descCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'Description des travaux'),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: techValue,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Technicien assigné',
                          helperMaxLines: 3,
                          helperText: options.isEmpty
                              ? 'Aucun technicien pour l\'instant : ajoutez-en dans l\'onglet « Techniciens » ou faites-les s\'inscrire.'
                              : (selectedTech != null && !selectedTech.hasAccount
                                  ? 'Ce technicien n\'a pas de compte : il ne verra pas l\'intervention sur son téléphone (elle reste suivie ici).'
                                  : null),
                        ),
                        items: [
                          const DropdownMenuItem(value: '', child: Text('Non assigné')),
                          ...options.map((o) => DropdownMenuItem(
                              value: o.key, child: Text(o.hasAccount ? o.name : '${o.name} (sans compte)'))),
                        ],
                        onChanged: (v) => setState(() => _techKey = v ?? ''),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
                ElevatedButton(
                  onPressed: () async {
                    if (selected == null || _descCtrl.text.trim().isEmpty) return;
                    Vehicle? veh;
                    for (final v in vehicles) {
                      if (v.id == vehicleValue) veh = v;
                    }
                    // Listes pas encore chargées : on garde l'assignation existante.
                    final keepOld = selectedTech == null && widget.existing != null &&
                        _techKey.isNotEmpty && !(techSnap.hasData && recSnap.hasData);
                    final techName = keepOld ? widget.existing!.tech : (selectedTech?.name ?? 'Non assigné');
                    final techUid = keepOld ? widget.existing!.technicianUid : (selectedTech?.uid ?? '');
                    final job = RepairJob(
                      id: widget.existing?.id ?? '',
                      clientId: selected.id,
                      vehicleId: vehicleValue ?? '',
                      desc: _descCtrl.text.trim(),
                      tech: techName,
                      technicianUid: techUid,
                      clientName: selected.name,
                      vehicleLabel: veh == null ? '' : '${veh.plate} — ${veh.make} ${veh.model}',
                      status: widget.existing?.status ?? JobStatus.attente,
                      createdAt: widget.existing?.createdAt,
                    );
                    if (widget.existing == null) {
                      await FirestoreService.instance.addJob(job);
                    } else {
                      await FirestoreService.instance.updateJob(job);
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Text(widget.existing == null ? 'Créer' : 'Enregistrer'),
                ),
              ],
            );
            },
           );
          },
        );
      },
    );
  }
}

class _TechOption {
  final String key;
  final String name;
  final String uid; // '' pour une fiche sans compte
  final bool hasAccount;
  const _TechOption(this.key, this.name, this.uid, this.hasAccount);
}
