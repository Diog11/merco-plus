import 'dart:js_interop';

import 'package:intl/intl.dart';
import 'package:web/web.dart' as web;

import '../models/models.dart';

/// Impression des devis, factures et du brouillard de caisse.
///
/// On construit une page HTML mise en forme (A4), ouverte dans un nouvel
/// onglet ; la fenêtre d'impression du navigateur s'ouvre toute seule. On peut
/// y choisir une imprimante ou « Enregistrer au format PDF ».
class PrintService {
  PrintService._();

  static final _fmt = NumberFormat.decimalPattern('fr_FR');
  static final _date = DateFormat('dd/MM/yyyy', 'fr_FR');
  static final _dateLong = DateFormat('EEEE d MMMM yyyy', 'fr_FR');
  static final _time = DateFormat('HH:mm');

  // Papier à en-tête du garage (modifiable ici, à un seul endroit).
  static const _garageName = 'MERCO PLUS GARAGE';
  static const _garageServices1 = 'MÉCANIQUE | MÉCATRONIQUE | ÉLECTRICITÉ AUTO | TÔLERIE';
  static const _garageServices2 = 'PEINTURE | DIAGNOSTIC | REPROGRAMMATION | VENTE DE PIÈCES';
  static const _garageSlogan = 'Votre véhicule, notre passion !';
  static const _garageAddress = '96 rue Nzoko M’pila Gallieni, Brazzaville, Congo';
  static const _garagePhones = 'Tél. 06.760.33.33 / 06.761.33.33';
  static const _garageWeb = 'mercoplusgarage@gmail.com | www.mercoplus.cg';
  static const _garageLegal = 'RCCM : CG-PNR-01-2014-B12-00254 | NIU : M21000000181630C | '
      'N° compte BSCA : 20717830000 / Banque postale : 37142294601';

  /// Nombre minimal de lignes affichées (les lignes vides restent à remplir à la main).
  static const _minRows = 12;

  // ------------------------------------------------------------ devis / facture

  /// Retourne false si le navigateur a bloqué l'ouverture de la fenêtre.
  static bool printDocument({required DocumentRecord doc, Client? client, Vehicle? vehicle}) {
    final isInvoice = doc.type == DocType.facture;
    final kind = isInvoice ? 'FACTURE' : 'DEVIS';
    final paid = isInvoice && doc.status == DocStatus.paye;
    final ref = '${isInvoice ? 'fac' : 'dev'}-${doc.date.year}-${doc.num.toString().padLeft(4, '0')}';
    final t = doc.totals;
    final total = t.ttc;
    String amount(bool on, int v) => on ? '${_fmt.format(v)} FCFA' : '';

    final rows = StringBuffer();
    var n = 0;
    for (final l in doc.lines) {
      n++;
      rows.write('<tr><td class="c">$n</td><td>${_e(l.desc)}</td><td class="c">${l.qty}</td>'
          '<td class="c">${_fmt.format(l.price)}</td><td class="c">${_fmt.format(l.subtotal)}</td></tr>');
    }
    // La ligne « Remise » prend de la place : une ligne vide en moins pour rester sur une page.
    final minRows = t.discount > 0 ? _minRows - 1 : _minRows;
    for (var i = n; i < minRows; i++) {
      rows.write('<tr class="blank"><td class="c">&nbsp;</td><td></td><td></td><td></td><td></td></tr>');
    }

    String kv(String label, String value) =>
        '<div class="kv"><span>$label</span><b>${_e(value)}</b></div>';

    final clientHtml = kv('Nom :', client?.name ?? '') +
        kv('Téléphone :', client?.phone ?? '') +
        kv('Adresse :', '');
    final vehicleHtml = kv('Marque :', vehicle?.make ?? '') +
        kv('Modèle :', vehicle?.model ?? '') +
        kv('Immatriculation :', (vehicle == null || vehicle.plate == '—') ? '' : vehicle.plate) +
        ((vehicle?.chassis.isNotEmpty ?? false) ? kv('N° de châssis :', vehicle!.chassis) : '');

    // Timbre d'état (facture uniquement).
    final stamp = !isInvoice
        ? ''
        : paid
            ? '<div class="stamp paid">PAYÉE'
                '${doc.paidAt == null ? '' : '<small>le ${_date.format(doc.paidAt!)}'
                    '${kPayMethods[doc.payMethod] == null ? '' : ' · ${_e(kPayMethods[doc.payMethod]!)}'}</small>'}</div>'
            : '<div class="stamp due">À RÉGLER'
                '${doc.deposit > 0 ? '<small>acompte ${_fmt.format(doc.deposit)} FCFA versé</small>' : ''}</div>';

    // Mode de paiement : coché pour une facture payée.
    final pm = paid ? doc.payMethod : '';
    final other = paid && pm != 'especes' && pm != 'virement';
    String box(bool on, String label) => '<div class="cb"><i class="box${on ? ' on' : ''}"></i>$label</div>';
    final payBlock = '<h4>MODE DE PAIEMENT</h4>'
        '${box(pm == 'especes', 'Espèces')}'
        '${box(pm == 'virement', 'Virement bancaire')}'
        '<div class="cb"><i class="box${other ? ' on' : ''}"></i>Autre : '
        '${other ? '<u>${_e(kPayMethods[pm] ?? pm)}</u>' : '<span class="ln"></span>'}</div>';

    final middle = isInvoice
        ? '<h4>RÈGLEMENT</h4><small>${paid ? 'Facture acquittée'
            '${doc.paidAt == null ? '' : ' le ${_date.format(doc.paidAt!)}'}' : 'Facture à régler — reste à payer : ${_fmt.format(doc.remaining)} FCFA'}</small>'
        : '<h4>CONDITIONS DU DEVIS</h4><small>Devis soumis à validation du client<br>Montants à confirmer selon travaux réalisés</small>';

    final remaining = isInvoice ? doc.remaining : total;
    final remiseLabel = doc.discountType == 'percent'
        ? 'Remise ${doc.discountValue}% de ${_fmt.format(t.gross)}'
        : 'Remise';
    final body = '''
${_letterhead()}
<div class="titlebar">
  <div class="bar big">$kind</div>
  <div class="meta"><span>N° ${isInvoice ? 'facture' : 'devis'}</span><b>$ref</b></div>
  <div class="meta date"><b>${_date.format(doc.date)}</b></div>
</div>
<div class="cv">
  <div class="cvcol"><div class="bar sm">CLIENT</div>$clientHtml</div>
  <div class="cvcol"><div class="bar sm">VÉHICULE</div>$vehicleHtml</div>
</div>
<table class="items">
  <thead><tr><th style="width:7%">N°</th><th style="width:43%">DÉSIGNATION</th><th style="width:8%">QTÉ</th>
  <th style="width:21%">PRIX UNITAIRE<br>(FCFA)</th><th style="width:21%">MONTANT<br>(FCFA)</th></tr></thead>
  <tbody>$rows</tbody>
</table>
<div class="lower">
  <div class="lowleft">
    <div class="nb">${t.tva > 0 || doc.tvaRate > 0 ? '<b>NB :</b><br>Montants en FCFA — TVA ${doc.tvaRate} %${doc.cadRate > 0 ? ' et CAD ${doc.cadRate} % (calculée sur la TVA)' : ''} incluses dans le total TTC.' : '<b>NB :</b><br>(à titre informatif, non inclus dans le total)'}</div>
    $stamp
  </div>
  <div class="tot">
    <div class="bar trow"><span>${t.discount > 0 ? 'TOTAL HT NET' : 'TOTAL HT'}</span><b>${_fmt.format(t.ht)} FCFA</b></div>
    ${t.discount > 0 ? '<div class="trow"><span>$remiseLabel</span><b>− ${_fmt.format(t.discount)} FCFA</b></div>' : ''}
    <div class="trow"><span>Acompte</span><b>${isInvoice && doc.deposit > 0 ? '${_fmt.format(doc.deposit)} FCFA' : ''}</b></div>
    <div class="trow"><span>Reste à payer</span><b>${_fmt.format(remaining)} FCFA</b></div>
    <div class="trow"><span>Taux TVA</span><em>${doc.tvaRate > 0 ? '${doc.tvaRate}%' : '—'}</em><b></b></div>
    <div class="trow"><span>Taux CAD</span><em>${doc.cadRate > 0 ? '${doc.cadRate}%' : '—'}</em><b></b></div>
    <div class="trow"><span>TVA</span><b>${amount(doc.tvaRate > 0, t.tva)}</b></div>
    <div class="trow"><span>CAD</span><b>${amount(doc.cadRate > 0, t.cad)}</b></div>
    <div class="bar trow"><span>MTTC</span><b>${_fmt.format(total)} FCFA</b></div>
  </div>
</div>
<div class="words"><small>${isInvoice ? 'FACTURE ARRÊTÉE' : 'DEVIS ÉTABLI'} À LA SOMME DE :</small>
<div class="wbox">${_e(_amountInWords(total))}</div></div>
<div class="three">
  <div>$payBlock</div>
  <div>$middle</div>
  <div class="cachet"><h4>CACHET</h4><b>MERCO PLUS<br>GARAGE</b></div>
</div>
<div class="thanks">MERCI POUR VOTRE CONFIANCE • $_garageName</div>
<div class="tiny">$_garageName — ${isInvoice ? 'facture' : 'devis'} client</div>
''';

    return _open('${isInvoice ? 'Facture' : 'Devis'} $ref — Merco Plus', body);
  }

  // ------------------------------------------------------------ brouillard de caisse

  static bool printCashDay(CashDaySummary s) {
    final rows = StringBuffer();
    var running = s.opening;
    rows.write('<tr class="muted"><td></td><td colspan="3">Solde reporté de la veille</td><td></td><td></td>'
        '<td class="n">${_fmt.format(running)}</td></tr>');
    for (final e in s.entries) {
      running += e.signed;
      rows.write('<tr><td>${_time.format(e.date)}</td><td>${_e(e.label)}</td><td>${_e(e.category)}</td>'
          '<td>${_e(kPayMethods[e.method] ?? e.method)}</td>'
          '<td class="n in">${e.isIn ? _fmt.format(e.amount) : ''}</td>'
          '<td class="n out">${e.isIn ? '' : _fmt.format(e.amount)}</td>'
          '<td class="n">${_fmt.format(running)}</td></tr>');
    }
    rows.write('<tr class="sum"><td></td><td colspan="3">TOTAUX DU JOUR</td>'
        '<td class="n">${_fmt.format(s.totalIn)}</td><td class="n">${_fmt.format(s.totalOut)}</td>'
        '<td class="n">${_fmt.format(s.closing)}</td></tr>');

    final modes = StringBuffer();
    kPayMethods.forEach((key, label) {
      if (!s.entries.any((e) => e.method == key)) return;
      final n = s.netForMethod(key);
      modes.write('<span class="chip">${_e(label)} : ${n >= 0 ? '+' : '−'}${_fmt.format(n.abs())} FCFA</span>');
    });

    final day = _dateLong.format(s.day);
    final body = '''
${_letterhead()}
<div class="title"><h1>BROUILLARD DE CAISSE</h1><div>${_e(day[0].toUpperCase() + day.substring(1))}</div></div>
<div class="kpis">
  <div><span>Solde reporté</span><b>${_fmt.format(s.opening)}</b></div>
  <div><span>Entrées</span><b class="in">+${_fmt.format(s.totalIn)}</b></div>
  <div><span>Sorties</span><b class="out">−${_fmt.format(s.totalOut)}</b></div>
  <div class="hi"><span>Solde de clôture</span><b>${_fmt.format(s.closing)}</b></div>
</div>
<table>
  <thead><tr><th>Heure</th><th>Libellé</th><th>Catégorie</th><th>Mode</th>
  <th class="n">Entrée</th><th class="n">Sortie</th><th class="n">Solde</th></tr></thead>
  <tbody>$rows</tbody>
</table>
<div class="modes">${modes.isEmpty ? '' : 'Net du jour par mode de paiement : $modes'}</div>
<div class="note">Montants en FCFA · Solde de clôture = solde reporté + entrées − sorties.</div>
<div class="sign"><div>Le caissier<br><br><br></div><div>Le responsable (visa)<br><br><br></div></div>
<div class="foot">Édité le ${_date.format(DateTime.now())} à ${_time.format(DateTime.now())} — $_garageName</div>
''';
    return _open('Brouillard de caisse ${_date.format(s.day)} — Merco Plus', body);
  }

  // ------------------------------------------------------------ internes

  /// Papier à en-tête (logo, activités, coordonnées, mentions légales).
  static String _letterhead() {
    final logo = Uri.parse(web.document.baseURI).resolve('assets/assets/images/logo.png').toString();
    return '''
<div class="lh">
  <div class="lhtop">
    <img class="lhlogo" src="${_e(logo)}" alt="Merco Plus" onerror="this.style.visibility='hidden'">
    <div class="lhmid">
      <div class="lhname">$_garageName</div>
      <div class="lhserv">$_garageServices1<br>$_garageServices2</div>
      <div class="lhslogan">$_garageSlogan</div>
    </div>
    <div class="lhspacer"></div>
  </div>
  <div class="lhinfo"><b>$_garageAddress</b> &nbsp;|&nbsp; <b>$_garagePhones</b><br>$_garageWeb</div>
  <div class="lhlegal">$_garageLegal</div>
</div>''';
  }

  static String _e(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  // ------------------------------------------------------------ montant en lettres

  static const _units = [
    '', 'un', 'deux', 'trois', 'quatre', 'cinq', 'six', 'sept', 'huit', 'neuf', 'dix',
    'onze', 'douze', 'treize', 'quatorze', 'quinze', 'seize',
  ];
  static const _tens = ['', '', 'vingt', 'trente', 'quarante', 'cinquante', 'soixante'];

  static String _below100(int n, bool last) {
    if (n < 17) return _units[n];
    if (n < 20) return 'dix ${_units[n - 10]}';
    if (n < 70) {
      final t = _tens[n ~/ 10];
      final r = n % 10;
      if (r == 0) return t;
      if (r == 1) return '$t et un';
      return '$t ${_units[r]}';
    }
    if (n < 80) {
      final r = n - 60;
      return r == 11 ? 'soixante et onze' : 'soixante ${_below100(r, last)}';
    }
    if (n == 80) return last ? 'quatre vingts' : 'quatre vingt';
    return 'quatre vingt ${_below100(n - 80, last)}';
  }

  static String _below1000(int n, bool last) {
    final h = n ~/ 100;
    final r = n % 100;
    if (h == 0) return _below100(r, last);
    if (h == 1) return r == 0 ? 'cent' : 'cent ${_below100(r, last)}';
    final head = '${_units[h]} cent';
    return r == 0 ? (last ? '${head}s' : head) : '$head ${_below100(r, last)}';
  }

  /// Ex. 385000 -> « TROIS CENT QUATRE VINGT CINQ MILLE FRANCS CFA ».
  static String _amountInWords(int amount) {
    if (amount <= 0) return 'ZÉRO FRANC CFA';
    final bn = amount ~/ 1000000000;
    final mn = (amount ~/ 1000000) % 1000;
    final th = (amount ~/ 1000) % 1000;
    final rest = amount % 1000;
    final parts = <String>[];
    if (bn > 0) parts.add('${_below1000(bn, true)} milliard${bn > 1 ? 's' : ''}');
    if (mn > 0) parts.add('${_below1000(mn, true)} million${mn > 1 ? 's' : ''}');
    if (th > 0) parts.add(th == 1 ? 'mille' : '${_below1000(th, false)} mille');
    if (rest > 0) parts.add(_below1000(rest, true));
    return '${parts.join(' ').toUpperCase()} FRANCS CFA';
  }

  // ------------------------------------------------------------ ouverture

  static bool _open(String title, String body) {
    final html = '''<!doctype html>
<html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>${_e(title)}</title><style>$_css</style></head><body>
<div class="bar2 noprint"><button onclick="window.print()">Imprimer / Enregistrer en PDF</button>
<span>Astuce : dans la fenêtre d'impression, choisissez « Enregistrer au format PDF » pour obtenir un fichier.</span></div>
<table class="frame">
<thead><tr><td><div class="sp"></div></td></tr></thead>
<tfoot><tr><td><div class="sp"></div></td></tr></tfoot>
<tbody><tr><td><div class="sheet">$body</div></td></tr></tbody>
</table>
<script>window.addEventListener('load',function(){setTimeout(function(){window.focus();window.print();},350);});</script>
</body></html>''';
    final blob = web.Blob(<JSAny>[html.toJS].toJS, web.BlobPropertyBag(type: 'text/html;charset=utf-8'));
    final url = web.URL.createObjectURL(blob);
    return web.window.open(url, '_blank') != null;
  }

  static const _css = r'''
/* Marge 0 : le navigateur n'ajoute plus ses propres en-têtes/pieds de page (date, titre, adresse web).
   Les vraies marges sont recréées ci-dessous (.sp), et se répètent sur chaque page. */
@page { size: A4; margin: 0; }
* { box-sizing: border-box; }
body { margin: 0; font: 11.5px/1.4 Arial, Helvetica, sans-serif; color: #0a1330; background: #eef2f8;
  -webkit-print-color-adjust: exact; print-color-adjust: exact; }
.bar2 { background: #001048; color: #cfe0f5; padding: 10px 16px; display: flex; gap: 14px; align-items: center; font-size: 12px; }
.bar2 button { background: #48a0e8; color: #001048; border: 0; border-radius: 999px; padding: 8px 18px; font-weight: 700; cursor: pointer; }
.sheet { background: #fff; max-width: 190mm; margin: 14px auto; padding: 8mm 10mm; box-shadow: 0 2px 14px rgba(0,0,0,.15); }

/* ---- papier à en-tête ---- */
.lh { text-align: center; margin-bottom: 8px; }
.lhtop { display: flex; align-items: center; justify-content: space-between; }
.lhlogo { height: 68px; width: auto; }
.lhspacer { width: 86px; }
.lhmid { flex: 1; }
.lhname { font-size: 27px; font-weight: 800; letter-spacing: 1.5px; color: #2f86d4; line-height: 1.1; }
.lhserv { font-size: 9.5px; font-weight: 700; color: #4a5f86; letter-spacing: .5px; margin-top: 4px; line-height: 1.5; }
.lhslogan { font-size: 11px; font-style: italic; color: #8fa6c8; margin-top: 3px; }
.lhinfo { font-size: 10.5px; color: #223; margin-top: 6px; line-height: 1.5; }
.lhlegal { font-size: 8.5px; color: #55678a; margin-top: 3px; }

/* ---- facture / devis ---- */
.bar { background: #3d92dc; color: #fff; font-weight: 800; letter-spacing: .5px; }
.titlebar { display: flex; align-items: center; gap: 18px; margin: 8px 0 8px; }
.bar.big { font-size: 19px; padding: 5px 36px; min-width: 210px; text-align: center; }
.meta { font-size: 11px; display: flex; gap: 24px; align-items: baseline; }
.meta span { color: #55678a; } .meta b { font-size: 12px; }
.meta.date { margin-left: auto; }
.cv { display: flex; gap: 22px; margin-bottom: 8px; }
.cvcol { flex: 1; }
.bar.sm { font-size: 11px; padding: 3px 8px; }
.kv { display: flex; gap: 10px; padding: 2px 4px; border-bottom: 1px solid #e1e8f3; min-height: 19px; }
.kv span { width: 105px; color: #55678a; flex: none; } .kv b { font-weight: 700; }
.items { width: 100%; border-collapse: collapse; margin-top: 4px; }
.items th { background: #3d92dc; color: #fff; text-align: center; font-size: 10px; padding: 5px 6px; letter-spacing: .3px; }
.items td { padding: 3px 6px; border-bottom: 1px solid #e1e8f3; vertical-align: middle; font-size: 11.5px; }
.items td.c { text-align: center; }
.items tr.blank td { height: 20px; }
.lower { display: flex; gap: 22px; margin-top: 8px; align-items: flex-start; }
.lowleft { flex: 1; }
.nb { background: #eef3f9; text-align: center; padding: 8px 10px; font-size: 11.5px; color: #2c3f66; }
.tot { width: 46%; }
.trow { display: flex; align-items: center; gap: 12px; padding: 1px 8px; min-height: 19px; border-bottom: 1px solid #e1e8f3; }
.trow span { flex: 1; } .trow em { font-style: normal; width: 40px; } .trow b { min-width: 90px; text-align: right; }
.trow.bar { border: 0; padding: 4px 8px; font-size: 12px; }
.words { margin-top: 8px; } .words small { color: #55678a; font-size: 10.5px; letter-spacing: .3px; }
.wbox { background: #eef3f9; text-align: center; font-weight: 800; color: #2c3f66; padding: 8px 10px; margin-top: 4px; font-size: 12px; }
.three { display: flex; gap: 24px; margin-top: 10px; }
.three > div { flex: 1; }
.three h4 { margin: 0 0 5px; font-size: 11px; color: #2c3f66; letter-spacing: .3px; }
.three small { font-size: 10px; color: #334; line-height: 1.5; display: block; }
.cb { font-size: 11px; margin: 3px 0; display: flex; align-items: center; }
.box { display: inline-block; width: 10px; height: 10px; border: 1.4px solid #2f6fa8; margin-right: 6px; flex: none; }
.box.on { background: #2f86d4; box-shadow: inset 0 0 0 1.5px #fff; }
.ln { display: inline-block; width: 110px; border-bottom: 1px solid #55678a; margin-left: 4px; height: 10px; }
.cachet { text-align: center; } .cachet b { display: block; margin-top: 4px; color: #55678a; font-size: 10.5px; line-height: 1.4; }
.thanks { background: #3d92dc; color: #fff; text-align: center; font-weight: 800; letter-spacing: 1px; font-size: 11px; padding: 6px; margin-top: 10px; }
.tiny { text-align: center; font-size: 8.5px; color: #6b7894; margin-top: 3px; }

/* ---- tampon d'état ---- */
.stamp { display: inline-block; border: 3px solid; border-radius: 8px; padding: 5px 16px; font-weight: 800; font-size: 18px;
  letter-spacing: 2px; transform: rotate(-6deg); margin: 12px 0 0 22px; }
.stamp small { display: block; font-size: 10px; letter-spacing: 0; font-weight: 600; }
.stamp.paid { color: #1565c0; } .stamp.due { color: #c62828; }

/* ---- brouillard de caisse ---- */
.title { display: flex; justify-content: space-between; align-items: baseline; margin: 16px 0 12px; }
.title h1 { margin: 0; font-size: 22px; letter-spacing: 1px; color: #001048; }
table { width: 100%; border-collapse: collapse; margin-top: 4px; }
th { background: #001048; color: #fff; text-align: left; font-size: 11px; padding: 7px 8px; }
td { padding: 7px 8px; border-bottom: 1px solid #e1e8f3; vertical-align: top; }
.n { text-align: right; white-space: nowrap; }
tr { page-break-inside: avoid; }
.muted { color: #6b7894; }
.sum td { font-weight: 700; border-top: 2px solid #001048; background: #f1f6fd; }
.in { color: #1565c0; } .out { color: #c62828; }
.kpis { display: flex; gap: 10px; margin-bottom: 12px; }
.kpis div { flex: 1; border: 1px solid #cfd9ea; border-radius: 6px; padding: 8px 10px; }
.kpis span { display: block; font-size: 10.5px; color: #5b6b8c; text-transform: uppercase; letter-spacing: 1px; }
.kpis b { font-size: 16px; }
.kpis .hi { background: #001048; color: #fff; } .kpis .hi span { color: #a9c4e6; }
.modes { margin-top: 10px; font-size: 11.5px; } .chip { display: inline-block; background: #eaf3fc; border-radius: 99px; padding: 2px 10px; margin: 2px 4px 2px 0; }
.note { margin-top: 8px; font-size: 10.5px; color: #6b7894; }
.sign { display: flex; gap: 40px; margin-top: 30px; } .sign div { flex: 1; border-top: 1px solid #99a6c0; padding-top: 6px; font-size: 11.5px; color: #334; }
.foot { margin-top: 26px; text-align: center; font-size: 10.5px; color: #6b7894; border-top: 1px solid #e1e8f3; padding-top: 8px; }

.frame { width: 100%; border-collapse: collapse; }
.frame > thead > tr > td, .frame > tfoot > tr > td, .frame > tbody > tr > td { padding: 0; border: 0; background: none; }
.frame > tbody > tr { page-break-inside: auto; }
.sp { height: 0; }
@media print { body { background: #fff; } .noprint { display: none !important; }
  .sp { height: 7mm; }
  .sheet { box-shadow: none; margin: 0 auto; padding: 0 12mm; max-width: none; } }
''';
}
