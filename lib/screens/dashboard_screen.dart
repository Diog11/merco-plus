import 'dart:ui';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/kpi_card.dart';
import '../widgets/animated_card.dart';
import '../widgets/mp_footer.dart';
import '../widgets/mp_carousel.dart';

/// Vidéo d'arrière-plan libre de droits (licence Pexels, réutilisation
/// commerciale autorisée) — à remplacer par vos propres images d'atelier
/// dès qu'elles seront disponibles en bonne résolution.
const _heroVideoUrl =
    'https://videos.pexels.com/video-files/14514790/14514790-uhd_2560_1440_25fps.mp4';

const _galleryPhotos = [
  {
    'url': 'https://images.pexels.com/photos/20872015/pexels-photo-20872015.jpeg?auto=compress&cs=tinysrgb&w=800',
    'caption': 'Atelier — pont élévateur',
  },
  {
    'url': 'https://images.pexels.com/photos/8985456/pexels-photo-8985456.jpeg?auto=compress&cs=tinysrgb&w=800',
    'caption': 'Diagnostic moteur',
  },
  {
    'url': 'https://images.pexels.com/photos/6517339/pexels-photo-6517339.jpeg?auto=compress&cs=tinysrgb&w=800',
    'caption': 'Réparation mécanique',
  },
];

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  VideoPlayerController? _videoController;
  bool _videoReady = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(_heroVideoUrl));
      await controller.initialize();
      controller.setLooping(true);
      controller.setVolume(0);
      controller.play();
      if (mounted) {
        setState(() {
          _videoController = controller;
          _videoReady = true;
        });
      }
    } catch (_) {
      // Pas de réseau ou vidéo indisponible : le dégradé de secours
      // (voir build()) reste affiché à la place.
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  final _fmt = NumberFormat.decimalPattern('fr_FR');
  final _monthFmt = DateFormat('MMM', 'fr_FR');

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bonjour';
    if (h < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService.instance;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StreamBuilder<List<Client>>(
            stream: fs.watchClients(),
            builder: (context, clientsSnap) {
              return StreamBuilder<List<StockItem>>(
                stream: fs.watchStock(),
                builder: (context, stockSnap) {
                  return StreamBuilder<List<DocumentRecord>>(
                    stream: fs.watchDocuments(),
                    builder: (context, docsSnap) {
                      return StreamBuilder<List<RepairJob>>(
                        stream: fs.watchJobs(),
                        builder: (context, jobsSnap) {
                          final clients = clientsSnap.data ?? [];
                          final stock = stockSnap.data ?? [];
                          final docs = docsSnap.data ?? [];
                          final jobs = jobsSnap.data ?? [];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _hero(context, docs),
                              const SizedBox(height: 24),
                              _kpiSection(clients, stock, docs, jobs),
                              const SizedBox(height: 20),
                              LayoutBuilder(builder: (context, c) {
                                final wide = c.maxWidth > 900;
                                final chart = _revenueChart(docs);
                                final timeline = _activityTimeline(clients, docs, jobs);
                                if (wide) {
                                  return IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(flex: 3, child: chart),
                                        const SizedBox(width: 16),
                                        Expanded(flex: 2, child: timeline),
                                      ],
                                    ),
                                  );
                                }
                                return Column(children: [chart, const SizedBox(height: 20), timeline]);
                              }),
                              const SizedBox(height: 20),
                              _alerts(stock, docs, jobs),
                              const SizedBox(height: 20),
                              _gallery(),
                              const SizedBox(height: 30),
                              const MpFooter(),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ---------------- HERO ----------------

  Widget _hero(BuildContext context, List<DocumentRecord> docs) {
    final user = FirebaseAuth.instance.currentUser;
    final name = (user?.displayName?.isNotEmpty ?? false) ? user!.displayName! : (user?.email?.split('@').first ?? '');

    final now = DateTime.now();
    final thisMonth = docs.where((d) =>
        d.type == DocType.facture && d.date.year == now.year && d.date.month == now.month);
    final lastMonthDate = DateTime(now.year, now.month - 1);
    final lastMonth = docs.where((d) =>
        d.type == DocType.facture && d.date.year == lastMonthDate.year && d.date.month == lastMonthDate.month);
    final caMonth = thisMonth.fold<int>(0, (a, d) => a + d.total);
    final caLast = lastMonth.fold<int>(0, (a, d) => a + d.total);
    final progression = caLast == 0 ? null : ((caMonth - caLast) / caLast * 100);
    final up = (progression ?? 0) >= 0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        height: 360,
        color: MpColors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_videoReady && _videoController != null)
              Opacity(
                opacity: .35,
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _videoController!.value.size.width,
                    height: _videoController!.value.size.height,
                    child: VideoPlayer(_videoController!),
                  ),
                ),
              ),
            // Lueur verte unique, discrète — seule touche de couleur du fond.
            Positioned(top: -80, right: -40, child: _glow(MpColors.accent.withOpacity(.28), 320)),
            Container(color: MpColors.black.withOpacity(.55)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 52, vertical: 44),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOut,
                builder: (context, v, child) => Opacity(
                  opacity: v,
                  child: Transform.translate(offset: Offset(0, (1 - v) * 14), child: child),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _pillBadge(Icons.place_outlined, 'Brazzaville · République du Congo'),
                    const SizedBox(height: 22),
                    Text('${_greeting()}${name.isNotEmpty ? ", $name" : ""} 👋',
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 10),
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.oswald(fontSize: 46, fontWeight: FontWeight.w700, height: 1.05),
                        children: [
                          const TextSpan(text: 'Ce mois-ci : ', style: TextStyle(color: Colors.white)),
                          TextSpan(text: _fmt.format(caMonth), style: const TextStyle(color: MpColors.accent)),
                          const TextSpan(text: ' FCFA', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text('chiffre d\'affaires facturé', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                        if (progression != null) ...[
                          const SizedBox(width: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: (up ? MpColors.accent : MpColors.danger).withOpacity(.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(up ? Icons.trending_up : Icons.trending_down,
                                    size: 13, color: up ? MpColors.accent : MpColors.danger),
                                const SizedBox(width: 4),
                                Text('${progression.abs().toStringAsFixed(0)}% vs mois dernier',
                                    style: TextStyle(
                                        color: up ? MpColors.accent : MpColors.danger,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glow(Color color, double size) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }

  Widget _pillBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: MpColors.accent.withOpacity(.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: MpColors.accent.withOpacity(.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: MpColors.accent),
          const SizedBox(width: 7),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ---------------- KPI ----------------

  Widget _kpiSection(
      List<Client> clients, List<StockItem> stock, List<DocumentRecord> docs, List<RepairJob> jobs) {
    final vehCount = clients.fold<int>(0, (a, c) => a + c.vehicles.length);
    final stockValue = stock.fold<int>(0, (a, s) => a + s.qty * s.price);
    final unpaid = docs.where((d) => d.type == DocType.facture && d.status == DocStatus.impaye).toList();
    final unpaidSum = unpaid.fold<int>(0, (a, d) => a + d.total);
    final ongoing = jobs.where((j) => j.status == JobStatus.cours).length;

    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth > 800;
      final kpis = [
        KpiCard(
            label: 'Clients enregistrés',
            value: '${clients.length}',
            sub: '$vehCount véhicule(s) suivi(s)',
            icon: Icons.people_outline),
        KpiCard(
            label: 'Valeur du stock',
            value: _fmt.format(stockValue),
            sub: 'FCFA — pièces en magasin',
            icon: Icons.inventory_2_outlined),
        KpiCard(
            label: 'Factures impayées',
            value: '${unpaid.length}',
            sub: '${_fmt.format(unpaidSum)} FCFA en attente',
            warn: true,
            icon: Icons.warning_amber_rounded),
        KpiCard(
            label: 'Réparations en cours',
            value: '$ongoing',
            sub: 'sur le planning atelier',
            icon: Icons.build_outlined),
      ];
      return GridView.count(
        crossAxisCount: wide ? 4 : 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.5,
        children: [for (int i = 0; i < kpis.length; i++) AnimatedCard(delay: Duration(milliseconds: 60 * i), child: kpis[i])],
      );
    });
  }

  // ---------------- REVENUE CHART ----------------

  Widget _revenueChart(List<DocumentRecord> docs) {
    final now = DateTime.now();
    final months = List.generate(6, (i) => DateTime(now.year, now.month - (5 - i)));
    final totals = months.map((m) {
      return docs
          .where((d) => d.type == DocType.facture && d.date.year == m.year && d.date.month == m.month)
          .fold<int>(0, (a, d) => a + d.total);
    }).toList();
    final maxY = (totals.isEmpty ? 0 : totals.reduce((a, b) => a > b ? a : b)).toDouble();

    return AnimatedCard(
      delay: const Duration(milliseconds: 140),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 24, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Évolution du chiffre d\'affaires', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Total facturé par mois (6 derniers mois)',
                style: const TextStyle(color: MpColors.chromeC, fontSize: 11.5)),
            const SizedBox(height: 18),
            SizedBox(
              height: 190,
              child: totals.every((t) => t == 0)
                  ? const Center(
                      child: Text('Pas encore de facture sur cette période.',
                          style: TextStyle(color: MpColors.chromeC, fontSize: 12.5)))
                  : LineChart(
                      LineChartData(
                        minY: 0,
                        maxY: maxY == 0 ? 1 : maxY * 1.25,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: maxY == 0 ? 1 : maxY / 3,
                          getDrawingHorizontalLine: (_) => FlLine(color: Theme.of(context).dividerColor, strokeWidth: 1),
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 26,
                              getTitlesWidget: (value, meta) {
                                final i = value.toInt();
                                if (i < 0 || i >= months.length) return const SizedBox();
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(_monthFmt.format(months[i]),
                                      style: const TextStyle(color: MpColors.chromeC, fontSize: 10.5)),
                                );
                              },
                            ),
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            isCurved: true,
                            curveSmoothness: .28,
                            color: MpColors.blue,
                            barWidth: 3,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [MpColors.blue.withOpacity(.28), MpColors.blue.withOpacity(0)],
                              ),
                            ),
                            spots: [for (int i = 0; i < totals.length; i++) FlSpot(i.toDouble(), totals[i].toDouble())],
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- ACTIVITY TIMELINE ----------------

  Widget _activityTimeline(List<Client> clients, List<DocumentRecord> docs, List<RepairJob> jobs) {
    Client? clientOf(String id) {
      for (final c in clients) {
        if (c.id == id) return c;
      }
      return null;
    }

    final events = <_ActivityEvent>[
      for (final d in docs)
        _ActivityEvent(
          date: d.date,
          icon: d.type == DocType.facture ? Icons.receipt_long_outlined : Icons.article_outlined,
          text: '${d.type == DocType.facture ? "Facture" : "Devis"} #${d.num} — ${clientOf(d.clientId)?.name ?? "—"}',
        ),
      for (final j in jobs)
        _ActivityEvent(
          date: j.createdAt,
          icon: Icons.build_outlined,
          text: 'Intervention — ${clientOf(j.clientId)?.name ?? "—"} (${j.tech})',
        ),
    ]..sort((a, b) => b.date.compareTo(a.date));

    final recent = events.take(6).toList();

    return AnimatedCard(
      delay: const Duration(milliseconds: 180),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Activité récente', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 14),
            if (recent.isEmpty)
              const Text('Aucune activité pour le moment.', style: TextStyle(color: MpColors.chromeC, fontSize: 12.5))
            else
              ...recent.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                              color: MpColors.blue.withOpacity(.15), borderRadius: BorderRadius.circular(8)),
                          child: Icon(e.icon, size: 14, color: MpColors.blueLight),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.text, style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis),
                              Text(_timeAgo(e.date), style: const TextStyle(fontSize: 10.5, color: MpColors.chromeC)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'à l\'instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    if (diff.inDays < 30) return 'il y a ${diff.inDays} j';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  // ---------------- ALERTS ----------------

  Widget _alerts(List<StockItem> stock, List<DocumentRecord> docs, List<RepairJob> jobs) {
    final lowStock = stock.where((s) => s.isLow).toList();
    final unpaid = docs.where((d) => d.type == DocType.facture && d.status == DocStatus.impaye).toList();
    final ready = jobs.where((j) => j.status == JobStatus.termine).toList();

    final rows = <Widget>[
      ...lowStock.map((s) => _alertRow(Icons.remove_shopping_cart_outlined, MpColors.red,
          '${s.name} en rupture (${s.qty}/${s.min})')),
      ...unpaid.map((d) => _alertRow(Icons.description_outlined, MpColors.amber, 'Facture #${d.num} impayée')),
      ...ready.map((j) => _alertRow(Icons.check_circle_outline, MpColors.green, 'Véhicule prêt — ${j.desc}')),
    ];

    return AnimatedCard(
      delay: const Duration(milliseconds: 220),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Alertes', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              const Text('Rien à signaler pour le moment.', style: TextStyle(color: MpColors.chromeC, fontSize: 12.5))
            else
              Wrap(spacing: 12, runSpacing: 10, children: rows),
          ],
        ),
      ),
    );
  }

  Widget _alertRow(IconData icon, Color color, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(10)),
      constraints: const BoxConstraints(maxWidth: 340),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Flexible(child: Text(text, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  // ---------------- GALLERY ----------------

  Widget _gallery() {
    return AnimatedCard(
      delay: const Duration(milliseconds: 260),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Notre atelier en images', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text('Glissez pour parcourir', style: TextStyle(color: MpColors.chromeC, fontSize: 11.5)),
            const SizedBox(height: 16),
            MpCarousel(
              height: 190,
              viewportFraction: .38,
              items: _galleryPhotos
                  .map((p) => ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: _GalleryTile(url: p['url']!, caption: p['caption']!),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityEvent {
  final DateTime date;
  final IconData icon;
  final String text;
  _ActivityEvent({required this.date, required this.icon, required this.text});
}

class _GalleryTile extends StatefulWidget {
  final String url;
  final String caption;
  const _GalleryTile({required this.url, required this.caption});

  @override
  State<_GalleryTile> createState() => _GalleryTileState();
}

class _GalleryTileState extends State<_GalleryTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedScale(
              scale: _hover ? 1.06 : 1.0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              child: Image.network(widget.url, fit: BoxFit.cover),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(.65), Colors.transparent],
                  ),
                ),
                child: Text(widget.caption, style: const TextStyle(color: Colors.white, fontSize: 10.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
