import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firestore_collections.dart';
import '../data/repositories.dart';
import '../data/sample_seed_data.dart';
import '../domain/models.dart';
import '../domain/role_permissions.dart';

class DailyTransferRequestMetric {
  const DailyTransferRequestMetric({required this.day, required this.count});

  final DateTime day;
  final int count;
}

class OutOfStockConsultationMetric {
  const OutOfStockConsultationMetric({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.interestScore,
    required this.reservationHits,
    required this.transferHits,
    required this.availableStock,
    required this.lastMovementAt,
  });

  final String productId;
  final String productName;
  final String sku;
  final int interestScore;
  final int reservationHits;
  final int transferHits;
  final int availableStock;
  final DateTime? lastMovementAt;
}

class BranchOperationalStats {
  const BranchOperationalStats({
    required this.lowStockCount,
    required this.outOfStockCount,
    required this.pendingTransfersCount,
    required this.activeReservationsCount,
    required this.transferRequestsToday,
    required this.averageApiResponseTime,
    required this.transferRequestsByDay,
    required this.outOfStockConsultations,
  });

  final int lowStockCount;
  final int outOfStockCount;
  final int pendingTransfersCount;
  final int activeReservationsCount;
  final int transferRequestsToday;
  final Duration averageApiResponseTime;
  final List<DailyTransferRequestMetric> transferRequestsByDay;
  final List<OutOfStockConsultationMetric> outOfStockConsultations;

  int get consultedOutOfStockCount => outOfStockConsultations.length;
}

class ProductSearchResult {
  const ProductSearchResult({
    required this.product,
    required this.inventory,
    required this.relevanceScore,
  });

  final Product product;
  final InventoryItem? inventory;
  final int relevanceScore;

  bool get isOutOfStock => inventory == null || inventory!.availableStock <= 0;
}

class ProductSearchFilterOptions {
  const ProductSearchFilterOptions({
    required this.categories,
    required this.brands,
    required this.branches,
  });

  final List<Category> categories;
  final List<String> brands;
  final List<Branch> branches;
}

class TransferRequestCatalogItem {
  const TransferRequestCatalogItem({
    required this.product,
    required this.currentInventory,
  });

  final Product product;
  final InventoryItem? currentInventory;

  int get currentAvailableStock => currentInventory?.availableStock ?? 0;
  int get incomingStock => currentInventory?.incomingStock ?? 0;
  bool get isOutOfStock => currentAvailableStock <= 0;
  bool get isLowStock => currentInventory?.isLowStock ?? false;
}

enum InventoryDataReliabilityLevel { green, yellow, red }

class InventoryDataReliability {
  const InventoryDataReliability({
    required this.level,
    required this.lastUpdatedAt,
    required this.age,
    required this.message,
    required this.isIncomplete,
  });

  final InventoryDataReliabilityLevel level;
  final DateTime? lastUpdatedAt;
  final Duration? age;
  final String message;
  final bool isIncomplete;

  bool get isExpired => level == InventoryDataReliabilityLevel.red;

  String get statusLabel => switch (level) {
    InventoryDataReliabilityLevel.green => 'Verde',
    InventoryDataReliabilityLevel.yellow => 'Amarillo',
    InventoryDataReliabilityLevel.red =>
      isIncomplete ? 'Rojo incompleto' : 'Rojo vencido',
  };
}

class ProductBranchStockEntry {
  const ProductBranchStockEntry({
    required this.branch,
    required this.inventory,
    required this.lastUpdatedAt,
    required this.reliability,
  });

  final Branch branch;
  final InventoryItem? inventory;
  final DateTime? lastUpdatedAt;
  final InventoryDataReliability reliability;

  int get physicalStock => inventory?.stock ?? 0;
  int get reservedStock => inventory?.reservedStock ?? 0;
  int get availableStock => inventory?.availableStock ?? 0;
  int get inTransitStock => inventory?.incomingStock ?? 0;
  bool get hasInventoryRecord => inventory != null;
  bool get isStale => reliability.isExpired;
}

class ProductBranchSuggestion {
  const ProductBranchSuggestion({
    required this.stockEntry,
    required this.distanceKm,
    required this.estimatedTransferTime,
    required this.priorityScore,
  });

  final ProductBranchStockEntry stockEntry;
  final double distanceKm;
  final Duration estimatedTransferTime;
  final int priorityScore;

  Branch get branch => stockEntry.branch;
  int get availableStock => stockEntry.availableStock;
  String get etaLabel {
    final hours = estimatedTransferTime.inHours;
    final minutes = estimatedTransferTime.inMinutes.remainder(60);
    if (hours == 0) {
      return '${estimatedTransferTime.inMinutes} min';
    }
    return minutes == 0 ? '$hours h' : '$hours h $minutes min';
  }

  String get rationale =>
      '$availableStock uds disponibles | ${distanceKm.toStringAsFixed(1)} km | ETA $etaLabel';
}

class BranchDirectoryEntry {
  const BranchDirectoryEntry({
    required this.branch,
    required this.distanceKm,
    required this.stockEntry,
  });

  final Branch branch;
  final double distanceKm;
  final ProductBranchStockEntry? stockEntry;

  InventoryDataReliability? get reliability => stockEntry?.reliability;
  int get availableStock => stockEntry?.availableStock ?? 0;
  int get reservedStock => stockEntry?.reservedStock ?? 0;
  int get incomingStock => stockEntry?.inTransitStock ?? 0;
  DateTime? get lastUpdatedAt => stockEntry?.lastUpdatedAt;
  bool get hasSelectedProductStock => stockEntry != null;
}

class BranchDirectoryData {
  const BranchDirectoryData({
    required this.entries,
    required this.selectedProduct,
    required this.currentBranch,
    required this.isFromCache,
  });

  final List<BranchDirectoryEntry> entries;
  final Product? selectedProduct;
  final Branch? currentBranch;
  final bool isFromCache;

  List<String> get cities =>
      entries.map((entry) => entry.branch.city).toSet().toList()..sort();

  BranchDirectoryData copyWith({bool? isFromCache}) {
    return BranchDirectoryData(
      entries: entries,
      selectedProduct: selectedProduct,
      currentBranch: currentBranch,
      isFromCache: isFromCache ?? this.isFromCache,
    );
  }
}

class ProductDetailData {
  const ProductDetailData({
    required this.product,
    required this.inventory,
    required this.category,
    required this.branch,
    required this.stockByBranch,
    required this.branchSuggestions,
    required this.recommendedSuggestion,
    required this.reliability,
    required this.isFromCache,
  });

  final Product product;
  final InventoryItem? inventory;
  final Category? category;
  final Branch? branch;
  final List<ProductBranchStockEntry> stockByBranch;
  final List<ProductBranchSuggestion> branchSuggestions;
  final ProductBranchSuggestion? recommendedSuggestion;
  final InventoryDataReliability reliability;
  final bool isFromCache;

  bool get isOutOfStock => inventory == null || inventory!.availableStock <= 0;
  bool get hasStaleStockByBranch => stockByBranch.any((entry) => entry.isStale);
  bool get shouldShowAlternativeSuggestions => isOutOfStock;

  ProductDetailData copyWith({bool? isFromCache}) {
    return ProductDetailData(
      product: product,
      inventory: inventory,
      category: category,
      branch: branch,
      stockByBranch: stockByBranch,
      branchSuggestions: branchSuggestions,
      recommendedSuggestion: recommendedSuggestion,
      reliability: reliability,
      isFromCache: isFromCache ?? this.isFromCache,
    );
  }
}

class InventoryWorkflowService {
  InventoryWorkflowService({
    required FirebaseFirestore firestore,
    DateTime Function()? clock,
  }) : _firestore = firestore,
       _clock = clock ?? DateTime.now,
       users = UserRepository(firestore),
       catalog = CatalogRepository(firestore),
       inventories = InventoryRepository(firestore),
       reservations = ReservationRepository(firestore),
       transfers = TransferRepository(firestore),
       system = SystemRepository(firestore);

  final FirebaseFirestore _firestore;
  final DateTime Function() _clock;

  final UserRepository users;
  final CatalogRepository catalog;
  final InventoryRepository inventories;
  final ReservationRepository reservations;
  final TransferRepository transfers;
  final SystemRepository system;
  final Map<String, ProductDetailData> _productDetailCache =
      <String, ProductDetailData>{};
  final Map<String, List<ProductBranchStockEntry>> _productStockByBranchCache =
      <String, List<ProductBranchStockEntry>>{};
  final Map<String, BranchDirectoryData> _branchDirectoryCache =
      <String, BranchDirectoryData>{};
  List<Branch>? _branchCatalogCache;

  static const Duration _greenDataThreshold = Duration(minutes: 15);
  static const Duration _yellowDataThreshold = Duration(minutes: 30);

  CollectionReference<Map<String, dynamic>> get _inventoriesCollection =>
      _firestore.collection(FirestoreCollections.inventories);
  CollectionReference<Map<String, dynamic>> get _reservationsCollection =>
      _firestore.collection(FirestoreCollections.reservations);
  CollectionReference<Map<String, dynamic>> get _transfersCollection =>
      _firestore.collection(FirestoreCollections.transfers);
  CollectionReference<Map<String, dynamic>> get _notificationsCollection =>
      _firestore.collection(FirestoreCollections.notifications);
  CollectionReference<Map<String, dynamic>> get _auditLogsCollection =>
      _firestore.collection(FirestoreCollections.auditLogs);

  void _invalidateProductCaches([String? productId]) {
    if (productId == null || productId.isEmpty) {
      _productDetailCache.clear();
      _productStockByBranchCache.clear();
      _branchDirectoryCache.clear();
      return;
    }

    _productDetailCache.removeWhere((key, _) => key.endsWith('_$productId'));
    _productStockByBranchCache.removeWhere(
      (key, _) => key.endsWith('_$productId'),
    );
    _branchDirectoryCache.removeWhere((key, _) => key.endsWith('_$productId'));
  }

  void _invalidateBranchCatalogCache() {
    _branchCatalogCache = null;
    _branchDirectoryCache.clear();
  }

  Future<List<Branch>> _fetchBranchCatalog({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _branchCatalogCache;
      if (cached != null) {
        return cached;
      }
    }

    final branches = List<Branch>.unmodifiable(await catalog.fetchBranches());
    _branchCatalogCache = branches;
    return branches;
  }

  DateTime? _resolveInventoryTimestamp(
    InventoryItem? inventory,
    Branch? branch,
  ) {
    return inventory?.lastSyncAt ??
        inventory?.updatedAt ??
        branch?.lastSyncAt ??
        branch?.updatedAt;
  }

  InventoryDataReliability _buildInventoryReliability({
    required InventoryItem? inventory,
    required Branch? branch,
  }) {
    final lastUpdatedAt = _resolveInventoryTimestamp(inventory, branch);
    final age = lastUpdatedAt == null
        ? null
        : _clock().difference(lastUpdatedAt);

    if (inventory == null) {
      return InventoryDataReliability(
        level: InventoryDataReliabilityLevel.red,
        lastUpdatedAt: lastUpdatedAt,
        age: age,
        message: 'No hay inventario consolidado para esta sucursal.',
        isIncomplete: true,
      );
    }

    if (lastUpdatedAt == null) {
      return const InventoryDataReliability(
        level: InventoryDataReliabilityLevel.red,
        lastUpdatedAt: null,
        age: null,
        message: 'El inventario no tiene timestamp de actualizacion.',
        isIncomplete: true,
      );
    }

    final resolvedAge = age!;

    if (resolvedAge <= _greenDataThreshold) {
      return InventoryDataReliability(
        level: InventoryDataReliabilityLevel.green,
        lastUpdatedAt: lastUpdatedAt,
        age: resolvedAge,
        message: 'Dato reciente para informar al cliente con confianza.',
        isIncomplete: false,
      );
    }

    if (resolvedAge <= _yellowDataThreshold) {
      return InventoryDataReliability(
        level: InventoryDataReliabilityLevel.yellow,
        lastUpdatedAt: lastUpdatedAt,
        age: resolvedAge,
        message: 'Dato util, pero conviene confirmarlo pronto.',
        isIncomplete: false,
      );
    }

    return InventoryDataReliability(
      level: InventoryDataReliabilityLevel.red,
      lastUpdatedAt: lastUpdatedAt,
      age: resolvedAge,
      message: 'Dato vencido para comunicar sin validacion adicional.',
      isIncomplete: false,
    );
  }

  double _distanceInKm(BranchLocation origin, BranchLocation destination) {
    const earthRadiusKm = 6371.0;
    final latDelta = _degreesToRadians(destination.lat - origin.lat);
    final lngDelta = _degreesToRadians(destination.lng - origin.lng);
    final originLat = _degreesToRadians(origin.lat);
    final destinationLat = _degreesToRadians(destination.lat);

    final haversine =
        math.sin(latDelta / 2) * math.sin(latDelta / 2) +
        math.cos(originLat) *
            math.cos(destinationLat) *
            math.sin(lngDelta / 2) *
            math.sin(lngDelta / 2);
    final angularDistance =
        2 * math.atan2(math.sqrt(haversine), math.sqrt(1 - haversine));
    return earthRadiusKm * angularDistance;
  }

  double calculateDistanceKm({
    required BranchLocation origin,
    required BranchLocation destination,
  }) {
    return _distanceInKm(origin, destination);
  }

  double _degreesToRadians(double value) => value * (math.pi / 180.0);

  Duration _estimateTransferTime(double distanceKm) {
    final minutes = 25 + (distanceKm / 24 * 60).round();
    return Duration(minutes: math.max(minutes, 25));
  }

  int _recommendationScore({
    required ProductBranchStockEntry entry,
    required double distanceKm,
    required Duration estimatedTransferTime,
  }) {
    final reliabilityPenalty = switch (entry.reliability.level) {
      InventoryDataReliabilityLevel.green => 0,
      InventoryDataReliabilityLevel.yellow => 12,
      InventoryDataReliabilityLevel.red => 30,
    };

    return (entry.availableStock * 18) -
        (distanceKm * 2).round() -
        (estimatedTransferTime.inMinutes / 8).round() -
        reliabilityPenalty;
  }

  List<ProductBranchSuggestion> _buildBranchSuggestions({
    required Branch? currentBranch,
    required String currentBranchId,
    required List<ProductBranchStockEntry> stockByBranch,
  }) {
    final suggestions =
        stockByBranch
            .where(
              (entry) =>
                  entry.branch.id != currentBranchId &&
                  entry.availableStock > 0,
            )
            .map((entry) {
              final distanceKm = currentBranch == null
                  ? 0.0
                  : _distanceInKm(
                      currentBranch.location,
                      entry.branch.location,
                    );
              final estimatedTransferTime = _estimateTransferTime(distanceKm);
              final priorityScore = _recommendationScore(
                entry: entry,
                distanceKm: distanceKm,
                estimatedTransferTime: estimatedTransferTime,
              );

              return ProductBranchSuggestion(
                stockEntry: entry,
                distanceKm: distanceKm,
                estimatedTransferTime: estimatedTransferTime,
                priorityScore: priorityScore,
              );
            })
            .toList(growable: false)
          ..sort((left, right) {
            final score = right.priorityScore.compareTo(left.priorityScore);
            if (score != 0) {
              return score;
            }

            final eta = left.estimatedTransferTime.compareTo(
              right.estimatedTransferTime,
            );
            if (eta != 0) {
              return eta;
            }

            final distance = left.distanceKm.compareTo(right.distanceKm);
            if (distance != 0) {
              return distance;
            }

            return right.availableStock.compareTo(left.availableStock);
          });

    return List<ProductBranchSuggestion>.unmodifiable(suggestions);
  }

  void _ensurePermission(AppUser actorUser, AppPermission permission) {
    if (actorUser.can(permission)) {
      return;
    }

    throw InventoryException(
      'El rol ${actorUser.role.displayName} no tiene permiso para ${permission.label.toLowerCase()}.',
    );
  }

  void _ensureBranchAccess(AppUser actorUser, String branchId) {
    if (actorUser.canAccessBranch(branchId)) {
      return;
    }

    throw const InventoryException(
      'No puedes operar sobre una sucursal diferente a la asignada.',
    );
  }

  AuditLog _buildAuditLog({
    required AppUser actorUser,
    required String action,
    required String entityType,
    required String entityId,
    required String entityLabel,
    required String message,
    Map<String, String> metadata = const {},
    String? branchId,
    String? branchName,
  }) {
    final now = _clock();
    return AuditLog(
      id: _auditLogsCollection.doc().id,
      action: action,
      entityType: entityType,
      entityId: entityId,
      entityLabel: entityLabel,
      actorUserId: actorUser.id,
      actorName: actorUser.fullName,
      actorRole: actorUser.role,
      message: message,
      metadata: metadata,
      createdAt: now,
      branchId: branchId,
      branchName: branchName,
    );
  }

  Future<void> seedMasterData({required AppUser actorUser}) async {
    _ensurePermission(actorUser, AppPermission.seedMasterData);

    final now = _clock();
    final seed = SampleSeedData.build(now);
    final batch = _firestore.batch();
    final auditLog = _buildAuditLog(
      actorUser: actorUser,
      action: 'master_data_seeded',
      entityType: 'system',
      entityId: 'master_data',
      entityLabel: 'Base inicial',
      message: 'Creo o actualizo la base de datos inicial.',
      metadata: {
        'branches': '${seed.branches.length}',
        'products': '${seed.products.length}',
        'users': '${seed.users.length}',
      },
    );

    for (final user in seed.users) {
      batch.set(
        _firestore.collection(FirestoreCollections.users).doc(user.id),
        user.toFirestore(),
        SetOptions(merge: true),
      );
    }

    for (final branch in seed.branches) {
      batch.set(
        _firestore.collection(FirestoreCollections.branches).doc(branch.id),
        branch.toFirestore(),
        SetOptions(merge: true),
      );
    }

    for (final category in seed.categories) {
      batch.set(
        _firestore.collection(FirestoreCollections.categories).doc(category.id),
        category.toFirestore(),
        SetOptions(merge: true),
      );
    }

    for (final product in seed.products) {
      batch.set(
        _firestore.collection(FirestoreCollections.products).doc(product.id),
        product.toFirestore(),
        SetOptions(merge: true),
      );
    }

    for (final inventory in seed.inventories) {
      batch.set(
        _inventoriesCollection.doc(inventory.id),
        inventory.toFirestore(),
        SetOptions(merge: true),
      );
    }

    for (final reservation in seed.reservations) {
      batch.set(
        _reservationsCollection.doc(reservation.id),
        reservation.toFirestore(),
        SetOptions(merge: true),
      );
    }

    for (final transfer in seed.transfers) {
      batch.set(
        _transfersCollection.doc(transfer.id),
        transfer.toFirestore(),
        SetOptions(merge: true),
      );
    }

    for (final syncLog in seed.syncLogs) {
      batch.set(
        _firestore.collection(FirestoreCollections.syncLogs).doc(syncLog.id),
        syncLog.toFirestore(),
        SetOptions(merge: true),
      );
    }

    batch.set(_auditLogsCollection.doc(auditLog.id), auditLog.toFirestore());

    await batch.commit();
    _invalidateProductCaches();
    _invalidateBranchCatalogCache();
  }

  Future<Branch> createBranch({
    required AppUser actorUser,
    required String name,
    required String code,
    required String address,
    required String city,
    String phone = '',
    String email = '',
    String managerName = '',
    String openingHours = '08:00-18:00',
    double latitude = 0,
    double longitude = 0,
  }) async {
    _ensurePermission(actorUser, AppPermission.manageBranches);

    final normalizedCode = _normalizeBranchCode(code);
    final branchId = 'branch_$normalizedCode';
    final existingBranch = await catalog.fetchBranch(branchId);
    if (existingBranch != null) {
      throw InventoryException(
        'Ya existe una sucursal registrada con el codigo $normalizedCode.',
      );
    }

    final now = _clock();
    final branch = Branch(
      id: branchId,
      name: name.trim(),
      code: normalizedCode.toUpperCase(),
      address: address.trim(),
      city: city.trim(),
      phone: phone.trim(),
      email: email.trim(),
      location: BranchLocation(lat: latitude, lng: longitude),
      isActive: true,
      managerName: managerName.trim(),
      openingHours: openingHours.trim(),
      lastSyncAt: null,
      createdAt: now,
      updatedAt: now,
    );
    final auditLog = _buildAuditLog(
      actorUser: actorUser,
      action: 'branch_created',
      entityType: 'branch',
      entityId: branch.id,
      entityLabel: branch.name,
      message: 'Registro una nueva sucursal.',
      metadata: {
        'code': branch.code,
        'city': branch.city,
        'managerName': branch.managerName,
      },
      branchId: branch.id,
      branchName: branch.name,
    );

    final batch = _firestore.batch();
    batch.set(
      _firestore.collection(FirestoreCollections.branches).doc(branch.id),
      branch.toFirestore(),
    );
    batch.set(_auditLogsCollection.doc(auditLog.id), auditLog.toFirestore());
    await batch.commit();
    _invalidateProductCaches();
    _invalidateBranchCatalogCache();

    return branch;
  }

  Future<List<ProductSearchResult>> searchProducts({
    required AppUser actorUser,
    required String branchId,
    required String query,
    ProductSearchFilters filters = const ProductSearchFilters(),
  }) async {
    _ensurePermission(actorUser, AppPermission.viewOwnInventory);
    final normalizedFilters = _normalizeSearchFilters(filters);
    final effectiveBranchId = normalizedFilters.branchId ?? branchId;
    _ensureBranchAccess(actorUser, effectiveBranchId);

    final normalizedQuery = _normalizeSearchQuery(query);
    if (normalizedQuery.isEmpty && normalizedFilters.isEmpty) {
      return const <ProductSearchResult>[];
    }

    final products = await catalog.fetchProducts();
    final branchInventory = await inventories.fetchBranchInventory(
      effectiveBranchId,
    );
    final inventoryByProductId = {
      for (final item in branchInventory) item.productId: item,
    };

    final results =
        products
            .where((product) => product.isActive)
            .map((product) {
              final inventory = inventoryByProductId[product.id];
              if (!_matchesProductFilters(
                product,
                inventory,
                normalizedFilters,
              )) {
                return null;
              }

              final score = normalizedQuery.isEmpty
                  ? 1
                  : _productMatchScore(product, normalizedQuery);
              if (score == 0) {
                return null;
              }

              return ProductSearchResult(
                product: product,
                inventory: inventory,
                relevanceScore: score,
              );
            })
            .whereType<ProductSearchResult>()
            .toList(growable: false)
          ..sort((left, right) {
            final relevanceComparison = right.relevanceScore.compareTo(
              left.relevanceScore,
            );
            if (relevanceComparison != 0) {
              return relevanceComparison;
            }

            final leftStock = left.inventory?.availableStock ?? 0;
            final rightStock = right.inventory?.availableStock ?? 0;
            final stockComparison = rightStock.compareTo(leftStock);
            if (stockComparison != 0) {
              return stockComparison;
            }

            return left.product.name.compareTo(right.product.name);
          });

    return results;
  }

  Future<ProductSearchResult?> findProductByBarcode({
    required AppUser actorUser,
    required String branchId,
    required String barcode,
  }) async {
    _ensurePermission(actorUser, AppPermission.viewOwnInventory);
    _ensureBranchAccess(actorUser, branchId);

    final normalizedBarcode = _normalizeBarcode(barcode);
    if (normalizedBarcode.isEmpty) {
      return null;
    }

    final products = await catalog.fetchProducts();
    final matchedProduct = products.cast<Product?>().firstWhere(
      (product) =>
          product != null &&
          product.isActive &&
          _normalizeBarcode(product.barcode) == normalizedBarcode,
      orElse: () => null,
    );

    if (matchedProduct == null) {
      return null;
    }

    final inventory = await inventories.fetchInventory(
      branchId,
      matchedProduct.id,
    );

    return ProductSearchResult(
      product: matchedProduct,
      inventory: inventory,
      relevanceScore: 999,
    );
  }

  Future<ProductDetailData> fetchProductDetail({
    required AppUser actorUser,
    required String branchId,
    required String productId,
    bool forceRefresh = false,
  }) async {
    _ensurePermission(actorUser, AppPermission.viewOwnInventory);
    _ensureBranchAccess(actorUser, branchId);

    final cacheKey = '${branchId}_$productId';
    if (!forceRefresh) {
      final cached = _productDetailCache[cacheKey];
      if (cached != null) {
        return cached.copyWith(isFromCache: true);
      }
    }

    final product = await catalog.fetchProduct(productId);
    if (product == null || !product.isActive) {
      throw const InventoryException(
        'No se encontro el producto solicitado en el catalogo.',
      );
    }

    final branch = await catalog.fetchBranch(branchId);
    final inventory = await inventories.fetchInventory(branchId, product.id);
    final category = product.categoryId.isEmpty
        ? null
        : await catalog.fetchCategory(product.categoryId);
    final stockByBranch = await fetchProductStockByBranch(
      actorUser: actorUser,
      productId: product.id,
      forceRefresh: forceRefresh,
    );
    final branchSuggestions = _buildBranchSuggestions(
      currentBranch: branch,
      currentBranchId: branchId,
      stockByBranch: stockByBranch,
    );
    final reliability = _buildInventoryReliability(
      inventory: inventory,
      branch: branch,
    );

    final detail = ProductDetailData(
      product: product,
      inventory: inventory,
      category: category,
      branch: branch,
      stockByBranch: stockByBranch,
      branchSuggestions: branchSuggestions,
      recommendedSuggestion: branchSuggestions.isEmpty
          ? null
          : branchSuggestions.first,
      reliability: reliability,
      isFromCache: false,
    );
    _productDetailCache[cacheKey] = detail;
    return detail;
  }

  Future<List<ProductBranchStockEntry>> fetchProductStockByBranch({
    required AppUser actorUser,
    required String productId,
    bool forceRefresh = false,
  }) async {
    _ensurePermission(actorUser, AppPermission.viewStockByBranch);

    final cacheKey = '${actorUser.id}_$productId';
    if (!forceRefresh) {
      final cached = _productStockByBranchCache[cacheKey];
      if (cached != null) {
        return cached;
      }
    }

    final product = await catalog.fetchProduct(productId);
    if (product == null || !product.isActive) {
      throw const InventoryException(
        'No se encontro el producto solicitado en el catalogo.',
      );
    }

    final branches = await _fetchBranchCatalog(forceRefresh: forceRefresh);
    final productInventories = await inventories.fetchProductInventory(
      productId,
    );
    final inventoryByBranchId = {
      for (final item in productInventories.where((item) => item.isActive))
        item.branchId: item,
    };

    final stockByBranch =
        branches
            .where((branch) => branch.isActive)
            .map((branch) {
              final inventory = inventoryByBranchId[branch.id];
              final lastUpdatedAt = _resolveInventoryTimestamp(
                inventory,
                branch,
              );
              final reliability = _buildInventoryReliability(
                inventory: inventory,
                branch: branch,
              );

              return ProductBranchStockEntry(
                branch: branch,
                inventory: inventory,
                lastUpdatedAt: lastUpdatedAt,
                reliability: reliability,
              );
            })
            .toList(growable: false)
          ..sort((left, right) {
            final availability = right.availableStock.compareTo(
              left.availableStock,
            );
            if (availability != 0) {
              return availability;
            }

            final inTransit = right.inTransitStock.compareTo(
              left.inTransitStock,
            );
            if (inTransit != 0) {
              return inTransit;
            }

            return left.branch.name.compareTo(right.branch.name);
          });

    final immutableStockByBranch = List<ProductBranchStockEntry>.unmodifiable(
      stockByBranch,
    );
    _productStockByBranchCache[cacheKey] = immutableStockByBranch;
    return immutableStockByBranch;
  }

  Future<BranchDirectoryData> fetchBranchDirectory({
    required AppUser actorUser,
    String? productId,
    bool forceRefresh = false,
  }) async {
    _ensurePermission(actorUser, AppPermission.viewOwnInventory);

    final normalizedProductId = productId?.trim();
    final cacheKey = '${actorUser.id}_${normalizedProductId ?? 'catalog'}';
    if (!forceRefresh) {
      final cached = _branchDirectoryCache[cacheKey];
      if (cached != null) {
        return cached.copyWith(isFromCache: true);
      }
    }

    final branches = await _fetchBranchCatalog(forceRefresh: forceRefresh);
    final currentBranch = branches.cast<Branch?>().firstWhere(
      (branch) => branch?.id == actorUser.branchId,
      orElse: () => null,
    );

    Product? selectedProduct;
    Map<String, ProductBranchStockEntry> stockByBranchId =
        const <String, ProductBranchStockEntry>{};

    if (normalizedProductId != null && normalizedProductId.isNotEmpty) {
      selectedProduct = await catalog.fetchProduct(normalizedProductId);
      if (selectedProduct == null || !selectedProduct.isActive) {
        throw const InventoryException(
          'No se encontro el producto solicitado en el catalogo.',
        );
      }

      final stockByBranch = await fetchProductStockByBranch(
        actorUser: actorUser,
        productId: normalizedProductId,
        forceRefresh: forceRefresh,
      );
      stockByBranchId = {
        for (final entry in stockByBranch) entry.branch.id: entry,
      };
    }

    final entries =
        branches
            .where((branch) => branch.isActive)
            .map(
              (branch) => BranchDirectoryEntry(
                branch: branch,
                distanceKm: currentBranch == null
                    ? 0
                    : _distanceInKm(currentBranch.location, branch.location),
                stockEntry: stockByBranchId[branch.id],
              ),
            )
            .toList(growable: false)
          ..sort((left, right) {
            if (selectedProduct != null) {
              final availability = right.availableStock.compareTo(
                left.availableStock,
              );
              if (availability != 0) {
                return availability;
              }
            }

            final distance = left.distanceKm.compareTo(right.distanceKm);
            if (distance != 0) {
              return distance;
            }

            return left.branch.name.compareTo(right.branch.name);
          });

    final directory = BranchDirectoryData(
      entries: List<BranchDirectoryEntry>.unmodifiable(entries),
      selectedProduct: selectedProduct,
      currentBranch: currentBranch,
      isFromCache: false,
    );
    _branchDirectoryCache[cacheKey] = directory;
    return directory;
  }

  Future<ProductSearchFilterOptions> fetchSearchFilterOptions({
    required AppUser actorUser,
  }) async {
    _ensurePermission(actorUser, AppPermission.viewOwnInventory);

    final branches = await catalog.fetchBranches();
    final categories = await catalog.fetchCategories();
    final products = await catalog.fetchProducts();

    final visibleBranches = branches
        .where(
          (branch) => branch.isActive && actorUser.canAccessBranch(branch.id),
        )
        .toList(growable: false);
    final visibleCategories = categories
        .where((category) => category.isActive)
        .toList(growable: false);
    final brandLabels = <String, String>{};
    for (final product in products) {
      if (!product.isActive) {
        continue;
      }
      final brand = product.brand.trim();
      if (brand.isEmpty) {
        continue;
      }
      brandLabels.putIfAbsent(brand.toLowerCase(), () => brand);
    }
    final brands = brandLabels.values.toList(growable: false)..sort();

    return ProductSearchFilterOptions(
      categories: visibleCategories,
      brands: brands,
      branches: visibleBranches,
    );
  }

  Future<List<TransferRequestCatalogItem>> fetchTransferRequestCatalog({
    required AppUser actorUser,
  }) async {
    _ensurePermission(actorUser, AppPermission.requestTransfer);

    final products = await catalog.fetchProducts();
    final branchInventory = await inventories.fetchBranchInventory(
      actorUser.branchId,
    );
    final inventoryByProductId = {
      for (final item in branchInventory.where((item) => item.isActive))
        item.productId: item,
    };

    final items =
        products
            .where((product) => product.isActive)
            .map(
              (product) => TransferRequestCatalogItem(
                product: product,
                currentInventory: inventoryByProductId[product.id],
              ),
            )
            .toList(growable: false)
          ..sort((left, right) {
            final stockComparison = left.currentAvailableStock.compareTo(
              right.currentAvailableStock,
            );
            if (stockComparison != 0) {
              return stockComparison;
            }

            final incomingComparison = left.incomingStock.compareTo(
              right.incomingStock,
            );
            if (incomingComparison != 0) {
              return incomingComparison;
            }

            return left.product.name.compareTo(right.product.name);
          });

    return List<TransferRequestCatalogItem>.unmodifiable(items);
  }

  Stream<List<SearchHistoryEntry>> watchRecentSearches({
    required AppUser actorUser,
    int limit = 8,
  }) {
    _ensurePermission(actorUser, AppPermission.viewOwnInventory);
    return system.watchRecentSearchHistory(actorUser.id, limit: limit);
  }

  Future<void> saveRecentSearch({
    required AppUser actorUser,
    required String query,
  }) async {
    _ensurePermission(actorUser, AppPermission.viewOwnInventory);

    final normalizedQuery = _normalizeSearchQuery(query);
    if (normalizedQuery.isEmpty) {
      return;
    }

    final existing = await system.fetchSearchHistory(
      actorUser.id,
      normalizedQuery,
    );
    final now = _clock();
    final entry = SearchHistoryEntry(
      id: system.searchHistoryId(actorUser.id, normalizedQuery),
      userId: actorUser.id,
      query: query.trim(),
      normalizedQuery: normalizedQuery,
      hitCount: (existing?.hitCount ?? 0) + 1,
      updatedAt: now,
    );

    await system.upsertSearchHistory(entry);
  }

  Stream<List<SavedSearchFilter>> watchRecentSearchFilters({
    required AppUser actorUser,
    int limit = 12,
  }) {
    _ensurePermission(actorUser, AppPermission.viewOwnInventory);
    return system.watchRecentSearchFilters(actorUser.id, limit: limit);
  }

  Future<void> saveSearchFilter({
    required AppUser actorUser,
    required ProductSearchFilters filters,
    required String label,
    bool favorite = false,
  }) async {
    _ensurePermission(actorUser, AppPermission.viewOwnInventory);

    final normalizedFilters = _normalizeSearchFilters(filters);
    if (normalizedFilters.isEmpty) {
      return;
    }
    if (normalizedFilters.branchId != null) {
      _ensureBranchAccess(actorUser, normalizedFilters.branchId!);
    }

    final normalizedLabel = label.trim();
    final filterKey = _filterKey(normalizedFilters);
    final existing = await system.fetchSearchFilter(actorUser.id, filterKey);
    final now = _clock();
    final effectiveLabel = existing?.isFavorite == true && !favorite
        ? existing!.label
        : normalizedLabel.isEmpty
        ? (existing?.label ?? 'Filtro guardado')
        : normalizedLabel;
    final entry = SavedSearchFilter(
      id: system.searchFilterId(actorUser.id, filterKey),
      userId: actorUser.id,
      label: effectiveLabel,
      filters: normalizedFilters,
      isFavorite: favorite || (existing?.isFavorite ?? false),
      usageCount: (existing?.usageCount ?? 0) + 1,
      updatedAt: now,
    );

    await system.upsertSearchFilter(entry);
  }

  Stream<BranchOperationalStats> watchOperationalStats({
    required AppUser actorUser,
    required String branchId,
  }) {
    _ensurePermission(actorUser, AppPermission.viewOperationalMetrics);
    _ensureBranchAccess(actorUser, branchId);

    final controller = StreamController<BranchOperationalStats>();
    var inventoriesState = const <InventoryItem>[];
    var reservationsState = const <Reservation>[];
    var transfersState = const <TransferRequest>[];
    var syncLogsState = const <SyncLog>[];
    var inventoriesReady = false;
    var reservationsReady = false;
    var transfersReady = false;
    var syncLogsReady = false;
    var subscriptions = <StreamSubscription<Object?>>[];

    void emit() {
      if (controller.isClosed) {
        return;
      }
      if (!inventoriesReady ||
          !reservationsReady ||
          !transfersReady ||
          !syncLogsReady) {
        return;
      }
      controller.add(
        _buildOperationalStats(
          inventories: inventoriesState,
          reservations: reservationsState,
          transfers: transfersState,
          syncLogs: syncLogsState,
          branchId: branchId,
        ),
      );
    }

    controller.onListen = () {
      if (subscriptions.isNotEmpty) {
        return;
      }

      subscriptions = <StreamSubscription<Object?>>[
        inventories.watchBranchInventory(branchId).listen((items) {
          inventoriesState = items;
          inventoriesReady = true;
          emit();
        }, onError: controller.addError),
        reservations.watchBranchReservations(branchId).listen((items) {
          reservationsState = items;
          reservationsReady = true;
          emit();
        }, onError: controller.addError),
        transfers.watchTransfers().listen((items) {
          transfersState = items;
          transfersReady = true;
          emit();
        }, onError: controller.addError),
        system.watchBranchSyncLogs(branchId, limit: 30).listen((items) {
          syncLogsState = items;
          syncLogsReady = true;
          emit();
        }, onError: controller.addError),
      ];
    };

    controller.onCancel = () async {
      final currentSubscriptions = subscriptions;
      subscriptions = <StreamSubscription<Object?>>[];
      for (final subscription in currentSubscriptions) {
        await subscription.cancel();
      }
    };

    return controller.stream;
  }

  Future<InventoryItem> setInventoryStock({
    required AppUser actorUser,
    required String branchId,
    required String productId,
    required int stock,
    int? minimumStock,
  }) async {
    _ensurePermission(actorUser, AppPermission.manageInventory);
    _ensureBranchAccess(actorUser, branchId);

    final now = _clock();
    final inventoryRef = _inventoriesCollection.doc(
      inventories.inventoryId(branchId, productId),
    );

    final updatedInventory = await _firestore.runTransaction((
      transaction,
    ) async {
      final inventorySnapshot = await transaction.get(inventoryRef);
      if (!inventorySnapshot.exists) {
        throw const InventoryException(
          'El inventario no existe para la sucursal y producto indicados.',
        );
      }

      final inventory = InventoryItem.fromFirestore(
        inventorySnapshot.id,
        inventorySnapshot.data()!,
      );
      final updatedInventory = inventory.recalculate(
        stock: stock,
        minimumStock: minimumStock,
        updatedBy: actorUser.id,
        updatedAt: now,
        lastMovementAt: now,
      );

      transaction.set(inventoryRef, updatedInventory.toFirestore());
      return updatedInventory;
    });
    _invalidateProductCaches(productId);
    return updatedInventory;
  }

  Future<Reservation> createReservation({
    required AppUser actorUser,
    required String branchId,
    required String productId,
    required String customerName,
    required String customerPhone,
    required int quantity,
    required Duration expiresIn,
  }) async {
    _ensurePermission(actorUser, AppPermission.createReservation);
    _ensureBranchAccess(actorUser, branchId);

    if (quantity <= 0) {
      throw const InventoryException(
        'La cantidad reservada debe ser mayor que cero.',
      );
    }

    final now = _clock();
    final expiresAt = now.add(expiresIn);
    final inventoryRef = _inventoriesCollection.doc(
      inventories.inventoryId(branchId, productId),
    );
    final reservationRef = _reservationsCollection.doc();

    final reservation = await _firestore.runTransaction((transaction) async {
      final inventorySnapshot = await transaction.get(inventoryRef);
      if (!inventorySnapshot.exists) {
        throw const InventoryException(
          'No existe inventario para la sucursal y producto indicados.',
        );
      }

      final inventory = InventoryItem.fromFirestore(
        inventorySnapshot.id,
        inventorySnapshot.data()!,
      );

      if (!inventory.isActive) {
        throw const InventoryException('El inventario se encuentra inactivo.');
      }

      if (inventory.availableStock < quantity) {
        throw InventoryException(
          'Stock insuficiente. Disponible: ${inventory.availableStock}, solicitado: $quantity.',
        );
      }

      final updatedInventory = inventory.recalculate(
        reservedStock: inventory.reservedStock + quantity,
        updatedBy: actorUser.id,
        updatedAt: now,
        lastMovementAt: now,
      );

      final reservation = Reservation(
        id: reservationRef.id,
        productId: inventory.productId,
        productName: inventory.productName,
        sku: inventory.sku,
        branchId: inventory.branchId,
        branchName: inventory.branchName,
        customerName: customerName,
        customerPhone: customerPhone,
        quantity: quantity,
        status: ReservationStatus.active,
        reservedBy: actorUser.id,
        expiresAt: expiresAt,
        createdAt: now,
        updatedAt: now,
      );

      transaction.set(inventoryRef, updatedInventory.toFirestore());
      transaction.set(reservationRef, reservation.toFirestore());

      return reservation;
    });
    _invalidateProductCaches(productId);
    return reservation;
  }

  Future<Reservation> updateReservationStatus({
    required AppUser actorUser,
    required String reservationId,
    required ReservationStatus nextStatus,
  }) async {
    _ensurePermission(actorUser, AppPermission.updateReservation);

    if (nextStatus == ReservationStatus.active) {
      throw const InventoryException('La reserva ya se crea en estado activo.');
    }

    final now = _clock();
    final reservationRef = _reservationsCollection.doc(reservationId);

    final updatedReservation = await _firestore.runTransaction((
      transaction,
    ) async {
      final reservationSnapshot = await transaction.get(reservationRef);
      if (!reservationSnapshot.exists) {
        throw const InventoryException('La reserva no existe.');
      }

      final reservation = Reservation.fromFirestore(
        reservationSnapshot.id,
        reservationSnapshot.data()!,
      );
      _ensureBranchAccess(actorUser, reservation.branchId);

      if (reservation.status != ReservationStatus.active) {
        throw InventoryException(
          'Solo se pueden cerrar reservas activas. Estado actual: ${reservation.status.name}.',
        );
      }

      final inventoryRef = _inventoriesCollection.doc(
        inventories.inventoryId(reservation.branchId, reservation.productId),
      );
      final inventorySnapshot = await transaction.get(inventoryRef);
      if (!inventorySnapshot.exists) {
        throw const InventoryException(
          'El inventario vinculado a la reserva no existe.',
        );
      }

      final inventory = InventoryItem.fromFirestore(
        inventorySnapshot.id,
        inventorySnapshot.data()!,
      );
      final updatedReservedStock =
          inventory.reservedStock - reservation.quantity;
      if (updatedReservedStock < 0) {
        throw const InventoryException(
          'La reserva no puede liberar mas stock del que esta reservado.',
        );
      }

      final updatedInventory = inventory.recalculate(
        reservedStock: updatedReservedStock,
        updatedBy: actorUser.id,
        updatedAt: now,
        lastMovementAt: now,
      );
      final updatedReservation = reservation.copyWith(
        status: nextStatus,
        updatedAt: now,
      );

      transaction.set(inventoryRef, updatedInventory.toFirestore());
      transaction.set(reservationRef, updatedReservation.toFirestore());

      return updatedReservation;
    });
    _invalidateProductCaches(updatedReservation.productId);
    return updatedReservation;
  }

  Future<TransferRequest> requestTransfer({
    required AppUser actorUser,
    required String productId,
    required String fromBranchId,
    required String toBranchId,
    required int quantity,
    required String reason,
    String notes = '',
  }) async {
    _ensurePermission(actorUser, AppPermission.requestTransfer);
    _ensureBranchAccess(actorUser, toBranchId);

    if (quantity <= 0) {
      throw const InventoryException(
        'La cantidad del traslado debe ser mayor que cero.',
      );
    }
    if (fromBranchId == toBranchId) {
      throw const InventoryException(
        'El origen y destino del traslado no pueden ser iguales.',
      );
    }

    final normalizedReason = reason.trim();
    if (normalizedReason.isEmpty) {
      throw const InventoryException(
        'Debes indicar el motivo de la solicitud de traslado.',
      );
    }

    final product = await catalog.fetchProduct(productId);
    final sourceBranch = await catalog.fetchBranch(fromBranchId);
    final destinationBranch = await catalog.fetchBranch(toBranchId);

    if (product == null || sourceBranch == null || destinationBranch == null) {
      throw const InventoryException(
        'No se encontro el producto o alguna de las sucursales del traslado.',
      );
    }

    final sourceInventory = await inventories.fetchInventory(
      fromBranchId,
      productId,
    );
    if (sourceInventory == null || !sourceInventory.isActive) {
      throw const InventoryException(
        'La sucursal origen no tiene inventario activo para este producto.',
      );
    }
    if (sourceInventory.availableStock < quantity) {
      throw InventoryException(
        'Stock insuficiente en ${sourceBranch.name}. Disponible: ${sourceInventory.availableStock}.',
      );
    }

    final now = _clock();
    final transferRef = _transfersCollection.doc();
    final transfer = TransferRequest(
      id: transferRef.id,
      productId: product.id,
      productName: product.name,
      sku: product.sku,
      fromBranchId: sourceBranch.id,
      fromBranchName: sourceBranch.name,
      toBranchId: destinationBranch.id,
      toBranchName: destinationBranch.name,
      requestedBy: actorUser.id,
      approvedBy: null,
      quantity: quantity,
      status: TransferStatus.pending,
      reason: normalizedReason,
      notes: notes.trim(),
      requestedAt: now,
      approvedAt: null,
      shippedAt: null,
      receivedAt: null,
      updatedAt: now,
    );

    await transferRef.set(transfer.toFirestore());
    _invalidateProductCaches(product.id);
    return transfer;
  }

  Future<TransferRequest> approveTransfer({
    required AppUser actorUser,
    required String transferId,
  }) async {
    _ensurePermission(actorUser, AppPermission.approveTransfer);

    final now = _clock();
    final transferRef = _transfersCollection.doc(transferId);
    final notificationRef = _notificationsCollection.doc();

    final updatedTransfer = await _firestore.runTransaction((
      transaction,
    ) async {
      final transferSnapshot = await transaction.get(transferRef);
      if (!transferSnapshot.exists) {
        throw const InventoryException('El traslado no existe.');
      }

      final transfer = TransferRequest.fromFirestore(
        transferSnapshot.id,
        transferSnapshot.data()!,
      );
      _ensureBranchAccess(actorUser, transfer.fromBranchId);

      if (transfer.status != TransferStatus.pending) {
        throw InventoryException(
          'Solo se pueden aprobar traslados pendientes. Estado: ${transfer.status.firestoreValue}.',
        );
      }

      final sourceInventoryRef = _inventoriesCollection.doc(
        inventories.inventoryId(transfer.fromBranchId, transfer.productId),
      );
      final destinationInventoryRef = _inventoriesCollection.doc(
        inventories.inventoryId(transfer.toBranchId, transfer.productId),
      );

      final sourceInventorySnapshot = await transaction.get(sourceInventoryRef);
      if (!sourceInventorySnapshot.exists) {
        throw const InventoryException(
          'No existe inventario origen para este traslado.',
        );
      }

      final sourceInventory = InventoryItem.fromFirestore(
        sourceInventorySnapshot.id,
        sourceInventorySnapshot.data()!,
      );
      if (sourceInventory.availableStock < transfer.quantity) {
        throw InventoryException(
          'Stock insuficiente para aprobar el traslado. Disponible: ${sourceInventory.availableStock}.',
        );
      }

      final destinationInventorySnapshot = await transaction.get(
        destinationInventoryRef,
      );
      final destinationInventory = destinationInventorySnapshot.exists
          ? InventoryItem.fromFirestore(
              destinationInventorySnapshot.id,
              destinationInventorySnapshot.data()!,
            )
          : InventoryItem.create(
              branchId: transfer.toBranchId,
              branchName: transfer.toBranchName,
              productId: transfer.productId,
              productName: transfer.productName,
              sku: transfer.sku,
              stock: 0,
              reservedStock: 0,
              incomingStock: 0,
              minimumStock: 0,
              updatedBy: actorUser.id,
              isActive: true,
              updatedAt: now,
              lastMovementAt: now,
            );

      final updatedSourceInventory = sourceInventory.recalculate(
        stock: sourceInventory.stock - transfer.quantity,
        updatedBy: actorUser.id,
        updatedAt: now,
        lastMovementAt: now,
      );
      final updatedDestinationInventory = destinationInventory.recalculate(
        incomingStock: destinationInventory.incomingStock + transfer.quantity,
        updatedBy: actorUser.id,
        updatedAt: now,
        lastMovementAt: now,
      );
      final updatedTransfer = transfer.copyWith(
        status: TransferStatus.approved,
        approvedBy: actorUser.id,
        approvedAt: now,
        updatedAt: now,
      );

      final notification = AppNotification(
        id: notificationRef.id,
        userId: transfer.requestedBy,
        title: 'Solicitud aprobada',
        message:
            'El traslado ${transfer.id} fue aprobado y quedo listo para despacho.',
        type: 'transfer',
        referenceId: transfer.id,
        isRead: false,
        createdAt: now,
      );

      transaction.set(sourceInventoryRef, updatedSourceInventory.toFirestore());
      transaction.set(
        destinationInventoryRef,
        updatedDestinationInventory.toFirestore(),
        SetOptions(merge: true),
      );
      transaction.set(transferRef, updatedTransfer.toFirestore());
      transaction.set(notificationRef, notification.toFirestore());

      return updatedTransfer;
    });
    _invalidateProductCaches(updatedTransfer.productId);
    return updatedTransfer;
  }

  Future<TransferRequest> markTransferInTransit({
    required AppUser actorUser,
    required String transferId,
  }) async {
    _ensurePermission(actorUser, AppPermission.dispatchTransfer);

    final now = _clock();
    final transferRef = _transfersCollection.doc(transferId);

    final updatedTransfer = await _firestore.runTransaction((
      transaction,
    ) async {
      final transferSnapshot = await transaction.get(transferRef);
      if (!transferSnapshot.exists) {
        throw const InventoryException('El traslado no existe.');
      }

      final transfer = TransferRequest.fromFirestore(
        transferSnapshot.id,
        transferSnapshot.data()!,
      );
      _ensureBranchAccess(actorUser, transfer.fromBranchId);

      if (transfer.status != TransferStatus.approved) {
        throw InventoryException(
          'Solo se puede despachar un traslado aprobado. Estado: ${transfer.status.firestoreValue}.',
        );
      }

      final updatedTransfer = transfer.copyWith(
        status: TransferStatus.inTransit,
        shippedAt: now,
        updatedAt: now,
        approvedBy: transfer.approvedBy ?? actorUser.id,
      );

      transaction.set(transferRef, updatedTransfer.toFirestore());
      return updatedTransfer;
    });
    _invalidateProductCaches(updatedTransfer.productId);
    return updatedTransfer;
  }

  Future<TransferRequest> receiveTransfer({
    required AppUser actorUser,
    required String transferId,
  }) async {
    _ensurePermission(actorUser, AppPermission.receiveTransfer);

    final now = _clock();
    final transferRef = _transfersCollection.doc(transferId);
    final notificationRef = _notificationsCollection.doc();

    final updatedTransfer = await _firestore.runTransaction((
      transaction,
    ) async {
      final transferSnapshot = await transaction.get(transferRef);
      if (!transferSnapshot.exists) {
        throw const InventoryException('El traslado no existe.');
      }

      final transfer = TransferRequest.fromFirestore(
        transferSnapshot.id,
        transferSnapshot.data()!,
      );
      _ensureBranchAccess(actorUser, transfer.toBranchId);

      if (transfer.status != TransferStatus.inTransit) {
        throw InventoryException(
          'Solo se puede recibir un traslado en transito. Estado: ${transfer.status.firestoreValue}.',
        );
      }

      final destinationInventoryRef = _inventoriesCollection.doc(
        inventories.inventoryId(transfer.toBranchId, transfer.productId),
      );
      final destinationInventorySnapshot = await transaction.get(
        destinationInventoryRef,
      );
      if (!destinationInventorySnapshot.exists) {
        throw const InventoryException(
          'No existe inventario destino para recibir el traslado.',
        );
      }

      final destinationInventory = InventoryItem.fromFirestore(
        destinationInventorySnapshot.id,
        destinationInventorySnapshot.data()!,
      );

      if (destinationInventory.incomingStock < transfer.quantity) {
        throw const InventoryException(
          'El inventario destino no tiene stock en camino suficiente para recibir.',
        );
      }

      final updatedDestinationInventory = destinationInventory.recalculate(
        stock: destinationInventory.stock + transfer.quantity,
        incomingStock: destinationInventory.incomingStock - transfer.quantity,
        updatedBy: actorUser.id,
        updatedAt: now,
        lastMovementAt: now,
      );
      final updatedTransfer = transfer.copyWith(
        status: TransferStatus.received,
        receivedAt: now,
        updatedAt: now,
      );

      final notification = AppNotification(
        id: notificationRef.id,
        userId: transfer.requestedBy,
        title: 'Traslado recibido',
        message:
            'El traslado ${transfer.id} fue recibido en ${transfer.toBranchName}.',
        type: 'transfer',
        referenceId: transfer.id,
        isRead: false,
        createdAt: now,
      );

      transaction.set(
        destinationInventoryRef,
        updatedDestinationInventory.toFirestore(),
      );
      transaction.set(transferRef, updatedTransfer.toFirestore());
      transaction.set(notificationRef, notification.toFirestore());

      return updatedTransfer;
    });
    _invalidateProductCaches(updatedTransfer.productId);
    return updatedTransfer;
  }

  String _normalizeBranchCode(String value) {
    final normalized = value.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '_',
    );
    final compact = normalized.replaceAll(RegExp(r'^_+|_+$'), '');
    if (compact.isEmpty) {
      throw const InventoryException(
        'El codigo de la sucursal debe incluir letras o numeros.',
      );
    }
    return compact;
  }

  BranchOperationalStats _buildOperationalStats({
    required List<InventoryItem> inventories,
    required List<Reservation> reservations,
    required List<TransferRequest> transfers,
    required List<SyncLog> syncLogs,
    required String branchId,
  }) {
    final lowStockCount = inventories
        .where((item) => item.isLowStock && item.availableStock > 0)
        .length;
    final outOfStockCount = inventories
        .where((item) => item.availableStock <= 0)
        .length;
    final activeReservationsCount = reservations
        .where((item) => item.status == ReservationStatus.active)
        .length;
    final branchTransfers = transfers
        .where((item) => _isTransferForBranch(item, branchId))
        .toList(growable: false);
    final pendingTransfersCount = branchTransfers
        .where((item) => item.status == TransferStatus.pending)
        .length;

    final transferRequestsByDay = _buildTransferRequestsByDay(branchTransfers);
    final transferRequestsToday = transferRequestsByDay.isEmpty
        ? 0
        : transferRequestsByDay.last.count;

    return BranchOperationalStats(
      lowStockCount: lowStockCount,
      outOfStockCount: outOfStockCount,
      pendingTransfersCount: pendingTransfersCount,
      activeReservationsCount: activeReservationsCount,
      transferRequestsToday: transferRequestsToday,
      averageApiResponseTime: _averageApiResponseTime(syncLogs),
      transferRequestsByDay: transferRequestsByDay,
      outOfStockConsultations: _buildOutOfStockConsultations(
        inventories: inventories,
        reservations: reservations,
        transfers: branchTransfers,
      ),
    );
  }

  List<DailyTransferRequestMetric> _buildTransferRequestsByDay(
    List<TransferRequest> transfers,
  ) {
    final now = _clock();
    final startDay = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 4));
    final counts = <DateTime, int>{};

    for (var index = 0; index < 5; index++) {
      final day = startDay.add(Duration(days: index));
      counts[DateTime(day.year, day.month, day.day)] = 0;
    }

    for (final transfer in transfers) {
      final requestedDay = DateTime(
        transfer.requestedAt.year,
        transfer.requestedAt.month,
        transfer.requestedAt.day,
      );
      if (requestedDay.isBefore(startDay)) {
        continue;
      }
      counts.update(requestedDay, (value) => value + 1, ifAbsent: () => 1);
    }

    final days = counts.keys.toList(growable: false)..sort();
    return days
        .map(
          (day) =>
              DailyTransferRequestMetric(day: day, count: counts[day] ?? 0),
        )
        .toList(growable: false);
  }

  Duration _averageApiResponseTime(List<SyncLog> syncLogs) {
    if (syncLogs.isEmpty) {
      return Duration.zero;
    }

    var totalMilliseconds = 0;
    for (final log in syncLogs) {
      totalMilliseconds += log.finishedAt
          .difference(log.startedAt)
          .inMilliseconds;
    }

    return Duration(
      milliseconds: (totalMilliseconds / syncLogs.length).round(),
    );
  }

  List<OutOfStockConsultationMetric> _buildOutOfStockConsultations({
    required List<InventoryItem> inventories,
    required List<Reservation> reservations,
    required List<TransferRequest> transfers,
  }) {
    final reservationHits = <String, int>{};
    for (final reservation in reservations) {
      if (reservation.status != ReservationStatus.active) {
        continue;
      }
      reservationHits.update(
        reservation.productId,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    final transferHits = <String, int>{};
    for (final transfer in transfers) {
      if (transfer.status == TransferStatus.rejected ||
          transfer.status == TransferStatus.cancelled) {
        continue;
      }
      transferHits.update(
        transfer.productId,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    final ranked =
        inventories
            .where((item) => item.availableStock <= 0)
            .map((inventory) {
              final reservationsForProduct =
                  reservationHits[inventory.productId] ?? 0;
              final transfersForProduct =
                  transferHits[inventory.productId] ?? 0;
              final recencyScore = _recencyWeight(
                inventory.lastMovementAt,
                _clock(),
              );
              final score =
                  reservationsForProduct * 4 +
                  transfersForProduct * 3 +
                  recencyScore +
                  (inventory.isLowStock ? 1 : 0);

              return OutOfStockConsultationMetric(
                productId: inventory.productId,
                productName: inventory.productName,
                sku: inventory.sku,
                interestScore: score,
                reservationHits: reservationsForProduct,
                transferHits: transfersForProduct,
                availableStock: inventory.availableStock,
                lastMovementAt: inventory.lastMovementAt,
              );
            })
            .toList(growable: false)
          ..sort((left, right) {
            final scoreComparison = right.interestScore.compareTo(
              left.interestScore,
            );
            if (scoreComparison != 0) {
              return scoreComparison;
            }

            final leftDate =
                left.lastMovementAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final rightDate =
                right.lastMovementAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return rightDate.compareTo(leftDate);
          });

    return ranked.take(5).toList(growable: false);
  }

  bool _isTransferForBranch(TransferRequest transfer, String branchId) {
    return transfer.fromBranchId == branchId || transfer.toBranchId == branchId;
  }

  int _recencyWeight(DateTime? value, DateTime now) {
    if (value == null) {
      return 0;
    }

    final difference = now.difference(value);
    if (difference.inHours < 6) {
      return 6;
    }
    if (difference.inHours < 24) {
      return 4;
    }
    if (difference.inDays < 7) {
      return 2;
    }
    return 0;
  }

  String _normalizeSearchQuery(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _normalizeBarcode(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  ProductSearchFilters _normalizeSearchFilters(ProductSearchFilters filters) {
    final categoryId = filters.categoryId?.trim();
    final brand = filters.brand?.trim();
    final branchId = filters.branchId?.trim();
    var minStock = filters.minStock;
    var maxStock = filters.maxStock;

    if (minStock != null && minStock < 0) {
      minStock = 0;
    }
    if (maxStock != null && maxStock < 0) {
      maxStock = 0;
    }
    if (minStock != null && maxStock != null && minStock > maxStock) {
      final lower = maxStock;
      maxStock = minStock;
      minStock = lower;
    }

    return ProductSearchFilters(
      categoryId: categoryId == null || categoryId.isEmpty ? null : categoryId,
      brand: brand == null || brand.isEmpty ? null : brand,
      branchId: branchId == null || branchId.isEmpty ? null : branchId,
      availability: filters.availability,
      minStock: minStock,
      maxStock: maxStock,
    );
  }

  bool _matchesProductFilters(
    Product product,
    InventoryItem? inventory,
    ProductSearchFilters filters,
  ) {
    if (filters.categoryId != null &&
        product.categoryId != filters.categoryId) {
      return false;
    }

    if (filters.brand != null &&
        product.brand.trim().toLowerCase() !=
            filters.brand!.trim().toLowerCase()) {
      return false;
    }

    final availableStock = inventory?.availableStock ?? 0;
    switch (filters.availability) {
      case ProductAvailabilityFilter.any:
        break;
      case ProductAvailabilityFilter.available:
        if (availableStock <= 0) {
          return false;
        }
        break;
      case ProductAvailabilityFilter.outOfStock:
        if (availableStock > 0) {
          return false;
        }
        break;
      case ProductAvailabilityFilter.lowStock:
        if (inventory == null || !inventory.isLowStock || availableStock <= 0) {
          return false;
        }
        break;
    }

    if (filters.minStock != null && availableStock < filters.minStock!) {
      return false;
    }
    if (filters.maxStock != null && availableStock > filters.maxStock!) {
      return false;
    }

    return true;
  }

  String _filterKey(ProductSearchFilters filters) {
    final values = <String>[
      filters.categoryId ?? '',
      filters.brand?.trim().toLowerCase() ?? '',
      filters.branchId ?? '',
      filters.availability.name,
      filters.minStock?.toString() ?? '',
      filters.maxStock?.toString() ?? '',
    ];
    return values.join('__');
  }

  int _productMatchScore(Product product, String normalizedQuery) {
    final queryWords = normalizedQuery
        .split(' ')
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
    final searchableFields =
        <String>[
              product.name,
              product.sku,
              product.barcode,
              product.brand,
              product.description,
              ...product.tags,
            ]
            .map((value) => value.trim().toLowerCase())
            .where((value) => value.isNotEmpty)
            .toList(growable: false);

    final matchesAllWords = queryWords.every(
      (word) => searchableFields.any((field) => field.contains(word)),
    );
    if (!matchesAllWords) {
      return 0;
    }

    var score = 10;
    final name = product.name.toLowerCase();
    final sku = product.sku.toLowerCase();
    final brand = product.brand.toLowerCase();
    final description = product.description.toLowerCase();

    if (name == normalizedQuery || sku == normalizedQuery) {
      score += 120;
    }
    if (name.startsWith(normalizedQuery)) {
      score += 70;
    }
    if (sku.startsWith(normalizedQuery)) {
      score += 60;
    }
    if (brand.startsWith(normalizedQuery)) {
      score += 35;
    }
    if (name.contains(normalizedQuery)) {
      score += 25;
    }
    if (description.contains(normalizedQuery)) {
      score += 12;
    }

    for (final word in queryWords) {
      if (name.contains(word)) {
        score += 8;
      }
      if (sku.contains(word)) {
        score += 7;
      }
      if (brand.contains(word)) {
        score += 5;
      }
      if (product.tags.any((tag) => tag.toLowerCase().contains(word))) {
        score += 4;
      }
    }

    return score;
  }
}
