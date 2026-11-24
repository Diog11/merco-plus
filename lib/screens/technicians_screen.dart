import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_card.dart';

class TechniciansScreen extends StatelessWidget {
  const TechniciansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: () => _openTechDialog(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Nouveau technicien'),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<List<Technician>>(
            stream: fs.watchTechnicians(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                  child: Text('Erreur Firestore : ${snap.error}',
                      style: const TextStyle(color: MpColors.danger, fontSize: 12), textAlign: TextAlign.center),
                );
              }
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final techs = snap.data!;
              if (techs.isEmpty) {
                return const Center(
                    child: Text('Aucun technicien enregistré. Ajoutez-en un pour commencer.',
                        style: TextStyle(color: MpColors.muted)));
              }
              return LayoutBuilder(builder: (context, constraints) {
                final wide = constraints.maxWidth > 700;
                return GridView.count(
                  crossAxisCount: wide ? 3 : 1,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: wide ? 2.6 : 3.2,
                  children: [
                    for (int i = 0; i < techs.length; i++)
                      AnimatedCard(
                        delay: Duration(milliseconds: 40 * i),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: MpColors.accent.withOpacity(.16),
                                child: Text(
                                  techs[i].name.isNotEmpty ? techs[i].name[0].toUpperCase() : '?',
                                  style: const TextStyle(color: MpColors.accent, fontWeight: FontWeight.w700),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(techs[i].name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                    if (techs[i].specialty.isNotEmpty)
                                      Text(techs[i].specialty, style: const TextStyle(color: MpColors.muted, fontSize: 12)),
                                    if (techs[i].phone.isNotEmpty)
                                      Text(techs[i].phone, style: const TextStyle(color: MpColors.muted, fontSize: 12)),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Modifier',
                                icon: const Icon(Icons.edit_outlined, size: 19),
                                onPressed: () => _openTechDialog(context, existing: techs[i]),
                              ),
                              IconButton(
                                tooltip: 'Supprimer',
                                icon: const Icon(Icons.delete_outline, color: MpColors.danger, size: 19),
                                onPressed: () => fs.deleteTechnician(techs[i].id),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              });
            },
          ),
        ),
      ],
    );
  }

  void _openTechDialog(BuildContext context, {Technician? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final specialtyCtrl = TextEditingController(text: existing?.specialty ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Nouveau technicien' : 'Modifier le technicien'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom')),
            const SizedBox(height: 10),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Téléphone')),
            const SizedBox(height: 10),
            TextField(controller: specialtyCtrl, decoration: const InputDecoration(labelText: 'Spécialité (optionnel)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final t = Technician(
                id: existing?.id ?? '',
                name: nameCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                specialty: specialtyCtrl.text.trim(),
              );
              if (existing == null) {
                await FirestoreService.instance.addTechnician(t);
              } else {
                await FirestoreService.instance.updateTechnician(t);
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
