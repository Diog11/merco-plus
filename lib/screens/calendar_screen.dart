import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_card.dart';
import '../widgets/kpi_card.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDay = DateTime.now();

  final _monthFmt = DateFormat('MMMM yyyy', 'fr_FR');
  final _dayFmt = DateFormat('EEEE d MMMM', 'fr_FR');
  final _timeFmt = DateFormat('HH:mm');

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService.instance;
    return StreamBuilder<List<Client>>(
      stream: fs.watchClients(),
      builder: (context, clientsSnap) {
        return StreamBuilder<List<Technician>>(
          stream: fs.watchTechnicians(),
          builder: (context, techSnap) {
            return StreamBuilder<List<Appointment>>(
              stream: fs.watchAppointments(),
              builder: (context, apptSnap) {
                if (apptSnap.hasError) {
                  return Center(
                    child: Text('Erreur Firestore : ${apptSnap.error}',
                        style: const TextStyle(color: MpColors.danger, fontSize: 12), textAlign: TextAlign.center),
                  );
                }
                if (!clientsSnap.hasData || !techSnap.hasData || !apptSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final clients = clientsSnap.data!;
                final techs = techSnap.data!;
                final appts = apptSnap.data!;

                Client? clientOf(String id) {
                  for (final c in clients) {
                    if (c.id == id) return c;
                  }
                  return null;
                }

                Technician? techOf(String id) {
                  for (final t in techs) {
                    if (t.id == id) return t;
                  }
                  return null;
                }

                final dayAppts = appts.where((a) => _sameDay(a.date, _selectedDay)).toList()
                  ..sort((a, b) => a.date.compareTo(b.date));

                return LayoutBuilder(builder: (context, constraints) {
                  final wide = constraints.maxWidth > 900;
                  final calendar = _monthGrid(appts);
                  final agenda = _agenda(dayAppts, clientOf, techOf, clients, techs);
                  if (wide) {
                    // Défilement vertical : plus de bandeau jaune "BOTTOM OVERFLOWED"
                    // quand la grille du mois est plus haute que l'écran.
                    return SingleChildScrollView(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: calendar),
                          const SizedBox(width: 16),
                          Expanded(flex: 2, child: agenda),
                        ],
                      ),
                    );
                  }
                  return SingleChildScrollView(
                    child: Column(children: [calendar, const SizedBox(height: 16), agenda]),
                  );
                });
              },
            );
          },
        );
      },
    );
  }

  Widget _monthGrid(List<Appointment> appts) {
    final firstOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    // Lundi = 0 ... Dimanche = 6
    final leading = (firstOfMonth.weekday - 1) % 7;

    final cells = <Widget>[];
    for (int i = 0; i < leading; i++) {
      cells.add(const SizedBox());
    }
    for (int d = 1; d <= daysInMonth; d++) {
      final day = DateTime(_visibleMonth.year, _visibleMonth.month, d);
      final hasAppt = appts.any((a) => _sameDay(a.date, day));
      final isSelected = _sameDay(day, _selectedDay);
      final isToday = _sameDay(day, DateTime.now());
      cells.add(_dayCell(day, hasAppt, isSelected, isToday));
    }

    return AnimatedCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_capitalize(_monthFmt.format(_visibleMonth)), style: Theme.of(context).textTheme.titleMedium),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => setState(() {
                        _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1);
                      }),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => setState(() {
                        _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1);
                      }),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: ['L', 'M', 'M', 'J', 'V', 'S', 'D']
                  .map((d) => Expanded(
                      child: Center(
                          child: Text(d, style: const TextStyle(color: MpColors.muted, fontSize: 11, fontWeight: FontWeight.w600)))))
                  .toList(),
            ),
            const SizedBox(height: 6),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1.7,
              children: cells,
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayCell(DateTime day, bool hasAppt, bool isSelected, bool isToday) {
    return GestureDetector(
      onTap: () => setState(() => _selectedDay = day),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? MpColors.accent.withOpacity(.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isToday && !isSelected ? Border.all(color: MpColors.accent.withOpacity(.5)) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${day.day}',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.w400,
                    color: isSelected ? MpColors.accent : null)),
            if (hasAppt)
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 4,
                height: 4,
                decoration: const BoxDecoration(color: MpColors.accent, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }

  Widget _agenda(List<Appointment> dayAppts, Client? Function(String) clientOf, Technician? Function(String) techOf,
      List<Client> clients, List<Technician> techs) {
    return AnimatedCard(
      delay: const Duration(milliseconds: 80),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_capitalize(_dayFmt.format(_selectedDay)), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('${dayAppts.length} rendez-vous', style: const TextStyle(color: MpColors.muted, fontSize: 11.5)),
            const SizedBox(height: 16),
            if (dayAppts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text('Aucun rendez-vous ce jour-là.', style: TextStyle(color: MpColors.muted, fontSize: 12.5)),
              )
            else
              ...dayAppts.map((a) {
                final c = clientOf(a.clientId);
                final t = techOf(a.technicianId);
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: MpColors.surfaceHi, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(color: MpColors.accent.withOpacity(.14), borderRadius: BorderRadius.circular(8)),
                        child: Text(_timeFmt.format(a.date),
                            style: const TextStyle(color: MpColors.accent, fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c?.name ?? '—', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            Text(t != null ? 'Technicien : ${t.name}' : 'Technicien non assigné',
                                style: const TextStyle(color: MpColors.muted, fontSize: 11.5)),
                          ],
                        ),
                      ),
                      _statusChip(a.status),
                      IconButton(
                        tooltip: 'Modifier',
                        icon: const Icon(Icons.edit_outlined, size: 16, color: MpColors.muted),
                        onPressed: () => _openAppointmentDialog(context, clients, techs, existing: a),
                      ),
                      IconButton(
                        tooltip: 'Supprimer',
                        icon: const Icon(Icons.close, size: 16, color: MpColors.muted),
                        onPressed: () => FirestoreService.instance.deleteAppointment(a.id),
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openAppointmentDialog(context, clients, techs),
                icon: const Icon(Icons.add, size: 17),
                label: const Text('Nouveau rendez-vous'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.confirme:
        return StatusTag.green('Confirmé');
      case AppointmentStatus.annule:
        return StatusTag.red('Annulé');
      case AppointmentStatus.enAttente:
        return StatusTag.grey('En attente');
    }
  }

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  void _openAppointmentDialog(BuildContext context, List<Client> clients, List<Technician> techs,
      {Appointment? existing}) {
    String? clientId = existing != null && clients.any((c) => c.id == existing.clientId) ? existing.clientId : null;
    String? vehicleId = existing != null && existing.vehicleId.isNotEmpty ? existing.vehicleId : null;
    String? technicianId =
        existing != null && techs.any((t) => t.id == existing.technicianId) ? existing.technicianId : null;
    DateTime day = existing != null
        ? DateTime(existing.date.year, existing.date.month, existing.date.day)
        : DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
    final timeCtrl = TextEditingController(text: existing != null ? _timeFmt.format(existing.date) : '09:00');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        final selectedClient = clients.where((c) => c.id == clientId);
        final vehicles = selectedClient.isNotEmpty ? selectedClient.first.vehicles : <Vehicle>[];
        final vehicleValue = vehicles.any((v) => v.id == vehicleId) ? vehicleId : null;

        return AlertDialog(
          title: Text(existing == null ? 'Nouveau rendez-vous' : 'Modifier le rendez-vous'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.event, size: 16),
                    label: Text(_capitalize(_dayFmt.format(day))),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: day,
                        firstDate: DateTime(day.year - 1),
                        lastDate: DateTime(day.year + 3),
                      );
                      if (picked != null) setLocal(() => day = picked);
                    },
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: clientId,
                  decoration: const InputDecoration(labelText: 'Client'),
                  items: clients.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                  onChanged: (v) => setLocal(() {
                    clientId = v;
                    vehicleId = null;
                  }),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: vehicleValue,
                  decoration: const InputDecoration(labelText: 'Véhicule'),
                  items: vehicles.map((v) => DropdownMenuItem(value: v.id, child: Text('${v.plate} — ${v.make} ${v.model}'))).toList(),
                  onChanged: (v) => setLocal(() => vehicleId = v),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: technicianId,
                  decoration: const InputDecoration(labelText: 'Technicien'),
                  items: techs.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))).toList(),
                  onChanged: (v) => setLocal(() => technicianId = v),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: timeCtrl,
                  decoration: const InputDecoration(labelText: 'Heure (ex. 09:00)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes (optionnel)'),
                  maxLines: 2,
                ),
              ],
            ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                if (clientId == null) return;
                final parts = timeCtrl.text.split(':');
                final hour = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 9;
                final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
                final date = DateTime(day.year, day.month, day.day, hour, minute);
                final appt = Appointment(
                  id: existing?.id ?? '',
                  clientId: clientId!,
                  vehicleId: vehicleValue ?? '',
                  technicianId: technicianId ?? '',
                  date: date,
                  notes: notesCtrl.text.trim(),
                  status: existing?.status ?? AppointmentStatus.enAttente,
                );
                if (existing == null) {
                  await FirestoreService.instance.addAppointment(appt);
                } else {
                  await FirestoreService.instance.updateAppointment(appt);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        );
      }),
    );
  }
}
