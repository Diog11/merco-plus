import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

/// Centralise tous les accès Firestore de l'application.
///
/// Collections utilisées :
///   clients/{clientId}                 -> {name, phone}
///   clients/{clientId}/vehicles/{id}   -> {make, model, plate, km}
///   stock/{itemId}                     -> StockItem
///   documents/{docId}                  -> DocumentRecord (devis/facture)
///   jobs/{jobId}                       -> RepairJob
///   counters/documents                 -> {next: <int>}  (numérotation devis/factures)
class FirestoreService {
  FirestoreService._();
  static final instance = FirestoreService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _clients => _db.collection('clients');
  CollectionReference<Map<String, dynamic>> get _stock => _db.collection('stock');
  CollectionReference<Map<String, dynamic>> get _docs => _db.collection('documents');
  CollectionReference<Map<String, dynamic>> get _jobs => _db.collection('jobs');

  // ---------------- CLIENTS ----------------
  Stream<List<Client>> watchClients() {
    return _clients.orderBy('name').snapshots().asyncMap((snap) async {
      final clients = <Client>[];
      for (final d in snap.docs) {
        final base = Client.fromDoc(d);
        final vehSnap = await d.reference.collection('vehicles').get();
        clients.add(Client(
          id: base.id,
          name: base.name,
          phone: base.phone,
          vehicles: vehSnap.docs.map((v) => Vehicle.fromMap(v.id, v.data())).toList(),
        ));
      }
      return clients;
    });
  }

  Future<String> addClient(String name, String phone) async {
    final ref = await _clients.add({'name': name, 'phone': phone});
    return ref.id;
  }

  Future<void> deleteClient(String clientId) async {
    final vehicles = await _clients.doc(clientId).collection('vehicles').get();
    for (final v in vehicles.docs) {
      await v.reference.delete();
    }
    await _clients.doc(clientId).delete();
  }

  Future<void> addVehicle(String clientId, Vehicle vehicle) async {
    await _clients.doc(clientId).collection('vehicles').add(vehicle.toMap());
  }

  // ---------------- STOCK ----------------
  Stream<List<StockItem>> watchStock() {
    return _stock.orderBy('name').snapshots().map(
        (snap) => snap.docs.map((d) => StockItem.fromDoc(d)).toList());
  }

  Future<void> addStockItem(StockItem item) => _stock.add(item.toMap());

  Future<void> adjustStock(String itemId, int currentQty, int delta) async {
    final newQty = (currentQty + delta).clamp(0, 1 << 30);
    await _stock.doc(itemId).update({'qty': newQty});
  }

  Future<void> deleteStockItem(String itemId) => _stock.doc(itemId).delete();

  // ---------------- DEVIS / FACTURES ----------------
  Stream<List<DocumentRecord>> watchDocuments() {
    return _docs.orderBy('num', descending: true).snapshots().map(
        (snap) => snap.docs.map((d) => DocumentRecord.fromDoc(d)).toList());
  }

  /// Numérotation auto-incrémentée via une transaction sur `counters/documents`.
  Future<int> _nextDocNumber() {
    final counterRef = _db.collection('counters').doc('documents');
    return _db.runTransaction<int>((tx) async {
      final snap = await tx.get(counterRef);
      final next = ((snap.data()?['next'] ?? 1001) as int);
      tx.set(counterRef, {'next': next + 1}, SetOptions(merge: true));
      return next;
    });
  }

  Future<void> addDocument({
    required DocType type,
    required String clientId,
    required String vehicleId,
    required List<LineItem> lines,
  }) async {
    final num = await _nextDocNumber();
    final doc = DocumentRecord(
      id: '',
      num: num,
      type: type,
      clientId: clientId,
      vehicleId: vehicleId,
      date: DateTime.now(),
      status: DocStatus.impaye,
      lines: lines,
    );
    await _docs.add(doc.toMap());
  }

  Future<void> convertToInvoice(String docId) =>
      _docs.doc(docId).update({'type': 'facture', 'status': 'impaye'});

  Future<void> markPaid(String docId) => _docs.doc(docId).update({'status': 'paye'});

  Future<void> deleteDocument(String docId) => _docs.doc(docId).delete();

  // ---------------- ATELIER / PLANNING ----------------
  Stream<List<RepairJob>> watchJobs() {
    return _jobs.snapshots().map((snap) => snap.docs.map((d) => RepairJob.fromDoc(d)).toList());
  }

  Future<void> addJob(RepairJob job) => _jobs.add(job.toMap());

  Future<void> changeJobStatus(String jobId, JobStatus status) =>
      _jobs.doc(jobId).update({'status': RepairJob.statusToString(status)});
}
