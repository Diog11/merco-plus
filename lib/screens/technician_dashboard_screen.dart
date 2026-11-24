import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_card.dart';
import '../widgets/kpi_card.dart';

/// Tableau de bord d'un compte Technicien : uniquement les interventions
/// qui lui sont attribuées (la requête ET les règles Firestore le garantissent).
class TechnicianDashboardScreen extends StatefulWidget {
  final AppUser user;
  const TechnicianDashboardScreen({super.key, required this.user});

  @override
  State<TechnicianDashboardScreen> createState() => _TechnicianDashboardScreenState();
}

class _TechnicianDashboardScreenState extends State<TechnicianDashboardScreen> {
  late final Stream<List<RepairJob>> _jobs = FirestoreService.instance.watchJobsForTechnician(widget.user.uid);
  final _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  Widget build(BuildContext context) {
    final first = widget.user.name.trim().split(' ').first;
    return StreamBuilder<List<RepairJob>>(
      stream: _jobs,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
              child: Text('Erreur Firestore : ${snap.error}',
                  style: const TextStyle(color: MpColors.red, fontSize: 12), textAlign: TextAlign.center));
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: MpColors.accent));
        final jobs = [...snap.data!]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        int count(JobStatus s) => jobs.where((j) => j.status == s).length;

        return ListView(
          children: [
            Text(first.isEmpty ? 'BONJOUR' : 'BONJOUR, ${first.toUpperCase()}',
                style: GoogleFonts.oswald(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            const SizedBox(height: 4),
            const Text('Voici les interventions qui vous sont attribuées.',
                style: TextStyle(color: MpColors.muted, fontSize: 13)),
            const SizedBox(height: 20),
            LayoutBuilder(builder: (context, c) {
              final cols = c.maxWidth > 720 ? 3 : 1;
              final w = (c.maxWidth - (cols - 1) * 14) / cols;
              Widget kpi(String label, int n, IconData icon, {bool warn = false}) => SizedBox(
                    width: w,
                    child: AnimatedCard(
                      child: KpiCard(label: label, value: '$n', sub: 'intervention(s)', icon: icon, warn: warn),
                    ),
                  );
              return Wrap(spacing: 14, runSpacing: 14, children: [
                kpi('En attente', count(JobStatus.attente), Icons.hourglass_empty, warn: count(JobStatus.attente) > 0),
                kpi('En cours', count(JobStatus.cours), Icons.build_outlined),
                kpi('Terminées', count(JobStatus.termine), Icons.check_circle_outline),
              ]);
            }),
            const SizedBox(height: 26),
            Text('MES INTERVENTIONS',
                style: GoogleFonts.oswald(fontSize: 13, letterSpacing: 1.4, color: MpColors.muted)),
            const SizedBox(height: 10),
            if (jobs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(
                    child: Text('Aucune intervention ne vous est attribuée pour le moment.',
                        style: TextStyle(color: MpColors.muted))),
              )
            else
              ...jobs.map(_jobCard),
          ],
        );
      },
    );
  }

  Widget _jobCard(RepairJob j) {
    final tag = switch (j.status) {
      JobStatus.attente => StatusTag.amber('En attente'),
      JobStatus.cours => StatusTag.green('En cours'),
      JobStatus.termine => StatusTag.grey('Terminé'),
    };
    return AnimatedCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(j.clientName.isEmpty ? 'Client' : j.clientName,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
                tag,
              ],
            ),
            const SizedBox(height: 2),
            Text(j.vehicleLabel.isEmpty ? 'Véhicule non précisé' : j.vehicleLabel,
                style: const TextStyle(fontSize: 12, color: MpColors.muted)),
            const SizedBox(height: 10),
            Text(j.desc, style: const TextStyle(fontSize: 13.5)),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Créée le ${_dateFmt.format(j.createdAt)}',
                    style: const TextStyle(fontSize: 11.5, color: MpColors.muted)),
                const Spacer(),
                DropdownButton<JobStatus>(
                  value: j.status,
                  underline: const SizedBox(),
                  style: TextStyle(fontSize: 12.5, color: Theme.of(context).textTheme.bodyMedium?.color),
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
  }
}
