import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
import '../widgets/mp_sidebar.dart' show MpNavEntry;
import '../widgets/connection_banner.dart';
import '../widgets/mp_top_nav.dart';
import 'dashboard_screen.dart';
import 'clients_screen.dart';
import 'stock_screen.dart';
import 'documents_screen.dart';
import 'atelier_screen.dart';
import 'calendar_screen.dart';
import 'technicians_screen.dart';
import 'cash_screen.dart';
import 'technician_dashboard_screen.dart';

/// Coque de l'application. L'interface dépend du rôle du compte :
///  - Admin      : les 7 modules.
///  - Technicien : uniquement son tableau de bord (ses interventions).
/// (Les règles Firestore appliquent la même restriction côté serveur.)
class HomeShell extends StatefulWidget {
  final AppUser user;
  const HomeShell({super.key, required this.user});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _adminEntries = [
    MpNavEntry('Tableau de bord', Icons.dashboard_outlined),
    MpNavEntry('Clients & véhicules', Icons.people_outline),
    MpNavEntry('Stock pièces', Icons.inventory_2_outlined),
    MpNavEntry('Devis & factures', Icons.receipt_long_outlined),
    MpNavEntry('Ateliers & planning', Icons.build_outlined),
    MpNavEntry('Calendrier', Icons.calendar_month_outlined),
    MpNavEntry('Techniciens', Icons.engineering_outlined),
    MpNavEntry('Caisse', Icons.payments_outlined),
  ];

  static const _cashIndex = 7;

  static const _techEntries = [
    MpNavEntry('Mes interventions', Icons.build_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    if (!widget.user.isAdmin) return _scaffold(context, alerts: 0);

    // Alertes (stock bas + factures impayées) : réservées à l'admin.
    final fs = FirestoreService.instance;
    return StreamBuilder<List<StockItem>>(
      stream: fs.watchStock(),
      builder: (context, stockSnap) {
        return StreamBuilder<List<DocumentRecord>>(
          stream: fs.watchDocuments(),
          builder: (context, docsSnap) {
            final lowStock = (stockSnap.data ?? []).where((s) => s.isLow).length;
            final unpaid = (docsSnap.data ?? [])
                .where((d) => d.type == DocType.facture && d.status == DocStatus.impaye)
                .length;
            return _scaffold(context, alerts: lowStock + unpaid);
          },
        );
      },
    );
  }

  Widget _adminScreen(int i) {
    switch (i) {
      case 0:
        return DashboardScreen(onOpenCash: () => setState(() => _index = _cashIndex));
      case 1:
        return const ClientsScreen();
      case 2:
        return const StockScreen();
      case 3:
        return const DocumentsScreen();
      case 4:
        return const AtelierScreen();
      case 5:
        return const CalendarScreen();
      case 6:
        return const TechniciansScreen();
      default:
        return const CashScreen();
    }
  }

  Widget _scaffold(BuildContext context, {required int alerts}) {
    final admin = widget.user.isAdmin;
    final compact = MediaQuery.of(context).size.width < 900;
    final entries = admin ? _adminEntries : _techEntries;
    final index = _index.clamp(0, entries.length - 1);
    final Widget body = admin ? _adminScreen(index) : TechnicianDashboardScreen(user: widget.user);

    return Scaffold(
      appBar: MpTopNav(
        index: index,
        entries: entries,
        alertCount: alerts,
        userName: widget.user.name.isEmpty ? widget.user.email : widget.user.name,
        roleLabel: admin ? 'Admin' : 'Technicien',
        showCreate: admin,
        onSelect: (i) => setState(() => _index = i),
        onCreateSelect: (i) => setState(() => _index = i),
      ),
      body: Column(
        children: [
          ConnectionBanner(uid: widget.user.uid),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(compact ? 14 : 22),
              child: body,
            ),
          ),
        ],
      ),
    );
  }
}
