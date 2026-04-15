import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firestore_collections.dart';
import '../domain/models.dart';

class UserRepository {
  UserRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirestoreCollections.users);

  Future<void> upsertUser(AppUser user) async {
    await _collection
        .doc(user.id)
        .set(user.toFirestore(), SetOptions(merge: true));
  }

  Future<void> deleteUser(String uid) async {
    await _collection.doc(uid).delete();
  }

  Future<AppUser?> fetchUser(String uid) async {
    final snapshot = await _collection.doc(uid).get();
    final data = snapshot.data();
    if (data == null) {
      return null;
    }
    return AppUser.fromFirestore(snapshot.id, data);
  }

  Stream<AppUser?> watchUser(String uid) {
    return _collection.doc(uid).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) {
        return null;
      }
      return AppUser.fromFirestore(snapshot.id, data);
    });
  }

  Stream<List<AppUser>> watchUsers() {
    return _collection
        .orderBy('fullName')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AppUser.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }
}

class CatalogRepository {
  CatalogRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _branches =>
      _firestore.collection(FirestoreCollections.branches);
  CollectionReference<Map<String, dynamic>> get _categories =>
      _firestore.collection(FirestoreCollections.categories);
  CollectionReference<Map<String, dynamic>> get _products =>
      _firestore.collection(FirestoreCollections.products);

  Future<void> upsertBranch(Branch branch) async {
    await _branches
        .doc(branch.id)
        .set(branch.toFirestore(), SetOptions(merge: true));
  }

  Future<void> upsertCategory(Category category) async {
    await _categories
        .doc(category.id)
        .set(category.toFirestore(), SetOptions(merge: true));
  }

  Future<void> upsertProduct(Product product) async {
    await _products
        .doc(product.id)
        .set(product.toFirestore(), SetOptions(merge: true));
  }

  Future<Branch?> fetchBranch(String branchId) async {
    final snapshot = await _branches.doc(branchId).get();
    final data = snapshot.data();
    if (data == null) {
      return null;
    }
    return Branch.fromFirestore(snapshot.id, data);
  }

  Future<Product?> fetchProduct(String productId) async {
    final snapshot = await _products.doc(productId).get();
    final data = snapshot.data();
    if (data == null) {
      return null;
    }
    return Product.fromFirestore(snapshot.id, data);
  }

  Future<List<Branch>> fetchBranches() async {
    final snapshot = await _branches.orderBy('name').get();
    return snapshot.docs
        .map((doc) => Branch.fromFirestore(doc.id, doc.data()))
        .toList(growable: false);
  }

  Future<List<Category>> fetchCategories() async {
    final snapshot = await _categories.orderBy('name').get();
    return snapshot.docs
        .map((doc) => Category.fromFirestore(doc.id, doc.data()))
        .toList(growable: false);
  }

  Future<List<Product>> fetchProducts() async {
    final snapshot = await _products.orderBy('name').get();
    return snapshot.docs
        .map((doc) => Product.fromFirestore(doc.id, doc.data()))
        .toList(growable: false);
  }

  Stream<List<Branch>> watchBranches() {
    return _branches
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Branch.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<Product>> watchProducts() {
    return _products
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Product.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<Category>> watchCategories() {
    return _categories
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Category.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }
}

class InventoryRepository {
  InventoryRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirestoreCollections.inventories);

  String inventoryId(String branchId, String productId) =>
      InventoryItem.inventoryId(branchId, productId);

  Future<void> upsertInventory(InventoryItem inventory) async {
    await _collection
        .doc(inventory.id)
        .set(inventory.toFirestore(), SetOptions(merge: true));
  }

  Future<InventoryItem?> fetchInventory(
    String branchId,
    String productId,
  ) async {
    final snapshot = await _collection
        .doc(inventoryId(branchId, productId))
        .get();
    final data = snapshot.data();
    if (data == null) {
      return null;
    }
    return InventoryItem.fromFirestore(snapshot.id, data);
  }

  Future<List<InventoryItem>> fetchBranchInventory(String branchId) async {
    final snapshot = await _collection
        .where('branchId', isEqualTo: branchId)
        .orderBy('productName')
        .get();
    return snapshot.docs
        .map((doc) => InventoryItem.fromFirestore(doc.id, doc.data()))
        .toList(growable: false);
  }

  Stream<List<InventoryItem>> watchBranchInventory(String branchId) {
    return _collection
        .where('branchId', isEqualTo: branchId)
        .orderBy('productName')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => InventoryItem.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<InventoryItem>> watchLowStock(String branchId) {
    return _collection
        .where('branchId', isEqualTo: branchId)
        .where('isLowStock', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => InventoryItem.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<InventoryItem>> watchProductInventory(String productId) {
    return _collection
        .where('productId', isEqualTo: productId)
        .orderBy('availableStock')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => InventoryItem.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }
}

class ReservationRepository {
  ReservationRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirestoreCollections.reservations);

  Future<Reservation?> fetchReservation(String reservationId) async {
    final snapshot = await _collection.doc(reservationId).get();
    final data = snapshot.data();
    if (data == null) {
      return null;
    }
    return Reservation.fromFirestore(snapshot.id, data);
  }

  Stream<List<Reservation>> watchReservations() {
    return _collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Reservation.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<Reservation>> watchBranchReservations(String branchId) {
    return _collection
        .where('branchId', isEqualTo: branchId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Reservation.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<Reservation>> watchActiveReservations(String branchId) {
    return _collection
        .where('branchId', isEqualTo: branchId)
        .where('status', isEqualTo: ReservationStatus.active.name)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Reservation.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<Reservation?> fetchFirstActiveReservation(String branchId) async {
    final snapshot = await _collection
        .where('branchId', isEqualTo: branchId)
        .where('status', isEqualTo: ReservationStatus.active.name)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    final doc = snapshot.docs.first;
    return Reservation.fromFirestore(doc.id, doc.data());
  }
}

class TransferRepository {
  TransferRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirestoreCollections.transfers);

  Future<TransferRequest?> fetchTransfer(String transferId) async {
    final snapshot = await _collection.doc(transferId).get();
    final data = snapshot.data();
    if (data == null) {
      return null;
    }
    return TransferRequest.fromFirestore(snapshot.id, data);
  }

  Stream<List<TransferRequest>> watchTransfers() {
    return _collection
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TransferRequest.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<TransferRequest>> watchPendingTransfers() {
    return _collection
        .where('status', isEqualTo: TransferStatus.pending.firestoreValue)
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TransferRequest.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<TransferRequest?> fetchFirstByStatus(TransferStatus status) async {
    final snapshot = await _collection
        .where('status', isEqualTo: status.firestoreValue)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    final doc = snapshot.docs.first;
    return TransferRequest.fromFirestore(doc.id, doc.data());
  }
}

class SystemRepository {
  SystemRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _syncLogs =>
      _firestore.collection(FirestoreCollections.syncLogs);
  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection(FirestoreCollections.notifications);
  CollectionReference<Map<String, dynamic>> get _auditLogs =>
      _firestore.collection(FirestoreCollections.auditLogs);
  CollectionReference<Map<String, dynamic>> get _searchHistory =>
      _firestore.collection(FirestoreCollections.searchHistory);
  CollectionReference<Map<String, dynamic>> get _searchFilters =>
      _firestore.collection(FirestoreCollections.searchFilters);

  Future<void> addSyncLog(SyncLog syncLog) async {
    await _syncLogs.doc(syncLog.id).set(syncLog.toFirestore());
  }

  Future<void> addNotification(AppNotification notification) async {
    await _notifications.doc(notification.id).set(notification.toFirestore());
  }

  Future<void> addAuditLog(AuditLog auditLog) async {
    await _auditLogs.doc(auditLog.id).set(auditLog.toFirestore());
  }

  Future<SearchHistoryEntry?> fetchSearchHistory(
    String userId,
    String normalizedQuery,
  ) async {
    final snapshot = await _searchHistory
        .doc(searchHistoryId(userId, normalizedQuery))
        .get();
    final data = snapshot.data();
    if (data == null) {
      return null;
    }
    return SearchHistoryEntry.fromFirestore(snapshot.id, data);
  }

  Future<void> upsertSearchHistory(SearchHistoryEntry entry) async {
    await _searchHistory
        .doc(entry.id)
        .set(entry.toFirestore(), SetOptions(merge: true));
  }

  Future<SavedSearchFilter?> fetchSearchFilter(
    String userId,
    String filterKey,
  ) async {
    final snapshot = await _searchFilters
        .doc(searchFilterId(userId, filterKey))
        .get();
    final data = snapshot.data();
    if (data == null) {
      return null;
    }
    return SavedSearchFilter.fromFirestore(snapshot.id, data);
  }

  Future<void> upsertSearchFilter(SavedSearchFilter entry) async {
    await _searchFilters
        .doc(entry.id)
        .set(entry.toFirestore(), SetOptions(merge: true));
  }

  String searchHistoryId(String userId, String normalizedQuery) {
    final compactQuery = normalizedQuery.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return '${userId}_$compactQuery';
  }

  String searchFilterId(String userId, String filterKey) {
    final compactKey = filterKey.replaceAll(RegExp(r'[^a-z0-9_]+'), '_');
    return '${userId}_$compactKey';
  }

  Stream<List<SyncLog>> watchRecentSyncLogs({int limit = 6}) {
    return _syncLogs
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SyncLog.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<SyncLog>> watchBranchSyncLogs(String branchId, {int limit = 6}) {
    return _syncLogs
        .where('branchId', isEqualTo: branchId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SyncLog.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<AppNotification>> watchNotifications(String userId) {
    return _notifications
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AppNotification.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<AuditLog>> watchRecentAuditLogs({int limit = 8}) {
    return _auditLogs
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AuditLog.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<SearchHistoryEntry>> watchRecentSearchHistory(
    String userId, {
    int limit = 8,
  }) {
    return _searchHistory
        .where('userId', isEqualTo: userId)
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => SearchHistoryEntry.fromFirestore(doc.id, doc.data()),
              )
              .toList(),
        );
  }

  Stream<List<SavedSearchFilter>> watchRecentSearchFilters(
    String userId, {
    int limit = 12,
  }) {
    return _searchFilters
        .where('userId', isEqualTo: userId)
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SavedSearchFilter.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }
}
