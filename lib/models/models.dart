import 'package:cloud_firestore/cloud_firestore.dart';

/// Un véhicule, toujours rattaché à un [Client]. On le stocke comme
/// sous-document dans la sous-collection `clients/{id}/vehicles`.
class Vehicle {
  final String id;
  final String make;
  final String model;
  final String plate;
  final int km;
  final String chassis; // numéro de châssis (VIN)

  Vehicle({
    required this.id,
    required this.make,
    required this.model,
    required this.plate,
    this.km = 0,
    this.chassis = '',
  });

  factory Vehicle.fromMap(String id, Map<String, dynamic> m) => Vehicle(
        id: id,
        make: m['make'] ?? '',
        model: m['model'] ?? '',
        plate: m['plate'] ?? '—',
        km: ((m['km'] ?? 0) as num).toInt(),
        chassis: m['chassis'] ?? '',
      );

  Map<String, dynamic> toMap() => {
        'make': make,
        'model': model,
        'plate': plate,
        'km': km,
        'chassis': chassis,
      };
}

class Client {
  final String id;
  final String name;
  final String phone;
  final List<Vehicle> vehicles;

  Client({
    required this.id,
    required this.name,
    required this.phone,
    this.vehicles = const [],
  });

  factory Client.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Client(id: d.id, name: m['name'] ?? '', phone: m['phone'] ?? '');
  }

  Map<String, dynamic> toMap() => {'name': name, 'phone': phone};
}

/// Une pièce détachée du stock.
class StockItem {
  final String id;
  final String ref;
  final String name;
  final int qty;
  final int min;
  final int price; // FCFA
  final String loc;
  final String supplier;

  StockItem({
    required this.id,
    required this.ref,
    required this.name,
    required this.qty,
    required this.min,
    required this.price,
    this.loc = '',
    this.supplier = '',
  });

  bool get isLow => qty <= min;

  factory StockItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return StockItem(
      id: d.id,
      ref: m['ref'] ?? '',
      name: m['name'] ?? '',
      qty: (m['qty'] ?? 0) as int,
      min: (m['min'] ?? 0) as int,
      price: (m['price'] ?? 0) as int,
      loc: m['loc'] ?? '',
      supplier: m['supplier'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'ref': ref,
        'name': name,
        'qty': qty,
        'min': min,
        'price': price,
        'loc': loc,
        'supplier': supplier,
      };
}

/// Une ligne de devis/facture (main-d'œuvre ou pièce).
class LineItem {
  final String desc;
  final int qty;
  final int price;

  LineItem({required this.desc, required this.qty, required this.price});

  int get subtotal => qty * price;

  factory LineItem.fromMap(Map<String, dynamic> m) => LineItem(
        desc: m['desc'] ?? '',
        qty: (m['qty'] ?? 0) as int,
        price: (m['price'] ?? 0) as int,
      );

  Map<String, dynamic> toMap() => {'desc': desc, 'qty': qty, 'price': price};
}

enum DocType { devis, facture }

/// Taux appliqués aux devis / factures (lignes saisies = montants hors taxes).
const int kTvaRate = 18; // TVA : % du total HT
const int kCadRate = 5; // CAD (centimes additionnels) : % du MONTANT DE LA TVA

/// Totaux d'un document : sous-total, remise, HT, TVA, CAD et TTC (montant à payer).
class DocTotals {
  final int gross; // somme des lignes (avant remise)
  final int discount; // remise déduite
  final int tva;
  final int cad;
  const DocTotals(this.gross, this.discount, this.tva, this.cad);

  /// Total hors taxes, remise déduite.
  int get ht => gross - discount;
  int get ttc => ht + tva + cad;

  /// [discountType] : 'percent' (valeur en %) ou 'amount' (valeur en FCFA) ; '' = pas de remise.
  /// [tvaRate] / [cadRate] : 0 = non appliqué. La TVA se calcule sur le HT remisé,
  /// la CAD sur le montant de la TVA.
  factory DocTotals.of(
    List<LineItem> lines, {
    int tvaRate = 0,
    int cadRate = 0,
    String discountType = '',
    int discountValue = 0,
  }) {
    final gross = lines.fold<int>(0, (a, l) => a + l.subtotal);
    var discount = 0;
    if (discountValue > 0) {
      if (discountType == 'percent') {
        final pct = discountValue > 100 ? 100 : discountValue;
        discount = (gross * pct / 100).round();
      } else if (discountType == 'amount') {
        discount = discountValue;
      }
    }
    if (discount > gross) discount = gross;
    if (discount < 0) discount = 0;
    final net = gross - discount;
    final tva = (net * tvaRate / 100).round();
    final cad = (tva * cadRate / 100).round();
    return DocTotals(gross, discount, tva, cad);
  }
}

enum DocStatus { impaye, paye }

/// Un devis ou une facture, toujours rattaché à un client (et,
/// optionnellement, à un véhicule précis de ce client).
class DocumentRecord {
  final String id;
  final int num;
  final DocType type;
  final String clientId;
  final String vehicleId;
  final DateTime date;
  final DocStatus status;
  final List<LineItem> lines;
  final DateTime? paidAt; // date d'encaissement (factures payées)
  final String payMethod; // clé de kPayMethods
  final int tvaRate; // 0 = TVA non appliquée (sinon kTvaRate)
  final int cadRate; // 0 = CAD non appliquée (sinon kCadRate)
  final String discountType; // '' (aucune) | 'percent' | 'amount'
  final int discountValue; // % ou FCFA selon discountType
  final int deposit; // acompte déjà versé (FCFA), factures uniquement

  DocumentRecord({
    required this.id,
    required this.num,
    required this.type,
    required this.clientId,
    required this.vehicleId,
    required this.date,
    required this.status,
    required this.lines,
    this.paidAt,
    this.payMethod = '',
    this.tvaRate = 0,
    this.cadRate = 0,
    this.discountType = '',
    this.discountValue = 0,
    this.deposit = 0,
  });

  DocTotals get totals => DocTotals.of(lines,
      tvaRate: tvaRate, cadRate: cadRate, discountType: discountType, discountValue: discountValue);

  /// Montant de la remise (FCFA).
  int get discount => totals.discount;

  /// Reste à payer : 0 si la facture est soldée, sinon TTC moins l'acompte.
  int get remaining {
    if (status == DocStatus.paye) return 0;
    final r = total - deposit;
    return r < 0 ? 0 : r;
  }

  /// Total hors taxes.
  int get subtotal => totals.ht;

  /// Montant à payer (TTC si TVA/CAD appliquées, sinon égal au total HT).
  int get total => totals.ttc;

  factory DocumentRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return DocumentRecord(
      id: d.id,
      num: (m['num'] ?? 0) as int,
      type: (m['type'] == 'facture') ? DocType.facture : DocType.devis,
      clientId: m['clientId'] ?? '',
      vehicleId: m['vehicleId'] ?? '',
      date: (m['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: (m['status'] == 'paye') ? DocStatus.paye : DocStatus.impaye,
      lines: ((m['lines'] ?? []) as List)
          .map((l) => LineItem.fromMap(Map<String, dynamic>.from(l)))
          .toList(),
      paidAt: (m['paidAt'] as Timestamp?)?.toDate(),
      payMethod: m['payMethod'] ?? '',
      tvaRate: int.tryParse('${m['tvaRate'] ?? 0}') ?? 0,
      cadRate: int.tryParse('${m['cadRate'] ?? 0}') ?? 0,
      discountType: (m['discountType'] ?? '') as String,
      discountValue: int.tryParse('${m['discountValue'] ?? 0}') ?? 0,
      deposit: int.tryParse('${m['deposit'] ?? 0}') ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'tvaRate': tvaRate,
        'cadRate': cadRate,
        'discountType': discountType,
        'discountValue': discountValue,
        'deposit': deposit,
        'num': num,
        'type': type == DocType.facture ? 'facture' : 'devis',
        'clientId': clientId,
        'vehicleId': vehicleId,
        'date': Timestamp.fromDate(date),
        'status': status == DocStatus.paye ? 'paye' : 'impaye',
        'lines': lines.map((l) => l.toMap()).toList(),
        if (paidAt != null) 'paidAt': Timestamp.fromDate(paidAt!),
        if (payMethod.isNotEmpty) 'payMethod': payMethod,
      };
}

enum JobStatus { attente, cours, termine }

/// Une intervention atelier suivie dans le planning (kanban).
class RepairJob {
  final String id;
  final String clientId;
  final String vehicleId;
  final String desc;
  final String tech;
  final String technicianUid; // uid du compte technicien assigné ('' = personne)
  final String clientName; // copie du nom du client (lisible par le technicien)
  final String vehicleLabel; // copie "plaque — marque modèle"
  final JobStatus status;
  final DateTime createdAt;

  RepairJob({
    required this.id,
    required this.clientId,
    required this.vehicleId,
    required this.desc,
    required this.tech,
    this.technicianUid = '',
    this.clientName = '',
    this.vehicleLabel = '',
    required this.status,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  static JobStatus statusFromString(String s) => switch (s) {
        'cours' => JobStatus.cours,
        'termine' => JobStatus.termine,
        _ => JobStatus.attente,
      };

  static String statusToString(JobStatus s) => switch (s) {
        JobStatus.attente => 'attente',
        JobStatus.cours => 'cours',
        JobStatus.termine => 'termine',
      };

  factory RepairJob.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return RepairJob(
      id: d.id,
      clientId: m['clientId'] ?? '',
      vehicleId: m['vehicleId'] ?? '',
      desc: m['desc'] ?? '',
      tech: m['tech'] ?? 'Non assigné',
      technicianUid: m['technicianUid'] ?? '',
      clientName: m['clientName'] ?? '',
      vehicleLabel: m['vehicleLabel'] ?? '',
      status: statusFromString(m['status'] ?? 'attente'),
      // Rétrocompatible : les interventions créées avant cette mise à jour
      // n'ont pas de champ createdAt en base — on retombe sur "maintenant".
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'clientId': clientId,
        'vehicleId': vehicleId,
        'desc': desc,
        'tech': tech,
        'technicianUid': technicianUid,
        'clientName': clientName,
        'vehicleLabel': vehicleLabel,
        'status': statusToString(status),
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

/// Un technicien de l'atelier (module Calendrier / planning).
class Technician {
  final String id;
  final String name;
  final String phone;
  final String specialty;

  Technician({required this.id, required this.name, this.phone = '', this.specialty = ''});

  factory Technician.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Technician(id: d.id, name: m['name'] ?? '', phone: m['phone'] ?? '', specialty: m['specialty'] ?? '');
  }

  Map<String, dynamic> toMap() => {'name': name, 'phone': phone, 'specialty': specialty};
}

enum AppointmentStatus { confirme, enAttente, annule }

/// Un rendez-vous planifié sur le calendrier de l'atelier.
class Appointment {
  final String id;
  final String clientId;
  final String vehicleId;
  final String technicianId;
  final DateTime date; // jour + heure du rendez-vous
  final String notes;
  final AppointmentStatus status;

  Appointment({
    required this.id,
    required this.clientId,
    required this.vehicleId,
    required this.technicianId,
    required this.date,
    this.notes = '',
    this.status = AppointmentStatus.enAttente,
  });

  static AppointmentStatus statusFromString(String s) => switch (s) {
        'confirme' => AppointmentStatus.confirme,
        'annule' => AppointmentStatus.annule,
        _ => AppointmentStatus.enAttente,
      };

  static String statusToString(AppointmentStatus s) => switch (s) {
        AppointmentStatus.confirme => 'confirme',
        AppointmentStatus.annule => 'annule',
        AppointmentStatus.enAttente => 'enAttente',
      };

  factory Appointment.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Appointment(
      id: d.id,
      clientId: m['clientId'] ?? '',
      vehicleId: m['vehicleId'] ?? '',
      technicianId: m['technicianId'] ?? '',
      date: (m['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notes: m['notes'] ?? '',
      status: statusFromString(m['status'] ?? 'enAttente'),
    );
  }

  Map<String, dynamic> toMap() => {
        'clientId': clientId,
        'vehicleId': vehicleId,
        'technicianId': technicianId,
        'date': Timestamp.fromDate(date),
        'notes': notes,
        'status': statusToString(status),
      };
}


/// Type de compte. L'accès réel aux données est appliqué par les règles
/// Firestore (firestore.rules) ; l'interface ne fait que refléter ce rôle.
enum UserRole { admin, technicien }

/// Profil d'un compte utilisateur, stocké dans `users/{uid}`.
class AppUser {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final UserRole role;

  AppUser({required this.uid, required this.name, required this.email, this.phone = '', required this.role});

  bool get isAdmin => role == UserRole.admin;

  static UserRole roleFromString(String? s) => s == 'admin' ? UserRole.admin : UserRole.technicien;
  static String roleToString(UserRole r) => r == UserRole.admin ? 'admin' : 'technicien';

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return AppUser(
      uid: d.id,
      name: m['name'] ?? '',
      email: m['email'] ?? '',
      phone: m['phone'] ?? '',
      role: roleFromString(m['role'] as String?),
    );
  }
}


// ======================= BROUILLARD DE CAISSE =======================

/// Modes de paiement (clé stockée -> libellé affiché).
const Map<String, String> kPayMethods = {
  'especes': 'Espèces',
  'mobile': 'Mobile Money',
  'virement': 'Virement',
  'cheque': 'Chèque',
};

// Saisie manuelle uniquement : les encaissements de factures sont inscrits
// automatiquement (catégorie « Facture client ») quand on marque une facture payée.
const List<String> kCashInCategories = ['Acompte', 'Vente comptoir', 'Autre entrée'];
const List<String> kCashOutCategories = [
  'Achat de pièces',
  'Salaires & avances',
  'Loyer & charges',
  'Carburant & transport',
  'Outillage',
  'Autre dépense',
];

enum CashType { entree, sortie }

/// Un mouvement de caisse (entrée ou sortie d'argent), dans `cashEntries`.
/// Les paiements de factures créent automatiquement une entrée (source = 'facture').
class CashEntry {
  final String id;
  final CashType type;
  final int amount; // FCFA, toujours positif
  final String label;
  final String category;
  final String method;
  final DateTime date;
  final String source; // 'manuel' | 'facture'
  final String docId;

  CashEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.label,
    this.category = '',
    this.method = 'especes',
    DateTime? date,
    this.source = 'manuel',
    this.docId = '',
  }) : date = date ?? DateTime.now();

  bool get isIn => type == CashType.entree;
  int get signed => isIn ? amount : -amount;

  factory CashEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return CashEntry(
      id: d.id,
      type: m['type'] == 'sortie' ? CashType.sortie : CashType.entree,
      amount: ((m['amount'] ?? 0) as num).toInt(),
      label: m['label'] ?? '',
      category: m['category'] ?? '',
      method: m['method'] ?? 'especes',
      date: (m['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      source: m['source'] ?? 'manuel',
      docId: m['docId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'type': isIn ? 'entree' : 'sortie',
        'amount': amount,
        'label': label,
        'category': category,
        'method': method,
        'date': Timestamp.fromDate(date),
        'source': source,
        'docId': docId,
      };
}

/// Bilan d'une journée : solde reporté + entrées - sorties = solde de clôture.
class CashDaySummary {
  final DateTime day;
  final int opening; // solde de la veille (report)
  final int totalIn;
  final int totalOut;
  final List<CashEntry> entries; // du jour, par heure croissante

  CashDaySummary({
    required this.day,
    required this.opening,
    required this.totalIn,
    required this.totalOut,
    required this.entries,
  });

  int get net => totalIn - totalOut;
  int get closing => opening + net;

  /// Total net (entrées - sorties) du jour pour un mode de paiement.
  int netForMethod(String method) => entries.where((e) => e.method == method).fold(0, (a, e) => a + e.signed);

  factory CashDaySummary.of(List<CashEntry> all, DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = DateTime(day.year, day.month, day.day + 1);
    var opening = 0;
    var tin = 0;
    var tout = 0;
    final list = <CashEntry>[];
    for (final e in all) {
      if (e.date.isBefore(start)) {
        opening += e.signed;
      } else if (e.date.isBefore(end)) {
        list.add(e);
        if (e.isIn) {
          tin += e.amount;
        } else {
          tout += e.amount;
        }
      }
    }
    list.sort((a, b) => a.date.compareTo(b.date));
    return CashDaySummary(day: start, opening: opening, totalIn: tin, totalOut: tout, entries: list);
  }
}
