import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/mp_sidebar.dart' show MpNavEntry;
import '../widgets/mp_top_nav.dart';
import 'dashboard_screen.dart';
import 'clients_screen.dart';
import 'stock_screen.dart';
import 'documents_screen.dart';
import 'atelier_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _entries = [
    MpNavEntry('Tableau de bord', Icons.dashboard_outlined),
    MpNavEntry('Clients & véhicules', Icons.people_outline),
    MpNavEntry('Stock pièces', Icons.inventory_2_outlined),
    MpNavEntry('Devis & factures', Icons.receipt_long_outlined),
    MpNavEntry('Ateliers & planning', Icons.build_outlined),
  ];

  static const _screens = [
    DashboardScreen(),
    ClientsScreen(),
    StockScreen(),
    DocumentsScreen(),
    AtelierScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 900;
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
            final alerts = lowStock + unpaid;

            return Scaffold(
              appBar: MpTopNav(
                index: _index,
                entries: _entries,
                compact: compact,
                alertCount: alerts,
                onSelect: (i) => setState(() => _index = i),
                onCreateSelect: (i) => setState(() => _index = i),
              ),
              floatingActionButton: compact
                  ? FloatingActionButton(
                      backgroundColor: MpColors.blue,
                      onPressed: () {},
                      child: const Icon(Icons.add, color: Colors.white),
                    )
                  : null,
              body: Padding(
                padding: EdgeInsets.all(compact ? 14 : 22),
                child: _screens[_index],
              ),
            );
          },
        );
      },
    );
  }
}
