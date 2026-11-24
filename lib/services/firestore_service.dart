import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import 'sync_status.dart';

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

  /// MODE HORS LIGNE : avec la persistance activée (main.dart), une écriture
  /// est appliquée tout de suite au cache local, mais sa Future ne se termine
  /// qu'au retour d'Internet (accusé du serveur). On n'attend donc le serveur
  /// que 2 s : en ligne, les erreurs (ex. permission refusée) remontent
  /// normalement ; hors ligne, l'écriture reste en file d'attente et part toute
  /// seule à la reconnexion, sans bloquer l'écran.
  Future<void> _w(Future<void> f) {
    // Une écriture refusée par le serveur échoue parfois APRÈS ces 2 s (elle est
    // alors annulée sur l'appareil) : on le signale à l'écran au lieu de l'ignorer.
    f.catchError((Object e) {
      SyncStatus.report(e);
    });
    return f.timeout(const Duration(seconds: 2), onTimeout: () {});
  }

  CollectionReference<Map<String, dynamic>> get _clients => _db.collection('clients');
  CollectionReference<Map<String, dynamic>> get _stock => _db.collection('stock');
  CollectionReference<Map<String, dynamic>> get _docs => _db.collection('documents');
  CollectionReference<Map<String, dynamic>> get _jobs => _db.collection('jobs');

  // ---------------- CLIENTS ----------------
  /// Clients + véhicules en temps réel.
  ///
  /// On écoute la collection `clients` ET, pour chaque client, sa
  /// sous-collection `vehicles`. Un véhicule ajouté/modifié apparaît donc
  /// aussitôt dans les listes déroulantes, et la liste des clients s'affiche
  /// même si la lecture des véhicules d'un client échoue.
  Stream<List<Client>> watchClients() {
    late final StreamController<List<Client>> ctrl;
    QuerySnapshot<Map<String, dynamic>>? clientsSnap;
    final vehicles = <String, List<Vehicle>>{};
    final vehicleSubs = <String, StreamSubscription<dynamic>>{};
    StreamSubscription<dynamic>? subClients;

    void emit() {
      final cs = clientsSnap;
      if (cs == null || ctrl.isClosed) return;
      ctrl.add(cs.docs.map((d) {
        final base = Client.fromDoc(d);
        return Client(id: base.id, name: base.name, phone: base.phone, vehicles: vehicles[d.id] ?? const []);
      }).toList());
    }

    void syncVehicleSubs(QuerySnapshot<Map<String, dynamic>> cs) {
      final ids = cs.docs.map((d) => d.id).toSet();
      for (final id in vehicleSubs.keys.toList()) {
        if (!ids.contains(id)) {
          vehicleSubs.remove(id)?.cancel();
          vehicles.remove(id);
        }
      }
      for (final d in cs.docs) {
        if (vehicleSubs.containsKey(d.id)) continue;
        vehicleSubs[d.id] = d.reference.collection('vehicles').snapshots().listen((vs) {
          vehicles[d.id] = vs.docs.map((v) => Vehicle.fromMap(v.id, v.data())).toList();
          emit();
        }, onError: (_) {
          vehicles[d.id] = const [];
          emit();
        });
      }
    }

    ctrl = StreamController<List<Client>>(
      onListen: () {
        subClients = _clients.orderBy('name').snapshots().listen((s) {
          clientsSnap = s;
          syncVehicleSubs(s);
          emit();
        }, onError: ctrl.addError);
      },
      onCancel: () async {
        await subClients?.cancel();
        for (final sub in vehicleSubs.values) {
          await sub.cancel();
        }
        vehicleSubs.clear();
      },
    );
    return ctrl.stream;
  }

  Future<String> addClient(String name, String phone) async {
    // Identifiant créé localement : utilisable tout de suite, même hors ligne.
    final ref = _clients.doc();
    await _w(ref.set({'name': name, 'phone': phone}));
    return ref.id;
  }

  Future<void> updateClient(String clientId, String name, String phone) =>
      _w(_clients.doc(clientId).update({'name': name, 'phone': phone}));

  Future<void> deleteClient(String clientId) async {
    // Le cache local est tenu à jour par les écoutes de watchClients().
    final vehicles = await _clients.doc(clientId).collection('vehicles').get(const GetOptions(source: Source.cache));
    final batch = _db.batch();
    for (final v in vehicles.docs) {
      batch.delete(v.reference);
    }
    batch.delete(_clients.doc(clientId));
    await _w(batch.commit());
  }

  Future<void> addVehicle(String clientId, Vehicle vehicle) async {
    await _w(_clients.doc(clientId).collection('vehicles').add(vehicle.toMap()).then((_) {}));
  }

  Future<void> updateVehicle(String clientId, Vehicle vehicle) async {
    await _w(_clients.doc(clientId).collection('vehicles').doc(vehicle.id).set(vehicle.toMap()));
  }

  // ---------------- STOCK ----------------
  Stream<List<StockItem>> watchStock() {
    return _stock.orderBy('name').snapshots().map(
        (snap) => snap.docs.map((d) => StockItem.fromDoc(d)).toList());
  }

  Future<void> addStockItem(StockItem item) => _w(_stock.add(item.toMap()).then((_) {}));

  Future<void> adjustStock(String itemId, int currentQty, int delta) async {
    final newQty = (currentQty + delta).clamp(0, 1 << 30);
    await _w(_stock.doc(itemId).update({'qty': newQty}));
  }

  Future<void> updateStockItem(StockItem item) => _w(_stock.doc(item.id).update(item.toMap()));

  Future<void> deleteStockItem(String itemId) => _w(_stock.doc(itemId).delete());

  // ---------------- DEVIS / FACTURES ----------------
  Stream<List<DocumentRecord>> watchDocuments() {
    return _docs.orderBy('num', descending: true).snapshots().map(
        (snap) => snap.docs.map((d) => DocumentRecord.fromDoc(d)).toList());
  }

  /// Numérotation auto-incrémentée via une transaction sur `counters/documents`.
  ///
  /// Une transaction exige Internet. Hors ligne (ou connexion trop lente), on
  /// prend le plus grand numéro déjà connu sur cet appareil + 1. Le compteur
  /// en ligne tient aussi compte des numéros existants, pour éviter les doublons
  /// quand la connexion revient.
  Future<int> _nextDocNumber() async {
    var maxKnown = 1000;
    try {
      final q = await _docs
          .orderBy('num', descending: true)
          .limit(1)
          .get(const GetOptions(source: Source.cache));
      if (q.docs.isNotEmpty) {
        final n = ((q.docs.first.data()['num'] ?? 0) as num).toInt();
        if (n > maxKnown) maxKnown = n;
      }
    } catch (_) {}

    final counterRef = _db.collection('counters').doc('documents');
    try {
      return await _db.runTransaction<int>((tx) async {
        final snap = await tx.get(counterRef);
        var next = ((snap.data()?['next'] ?? 1001) as num).toInt();
        if (next <= maxKnown) next = maxKnown + 1;
        tx.set(counterRef, {'next': next + 1}, SetOptions(merge: true));
        return next;
      }).timeout(const Duration(seconds: 5));
    } catch (_) {
      return maxKnown + 1; // hors ligne
    }
  }

  /// Nom du client (lu dans le cache local : marche hors ligne), '' si introuvable.
  Future<String> _clientNameOf(String clientId) async {
    if (clientId.isEmpty) return '';
    try {
      final c = await _clients.doc(clientId).get(const GetOptions(source: Source.cache));
      return (c.data()?['name'] ?? '') as String;
    } catch (_) {
      return '';
    }
  }

  static String _invLabel(int num, String clientName) =>
      'Facture #$num${clientName.isEmpty ? '' : ' — $clientName'}';

  static String _depositLabel(int num, String clientName) =>
      'Acompte facture #$num${clientName.isEmpty ? '' : ' — $clientName'}';

  Future<void> addDocument({
    required DocType type,
    required String clientId,
    required String vehicleId,
    required List<LineItem> lines,
    int tvaRate = 0,
    int cadRate = 0,
    String discountType = '',
    int discountValue = 0,
    int deposit = 0,
  }) async {
    final num = await _nextDocNumber();
    final dep = type == DocType.facture ? deposit : 0;
    final doc = DocumentRecord(
      id: '',
      num: num,
      type: type,
      clientId: clientId,
      vehicleId: vehicleId,
      date: DateTime.now(),
      status: DocStatus.impaye,
      lines: lines,
      tvaRate: tvaRate,
      cadRate: cadRate,
      discountType: discountType,
      discountValue: discountValue,
      deposit: dep,
    );
    final ref = _docs.doc();
    final batch = _db.batch();
    batch.set(ref, doc.toMap());
    // Un acompte versé est une entrée de caisse (document déterministe dep_<id>).
    if (dep > 0) {
      final name = await _clientNameOf(clientId);
      batch.set(
        _cash.doc('dep_${ref.id}'),
        CashEntry(
          id: '',
          type: CashType.entree,
          amount: dep,
          label: _depositLabel(num, name),
          category: 'Acompte client',
          method: 'especes',
          date: DateTime.now(),
          source: 'facture',
          docId: ref.id,
        ).toMap(),
      );
    }
    await _w(batch.commit());
  }

  /// Modifie un devis / une facture (client, véhicule, lignes, taxes, remise, acompte).
  /// Le brouillard de caisse reste juste : l'encaissement final (`inv_`) vaut
  /// TTC − acompte, et l'acompte (`dep_`) est une entrée à part.
  Future<void> updateDocument(
    DocumentRecord old, {
    required String clientId,
    required String vehicleId,
    required List<LineItem> lines,
    int tvaRate = 0,
    int cadRate = 0,
    String discountType = '',
    int discountValue = 0,
    int deposit = 0,
  }) async {
    final isInvoice = old.type == DocType.facture;
    final dep = isInvoice ? deposit : 0;
    final totals = DocTotals.of(lines,
        tvaRate: tvaRate, cadRate: cadRate, discountType: discountType, discountValue: discountValue);
    final batch = _db.batch();
    batch.update(_docs.doc(old.id), {
      'clientId': clientId,
      'vehicleId': vehicleId,
      'lines': lines.map((l) => l.toMap()).toList(),
      'tvaRate': tvaRate,
      'cadRate': cadRate,
      'discountType': discountType,
      'discountValue': discountValue,
      'deposit': dep,
    });
    if (isInvoice) {
      final clientName = await _clientNameOf(clientId);

      Future<DocumentSnapshot<Map<String, dynamic>>?> readCash(DocumentReference<Map<String, dynamic>> r) async {
        try {
          return await r.get(const GetOptions(source: Source.cache));
        } catch (_) {
          try {
            return await r.get().timeout(const Duration(seconds: 3));
          } catch (_) {
            return null;
          }
        }
      }

      // Acompte.
      final depRef = _cash.doc('dep_${old.id}');
      if (dep > 0) {
        final c = await readCash(depRef);
        if (c != null && c.exists) {
          batch.update(depRef, {'amount': dep, 'label': _depositLabel(old.num, clientName)});
        } else {
          batch.set(
            depRef,
            CashEntry(
              id: '',
              type: CashType.entree,
              amount: dep,
              label: _depositLabel(old.num, clientName),
              category: 'Acompte client',
              method: 'especes',
              date: DateTime.now(),
              source: 'facture',
              docId: old.id,
            ).toMap(),
          );
        }
      } else {
        batch.delete(depRef);
      }

      // Facture déjà encaissée : le solde encaissé = TTC − acompte.
      if (old.status == DocStatus.paye) {
        final rest = (totals.ttc - dep) < 0 ? 0 : totals.ttc - dep;
        final cashRef = _cash.doc('inv_${old.id}');
        final c = await readCash(cashRef);
        if (c != null && c.exists) {
          batch.update(cashRef, {'amount': rest, 'label': _invLabel(old.num, clientName)});
        } else if (rest > 0) {
          batch.set(
            cashRef,
            CashEntry(
              id: '',
              type: CashType.entree,
              amount: rest,
              label: _invLabel(old.num, clientName),
              category: 'Facture client',
              method: old.payMethod.isEmpty ? 'especes' : old.payMethod,
              date: old.paidAt ?? DateTime.now(),
              source: 'facture',
              docId: old.id,
            ).toMap(),
          );
        }
      }
    }
    await _w(batch.commit());
  }

  Future<void> convertToInvoice(String docId) =>
      _w(_docs.doc(docId).update({'type': 'facture', 'status': 'impaye'}));

  /// Marque la facture payée ET inscrit l'encaissement au brouillard de caisse
  /// (document déterministe `inv_<id>` : impossible de le créer en double).
  Future<void> markPaid(String docId, {String method = 'especes'}) async {
    final ref = _docs.doc(docId);
    // Lecture dans le cache local (tenu à jour par les écoutes) : marche hors ligne.
    DocumentSnapshot<Map<String, dynamic>> snap;
    try {
      snap = await ref.get(const GetOptions(source: Source.cache));
    } catch (_) {
      snap = await ref.get();
    }
    final rec = DocumentRecord.fromDoc(snap);
    var clientName = '';
    if (rec.clientId.isNotEmpty) {
      try {
        final c = await _clients.doc(rec.clientId).get(const GetOptions(source: Source.cache));
        clientName = (c.data()?['name'] ?? '') as String;
      } catch (_) {}
    }
    final now = DateTime.now();
    final batch = _db.batch();
    batch.update(ref, {'status': 'paye', 'paidAt': Timestamp.fromDate(now), 'payMethod': method});
    // Solde encaissé = TTC − acompte déjà inscrit en caisse.
    final rest = (rec.total - rec.deposit) < 0 ? 0 : rec.total - rec.deposit;
    if (rest > 0) {
      batch.set(
        _cash.doc('inv_$docId'),
        CashEntry(
          id: '',
          type: CashType.entree,
          amount: rest,
          label: _invLabel(rec.num, clientName),
          category: 'Facture client',
          method: method,
          date: now,
          source: 'facture',
          docId: docId,
        ).toMap(),
      );
    }
    await _w(batch.commit());
  }

  // ---------------- BROUILLARD DE CAISSE ----------------
  CollectionReference<Map<String, dynamic>> get _cash => _db.collection('cashEntries');

  /// Tous les mouvements (le report de solde se calcule sur l'historique).
  Stream<List<CashEntry>> watchCash() {
    return _cash.orderBy('date').snapshots().map((snap) => snap.docs.map((d) => CashEntry.fromDoc(d)).toList());
  }

  Future<void> addCashEntry(CashEntry e) => _w(_cash.add(e.toMap()).then((_) {}));

  Future<void> updateCashEntry(CashEntry e) => _w(_cash.doc(e.id).update({
        'amount': e.amount,
        'label': e.label,
        'category': e.category,
        'method': e.method,
        'date': Timestamp.fromDate(e.date),
      }));

  Future<void> deleteCashEntry(String id) => _w(_cash.doc(id).delete());

  Future<void> deleteDocument(String docId) => _w(_docs.doc(docId).delete());

  // ---------------- ATELIER / PLANNING ----------------
  Stream<List<RepairJob>> watchJobs() {
    return _jobs.snapshots().map((snap) => snap.docs.map((d) => RepairJob.fromDoc(d)).toList());
  }

  /// Interventions assignées à UN technicien (son tableau de bord).
  /// Cette requête correspond exactement à la règle Firestore : un
  /// technicien ne peut lire que les interventions dont technicianUid = son uid.
  Stream<List<RepairJob>> watchJobsForTechnician(String uid) {
    return _jobs
        .where('technicianUid', isEqualTo: uid)
        .snapshots()
        .map((snap) => snap.docs.map((d) => RepairJob.fromDoc(d)).toList());
  }

  Future<void> addJob(RepairJob job) => _w(_jobs.add(job.toMap()).then((_) {}));

  Future<void> updateJob(RepairJob j) => _w(_jobs.doc(j.id).update({
        'clientId': j.clientId,
        'vehicleId': j.vehicleId,
        'desc': j.desc,
        'tech': j.tech,
        'technicianUid': j.technicianUid,
        'clientName': j.clientName,
        'vehicleLabel': j.vehicleLabel,
      }));

  Future<void> deleteJob(String id) => _w(_jobs.doc(id).delete());

  Future<void> changeJobStatus(String jobId, JobStatus status) =>
      _w(_jobs.doc(jobId).update({'status': RepairJob.statusToString(status)}));

  // ---------------- COMPTES UTILISATEURS (rôles) ----------------
  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');

  /// Profil du compte connecté (null tant qu'il n'existe pas).
  Stream<AppUser?> watchUser(String uid) {
    return _users.doc(uid).snapshots().map((d) => d.exists ? AppUser.fromDoc(d) : null);
  }

  /// Comptes de rôle "technicien" (liste d'assignation des interventions) — admin uniquement.
  Stream<List<AppUser>> watchTechnicianAccounts() {
    return _users.where('role', isEqualTo: 'technicien').snapshots().map((snap) {
      final list = snap.docs.map((d) => AppUser.fromDoc(d)).toList();
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    });
  }

  /// Crée le profil du compte. Pour le rôle admin, le code d'invitation est
  /// vérifié CÔTÉ SERVEUR par les règles Firestore (config/adminInvite) :
  /// un mauvais code => permission-denied. Le code est ensuite retiré du profil.
  Future<void> createUserProfile({
    required String uid,
    required String name,
    required String email,
    String phone = '',
    required UserRole role,
    String adminCode = '',
  }) async {
    final data = <String, dynamic>{
      'name': name,
      'email': email,
      'phone': phone,
      'role': AppUser.roleToString(role),
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (role == UserRole.admin) data['adminCode'] = adminCode;
    await _users.doc(uid).set(data);
    if (role == UserRole.admin) {
      try {
        await _users.doc(uid).update({'adminCode': FieldValue.delete()});
      } catch (_) {/* sans gravité : le code n'est lisible que par son propriétaire et les admins */}
    }
  }

  // ---------------- TECHNICIENS ----------------
  CollectionReference<Map<String, dynamic>> get _technicians => _db.collection('technicians');

  Stream<List<Technician>> watchTechnicians() {
    return _technicians.orderBy('name').snapshots().map(
        (snap) => snap.docs.map((d) => Technician.fromDoc(d)).toList());
  }

  Future<void> addTechnician(Technician t) => _w(_technicians.add(t.toMap()).then((_) {}));

  Future<void> updateTechnician(Technician t) => _w(_technicians.doc(t.id).update(t.toMap()));

  Future<void> deleteTechnician(String id) => _w(_technicians.doc(id).delete());

  // ---------------- CALENDRIER / RENDEZ-VOUS ----------------
  CollectionReference<Map<String, dynamic>> get _appointments => _db.collection('appointments');

  Stream<List<Appointment>> watchAppointments() {
    return _appointments.snapshots().map(
        (snap) => snap.docs.map((d) => Appointment.fromDoc(d)).toList());
  }

  Future<void> addAppointment(Appointment a) => _w(_appointments.add(a.toMap()).then((_) {}));

  Future<void> updateAppointment(Appointment a) => _w(_appointments.doc(a.id).update({
        'clientId': a.clientId,
        'vehicleId': a.vehicleId,
        'technicianId': a.technicianId,
        'date': Timestamp.fromDate(a.date),
        'notes': a.notes,
      }));

  Future<void> deleteAppointment(String id) => _w(_appointments.doc(id).delete());

  Future<void> setAppointmentStatus(String id, AppointmentStatus status) =>
      _w(_appointments.doc(id).update({'status': Appointment.statusToString(status)}));
}
