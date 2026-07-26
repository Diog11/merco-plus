import 'package:cloud_firestore/cloud_firestore.dart';

/// Un véhicule, toujours rattaché à un [Client]. On le stocke comme
/// sous-document dans la sous-collection `clients/{id}/vehicles`.
class Vehicle {
  final String id;
  final String make;
  final String model;
  final String plate;
  final int km;

  Vehicle({
    required this.id,
    required this.make,
    required this.model,
    required this.plate,
    this.km = 0,
  });

  factory Vehicle.fromMap(String id, Map<String, dynamic> m) => Vehicle(
        id: id,
        make: m['make'] ?? '',
        model: m['model'] ?? '',
        plate: m['plate'] ?? '—',
        km: (m['km'] ?? 0) as int,
      );

  Map<String, dynamic> toMap() => {
        'make': make,
        'model': model,
        'plate': plate,
        'km': km,
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

  DocumentRecord({
    required this.id,
    required this.num,
    required this.type,
    required this.clientId,
    required this.vehicleId,
    required this.date,
    required this.status,
    required this.lines,
  });

  int get total => lines.fold(0, (a, l) => a + l.subtotal);

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
    );
  }

  Map<String, dynamic> toMap() => {
        'num': num,
        'type': type == DocType.facture ? 'facture' : 'devis',
        'clientId': clientId,
        'vehicleId': vehicleId,
        'date': Timestamp.fromDate(date),
        'status': status == DocStatus.paye ? 'paye' : 'impaye',
        'lines': lines.map((l) => l.toMap()).toList(),
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
  final JobStatus status;
  final DateTime createdAt;

  RepairJob({
    required this.id,
    required this.clientId,
    required this.vehicleId,
    required this.desc,
    required this.tech,
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
        'status': statusToString(status),
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
