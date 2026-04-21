import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firestore_collections.dart';
import '../data/inventory_offline_cache.dart';
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

enum SyncStatusSeverity { healthy, warning, critical, unknown }

class SyncBranchStatus {
  const SyncBranchStatus({
    required this.branch,
    required this.latestLog,
    required this.lastSyncAt,
    required this.age,
    required this.severity,
    required this.summary,
    required this.detail,
  });

  final Branch branch;
  final SyncLog? latestLog;
  final DateTime? lastSyncAt;
  final Duration? age;
  final SyncStatusSeverity severity;
  final String summary;
  final String detail;

  bool get isHealthy => severity == SyncStatusSeverity.healthy;
  bool get isWarning => severity == SyncStatusSeverity.warning;
  bool get isCritical => severity == SyncStatusSeverity.critical;
}

class SyncApiStatus {
  const SyncApiStatus({
    required this.severity,
    required this.summary,
    required this.detail,
    required this.latestLog,
    required this.averageResponseTime,
    required this.lastUpdatedAt,
  });

  final SyncStatusSeverity severity;
  final String summary;
  final String detail;
  final SyncLog? latestLog;
  final Duration averageResponseTime;
  final DateTime? lastUpdatedAt;

  bool get isHealthy => severity == SyncStatusSeverity.healthy;
  bool get isWarning => severity == SyncStatusSeverity.warning;
  bool get isCritical => severity == SyncStatusSeverity.critical;
}

class SyncStatusOverview {
  const SyncStatusOverview({
    required this.generatedAt,
    required this.apiStatus,
    required this.branches,
    required this.warnings,
  });

  final DateTime generatedAt;
  final SyncApiStatus apiStatus;
  final List<SyncBranchStatus> branches;
  final List<String> warnings;

  List<SyncBranchStatus> get healthyBranches => branches
      .where((item) => item.severity == SyncStatusSeverity.healthy)
      .toList(growable: false);

  List<SyncBranchStatus> get warningBranches => branches
      .where((item) => item.severity == SyncStatusSeverity.warning)
      .toList(growable: false);

  List<SyncBranchStatus> get criticalBranches => branches
      .where((item) => item.severity == SyncStatusSeverity.critical)
      .toList(growable: false);

  bool get hasWarnings =>
      warnings.isNotEmpty ||
      !apiStatus.isHealthy ||
      warningBranches.isNotEmpty ||
      criticalBranches.isNotEmpty;

  SyncBranchStatus? statusForBranch(String branchId) {
    for (final branch in branches) {
      if (branch.branch.id == branchId) {
        return branch;
      }
    }
    return null;
  }
}

enum StockAlertSeverity { warning, critical }

enum StockAlertThresholdSource { product, category }

class StockAlertItem {
  const StockAlertItem({
    required this.id,
    required this.branchId,
    required this.branchName,
    required this.productId,
    required this.productName,
    required this.sku,
    required this.categoryId,
    required this.categoryName,
    required this.availableStock,
    required this.reservedStock,
    required this.incomingStock,
    required this.resolvedThreshold,
    required this.productThreshold,
    required this.categoryThreshold,
    required this.thresholdSource,
    required this.severity,
    required this.lastMovementAt,
    required this.updatedAt,
    required this.isRead,
    required this.readAt,
  });

  final String id;
  final String branchId;
  final String branchName;
  final String productId;
  final String productName;
  final String sku;
  final String categoryId;
  final String categoryName;
  final int availableStock;
  final int reservedStock;
  final int incomingStock;
  final int resolvedThreshold;
  final int? productThreshold;
  final int? categoryThreshold;
  final StockAlertThresholdSource thresholdSource;
  final StockAlertSeverity severity;
  final DateTime? lastMovementAt;
  final DateTime updatedAt;
  final bool isRead;
  final DateTime? readAt;

  bool get isCritical => severity == StockAlertSeverity.critical;
  bool get isWarning => severity == StockAlertSeverity.warning;
  int get shortfall => math.max(0, resolvedThreshold - availableStock);
}

class StockAlertFeedData {
  const StockAlertFeedData({required this.alerts, required this.generatedAt});

  final List<StockAlertItem> alerts;
  final DateTime generatedAt;

  int get unreadCount => alerts.where((item) => !item.isRead).length;
  int get criticalCount => alerts.where((item) => item.isCritical).length;
  int get warningCount => alerts.where((item) => item.isWarning).length;
  int get readCount => alerts.where((item) => item.isRead).length;
  bool get hasCritical => criticalCount > 0;
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

class ProductSearchData {
  const ProductSearchData({required this.results, required this.isFromCache});

  final List<ProductSearchResult> results;
  final bool isFromCache;

  ProductSearchData copyWith({bool? isFromCache}) {
    return ProductSearchData(
      results: results,
      isFromCache: isFromCache ?? this.isFromCache,
    );
  }
}

class ProductSearchFilterOptions {
  const ProductSearchFilterOptions({
    required this.categories,
    required this.brands,
    required this.branches,
    required this.isFromCache,
  });

  final List<Category> categories;
  final List<String> brands;
  final List<Branch> branches;
  final bool isFromCache;

  ProductSearchFilterOptions copyWith({bool? isFromCache}) {
    return ProductSearchFilterOptions(
      categories: categories,
      brands: brands,
      branches: branches,
      isFromCache: isFromCache ?? this.isFromCache,
    );
  }
}

enum InventoryRefreshDataType {
  dashboard,
  searchResults,
  searchFilters,
  productDetail,
  stockByBranch,
  branchDirectory,
  transferCatalog,
  reservationCatalog,
}

class InventoryRefreshPolicy {
  const InventoryRefreshPolicy({
    required this.ttl,
    required this.autoRefreshInterval,
  });

  final Duration ttl;
  final Duration autoRefreshInterval;
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

class ReservationRequestCatalogItem {
  const ReservationRequestCatalogItem({
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

class TransferTraceabilityData {
  const TransferTraceabilityData({
    required this.transfer,
    required this.requesterUser,
    required this.approverUser,
    required this.sourceInventory,
    required this.destinationInventory,
    required this.auditTrail,
  });

  final TransferRequest transfer;
  final AppUser? requesterUser;
  final AppUser? approverUser;
  final InventoryItem? sourceInventory;
  final InventoryItem? destinationInventory;
  final List<AuditLog> auditTrail;

  AuditLog? get requestLog => _findAudit('transfer_requested');
  AuditLog? get approvalLog => _findAudit('transfer_approved');
  AuditLog? get dispatchLog => _findAudit('transfer_in_transit');
  AuditLog? get receiveLog => _findAudit('transfer_received');

  AuditLog? _findAudit(String action) {
    return auditTrail.cast<AuditLog?>().firstWhere(
      (item) => item?.action == action,
      orElse: () => null,
    );
  }
}

class ReservationTraceabilityData {
  const ReservationTraceabilityData({
    required this.reservation,
    required this.requesterUser,
    required this.branchInventory,
    required this.auditTrail,
  });

  final Reservation reservation;
  final AppUser? requesterUser;
  final InventoryItem? branchInventory;
  final List<AuditLog> auditTrail;

  AuditLog? get requestLog => _findAudit('reservation_created');
  AuditLog? get approvalLog => _findAudit('reservation_approved');
  AuditLog? get rejectionLog => _findAudit('reservation_rejected');
  AuditLog? get completionLog => _findAudit('reservation_completed');
  AuditLog? get cancellationLog => _findAudit('reservation_cancelled');
  AuditLog? get expirationLog => _findAudit('reservation_expired');

  AuditLog? get latestStatusLog =>
      rejectionLog ??
      expirationLog ??
      cancellationLog ??
      completionLog ??
      approvalLog ??
      requestLog;

  AuditLog? _findAudit(String action) {
    return auditTrail.cast<AuditLog?>().firstWhere(
      (item) => item?.action == action,
      orElse: () => null,
    );
  }
}

class ApprovalQueueData {
  const ApprovalQueueData({
    required this.pendingReservations,
    required this.pendingTransfers,
    required this.scopeLabel,
    required this.scopeIsGlobal,
  });

  final List<Reservation> pendingReservations;
  final List<TransferRequest> pendingTransfers;
  final String scopeLabel;
  final bool scopeIsGlobal;

  int get totalPending => pendingReservations.length + pendingTransfers.length;

  bool get hasItems => totalPending > 0;
}

enum RequestTrackingType { reservation, transfer }

enum RequestTrackingStatus {
  pending('Pendiente'),
  approved('Aprobada'),
  rejected('Rechazada'),
  inTransit('En transito'),
  received('Recibida'),
  completed('Completada'),
  cancelled('Cancelada'),
  expired('Vencida');

  const RequestTrackingStatus(this.label);

  final String label;
}

class RequestStatusHistoryEntry {
  const RequestStatusHistoryEntry({
    required this.status,
    required this.title,
    required this.detail,
    required this.occurredAt,
  });

  final RequestTrackingStatus status;
  final String title;
  final String detail;
  final DateTime occurredAt;
}

class RequestTrackingItem {
  const RequestTrackingItem({
    required this.id,
    required this.type,
    required this.productId,
    required this.productName,
    required this.sku,
    required this.quantity,
    required this.status,
    required this.requestedAt,
    required this.updatedAt,
    required this.primaryBranchName,
    required this.secondaryBranchName,
    required this.requesterLabel,
    required this.customerLabel,
    required this.reasonLabel,
    required this.reviewComment,
    required this.history,
  });

  final String id;
  final RequestTrackingType type;
  final String productId;
  final String productName;
  final String sku;
  final int quantity;
  final RequestTrackingStatus status;
  final DateTime requestedAt;
  final DateTime updatedAt;
  final String primaryBranchName;
  final String secondaryBranchName;
  final String requesterLabel;
  final String customerLabel;
  final String reasonLabel;
  final String reviewComment;
  final List<RequestStatusHistoryEntry> history;

  String get statusLabel => status.label;

  String get typeLabel => switch (type) {
    RequestTrackingType.reservation => 'Reserva',
    RequestTrackingType.transfer => 'Traslado',
  };

  DateTime get lastStatusAt => history.last.occurredAt;

  bool get hasReviewComment => reviewComment.trim().isNotEmpty;
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

class _CachedLoad<T> {
  const _CachedLoad({required this.data, required this.isFromCache});

  final T data;
  final bool isFromCache;
}

class InventoryWorkflowService {
  InventoryWorkflowService({
    required FirebaseFirestore firestore,
    DateTime Function()? clock,
    InventoryOfflineCache? offlineCache,
  }) : _firestore = firestore,
       _clock = clock ?? DateTime.now,
       _offlineCache = offlineCache ?? MemoryInventoryOfflineCache(),
       users = UserRepository(firestore),
       catalog = CatalogRepository(firestore),
       inventories = InventoryRepository(firestore),
       reservations = ReservationRepository(firestore),
       transfers = TransferRepository(firestore),
       system = SystemRepository(firestore);

  final FirebaseFirestore _firestore;
  final DateTime Function() _clock;
  final InventoryOfflineCache _offlineCache;

  final UserRepository users;
  final CatalogRepository catalog;
  final InventoryRepository inventories;
  final ReservationRepository reservations;
  final TransferRepository transfers;
  final SystemRepository system;
  final Map<String, DateTime> _refreshRegistry = <String, DateTime>{};
  final Map<String, ProductSearchData> _productSearchCache =
      <String, ProductSearchData>{};
  final Map<String, ProductDetailData> _productDetailCache =
      <String, ProductDetailData>{};
  final Map<String, List<ProductBranchStockEntry>> _productStockByBranchCache =
      <String, List<ProductBranchStockEntry>>{};
  final Map<String, BranchDirectoryData> _branchDirectoryCache =
      <String, BranchDirectoryData>{};
  final Map<String, List<TransferRequestCatalogItem>> _transferCatalogCache =
      <String, List<TransferRequestCatalogItem>>{};
  final Map<String, List<ReservationRequestCatalogItem>>
  _reservationCatalogCache = <String, List<ReservationRequestCatalogItem>>{};
  ProductSearchFilterOptions? _searchFilterOptionsCache;
  List<Branch>? _branchCatalogCache;
  List<Category>? _categoryCatalogCache;
  List<Product>? _productCatalogCache;
  bool _branchCatalogFromOfflineCache = false;
  bool _categoryCatalogFromOfflineCache = false;
  bool _productCatalogFromOfflineCache = false;

  static const Duration _greenDataThreshold = Duration(minutes: 15);
  static const Duration _yellowDataThreshold = Duration(minutes: 30);
  static const Duration _redDataThreshold = Duration(minutes: 60);
  static const Duration _syncStatusTick = Duration(minutes: 1);
  static const int _syncStatusLogLimit = 180;
  static const double _criticalStockThresholdFactor = 0.5;
  static const Map<InventoryRefreshDataType, InventoryRefreshPolicy>
  _refreshPolicies = <InventoryRefreshDataType, InventoryRefreshPolicy>{
    InventoryRefreshDataType.dashboard: InventoryRefreshPolicy(
      ttl: Duration(seconds: 45),
      autoRefreshInterval: Duration(seconds: 60),
    ),
    InventoryRefreshDataType.searchResults: InventoryRefreshPolicy(
      ttl: Duration(minutes: 2),
      autoRefreshInterval: Duration(minutes: 2),
    ),
    InventoryRefreshDataType.searchFilters: InventoryRefreshPolicy(
      ttl: Duration(minutes: 10),
      autoRefreshInterval: Duration(minutes: 10),
    ),
    InventoryRefreshDataType.productDetail: InventoryRefreshPolicy(
      ttl: Duration(minutes: 2),
      autoRefreshInterval: Duration(minutes: 2),
    ),
    InventoryRefreshDataType.stockByBranch: InventoryRefreshPolicy(
      ttl: Duration(minutes: 2),
      autoRefreshInterval: Duration(minutes: 2),
    ),
    InventoryRefreshDataType.branchDirectory: InventoryRefreshPolicy(
      ttl: Duration(minutes: 3),
      autoRefreshInterval: Duration(minutes: 3),
    ),
    InventoryRefreshDataType.transferCatalog: InventoryRefreshPolicy(
      ttl: Duration(minutes: 2),
      autoRefreshInterval: Duration(minutes: 2),
    ),
    InventoryRefreshDataType.reservationCatalog: InventoryRefreshPolicy(
      ttl: Duration(minutes: 2),
      autoRefreshInterval: Duration(minutes: 2),
    ),
  };

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

  String _refreshRegistryKey(InventoryRefreshDataType type, String scope) =>
      '${type.name}|$scope';

  InventoryRefreshPolicy refreshPolicyFor(InventoryRefreshDataType type) =>
      _refreshPolicies[type]!;

  bool shouldRefreshData({
    required InventoryRefreshDataType type,
    required String scope,
  }) {
    final lastRefreshAt = _refreshRegistry[_refreshRegistryKey(type, scope)];
    if (lastRefreshAt == null) {
      return true;
    }
    final ttl = refreshPolicyFor(type).ttl;
    return _clock().difference(lastRefreshAt) >= ttl;
  }

  DateTime? lastRefreshAt({
    required InventoryRefreshDataType type,
    required String scope,
  }) {
    return _refreshRegistry[_refreshRegistryKey(type, scope)];
  }

  void markRefreshCompleted({
    required InventoryRefreshDataType type,
    required String scope,
  }) {
    _refreshRegistry[_refreshRegistryKey(type, scope)] = _clock();
  }

  void _invalidateProductCaches([String? productId]) {
    _refreshRegistry.clear();
    _productSearchCache.clear();
    if (productId == null || productId.isEmpty) {
      _productDetailCache.clear();
      _productStockByBranchCache.clear();
      _branchDirectoryCache.clear();
      _transferCatalogCache.clear();
      _reservationCatalogCache.clear();
      _searchFilterOptionsCache = null;
      _productCatalogCache = null;
      _categoryCatalogCache = null;
      _branchCatalogCache = null;
      _productCatalogFromOfflineCache = false;
      _categoryCatalogFromOfflineCache = false;
      _branchCatalogFromOfflineCache = false;
      _runBackgroundTask(_offlineCache.clearAll);
      return;
    }

    _productDetailCache.removeWhere((key, _) => key.endsWith('_$productId'));
    _productStockByBranchCache.removeWhere(
      (key, _) => key.endsWith('_$productId'),
    );
    _branchDirectoryCache.removeWhere((key, _) => key.endsWith('_$productId'));
    _runBackgroundTask(() => _offlineCache.clearProductScopedCaches(productId));
  }

  void _invalidateBranchCatalogCache() {
    _refreshRegistry.clear();
    _branchCatalogCache = null;
    _branchCatalogFromOfflineCache = false;
    _branchDirectoryCache.clear();
    _searchFilterOptionsCache = null;
    _runBackgroundTask(_offlineCache.clearBranchCatalogCaches);
  }

  void _invalidateSearchOptionsCache() {
    _searchFilterOptionsCache = null;
    _productSearchCache.clear();
  }

  void _runBackgroundTask(Future<void> Function() action) {
    unawaited(() async {
      try {
        await action();
      } catch (_) {}
    }());
  }

  Future<_CachedLoad<List<Branch>>> _fetchBranchCatalog({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _branchCatalogCache;
      if (cached != null) {
        return _CachedLoad(
          data: cached,
          isFromCache: _branchCatalogFromOfflineCache,
        );
      }
    }

    try {
      final branches = List<Branch>.unmodifiable(await catalog.fetchBranches());
      _branchCatalogCache = branches;
      _branchCatalogFromOfflineCache = false;
      await _offlineCache.cacheBranches(branches);
      return _CachedLoad(data: branches, isFromCache: false);
    } catch (error) {
      final cached = _offlineCache.getBranches();
      if (cached != null) {
        final branches = List<Branch>.unmodifiable(cached);
        _branchCatalogCache = branches;
        _branchCatalogFromOfflineCache = true;
        return _CachedLoad(data: branches, isFromCache: true);
      }
      rethrow;
    }
  }

  Future<_CachedLoad<List<Category>>> _fetchCategoryCatalog({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _categoryCatalogCache;
      if (cached != null) {
        return _CachedLoad(
          data: cached,
          isFromCache: _categoryCatalogFromOfflineCache,
        );
      }
    }

    try {
      final categories = List<Category>.unmodifiable(
        await catalog.fetchCategories(),
      );
      _categoryCatalogCache = categories;
      _categoryCatalogFromOfflineCache = false;
      await _offlineCache.cacheCategories(categories);
      return _CachedLoad(data: categories, isFromCache: false);
    } catch (error) {
      final cached = _offlineCache.getCategories();
      if (cached != null) {
        final categories = List<Category>.unmodifiable(cached);
        _categoryCatalogCache = categories;
        _categoryCatalogFromOfflineCache = true;
        return _CachedLoad(data: categories, isFromCache: true);
      }
      rethrow;
    }
  }

  Future<_CachedLoad<List<Product>>> _fetchProductCatalog({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _productCatalogCache;
      if (cached != null) {
        return _CachedLoad(
          data: cached,
          isFromCache: _productCatalogFromOfflineCache,
        );
      }
    }

    try {
      final products = List<Product>.unmodifiable(
        await catalog.fetchProducts(),
      );
      _productCatalogCache = products;
      _productCatalogFromOfflineCache = false;
      await _offlineCache.cacheProducts(products);
      return _CachedLoad(data: products, isFromCache: false);
    } catch (error) {
      final cached = _offlineCache.getProducts();
      if (cached != null) {
        final products = List<Product>.unmodifiable(cached);
        _productCatalogCache = products;
        _productCatalogFromOfflineCache = true;
        return _CachedLoad(data: products, isFromCache: true);
      }
      rethrow;
    }
  }

  Future<_CachedLoad<Branch?>> _fetchBranchById(
    String branchId, {
    bool forceRefresh = false,
  }) async {
    try {
      final branch = await catalog.fetchBranch(branchId);
      if (branch != null) {
        await _offlineCache.cacheBranch(branch);
      }
      return _CachedLoad(data: branch, isFromCache: false);
    } catch (error) {
      final cachedCatalog = await _fetchBranchCatalog(
        forceRefresh: forceRefresh,
      );
      final branch = cachedCatalog.data.cast<Branch?>().firstWhere(
        (item) => item?.id == branchId,
        orElse: () => null,
      );
      if (branch != null) {
        return _CachedLoad(
          data: branch,
          isFromCache: cachedCatalog.isFromCache,
        );
      }
      rethrow;
    }
  }

  Future<_CachedLoad<Product?>> _fetchProductById(
    String productId, {
    bool forceRefresh = false,
  }) async {
    try {
      final product = await catalog.fetchProduct(productId);
      if (product != null) {
        await _offlineCache.cacheProduct(product);
      }
      return _CachedLoad(data: product, isFromCache: false);
    } catch (error) {
      final cachedCatalog = await _fetchProductCatalog(
        forceRefresh: forceRefresh,
      );
      final product = cachedCatalog.data.cast<Product?>().firstWhere(
        (item) => item?.id == productId,
        orElse: () => null,
      );
      if (product != null) {
        return _CachedLoad(
          data: product,
          isFromCache: cachedCatalog.isFromCache,
        );
      }
      rethrow;
    }
  }

  Future<_CachedLoad<Category?>> _fetchCategoryById(
    String categoryId, {
    bool forceRefresh = false,
  }) async {
    try {
      final category = await catalog.fetchCategory(categoryId);
      if (category != null) {
        await _offlineCache.cacheCategory(category);
      }
      return _CachedLoad(data: category, isFromCache: false);
    } catch (error) {
      final cachedCatalog = await _fetchCategoryCatalog(
        forceRefresh: forceRefresh,
      );
      final category = cachedCatalog.data.cast<Category?>().firstWhere(
        (item) => item?.id == categoryId,
        orElse: () => null,
      );
      if (category != null) {
        return _CachedLoad(
          data: category,
          isFromCache: cachedCatalog.isFromCache,
        );
      }
      rethrow;
    }
  }

  Future<_CachedLoad<List<InventoryItem>>> _fetchBranchInventory(
    String branchId,
  ) async {
    try {
      final items = List<InventoryItem>.unmodifiable(
        await inventories.fetchBranchInventory(branchId),
      );
      await _offlineCache.cacheBranchInventory(branchId, items);
      return _CachedLoad(data: items, isFromCache: false);
    } catch (error) {
      final cached = _offlineCache.getBranchInventory(branchId);
      if (cached != null) {
        return _CachedLoad(
          data: List<InventoryItem>.unmodifiable(cached),
          isFromCache: true,
        );
      }
      rethrow;
    }
  }

  Future<_CachedLoad<List<InventoryItem>>> _fetchProductInventory(
    String productId,
  ) async {
    try {
      final items = List<InventoryItem>.unmodifiable(
        await inventories.fetchProductInventory(productId),
      );
      await _offlineCache.cacheProductInventory(productId, items);
      return _CachedLoad(data: items, isFromCache: false);
    } catch (error) {
      final cached = _offlineCache.getProductInventory(productId);
      if (cached != null) {
        return _CachedLoad(
          data: List<InventoryItem>.unmodifiable(cached),
          isFromCache: true,
        );
      }
      rethrow;
    }
  }

  Future<_CachedLoad<InventoryItem?>> _fetchInventoryItem(
    String branchId,
    String productId,
  ) async {
    try {
      final inventory = await inventories.fetchInventory(branchId, productId);
      if (inventory != null) {
        await _offlineCache.cacheInventoryItem(inventory);
      }
      return _CachedLoad(data: inventory, isFromCache: false);
    } catch (error) {
      return _CachedLoad(
        data: _offlineCache.getInventory(branchId, productId),
        isFromCache: true,
      );
    }
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

  AuditLog _buildTransferAuditLog({
    required AppUser actorUser,
    required TransferRequest transfer,
    required String action,
    required String message,
    required String branchId,
    required String branchName,
    Map<String, String> extraMetadata = const {},
  }) {
    return _buildAuditLog(
      actorUser: actorUser,
      action: action,
      entityType: 'transfer',
      entityId: transfer.id,
      entityLabel: transfer.productName,
      message: message,
      metadata: {
        'productId': transfer.productId,
        'sku': transfer.sku,
        'quantity': '${transfer.quantity}',
        'fromBranchId': transfer.fromBranchId,
        'fromBranchName': transfer.fromBranchName,
        'toBranchId': transfer.toBranchId,
        'toBranchName': transfer.toBranchName,
        'requestedByUserId': transfer.requestedBy,
        if (transfer.requestedByName.isNotEmpty)
          'requestedByName': transfer.requestedByName,
        'status': transfer.status.firestoreValue,
        'reason': transfer.reason,
        if (transfer.notes.isNotEmpty) 'notes': transfer.notes,
        if (transfer.reviewComment.isNotEmpty)
          'reviewComment': transfer.reviewComment,
        ...extraMetadata,
      },
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

  String _buildSearchCacheKey({
    required String branchId,
    required String normalizedQuery,
    required ProductSearchFilters filters,
  }) {
    return [
      branchId,
      normalizedQuery,
      filters.categoryId ?? '-',
      filters.brand?.trim().toLowerCase() ?? '-',
      filters.branchId ?? '-',
      filters.availability.name,
      filters.minStock?.toString() ?? '-',
      filters.maxStock?.toString() ?? '-',
    ].join('|');
  }

  String detailRefreshScope({
    required String branchId,
    required String productId,
  }) => '${branchId}_$productId';

  String searchResultsRefreshScope({
    required String branchId,
    required String query,
    ProductSearchFilters filters = const ProductSearchFilters(),
  }) {
    final normalizedFilters = _normalizeSearchFilters(filters);
    final effectiveBranchId = normalizedFilters.branchId ?? branchId;
    return _buildSearchCacheKey(
      branchId: effectiveBranchId,
      normalizedQuery: _normalizeSearchQuery(query),
      filters: normalizedFilters,
    );
  }

  String stockByBranchRefreshScope({
    required AppUser actorUser,
    required String productId,
  }) => '${actorUser.id}_$productId';

  String branchDirectoryRefreshScope({
    required AppUser actorUser,
    String? productId,
  }) =>
      '${actorUser.id}_${productId?.trim().isNotEmpty == true ? productId!.trim() : 'catalog'}';

  String searchFiltersRefreshScope({required AppUser actorUser}) =>
      actorUser.id;

  String transferCatalogRefreshScope({required AppUser actorUser}) =>
      actorUser.branchId;

  String reservationCatalogRefreshScope({required AppUser actorUser}) =>
      actorUser.branchId;

  String dashboardRefreshScope({required AppUser actorUser}) =>
      '${actorUser.role.name}|${actorUser.branchId}';

  List<ProductSearchResult> _buildSearchResults({
    required List<Product> products,
    required List<InventoryItem> branchInventory,
    required String normalizedQuery,
    required ProductSearchFilters filters,
  }) {
    final inventoryByProductId = {
      for (final item in branchInventory) item.productId: item,
    };

    return products
        .where((product) => product.isActive)
        .map((product) {
          final inventory = inventoryByProductId[product.id];
          if (!_matchesProductFilters(product, inventory, filters)) {
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
  }

  ProductSearchData _materializeSearchCache(
    List<CachedSearchResultRecord> records,
  ) {
    final results = List<ProductSearchResult>.unmodifiable(
      records
          .map(
            (record) => ProductSearchResult(
              product: record.product,
              inventory: record.inventory,
              relevanceScore: record.relevanceScore,
            ),
          )
          .toList(growable: false),
    );
    return ProductSearchData(results: results, isFromCache: true);
  }

  Future<ProductSearchData> _loadSearchProducts({
    required AppUser actorUser,
    required String effectiveBranchId,
    required String normalizedQuery,
    required ProductSearchFilters filters,
    required String searchCacheKey,
  }) async {
    final products = await _fetchProductCatalog();
    final branchInventory = await _fetchBranchInventory(effectiveBranchId);
    final results = List<ProductSearchResult>.unmodifiable(
      _buildSearchResults(
        products: products.data,
        branchInventory: branchInventory.data,
        normalizedQuery: normalizedQuery,
        filters: filters,
      ),
    );
    final isFromCache = products.isFromCache || branchInventory.isFromCache;
    final cacheRecords = results
        .map(
          (result) => CachedSearchResultRecord(
            product: result.product,
            inventory: result.inventory,
            relevanceScore: result.relevanceScore,
          ),
        )
        .toList(growable: false);

    await _offlineCache.cacheSearchResults(searchCacheKey, cacheRecords);
    await _offlineCache.cacheRecentProducts(
      actorUser.id,
      results.take(8).map((result) => result.product),
    );
    markRefreshCompleted(
      type: InventoryRefreshDataType.searchResults,
      scope: searchCacheKey,
    );
    final data = ProductSearchData(results: results, isFromCache: isFromCache);
    _productSearchCache[searchCacheKey] = ProductSearchData(
      results: results,
      isFromCache: false,
    );
    return data;
  }

  Future<ProductSearchData> searchProducts({
    required AppUser actorUser,
    required String branchId,
    required String query,
    ProductSearchFilters filters = const ProductSearchFilters(),
    bool forceRefresh = false,
  }) async {
    _ensurePermission(actorUser, AppPermission.viewOwnInventory);
    final normalizedFilters = _normalizeSearchFilters(filters);
    final effectiveBranchId = normalizedFilters.branchId ?? branchId;
    _ensureBranchAccess(actorUser, effectiveBranchId);

    final normalizedQuery = _normalizeSearchQuery(query);
    if (normalizedQuery.isEmpty && normalizedFilters.isEmpty) {
      return const ProductSearchData(
        results: <ProductSearchResult>[],
        isFromCache: false,
      );
    }

    final searchCacheKey = _buildSearchCacheKey(
      branchId: effectiveBranchId,
      normalizedQuery: normalizedQuery,
      filters: normalizedFilters,
    );
    final cached = _productSearchCache[searchCacheKey];
    if (!forceRefresh && cached != null) {
      if (shouldRefreshData(
        type: InventoryRefreshDataType.searchResults,
        scope: searchCacheKey,
      )) {
        _runBackgroundTask(
          () => _loadSearchProducts(
            actorUser: actorUser,
            effectiveBranchId: effectiveBranchId,
            normalizedQuery: normalizedQuery,
            filters: normalizedFilters,
            searchCacheKey: searchCacheKey,
          ).then((_) {}),
        );
      }
      return cached.copyWith(isFromCache: true);
    }

    try {
      return await _loadSearchProducts(
        actorUser: actorUser,
        effectiveBranchId: effectiveBranchId,
        normalizedQuery: normalizedQuery,
        filters: normalizedFilters,
        searchCacheKey: searchCacheKey,
      );
    } catch (error) {
      final cachedRecords = _offlineCache.getSearchResults(searchCacheKey);
      if (cachedRecords != null) {
        final searchData = _materializeSearchCache(cachedRecords);
        _productSearchCache[searchCacheKey] = ProductSearchData(
          results: searchData.results,
          isFromCache: false,
        );
        return searchData;
      }
      rethrow;
    }
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

    final products = await _fetchProductCatalog();
    final matchedProduct = products.data.cast<Product?>().firstWhere(
      (product) =>
          product != null &&
          product.isActive &&
          _normalizeBarcode(product.barcode) == normalizedBarcode,
      orElse: () => null,
    );

    if (matchedProduct == null) {
      return null;
    }

    final inventory = await _fetchInventoryItem(branchId, matchedProduct.id);

    return ProductSearchResult(
      product: matchedProduct,
      inventory: inventory.data,
      relevanceScore: 999,
    );
  }

  List<ProductBranchStockEntry> _buildStockByBranchEntries({
    required List<Branch> branches,
    required List<InventoryItem> productInventories,
  }) {
    final inventoryByBranchId = {
      for (final item in productInventories.where((item) => item.isActive))
        item.branchId: item,
    };

    return branches
        .where((branch) => branch.isActive)
        .map((branch) {
          final inventory = inventoryByBranchId[branch.id];
          final lastUpdatedAt = _resolveInventoryTimestamp(inventory, branch);
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

        final inTransit = right.inTransitStock.compareTo(left.inTransitStock);
        if (inTransit != 0) {
          return inTransit;
        }

        return left.branch.name.compareTo(right.branch.name);
      });
  }

  ProductBranchStockEntry _materializeStockEntry(
    CachedBranchStockRecord record,
  ) {
    final lastUpdatedAt = _resolveInventoryTimestamp(
      record.inventory,
      record.branch,
    );
    final reliability = _buildInventoryReliability(
      inventory: record.inventory,
      branch: record.branch,
    );
    return ProductBranchStockEntry(
      branch: record.branch,
      inventory: record.inventory,
      lastUpdatedAt: lastUpdatedAt,
      reliability: reliability,
    );
  }

  List<ProductBranchStockEntry> _materializeStockByBranch(
    List<CachedBranchStockRecord> records,
  ) {
    return records.map(_materializeStockEntry).toList(growable: false)..sort((
      left,
      right,
    ) {
      final availability = right.availableStock.compareTo(left.availableStock);
      if (availability != 0) {
        return availability;
      }

      final inTransit = right.inTransitStock.compareTo(left.inTransitStock);
      if (inTransit != 0) {
        return inTransit;
      }

      return left.branch.name.compareTo(right.branch.name);
    });
  }

  Future<ProductDetailData> fetchProductDetail({
    required AppUser actorUser,
    required String branchId,
    required String productId,
    bool forceRefresh = false,
  }) async {
    _ensurePermission(actorUser, AppPermission.viewOwnInventory);
    _ensureBranchAccess(actorUser, branchId);

    final cacheKey = detailRefreshScope(
      branchId: branchId,
      productId: productId,
    );
    if (!forceRefresh) {
      final cached = _productDetailCache[cacheKey];
      if (cached != null) {
        if (shouldRefreshData(
          type: InventoryRefreshDataType.productDetail,
          scope: cacheKey,
        )) {
          _runBackgroundTask(
            () => fetchProductDetail(
              actorUser: actorUser,
              branchId: branchId,
              productId: productId,
              forceRefresh: true,
            ).then((_) {}),
          );
        }
        return cached.copyWith(isFromCache: true);
      }
    }

    try {
      final product = await _fetchProductById(
        productId,
        forceRefresh: forceRefresh,
      );
      final resolvedProduct = product.data;
      if (resolvedProduct == null || !resolvedProduct.isActive) {
        throw const InventoryException(
          'No se encontro el producto solicitado en el catalogo.',
        );
      }

      final branch = await _fetchBranchById(
        branchId,
        forceRefresh: forceRefresh,
      );
      final inventory = await _fetchInventoryItem(branchId, resolvedProduct.id);
      final category = resolvedProduct.categoryId.isEmpty
          ? const _CachedLoad<Category?>(data: null, isFromCache: false)
          : await _fetchCategoryById(
              resolvedProduct.categoryId,
              forceRefresh: forceRefresh,
            );
      final stockByBranch = await fetchProductStockByBranch(
        actorUser: actorUser,
        productId: resolvedProduct.id,
        forceRefresh: forceRefresh,
      );
      final branchSuggestions = _buildBranchSuggestions(
        currentBranch: branch.data,
        currentBranchId: branchId,
        stockByBranch: stockByBranch,
      );
      final reliability = _buildInventoryReliability(
        inventory: inventory.data,
        branch: branch.data,
      );
      final isFromCache =
          product.isFromCache ||
          branch.isFromCache ||
          inventory.isFromCache ||
          category.isFromCache;

      final detail = ProductDetailData(
        product: resolvedProduct,
        inventory: inventory.data,
        category: category.data,
        branch: branch.data,
        stockByBranch: stockByBranch,
        branchSuggestions: branchSuggestions,
        recommendedSuggestion: branchSuggestions.isEmpty
            ? null
            : branchSuggestions.first,
        reliability: reliability,
        isFromCache: isFromCache,
      );
      _productDetailCache[cacheKey] = detail.copyWith(isFromCache: false);
      await _offlineCache.cacheProductDetail(
        cacheKey,
        CachedProductDetailRecord(
          product: resolvedProduct,
          inventory: inventory.data,
          category: category.data,
          branch: branch.data,
          stockByBranch: stockByBranch
              .map(
                (entry) => CachedBranchStockRecord(
                  branch: entry.branch,
                  inventory: entry.inventory,
                ),
              )
              .toList(growable: false),
        ),
      );
      await _offlineCache.cacheRecentProducts(actorUser.id, <Product>[
        resolvedProduct,
      ]);
      markRefreshCompleted(
        type: InventoryRefreshDataType.productDetail,
        scope: cacheKey,
      );
      return detail;
    } catch (error) {
      final cachedDetail = _offlineCache.getProductDetail(cacheKey);
      if (cachedDetail != null) {
        final stockByBranch = _materializeStockByBranch(
          cachedDetail.stockByBranch,
        );
        final branchSuggestions = _buildBranchSuggestions(
          currentBranch: cachedDetail.branch,
          currentBranchId: branchId,
          stockByBranch: stockByBranch,
        );
        final reliability = _buildInventoryReliability(
          inventory: cachedDetail.inventory,
          branch: cachedDetail.branch,
        );
        final detail = ProductDetailData(
          product: cachedDetail.product,
          inventory: cachedDetail.inventory,
          category: cachedDetail.category,
          branch: cachedDetail.branch,
          stockByBranch: stockByBranch,
          branchSuggestions: branchSuggestions,
          recommendedSuggestion: branchSuggestions.isEmpty
              ? null
              : branchSuggestions.first,
          reliability: reliability,
          isFromCache: true,
        );
        _productDetailCache[cacheKey] = detail.copyWith(isFromCache: false);
        return detail;
      }
      rethrow;
    }
  }

  Future<List<ProductBranchStockEntry>> fetchProductStockByBranch({
    required AppUser actorUser,
    required String productId,
    bool forceRefresh = false,
  }) async {
    _ensurePermission(actorUser, AppPermission.viewStockByBranch);

    final cacheKey = stockByBranchRefreshScope(
      actorUser: actorUser,
      productId: productId,
    );
    if (!forceRefresh) {
      final cached = _productStockByBranchCache[cacheKey];
      if (cached != null) {
        if (shouldRefreshData(
          type: InventoryRefreshDataType.stockByBranch,
          scope: cacheKey,
        )) {
          _runBackgroundTask(
            () => fetchProductStockByBranch(
              actorUser: actorUser,
              productId: productId,
              forceRefresh: true,
            ).then((_) {}),
          );
        }
        return cached;
      }
    }

    try {
      final product = await _fetchProductById(
        productId,
        forceRefresh: forceRefresh,
      );
      if (product.data == null || !product.data!.isActive) {
        throw const InventoryException(
          'No se encontro el producto solicitado en el catalogo.',
        );
      }

      final branches = await _fetchBranchCatalog(forceRefresh: forceRefresh);
      final productInventories = await _fetchProductInventory(productId);
      final stockByBranch = _buildStockByBranchEntries(
        branches: branches.data,
        productInventories: productInventories.data,
      );
      final immutableStockByBranch = List<ProductBranchStockEntry>.unmodifiable(
        stockByBranch,
      );
      _productStockByBranchCache[cacheKey] = immutableStockByBranch;
      await _offlineCache.cacheStockByBranch(
        cacheKey,
        immutableStockByBranch
            .map(
              (entry) => CachedBranchStockRecord(
                branch: entry.branch,
                inventory: entry.inventory,
              ),
            )
            .toList(growable: false),
      );
      markRefreshCompleted(
        type: InventoryRefreshDataType.stockByBranch,
        scope: cacheKey,
      );
      return immutableStockByBranch;
    } catch (error) {
      final cachedStock = _offlineCache.getStockByBranch(cacheKey);
      if (cachedStock != null) {
        final stockByBranch = List<ProductBranchStockEntry>.unmodifiable(
          _materializeStockByBranch(cachedStock),
        );
        _productStockByBranchCache[cacheKey] = stockByBranch;
        return stockByBranch;
      }
      rethrow;
    }
  }

  Future<BranchDirectoryData> fetchBranchDirectory({
    required AppUser actorUser,
    String? productId,
    bool forceRefresh = false,
  }) async {
    _ensurePermission(actorUser, AppPermission.viewOwnInventory);

    final normalizedProductId = productId?.trim();
    final cacheKey = branchDirectoryRefreshScope(
      actorUser: actorUser,
      productId: normalizedProductId,
    );
    if (!forceRefresh) {
      final cached = _branchDirectoryCache[cacheKey];
      if (cached != null) {
        if (shouldRefreshData(
          type: InventoryRefreshDataType.branchDirectory,
          scope: cacheKey,
        )) {
          _runBackgroundTask(
            () => fetchBranchDirectory(
              actorUser: actorUser,
              productId: productId,
              forceRefresh: true,
            ).then((_) {}),
          );
        }
        return cached.copyWith(isFromCache: true);
      }
    }

    try {
      final branches = await _fetchBranchCatalog(forceRefresh: forceRefresh);
      final currentBranch = branches.data.cast<Branch?>().firstWhere(
        (branch) => branch?.id == actorUser.branchId,
        orElse: () => null,
      );

      Product? selectedProduct;
      bool selectedProductFromCache = false;
      Map<String, ProductBranchStockEntry> stockByBranchId =
          const <String, ProductBranchStockEntry>{};

      if (normalizedProductId != null && normalizedProductId.isNotEmpty) {
        final product = await _fetchProductById(
          normalizedProductId,
          forceRefresh: forceRefresh,
        );
        selectedProduct = product.data;
        selectedProductFromCache = product.isFromCache;
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
          branches.data
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
        isFromCache: branches.isFromCache || selectedProductFromCache,
      );
      _branchDirectoryCache[cacheKey] = directory.copyWith(isFromCache: false);
      await _offlineCache.cacheBranchDirectory(
        cacheKey,
        CachedBranchDirectoryRecord(
          entries: entries
              .map(
                (entry) => CachedBranchDirectoryEntryRecord(
                  branch: entry.branch,
                  distanceKm: entry.distanceKm,
                  stockEntry: entry.stockEntry == null
                      ? null
                      : CachedBranchStockRecord(
                          branch: entry.stockEntry!.branch,
                          inventory: entry.stockEntry!.inventory,
                        ),
                ),
              )
              .toList(growable: false),
          selectedProduct: selectedProduct,
          currentBranch: currentBranch,
        ),
      );
      markRefreshCompleted(
        type: InventoryRefreshDataType.branchDirectory,
        scope: cacheKey,
      );
      return directory;
    } catch (error) {
      final cachedDirectory = _offlineCache.getBranchDirectory(cacheKey);
      if (cachedDirectory != null) {
        final directory = BranchDirectoryData(
          entries: List<BranchDirectoryEntry>.unmodifiable(
            cachedDirectory.entries
                .map(
                  (entry) => BranchDirectoryEntry(
                    branch: entry.branch,
                    distanceKm: entry.distanceKm,
                    stockEntry: entry.stockEntry == null
                        ? null
                        : _materializeStockEntry(entry.stockEntry!),
                  ),
                )
                .toList(growable: false),
          ),
          selectedProduct: cachedDirectory.selectedProduct,
          currentBranch: cachedDirectory.currentBranch,
          isFromCache: true,
        );
        _branchDirectoryCache[cacheKey] = directory.copyWith(
          isFromCache: false,
        );
        return directory;
      }
      rethrow;
    }
  }

  Future<ProductSearchFilterOptions> fetchSearchFilterOptions({
    required AppUser actorUser,
    bool forceRefresh = false,
  }) async {
    _ensurePermission(actorUser, AppPermission.viewOwnInventory);
    final refreshScope = searchFiltersRefreshScope(actorUser: actorUser);
    final cached = _searchFilterOptionsCache;
    if (!forceRefresh && cached != null) {
      if (shouldRefreshData(
        type: InventoryRefreshDataType.searchFilters,
        scope: refreshScope,
      )) {
        _runBackgroundTask(
          () => fetchSearchFilterOptions(
            actorUser: actorUser,
            forceRefresh: true,
          ).then((_) {}),
        );
      }
      return cached.copyWith(isFromCache: true);
    }

    final branches = await _fetchBranchCatalog(forceRefresh: forceRefresh);
    final categories = await _fetchCategoryCatalog(forceRefresh: forceRefresh);
    final products = await _fetchProductCatalog(forceRefresh: forceRefresh);

    final visibleBranches = branches.data
        .where(
          (branch) => branch.isActive && actorUser.canAccessBranch(branch.id),
        )
        .toList(growable: false);
    final visibleCategories = categories.data
        .where((category) => category.isActive)
        .toList(growable: false);
    final brandLabels = <String, String>{};
    for (final product in products.data) {
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
    final options = ProductSearchFilterOptions(
      categories: visibleCategories,
      brands: brands,
      branches: visibleBranches,
      isFromCache:
          branches.isFromCache ||
          categories.isFromCache ||
          products.isFromCache,
    );
    _searchFilterOptionsCache = options.copyWith(isFromCache: false);
    markRefreshCompleted(
      type: InventoryRefreshDataType.searchFilters,
      scope: refreshScope,
    );
    return options;
  }

  List<Product> fetchRecentCachedProducts({required AppUser actorUser}) {
    _ensurePermission(actorUser, AppPermission.viewOwnInventory);
    return _offlineCache.getRecentProducts(actorUser.id);
  }

  Future<List<TransferRequestCatalogItem>> fetchTransferRequestCatalog({
    required AppUser actorUser,
    bool forceRefresh = false,
  }) async {
    _ensurePermission(actorUser, AppPermission.requestTransfer);
    final refreshScope = transferCatalogRefreshScope(actorUser: actorUser);
    if (!forceRefresh) {
      final cached = _transferCatalogCache[refreshScope];
      if (cached != null) {
        if (shouldRefreshData(
          type: InventoryRefreshDataType.transferCatalog,
          scope: refreshScope,
        )) {
          _runBackgroundTask(
            () => fetchTransferRequestCatalog(
              actorUser: actorUser,
              forceRefresh: true,
            ).then((_) {}),
          );
        }
        return List<TransferRequestCatalogItem>.unmodifiable(cached);
      }
    }

    final products = await _fetchProductCatalog(forceRefresh: forceRefresh);
    final branchInventory = await _fetchBranchInventory(actorUser.branchId);
    final inventoryByProductId = {
      for (final item in branchInventory.data.where((item) => item.isActive))
        item.productId: item,
    };

    final items =
        products.data
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

    final immutableItems = List<TransferRequestCatalogItem>.unmodifiable(items);
    _transferCatalogCache[refreshScope] = immutableItems;
    markRefreshCompleted(
      type: InventoryRefreshDataType.transferCatalog,
      scope: refreshScope,
    );
    return immutableItems;
  }

  Future<List<ReservationRequestCatalogItem>> fetchReservationRequestCatalog({
    required AppUser actorUser,
    bool forceRefresh = false,
  }) async {
    _ensurePermission(actorUser, AppPermission.createReservation);
    final refreshScope = reservationCatalogRefreshScope(actorUser: actorUser);
    if (!forceRefresh) {
      final cached = _reservationCatalogCache[refreshScope];
      if (cached != null) {
        if (shouldRefreshData(
          type: InventoryRefreshDataType.reservationCatalog,
          scope: refreshScope,
        )) {
          _runBackgroundTask(
            () => fetchReservationRequestCatalog(
              actorUser: actorUser,
              forceRefresh: true,
            ).then((_) {}),
          );
        }
        return List<ReservationRequestCatalogItem>.unmodifiable(cached);
      }
    }

    final products = await _fetchProductCatalog(forceRefresh: forceRefresh);
    final branchInventory = await _fetchBranchInventory(actorUser.branchId);
    final inventoryByProductId = {
      for (final item in branchInventory.data.where((item) => item.isActive))
        item.productId: item,
    };

    final items =
        products.data
            .where((product) => product.isActive)
            .map(
              (product) => ReservationRequestCatalogItem(
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

    final immutableItems = List<ReservationRequestCatalogItem>.unmodifiable(
      items,
    );
    _reservationCatalogCache[refreshScope] = immutableItems;
    markRefreshCompleted(
      type: InventoryRefreshDataType.reservationCatalog,
      scope: refreshScope,
    );
    return immutableItems;
  }

  Future<TransferTraceabilityData> fetchTransferTraceability({
    required AppUser actorUser,
    required String transferId,
  }) async {
    final transfer = await transfers.fetchTransfer(transferId);
    if (transfer == null) {
      throw const InventoryException('El traslado solicitado no existe.');
    }

    final canInspect =
        actorUser.role == UserRole.admin ||
        actorUser.canAccessBranch(transfer.fromBranchId) ||
        actorUser.canAccessBranch(transfer.toBranchId);
    if (!canInspect) {
      throw const InventoryException(
        'No tienes permiso para revisar la trazabilidad de este traslado.',
      );
    }

    final requesterFuture =
        actorUser.role == UserRole.admin || actorUser.id == transfer.requestedBy
        ? users.fetchUser(transfer.requestedBy)
        : Future<AppUser?>.value(null);
    final approverFuture =
        actorUser.role == UserRole.admin && transfer.approvedBy != null
        ? users.fetchUser(transfer.approvedBy!)
        : Future<AppUser?>.value(null);
    final auditTrailFuture = actorUser.role == UserRole.admin
        ? system.fetchAuditLogsForEntity(
            entityId: transfer.id,
            entityType: 'transfer',
          )
        : Future<List<AuditLog>>.value(const <AuditLog>[]);

    final results = await Future.wait<Object?>([
      requesterFuture,
      approverFuture,
      inventories.fetchInventory(transfer.fromBranchId, transfer.productId),
      inventories.fetchInventory(transfer.toBranchId, transfer.productId),
      auditTrailFuture,
    ]);

    return TransferTraceabilityData(
      transfer: transfer,
      requesterUser: results[0] as AppUser?,
      approverUser: results[1] as AppUser?,
      sourceInventory: results[2] as InventoryItem?,
      destinationInventory: results[3] as InventoryItem?,
      auditTrail: List<AuditLog>.unmodifiable(results[4] as List<AuditLog>),
    );
  }

  Future<ReservationTraceabilityData> fetchReservationTraceability({
    required AppUser actorUser,
    required String reservationId,
  }) async {
    final reservation = await reservations.fetchReservation(reservationId);
    if (reservation == null) {
      throw const InventoryException('La reserva solicitada no existe.');
    }

    final canInspect =
        actorUser.role == UserRole.admin ||
        actorUser.canAccessBranch(reservation.branchId) ||
        actorUser.id == reservation.reservedBy;
    if (!canInspect) {
      throw const InventoryException(
        'No tienes permiso para revisar la trazabilidad de esta reserva.',
      );
    }

    final requesterFuture =
        actorUser.role == UserRole.admin ||
            actorUser.id == reservation.reservedBy
        ? users.fetchUser(reservation.reservedBy)
        : Future<AppUser?>.value(null);
    final auditTrailFuture = actorUser.role == UserRole.admin
        ? system.fetchAuditLogsForEntity(
            entityId: reservation.id,
            entityType: 'reservation',
          )
        : Future<List<AuditLog>>.value(const <AuditLog>[]);

    final results = await Future.wait<Object?>([
      requesterFuture,
      inventories.fetchInventory(reservation.branchId, reservation.productId),
      auditTrailFuture,
    ]);

    return ReservationTraceabilityData(
      reservation: reservation,
      requesterUser: results[0] as AppUser?,
      branchInventory: results[1] as InventoryItem?,
      auditTrail: List<AuditLog>.unmodifiable(results[2] as List<AuditLog>),
    );
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

  Stream<ApprovalQueueData> watchApprovalQueue({required AppUser actorUser}) {
    final canReviewTransfers = actorUser.can(AppPermission.approveTransfer);
    final canReviewReservations = actorUser.can(
      AppPermission.approveReservation,
    );
    if (!canReviewTransfers && !canReviewReservations) {
      throw InventoryException(
        'El rol ${actorUser.role.displayName} no tiene permiso para revisar solicitudes pendientes.',
      );
    }

    final controller = StreamController<ApprovalQueueData>();
    var reservationsState = const <Reservation>[];
    var transfersState = const <TransferRequest>[];
    var reservationsReady = false;
    var transfersReady = false;
    var subscriptions = <StreamSubscription<Object?>>[];

    Iterable<Reservation> filterReservations() {
      return reservationsState.where((item) {
        if (item.status != ReservationStatus.pending) {
          return false;
        }
        if (actorUser.role == UserRole.admin) {
          return true;
        }
        return item.branchId == actorUser.branchId;
      });
    }

    Iterable<TransferRequest> filterTransfers() {
      return transfersState.where((item) {
        if (item.status != TransferStatus.pending) {
          return false;
        }
        if (actorUser.role == UserRole.admin) {
          return true;
        }
        return item.fromBranchId == actorUser.branchId;
      });
    }

    void emit() {
      if (controller.isClosed || !reservationsReady || !transfersReady) {
        return;
      }

      final pendingReservations = filterReservations().toList(growable: false)
        ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
      final pendingTransfers = filterTransfers().toList(growable: false)
        ..sort((left, right) => right.requestedAt.compareTo(left.requestedAt));

      controller.add(
        ApprovalQueueData(
          pendingReservations: List<Reservation>.unmodifiable(
            pendingReservations,
          ),
          pendingTransfers: List<TransferRequest>.unmodifiable(
            pendingTransfers,
          ),
          scopeLabel: actorUser.role == UserRole.admin
              ? 'Todas las sucursales'
              : actorUser.branchId,
          scopeIsGlobal: actorUser.role == UserRole.admin,
        ),
      );
    }

    controller.onListen = () {
      if (subscriptions.isNotEmpty) {
        return;
      }

      subscriptions = <StreamSubscription<Object?>>[
        reservations.watchReservations().listen((items) {
          reservationsState = items;
          reservationsReady = true;
          emit();
        }, onError: controller.addError),
        transfers.watchTransfers().listen((items) {
          transfersState = items;
          transfersReady = true;
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

  Stream<List<AppNotification>> watchNotifications({
    required AppUser actorUser,
    int limit = 40,
  }) {
    _ensurePermission(actorUser, AppPermission.viewNotifications);
    return system.watchNotifications(actorUser.id, limit: limit);
  }

  Future<void> markNotificationAsRead({
    required AppUser actorUser,
    required String notificationId,
  }) async {
    _ensurePermission(actorUser, AppPermission.viewNotifications);

    final notificationSnapshot = await _notificationsCollection
        .doc(notificationId)
        .get();
    if (!notificationSnapshot.exists) {
      throw const InventoryException('La notificacion no existe.');
    }

    final notification = AppNotification.fromFirestore(
      notificationSnapshot.id,
      notificationSnapshot.data()!,
    );
    if (notification.userId != actorUser.id) {
      throw const InventoryException(
        'No puedes modificar notificaciones de otro usuario.',
      );
    }

    if (notification.isRead) {
      return;
    }

    await system.markNotificationAsRead(notificationId);
  }

  Future<int> markAllNotificationsAsRead({required AppUser actorUser}) async {
    _ensurePermission(actorUser, AppPermission.viewNotifications);
    return system.markAllNotificationsAsRead(actorUser.id);
  }

  Future<StockAlertFeedData> fetchLowStockAlerts({
    required AppUser actorUser,
  }) async {
    _ensurePermission(actorUser, AppPermission.viewLowStock);

    final inventoryItems = actorUser.role == UserRole.admin
        ? await inventories.fetchInventories()
        : await inventories.fetchBranchInventory(actorUser.branchId);
    final products = await catalog.fetchProducts();
    final categories = await catalog.fetchCategories();
    final readStates = await system.fetchStockAlertReadStates(actorUser.id);

    return _buildStockAlertFeedData(
      inventoryItems: inventoryItems,
      products: products,
      categories: categories,
      readStates: readStates,
    );
  }

  Stream<StockAlertFeedData> watchLowStockAlerts({required AppUser actorUser}) {
    _ensurePermission(actorUser, AppPermission.viewLowStock);

    final inventoryStream = actorUser.role == UserRole.admin
        ? inventories.watchInventories()
        : inventories.watchBranchInventory(actorUser.branchId);
    final controller = StreamController<StockAlertFeedData>();
    var inventoryState = const <InventoryItem>[];
    var productsState = const <Product>[];
    var categoriesState = const <Category>[];
    var readStatesState = const <StockAlertReadState>[];
    var inventoryReady = false;
    var productsReady = false;
    var categoriesReady = false;
    var readStatesReady = false;
    var subscriptions = <StreamSubscription<Object?>>[];

    void emit() {
      if (controller.isClosed ||
          !inventoryReady ||
          !productsReady ||
          !categoriesReady ||
          !readStatesReady) {
        return;
      }

      controller.add(
        _buildStockAlertFeedData(
          inventoryItems: inventoryState,
          products: productsState,
          categories: categoriesState,
          readStates: readStatesState,
        ),
      );
    }

    controller.onListen = () {
      if (subscriptions.isNotEmpty) {
        return;
      }

      subscriptions = <StreamSubscription<Object?>>[
        inventoryStream.listen((items) {
          inventoryState = items;
          inventoryReady = true;
          emit();
        }, onError: controller.addError),
        catalog.watchProducts().listen((items) {
          productsState = items;
          productsReady = true;
          emit();
        }, onError: controller.addError),
        catalog.watchCategories().listen((items) {
          categoriesState = items;
          categoriesReady = true;
          emit();
        }, onError: controller.addError),
        system.watchStockAlertReadStates(actorUser.id).listen((items) {
          readStatesState = items;
          readStatesReady = true;
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

  Future<void> markStockAlertAsRead({
    required AppUser actorUser,
    required StockAlertItem alert,
  }) async {
    _ensurePermission(actorUser, AppPermission.viewLowStock);
    if (actorUser.role != UserRole.admin) {
      _ensureBranchAccess(actorUser, alert.branchId);
    }

    final readState = StockAlertReadState(
      id: _stockAlertReadStateId(actorUser.id, alert.id),
      userId: actorUser.id,
      alertId: alert.id,
      branchId: alert.branchId,
      productId: alert.productId,
      alertUpdatedAt: alert.updatedAt,
      readAt: _clock(),
    );
    await system.upsertStockAlertReadState(readState);
  }

  Future<int> markAllStockAlertsAsRead({
    required AppUser actorUser,
    required List<StockAlertItem> alerts,
  }) async {
    _ensurePermission(actorUser, AppPermission.viewLowStock);

    final unreadAlerts = alerts
        .where((item) => !item.isRead)
        .toList(growable: false);
    if (unreadAlerts.isEmpty) {
      return 0;
    }

    final now = _clock();
    await Future.wait(
      unreadAlerts.map((alert) {
        if (actorUser.role != UserRole.admin) {
          _ensureBranchAccess(actorUser, alert.branchId);
        }
        return system.upsertStockAlertReadState(
          StockAlertReadState(
            id: _stockAlertReadStateId(actorUser.id, alert.id),
            userId: actorUser.id,
            alertId: alert.id,
            branchId: alert.branchId,
            productId: alert.productId,
            alertUpdatedAt: alert.updatedAt,
            readAt: now,
          ),
        );
      }),
    );
    return unreadAlerts.length;
  }

  Future<SyncStatusOverview> fetchSyncStatusOverview({
    required AppUser actorUser,
  }) async {
    _ensurePermission(actorUser, AppPermission.viewSyncStatus);

    final branches = await catalog.fetchBranches();
    final syncLogs = await system.fetchRecentSyncLogs(
      limit: _syncStatusLogLimit,
    );

    return _buildSyncStatusOverview(
      branches: branches,
      syncLogs: syncLogs,
      currentBranchId: actorUser.branchId,
    );
  }

  Stream<SyncStatusOverview> watchSyncStatus({required AppUser actorUser}) {
    _ensurePermission(actorUser, AppPermission.viewSyncStatus);

    final controller = StreamController<SyncStatusOverview>();
    var branchesState = const <Branch>[];
    var syncLogsState = const <SyncLog>[];
    var branchesReady = false;
    var syncLogsReady = false;
    var subscriptions = <StreamSubscription<Object?>>[];
    Timer? ticker;

    void emit() {
      if (controller.isClosed || !branchesReady || !syncLogsReady) {
        return;
      }

      controller.add(
        _buildSyncStatusOverview(
          branches: branchesState,
          syncLogs: syncLogsState,
          currentBranchId: actorUser.branchId,
        ),
      );
    }

    controller.onListen = () {
      if (subscriptions.isNotEmpty) {
        return;
      }

      subscriptions = <StreamSubscription<Object?>>[
        catalog.watchBranches().listen((items) {
          branchesState = items;
          branchesReady = true;
          emit();
        }, onError: controller.addError),
        system.watchRecentSyncLogs(limit: _syncStatusLogLimit).listen((items) {
          syncLogsState = items;
          syncLogsReady = true;
          emit();
        }, onError: controller.addError),
      ];
      ticker = Timer.periodic(_syncStatusTick, (_) => emit());
    };

    controller.onCancel = () async {
      ticker?.cancel();
      ticker = null;
      final currentSubscriptions = subscriptions;
      subscriptions = <StreamSubscription<Object?>>[];
      for (final subscription in currentSubscriptions) {
        await subscription.cancel();
      }
    };

    return controller.stream;
  }

  Stream<List<RequestTrackingItem>> watchRequestTracking({
    required AppUser actorUser,
  }) {
    _ensurePermission(actorUser, AppPermission.viewRequestTracking);

    final reservationStream = actorUser.role == UserRole.admin
        ? reservations.watchReservations()
        : actorUser.role == UserRole.supervisor
        ? reservations.watchReservationsForBranchTracking(actorUser.branchId)
        : reservations.watchReservationsByUser(actorUser.id);
    final transferStream = actorUser.role == UserRole.admin
        ? transfers.watchTransfers()
        : transfers.watchTransfersForBranch(actorUser.branchId);

    final controller = StreamController<List<RequestTrackingItem>>();
    var reservationsState = const <Reservation>[];
    var transfersState = const <TransferRequest>[];
    var reservationsReady = false;
    var transfersReady = false;
    var subscriptions = <StreamSubscription<Object?>>[];

    void emit() {
      if (controller.isClosed || !reservationsReady || !transfersReady) {
        return;
      }

      final items = <RequestTrackingItem>[
        ...reservationsState
            .where((item) => _canTrackReservation(actorUser, item))
            .map(_buildReservationTrackingItem),
        ...transfersState
            .where((item) => _canTrackTransfer(actorUser, item))
            .map(_buildTransferTrackingItem),
      ]..sort((left, right) => right.lastStatusAt.compareTo(left.lastStatusAt));

      controller.add(List<RequestTrackingItem>.unmodifiable(items));
    }

    controller.onListen = () {
      if (subscriptions.isNotEmpty) {
        return;
      }

      subscriptions = <StreamSubscription<Object?>>[
        reservationStream.listen((items) {
          reservationsState = items;
          reservationsReady = true;
          emit();
        }, onError: controller.addError),
        transferStream.listen((items) {
          transfersState = items;
          transfersReady = true;
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

  bool _canTrackReservation(AppUser actorUser, Reservation reservation) {
    if (actorUser.role == UserRole.admin) {
      return true;
    }
    if (actorUser.role == UserRole.supervisor) {
      return reservation.branchId == actorUser.branchId ||
          reservation.requestingBranchId == actorUser.branchId ||
          reservation.reservedBy == actorUser.id;
    }
    return reservation.reservedBy == actorUser.id;
  }

  bool _canTrackTransfer(AppUser actorUser, TransferRequest transfer) {
    if (actorUser.role == UserRole.admin) {
      return true;
    }
    if (actorUser.role == UserRole.supervisor) {
      return transfer.fromBranchId == actorUser.branchId ||
          transfer.toBranchId == actorUser.branchId ||
          transfer.requestedBy == actorUser.id;
    }
    return transfer.requestedBy == actorUser.id;
  }

  RequestTrackingItem _buildReservationTrackingItem(Reservation reservation) {
    final requestingBranch = reservation.requestingBranchName.isNotEmpty
        ? reservation.requestingBranchName
        : reservation.requestingBranchId;

    return RequestTrackingItem(
      id: reservation.id,
      type: RequestTrackingType.reservation,
      productId: reservation.productId,
      productName: reservation.productName,
      sku: reservation.sku,
      quantity: reservation.quantity,
      status: _mapReservationTrackingStatus(reservation.status),
      requestedAt: reservation.createdAt,
      updatedAt: reservation.updatedAt,
      primaryBranchName: reservation.branchName,
      secondaryBranchName: requestingBranch,
      requesterLabel: reservation.requestedByName.isNotEmpty
          ? reservation.requestedByName
          : reservation.reservedBy,
      customerLabel: reservation.customerName,
      reasonLabel: requestingBranch.isEmpty
          ? 'Solicitud de reserva'
          : 'Solicita desde $requestingBranch',
      reviewComment: reservation.reviewComment,
      history: List<RequestStatusHistoryEntry>.unmodifiable(
        _buildReservationHistory(reservation),
      ),
    );
  }

  RequestTrackingItem _buildTransferTrackingItem(TransferRequest transfer) {
    return RequestTrackingItem(
      id: transfer.id,
      type: RequestTrackingType.transfer,
      productId: transfer.productId,
      productName: transfer.productName,
      sku: transfer.sku,
      quantity: transfer.quantity,
      status: _mapTransferTrackingStatus(transfer.status),
      requestedAt: transfer.requestedAt,
      updatedAt: transfer.updatedAt,
      primaryBranchName: transfer.fromBranchName,
      secondaryBranchName: transfer.toBranchName,
      requesterLabel: transfer.requestedByName.isNotEmpty
          ? transfer.requestedByName
          : transfer.requestedBy,
      customerLabel: '',
      reasonLabel: transfer.reason,
      reviewComment: transfer.reviewComment,
      history: List<RequestStatusHistoryEntry>.unmodifiable(
        _buildTransferHistory(transfer),
      ),
    );
  }

  RequestTrackingStatus _mapReservationTrackingStatus(
    ReservationStatus status,
  ) {
    return switch (status) {
      ReservationStatus.pending => RequestTrackingStatus.pending,
      ReservationStatus.active => RequestTrackingStatus.approved,
      ReservationStatus.rejected => RequestTrackingStatus.rejected,
      ReservationStatus.completed => RequestTrackingStatus.completed,
      ReservationStatus.cancelled => RequestTrackingStatus.cancelled,
      ReservationStatus.expired => RequestTrackingStatus.expired,
    };
  }

  RequestTrackingStatus _mapTransferTrackingStatus(TransferStatus status) {
    return switch (status) {
      TransferStatus.pending => RequestTrackingStatus.pending,
      TransferStatus.approved => RequestTrackingStatus.approved,
      TransferStatus.rejected => RequestTrackingStatus.rejected,
      TransferStatus.inTransit => RequestTrackingStatus.inTransit,
      TransferStatus.received => RequestTrackingStatus.received,
      TransferStatus.cancelled => RequestTrackingStatus.cancelled,
    };
  }

  List<RequestStatusHistoryEntry> _buildReservationHistory(
    Reservation reservation,
  ) {
    final history = <RequestStatusHistoryEntry>[
      RequestStatusHistoryEntry(
        status: RequestTrackingStatus.pending,
        title: 'Solicitud creada',
        detail:
            '${reservation.quantity} unidad(es) para ${reservation.customerName} en ${reservation.branchName}.',
        occurredAt: reservation.createdAt,
      ),
    ];

    if (reservation.approvedAt != null) {
      history.add(
        RequestStatusHistoryEntry(
          status: RequestTrackingStatus.approved,
          title: 'Solicitud aprobada',
          detail: reservation.reviewComment.trim().isEmpty
              ? 'La reserva fue aprobada para comprometer stock real.'
              : reservation.reviewComment,
          occurredAt: reservation.approvedAt!,
        ),
      );
    }

    if (reservation.rejectedAt != null) {
      history.add(
        RequestStatusHistoryEntry(
          status: RequestTrackingStatus.rejected,
          title: 'Solicitud rechazada',
          detail: reservation.reviewComment.trim().isEmpty
              ? 'La solicitud fue rechazada por la sucursal destino.'
              : reservation.reviewComment,
          occurredAt: reservation.rejectedAt!,
        ),
      );
    }

    if (reservation.status == ReservationStatus.completed) {
      history.add(
        RequestStatusHistoryEntry(
          status: RequestTrackingStatus.completed,
          title: 'Reserva completada',
          detail: 'El compromiso quedo cerrado despues de la entrega.',
          occurredAt: reservation.updatedAt,
        ),
      );
    } else if (reservation.status == ReservationStatus.cancelled) {
      history.add(
        RequestStatusHistoryEntry(
          status: RequestTrackingStatus.cancelled,
          title: 'Reserva cancelada',
          detail: 'La reserva fue cancelada y el stock se libero.',
          occurredAt: reservation.updatedAt,
        ),
      );
    } else if (reservation.status == ReservationStatus.expired) {
      history.add(
        RequestStatusHistoryEntry(
          status: RequestTrackingStatus.expired,
          title: 'Reserva vencida',
          detail:
              'La solicitud expiro sin concretarse dentro del tiempo limite.',
          occurredAt: reservation.updatedAt,
        ),
      );
    }

    history.sort((left, right) => left.occurredAt.compareTo(right.occurredAt));
    return history;
  }

  List<RequestStatusHistoryEntry> _buildTransferHistory(
    TransferRequest transfer,
  ) {
    final history = <RequestStatusHistoryEntry>[
      RequestStatusHistoryEntry(
        status: RequestTrackingStatus.pending,
        title: 'Solicitud creada',
        detail:
            '${transfer.fromBranchName} -> ${transfer.toBranchName} | ${transfer.quantity} unidad(es).',
        occurredAt: transfer.requestedAt,
      ),
    ];

    if (transfer.approvedAt != null) {
      history.add(
        RequestStatusHistoryEntry(
          status: RequestTrackingStatus.approved,
          title: 'Solicitud aprobada',
          detail: transfer.reviewComment.trim().isEmpty
              ? 'El traslado quedo listo para despacho.'
              : transfer.reviewComment,
          occurredAt: transfer.approvedAt!,
        ),
      );
    }

    if (transfer.rejectedAt != null) {
      history.add(
        RequestStatusHistoryEntry(
          status: RequestTrackingStatus.rejected,
          title: 'Solicitud rechazada',
          detail: transfer.reviewComment.trim().isEmpty
              ? 'La sucursal origen rechazo la solicitud.'
              : transfer.reviewComment,
          occurredAt: transfer.rejectedAt!,
        ),
      );
    }

    if (transfer.shippedAt != null) {
      history.add(
        RequestStatusHistoryEntry(
          status: RequestTrackingStatus.inTransit,
          title: 'Traslado en transito',
          detail:
              'La mercancia fue despachada desde ${transfer.fromBranchName}.',
          occurredAt: transfer.shippedAt!,
        ),
      );
    }

    if (transfer.receivedAt != null) {
      history.add(
        RequestStatusHistoryEntry(
          status: RequestTrackingStatus.received,
          title: 'Traslado recibido',
          detail: 'La sucursal ${transfer.toBranchName} confirmo la recepcion.',
          occurredAt: transfer.receivedAt!,
        ),
      );
    }

    history.sort((left, right) => left.occurredAt.compareTo(right.occurredAt));
    return history;
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
    InventoryItem? previousInventory;

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
      previousInventory = inventory;
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
    await _handleLowStockAlertTransition(
      previousInventory: previousInventory,
      updatedInventory: updatedInventory,
    );
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

    if (quantity <= 0) {
      throw const InventoryException(
        'La cantidad reservada debe ser mayor que cero.',
      );
    }
    final normalizedCustomerName = customerName.trim();
    if (normalizedCustomerName.isEmpty) {
      throw const InventoryException(
        'Debes asociar la reserva a un cliente o referencia comercial.',
      );
    }

    final now = _clock();
    final expiresAt = now.add(expiresIn);
    final requestingBranch = await catalog.fetchBranch(actorUser.branchId);
    final inventoryRef = _inventoriesCollection.doc(
      inventories.inventoryId(branchId, productId),
    );
    final reservationRef = _reservationsCollection.doc();
    final auditLogRef = _auditLogsCollection.doc();

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

      final reservation = Reservation(
        id: reservationRef.id,
        productId: inventory.productId,
        productName: inventory.productName,
        sku: inventory.sku,
        branchId: inventory.branchId,
        branchName: inventory.branchName,
        requestingBranchId: actorUser.branchId,
        requestingBranchName: requestingBranch?.name.isNotEmpty == true
            ? requestingBranch!.name
            : actorUser.branchId,
        customerName: normalizedCustomerName,
        customerPhone: customerPhone.trim(),
        quantity: quantity,
        status: ReservationStatus.pending,
        reservedBy: actorUser.id,
        requestedByName: actorUser.fullName,
        expiresAt: expiresAt,
        createdAt: now,
        updatedAt: now,
      );
      final auditLog = _buildAuditLog(
        actorUser: actorUser,
        action: 'reservation_created',
        entityType: 'reservation',
        entityId: reservation.id,
        entityLabel: reservation.productName,
        message: 'Registro una solicitud de reserva para',
        metadata: {
          'reservationBranchId': reservation.branchId,
          'reservationBranchName': reservation.branchName,
          'quantity': '${reservation.quantity}',
          'customerName': reservation.customerName,
          'requestingBranchId': actorUser.branchId,
          'requestingBranchName': reservation.requestingBranchName,
          'status': reservation.status.name,
        },
        branchId: reservation.branchId,
        branchName: reservation.branchName,
      );

      transaction.set(reservationRef, reservation.toFirestore());
      transaction.set(auditLogRef, auditLog.toFirestore());

      return reservation;
    });
    _invalidateProductCaches(productId);
    return reservation;
  }

  Future<Reservation> approveReservation({
    required AppUser actorUser,
    required String reservationId,
    String reviewComment = '',
  }) async {
    _ensurePermission(actorUser, AppPermission.approveReservation);

    final now = _clock();
    final normalizedComment = reviewComment.trim();
    final reservationRef = _reservationsCollection.doc(reservationId);
    final notificationRef = _notificationsCollection.doc();
    final auditLogRef = _auditLogsCollection.doc();
    InventoryItem? previousInventory;
    InventoryItem? updatedInventory;

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

      if (reservation.status != ReservationStatus.pending) {
        throw InventoryException(
          'Solo se pueden aprobar reservas pendientes. Estado actual: ${reservation.status.name}.',
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
      previousInventory = inventory;
      if (!inventory.isActive) {
        throw const InventoryException('El inventario se encuentra inactivo.');
      }
      if (inventory.availableStock < reservation.quantity) {
        throw InventoryException(
          'Stock insuficiente para aprobar la reserva. Disponible: ${inventory.availableStock}.',
        );
      }

      updatedInventory = inventory.recalculate(
        reservedStock: inventory.reservedStock + reservation.quantity,
        updatedBy: actorUser.id,
        updatedAt: now,
        lastMovementAt: now,
      );
      final updatedReservation = reservation.copyWith(
        status: ReservationStatus.active,
        approvedBy: actorUser.id,
        approvedAt: now,
        reviewComment: normalizedComment,
        updatedAt: now,
      );
      final notification = AppNotification(
        id: notificationRef.id,
        userId: reservation.reservedBy,
        title: 'Reserva aprobada',
        message:
            'La solicitud ${reservation.id} fue aprobada en ${reservation.branchName}.${normalizedComment.isNotEmpty ? ' Nota: $normalizedComment' : ''}',
        type: 'reservation',
        referenceId: reservation.id,
        isRead: false,
        createdAt: now,
      );
      final auditLog = _buildAuditLog(
        actorUser: actorUser,
        action: 'reservation_approved',
        entityType: 'reservation',
        entityId: updatedReservation.id,
        entityLabel: updatedReservation.productName,
        message: 'Aprobo la solicitud de reserva para',
        metadata: {
          'status': updatedReservation.status.name,
          'reservationBranchId': updatedReservation.branchId,
          'reservationBranchName': updatedReservation.branchName,
          'quantity': '${updatedReservation.quantity}',
          'customerName': updatedReservation.customerName,
          'requestingBranchId': updatedReservation.requestingBranchId,
          'requestingBranchName': updatedReservation.requestingBranchName,
          if (normalizedComment.isNotEmpty) 'reviewComment': normalizedComment,
          'approvedByUserId': actorUser.id,
        },
        branchId: updatedReservation.branchId,
        branchName: updatedReservation.branchName,
      );

      transaction.set(inventoryRef, updatedInventory!.toFirestore());
      transaction.set(reservationRef, updatedReservation.toFirestore());
      transaction.set(notificationRef, notification.toFirestore());
      transaction.set(auditLogRef, auditLog.toFirestore());

      return updatedReservation;
    });
    if (updatedInventory != null) {
      await _handleLowStockAlertTransition(
        previousInventory: previousInventory,
        updatedInventory: updatedInventory!,
      );
    }
    _invalidateProductCaches(updatedReservation.productId);
    return updatedReservation;
  }

  Future<Reservation> rejectReservation({
    required AppUser actorUser,
    required String reservationId,
    required String reviewComment,
  }) async {
    _ensurePermission(actorUser, AppPermission.approveReservation);

    final normalizedComment = reviewComment.trim();
    if (normalizedComment.isEmpty) {
      throw const InventoryException(
        'Debes registrar un motivo para rechazar la reserva.',
      );
    }

    final now = _clock();
    final reservationRef = _reservationsCollection.doc(reservationId);
    final notificationRef = _notificationsCollection.doc();
    final auditLogRef = _auditLogsCollection.doc();

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

      if (reservation.status != ReservationStatus.pending) {
        throw InventoryException(
          'Solo se pueden rechazar reservas pendientes. Estado actual: ${reservation.status.name}.',
        );
      }

      final updatedReservation = reservation.copyWith(
        status: ReservationStatus.rejected,
        rejectedBy: actorUser.id,
        rejectedAt: now,
        reviewComment: normalizedComment,
        updatedAt: now,
      );
      final notification = AppNotification(
        id: notificationRef.id,
        userId: reservation.reservedBy,
        title: 'Reserva rechazada',
        message:
            'La solicitud ${reservation.id} fue rechazada en ${reservation.branchName}. Motivo: $normalizedComment',
        type: 'reservation',
        referenceId: reservation.id,
        isRead: false,
        createdAt: now,
      );
      final auditLog = _buildAuditLog(
        actorUser: actorUser,
        action: 'reservation_rejected',
        entityType: 'reservation',
        entityId: updatedReservation.id,
        entityLabel: updatedReservation.productName,
        message: 'Rechazo la solicitud de reserva para',
        metadata: {
          'status': updatedReservation.status.name,
          'reservationBranchId': updatedReservation.branchId,
          'reservationBranchName': updatedReservation.branchName,
          'quantity': '${updatedReservation.quantity}',
          'customerName': updatedReservation.customerName,
          'requestingBranchId': updatedReservation.requestingBranchId,
          'requestingBranchName': updatedReservation.requestingBranchName,
          'reviewComment': normalizedComment,
          'rejectedByUserId': actorUser.id,
        },
        branchId: updatedReservation.branchId,
        branchName: updatedReservation.branchName,
      );

      transaction.set(reservationRef, updatedReservation.toFirestore());
      transaction.set(notificationRef, notification.toFirestore());
      transaction.set(auditLogRef, auditLog.toFirestore());

      return updatedReservation;
    });
    _invalidateProductCaches(updatedReservation.productId);
    return updatedReservation;
  }

  Future<Reservation> updateReservationStatus({
    required AppUser actorUser,
    required String reservationId,
    required ReservationStatus nextStatus,
  }) async {
    _ensurePermission(actorUser, AppPermission.updateReservation);

    if (nextStatus == ReservationStatus.active) {
      throw const InventoryException(
        'Las reservas pendientes se aprueban desde la bandeja de solicitudes.',
      );
    }
    if (nextStatus == ReservationStatus.pending ||
        nextStatus == ReservationStatus.rejected) {
      throw const InventoryException(
        'Ese estado se gestiona desde la bandeja de aprobaciones.',
      );
    }

    final now = _clock();
    final reservationRef = _reservationsCollection.doc(reservationId);
    InventoryItem? previousInventory;
    InventoryItem? updatedInventory;

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
      final canManageReservation =
          actorUser.canAccessBranch(reservation.branchId) ||
          actorUser.id == reservation.reservedBy;
      if (!canManageReservation) {
        throw const InventoryException(
          'No puedes operar esta reserva desde una sucursal diferente.',
        );
      }

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
      previousInventory = inventory;
      final updatedReservedStock =
          inventory.reservedStock - reservation.quantity;
      if (updatedReservedStock < 0) {
        throw const InventoryException(
          'La reserva no puede liberar mas stock del que esta reservado.',
        );
      }

      updatedInventory = inventory.recalculate(
        reservedStock: updatedReservedStock,
        updatedBy: actorUser.id,
        updatedAt: now,
        lastMovementAt: now,
      );
      final updatedReservation = reservation.copyWith(
        status: nextStatus,
        updatedAt: now,
      );
      final auditLog = _buildAuditLog(
        actorUser: actorUser,
        action: switch (nextStatus) {
          ReservationStatus.pending => 'reservation_updated',
          ReservationStatus.active => 'reservation_updated',
          ReservationStatus.rejected => 'reservation_updated',
          ReservationStatus.completed => 'reservation_completed',
          ReservationStatus.cancelled => 'reservation_cancelled',
          ReservationStatus.expired => 'reservation_expired',
        },
        entityType: 'reservation',
        entityId: updatedReservation.id,
        entityLabel: updatedReservation.productName,
        message: 'Actualizo el estado de la reserva para',
        metadata: {
          'status': nextStatus.name,
          'reservationBranchId': updatedReservation.branchId,
          'customerName': updatedReservation.customerName,
        },
        branchId: updatedReservation.branchId,
        branchName: updatedReservation.branchName,
      );
      final auditLogRef = _auditLogsCollection.doc();

      transaction.set(inventoryRef, updatedInventory!.toFirestore());
      transaction.set(reservationRef, updatedReservation.toFirestore());
      transaction.set(auditLogRef, auditLog.toFirestore());

      return updatedReservation;
    });
    if (updatedInventory != null) {
      await _handleLowStockAlertTransition(
        previousInventory: previousInventory,
        updatedInventory: updatedInventory!,
      );
    }
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
    final auditLogRef = _auditLogsCollection.doc();
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
      requestedByName: actorUser.fullName,
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
    final auditLog = _buildTransferAuditLog(
      actorUser: actorUser,
      transfer: transfer,
      action: 'transfer_requested',
      message: 'Solicito un traslado para',
      branchId: transfer.toBranchId,
      branchName: transfer.toBranchName,
      extraMetadata: {
        'requestingBranchId': transfer.toBranchId,
        'requestingBranchName': transfer.toBranchName,
      },
    );

    final batch = _firestore.batch();
    batch.set(transferRef, transfer.toFirestore());
    batch.set(auditLogRef, auditLog.toFirestore());
    await batch.commit();
    _invalidateProductCaches(product.id);
    return transfer;
  }

  Future<TransferRequest> approveTransfer({
    required AppUser actorUser,
    required String transferId,
    String reviewComment = '',
  }) async {
    _ensurePermission(actorUser, AppPermission.approveTransfer);

    final now = _clock();
    final normalizedComment = reviewComment.trim();
    final transferRef = _transfersCollection.doc(transferId);
    final notificationRef = _notificationsCollection.doc();
    final auditLogRef = _auditLogsCollection.doc();
    InventoryItem? previousSourceInventory;
    InventoryItem? updatedSourceInventory;
    InventoryItem? previousDestinationInventory;
    InventoryItem? updatedDestinationInventory;

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
      previousSourceInventory = sourceInventory;
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
      previousDestinationInventory = destinationInventorySnapshot.exists
          ? destinationInventory
          : null;

      updatedSourceInventory = sourceInventory.recalculate(
        stock: sourceInventory.stock - transfer.quantity,
        updatedBy: actorUser.id,
        updatedAt: now,
        lastMovementAt: now,
      );
      updatedDestinationInventory = destinationInventory.recalculate(
        incomingStock: destinationInventory.incomingStock + transfer.quantity,
        updatedBy: actorUser.id,
        updatedAt: now,
        lastMovementAt: now,
      );
      final updatedTransfer = transfer.copyWith(
        status: TransferStatus.approved,
        approvedBy: actorUser.id,
        reviewComment: normalizedComment,
        approvedAt: now,
        updatedAt: now,
      );

      final notification = AppNotification(
        id: notificationRef.id,
        userId: transfer.requestedBy,
        title: 'Solicitud aprobada',
        message:
            'El traslado ${transfer.id} fue aprobado y quedo listo para despacho.${normalizedComment.isNotEmpty ? ' Nota: $normalizedComment' : ''}',
        type: 'transfer',
        referenceId: transfer.id,
        isRead: false,
        createdAt: now,
      );
      final auditLog = _buildTransferAuditLog(
        actorUser: actorUser,
        transfer: updatedTransfer,
        action: 'transfer_approved',
        message: 'Aprobo el traslado de',
        branchId: updatedTransfer.fromBranchId,
        branchName: updatedTransfer.fromBranchName,
        extraMetadata: {
          'approvedByUserId': actorUser.id,
          if (normalizedComment.isNotEmpty) 'reviewComment': normalizedComment,
        },
      );

      transaction.set(
        sourceInventoryRef,
        updatedSourceInventory!.toFirestore(),
      );
      transaction.set(
        destinationInventoryRef,
        updatedDestinationInventory!.toFirestore(),
        SetOptions(merge: true),
      );
      transaction.set(transferRef, updatedTransfer.toFirestore());
      transaction.set(notificationRef, notification.toFirestore());
      transaction.set(auditLogRef, auditLog.toFirestore());

      return updatedTransfer;
    });
    if (updatedSourceInventory != null) {
      await _handleLowStockAlertTransition(
        previousInventory: previousSourceInventory,
        updatedInventory: updatedSourceInventory!,
      );
    }
    if (updatedDestinationInventory != null) {
      await _handleLowStockAlertTransition(
        previousInventory: previousDestinationInventory,
        updatedInventory: updatedDestinationInventory!,
      );
    }
    _invalidateProductCaches(updatedTransfer.productId);
    return updatedTransfer;
  }

  Future<TransferRequest> rejectTransfer({
    required AppUser actorUser,
    required String transferId,
    required String reviewComment,
  }) async {
    _ensurePermission(actorUser, AppPermission.approveTransfer);

    final normalizedComment = reviewComment.trim();
    if (normalizedComment.isEmpty) {
      throw const InventoryException(
        'Debes registrar un motivo para rechazar el traslado.',
      );
    }

    final now = _clock();
    final transferRef = _transfersCollection.doc(transferId);
    final notificationRef = _notificationsCollection.doc();
    final auditLogRef = _auditLogsCollection.doc();

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
          'Solo se pueden rechazar traslados pendientes. Estado: ${transfer.status.firestoreValue}.',
        );
      }

      final updatedTransfer = transfer.copyWith(
        status: TransferStatus.rejected,
        rejectedBy: actorUser.id,
        rejectedAt: now,
        reviewComment: normalizedComment,
        updatedAt: now,
      );
      final notification = AppNotification(
        id: notificationRef.id,
        userId: transfer.requestedBy,
        title: 'Solicitud rechazada',
        message:
            'El traslado ${transfer.id} fue rechazado por ${transfer.fromBranchName}. Motivo: $normalizedComment',
        type: 'transfer',
        referenceId: transfer.id,
        isRead: false,
        createdAt: now,
      );
      final auditLog = _buildTransferAuditLog(
        actorUser: actorUser,
        transfer: updatedTransfer,
        action: 'transfer_rejected',
        message: 'Rechazo el traslado de',
        branchId: updatedTransfer.fromBranchId,
        branchName: updatedTransfer.fromBranchName,
        extraMetadata: {
          'rejectedByUserId': actorUser.id,
          'reviewComment': normalizedComment,
        },
      );

      transaction.set(transferRef, updatedTransfer.toFirestore());
      transaction.set(notificationRef, notification.toFirestore());
      transaction.set(auditLogRef, auditLog.toFirestore());

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
    final auditLogRef = _auditLogsCollection.doc();

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
      final auditLog = _buildTransferAuditLog(
        actorUser: actorUser,
        transfer: updatedTransfer,
        action: 'transfer_in_transit',
        message: 'Despacho el traslado de',
        branchId: updatedTransfer.fromBranchId,
        branchName: updatedTransfer.fromBranchName,
        extraMetadata: {'dispatchedByUserId': actorUser.id},
      );

      transaction.set(transferRef, updatedTransfer.toFirestore());
      transaction.set(auditLogRef, auditLog.toFirestore());
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
    final auditLogRef = _auditLogsCollection.doc();
    InventoryItem? previousInventory;
    InventoryItem? updatedInventory;

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
      previousInventory = destinationInventory;

      if (destinationInventory.incomingStock < transfer.quantity) {
        throw const InventoryException(
          'El inventario destino no tiene stock en camino suficiente para recibir.',
        );
      }

      updatedInventory = destinationInventory.recalculate(
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
      final auditLog = _buildTransferAuditLog(
        actorUser: actorUser,
        transfer: updatedTransfer,
        action: 'transfer_received',
        message: 'Recibio el traslado de',
        branchId: updatedTransfer.toBranchId,
        branchName: updatedTransfer.toBranchName,
        extraMetadata: {'receivedByUserId': actorUser.id},
      );

      transaction.set(destinationInventoryRef, updatedInventory!.toFirestore());
      transaction.set(transferRef, updatedTransfer.toFirestore());
      transaction.set(notificationRef, notification.toFirestore());
      transaction.set(auditLogRef, auditLog.toFirestore());

      return updatedTransfer;
    });
    if (updatedInventory != null) {
      await _handleLowStockAlertTransition(
        previousInventory: previousInventory,
        updatedInventory: updatedInventory!,
      );
    }
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

  StockAlertFeedData _buildStockAlertFeedData({
    required List<InventoryItem> inventoryItems,
    required List<Product> products,
    required List<Category> categories,
    required List<StockAlertReadState> readStates,
  }) {
    final productsById = <String, Product>{
      for (final product in products) product.id: product,
    };
    final categoriesById = <String, Category>{
      for (final category in categories) category.id: category,
    };
    final readStateByAlertId = <String, StockAlertReadState>{
      for (final readState in readStates) readState.alertId: readState,
    };

    final alerts =
        inventoryItems
            .map(
              (inventory) => _buildStockAlertItem(
                inventory: inventory,
                product: productsById[inventory.productId],
                category:
                    categoriesById[productsById[inventory.productId]
                        ?.categoryId],
                readState: readStateByAlertId[_stockAlertId(inventory)],
              ),
            )
            .whereType<StockAlertItem>()
            .toList(growable: false)
          ..sort(_compareStockAlerts);

    return StockAlertFeedData(
      alerts: List<StockAlertItem>.unmodifiable(alerts),
      generatedAt: _clock(),
    );
  }

  StockAlertItem? _buildStockAlertItem({
    required InventoryItem inventory,
    required Product? product,
    required Category? category,
    required StockAlertReadState? readState,
  }) {
    final resolvedThreshold = _resolveLowStockThreshold(
      inventory: inventory,
      category: category,
    );
    if (resolvedThreshold == null ||
        resolvedThreshold <= 0 ||
        inventory.availableStock > resolvedThreshold) {
      return null;
    }

    final severity = _stockAlertSeverity(
      availableStock: inventory.availableStock,
      resolvedThreshold: resolvedThreshold,
    );
    final thresholdSource = inventory.minimumStock > 0
        ? StockAlertThresholdSource.product
        : StockAlertThresholdSource.category;

    return StockAlertItem(
      id: _stockAlertId(inventory),
      branchId: inventory.branchId,
      branchName: inventory.branchName,
      productId: inventory.productId,
      productName: inventory.productName,
      sku: inventory.sku,
      categoryId: product?.categoryId ?? '',
      categoryName: category?.name ?? 'Sin categoria',
      availableStock: inventory.availableStock,
      reservedStock: inventory.reservedStock,
      incomingStock: inventory.incomingStock,
      resolvedThreshold: resolvedThreshold,
      productThreshold: inventory.minimumStock > 0
          ? inventory.minimumStock
          : null,
      categoryThreshold: category?.lowStockThreshold,
      thresholdSource: thresholdSource,
      severity: severity,
      lastMovementAt: inventory.lastMovementAt,
      updatedAt: inventory.updatedAt,
      isRead: _isStockAlertRead(inventory, readState),
      readAt: readState?.readAt,
    );
  }

  int? _resolveLowStockThreshold({
    required InventoryItem inventory,
    required Category? category,
  }) {
    if (inventory.minimumStock > 0) {
      return inventory.minimumStock;
    }
    final categoryThreshold = category?.lowStockThreshold;
    if (categoryThreshold != null && categoryThreshold > 0) {
      return categoryThreshold;
    }
    return null;
  }

  StockAlertSeverity _stockAlertSeverity({
    required int availableStock,
    required int resolvedThreshold,
  }) {
    if (availableStock <= 0) {
      return StockAlertSeverity.critical;
    }

    final criticalThreshold = math.max(
      1,
      (resolvedThreshold * _criticalStockThresholdFactor).ceil(),
    );
    if (availableStock <= criticalThreshold) {
      return StockAlertSeverity.critical;
    }
    return StockAlertSeverity.warning;
  }

  bool _isStockAlertRead(
    InventoryItem inventory,
    StockAlertReadState? readState,
  ) {
    if (readState == null) {
      return false;
    }
    return !inventory.updatedAt.isAfter(readState.alertUpdatedAt);
  }

  int _compareStockAlerts(StockAlertItem left, StockAlertItem right) {
    if (left.isCritical != right.isCritical) {
      return left.isCritical ? -1 : 1;
    }
    if (left.isRead != right.isRead) {
      return left.isRead ? 1 : -1;
    }
    final stockComparison = left.availableStock.compareTo(right.availableStock);
    if (stockComparison != 0) {
      return stockComparison;
    }
    return right.updatedAt.compareTo(left.updatedAt);
  }

  String _stockAlertId(InventoryItem inventory) =>
      '${inventory.branchId}_${inventory.productId}';

  String _stockAlertReadStateId(String userId, String alertId) =>
      '${userId}_$alertId';

  Future<void> _handleLowStockAlertTransition({
    required InventoryItem? previousInventory,
    required InventoryItem updatedInventory,
  }) async {
    final product = await catalog.fetchProduct(updatedInventory.productId);
    if (product == null) {
      return;
    }
    final category = await catalog.fetchCategory(product.categoryId);

    final previousThreshold = previousInventory == null
        ? null
        : _resolveLowStockThreshold(
            inventory: previousInventory,
            category: category,
          );
    final nextThreshold = _resolveLowStockThreshold(
      inventory: updatedInventory,
      category: category,
    );

    final previousSeverity =
        previousThreshold == null ||
            previousThreshold <= 0 ||
            previousInventory == null ||
            previousInventory.availableStock > previousThreshold
        ? null
        : _stockAlertSeverity(
            availableStock: previousInventory.availableStock,
            resolvedThreshold: previousThreshold,
          );
    final nextSeverity =
        nextThreshold == null ||
            nextThreshold <= 0 ||
            updatedInventory.availableStock > nextThreshold
        ? null
        : _stockAlertSeverity(
            availableStock: updatedInventory.availableStock,
            resolvedThreshold: nextThreshold,
          );

    if (nextSeverity != StockAlertSeverity.critical ||
        previousSeverity == StockAlertSeverity.critical) {
      return;
    }

    final allUsers = await users.fetchUsers();
    final targetUsers = allUsers
        .where(
          (user) =>
              user.isActive &&
              (user.role == UserRole.admin ||
                  (user.role == UserRole.supervisor &&
                      user.branchId == updatedInventory.branchId)),
        )
        .toList(growable: false);
    if (targetUsers.isEmpty) {
      return;
    }

    final now = _clock();
    final batch = _firestore.batch();
    for (final user in targetUsers) {
      final notificationRef = _notificationsCollection.doc();
      final notification = AppNotification(
        id: notificationRef.id,
        userId: user.id,
        title: 'Alerta critica de stock',
        message:
            '${updatedInventory.productName} quedo en ${updatedInventory.availableStock} unidad(es) en ${updatedInventory.branchName}. Umbral: $nextThreshold.',
        type: 'stock_alert_critical',
        referenceId: _stockAlertId(updatedInventory),
        isRead: false,
        createdAt: now,
      );
      batch.set(notificationRef, notification.toFirestore());
    }
    await batch.commit();
  }

  SyncStatusOverview _buildSyncStatusOverview({
    required List<Branch> branches,
    required List<SyncLog> syncLogs,
    required String currentBranchId,
  }) {
    final orderedLogs = List<SyncLog>.from(syncLogs)
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    final latestLogByBranch = <String, SyncLog>{};
    for (final log in orderedLogs) {
      latestLogByBranch.putIfAbsent(log.branchId, () => log);
    }

    final branchStatuses =
        branches
            .map(
              (branch) => _buildBranchSyncStatus(
                branch: branch,
                latestLog: latestLogByBranch[branch.id],
              ),
            )
            .toList(growable: false)
          ..sort(
            (left, right) => _compareBranchSyncStatus(
              left,
              right,
              currentBranchId: currentBranchId,
            ),
          );

    final apiStatus = _buildSyncApiStatus(
      syncLogs: orderedLogs,
      branchStatuses: branchStatuses,
    );

    return SyncStatusOverview(
      generatedAt: _clock(),
      apiStatus: apiStatus,
      branches: List<SyncBranchStatus>.unmodifiable(branchStatuses),
      warnings: List<String>.unmodifiable(
        _buildSyncWarnings(
          apiStatus: apiStatus,
          branchStatuses: branchStatuses,
        ),
      ),
    );
  }

  SyncBranchStatus _buildBranchSyncStatus({
    required Branch branch,
    required SyncLog? latestLog,
  }) {
    final lastSyncAt = latestLog?.createdAt ?? branch.lastSyncAt;
    final age = lastSyncAt == null ? null : _clock().difference(lastSyncAt);
    final normalizedStatus = latestLog?.status.trim().toLowerCase() ?? '';

    if (latestLog != null && _isSyncFailureStatus(normalizedStatus)) {
      return SyncBranchStatus(
        branch: branch,
        latestLog: latestLog,
        lastSyncAt: lastSyncAt,
        age: age,
        severity: SyncStatusSeverity.critical,
        summary: 'Con fallo',
        detail: latestLog.message.trim().isEmpty
            ? 'La ultima sincronizacion reporto un error y requiere revision.'
            : latestLog.message.trim(),
      );
    }

    if (latestLog != null && _isSyncRunningStatus(normalizedStatus)) {
      return SyncBranchStatus(
        branch: branch,
        latestLog: latestLog,
        lastSyncAt: lastSyncAt,
        age: age,
        severity: SyncStatusSeverity.warning,
        summary: 'En proceso',
        detail: 'Hay una sincronizacion en curso para esta sucursal.',
      );
    }

    if (lastSyncAt == null) {
      return SyncBranchStatus(
        branch: branch,
        latestLog: latestLog,
        lastSyncAt: null,
        age: null,
        severity: SyncStatusSeverity.critical,
        summary: 'Sin registro',
        detail: 'No existe una ultima sincronizacion registrada.',
      );
    }

    if (age! <= _greenDataThreshold) {
      return SyncBranchStatus(
        branch: branch,
        latestLog: latestLog,
        lastSyncAt: lastSyncAt,
        age: age,
        severity: SyncStatusSeverity.healthy,
        summary: 'Al dia',
        detail: 'Los datos de esta sucursal se ven consistentes y recientes.',
      );
    }

    if (age <= _yellowDataThreshold) {
      return SyncBranchStatus(
        branch: branch,
        latestLog: latestLog,
        lastSyncAt: lastSyncAt,
        age: age,
        severity: SyncStatusSeverity.warning,
        summary: 'Con retraso',
        detail: 'La sucursal sigue operativa, pero conviene validar el dato.',
      );
    }

    return SyncBranchStatus(
      branch: branch,
      latestLog: latestLog,
      lastSyncAt: lastSyncAt,
      age: age,
      severity: SyncStatusSeverity.critical,
      summary: age <= _redDataThreshold ? 'Desactualizada' : 'Muy atrasada',
      detail: age <= _redDataThreshold
          ? 'La sincronizacion ya supero el umbral recomendado.'
          : 'La sucursal lleva demasiado tiempo sin sincronizar.',
    );
  }

  SyncApiStatus _buildSyncApiStatus({
    required List<SyncLog> syncLogs,
    required List<SyncBranchStatus> branchStatuses,
  }) {
    final latestLog = syncLogs.isEmpty ? null : syncLogs.first;
    final averageResponseTime = _averageApiResponseTime(
      syncLogs.take(12).toList(growable: false),
    );
    final criticalBranches = branchStatuses.where((item) => item.isCritical);
    final warningBranches = branchStatuses.where((item) => item.isWarning);

    if (latestLog == null) {
      return const SyncApiStatus(
        severity: SyncStatusSeverity.unknown,
        summary: 'Sin señal',
        detail: 'Todavia no hay eventos de sincronizacion para evaluar la API.',
        latestLog: null,
        averageResponseTime: Duration.zero,
        lastUpdatedAt: null,
      );
    }

    final latestAge = _clock().difference(latestLog.createdAt);
    final normalizedStatus = latestLog.status.trim().toLowerCase();

    if (_isSyncFailureStatus(normalizedStatus)) {
      return SyncApiStatus(
        severity: SyncStatusSeverity.critical,
        summary: 'Con fallas',
        detail: latestLog.message.trim().isEmpty
            ? 'El ultimo evento de sincronizacion reporto error.'
            : latestLog.message.trim(),
        latestLog: latestLog,
        averageResponseTime: averageResponseTime,
        lastUpdatedAt: latestLog.createdAt,
      );
    }

    if (latestAge > _redDataThreshold) {
      return SyncApiStatus(
        severity: SyncStatusSeverity.critical,
        summary: 'Sin respuesta reciente',
        detail:
            'No hay actividad de sincronizacion dentro del umbral esperado.',
        latestLog: latestLog,
        averageResponseTime: averageResponseTime,
        lastUpdatedAt: latestLog.createdAt,
      );
    }

    if (criticalBranches.isNotEmpty ||
        warningBranches.isNotEmpty ||
        averageResponseTime > const Duration(seconds: 15)) {
      return SyncApiStatus(
        severity: SyncStatusSeverity.warning,
        summary: 'Con alertas',
        detail: averageResponseTime > const Duration(seconds: 15)
            ? 'La API responde, pero con latencia superior a la esperada.'
            : 'Se detectaron sucursales con retraso o incidencias de sincronizacion.',
        latestLog: latestLog,
        averageResponseTime: averageResponseTime,
        lastUpdatedAt: latestLog.createdAt,
      );
    }

    return SyncApiStatus(
      severity: SyncStatusSeverity.healthy,
      summary: 'Operativa',
      detail: 'La sincronizacion responde dentro de los parametros esperados.',
      latestLog: latestLog,
      averageResponseTime: averageResponseTime,
      lastUpdatedAt: latestLog.createdAt,
    );
  }

  List<String> _buildSyncWarnings({
    required SyncApiStatus apiStatus,
    required List<SyncBranchStatus> branchStatuses,
  }) {
    final warnings = <String>[];
    final criticalBranches = branchStatuses
        .where((item) => item.isCritical)
        .toList(growable: false);
    final warningBranches = branchStatuses
        .where((item) => item.isWarning)
        .toList(growable: false);
    final missingSync = branchStatuses
        .where((item) => item.lastSyncAt == null)
        .length;

    if (!apiStatus.isHealthy) {
      warnings.add(apiStatus.detail);
    }
    if (criticalBranches.isNotEmpty) {
      warnings.add(
        '${criticalBranches.length} sucursal(es) con fallo o desactualizacion critica.',
      );
    }
    if (warningBranches.isNotEmpty) {
      warnings.add(
        '${warningBranches.length} sucursal(es) con retraso moderado que conviene revisar.',
      );
    }
    if (missingSync > 0) {
      warnings.add(
        '$missingSync sucursal(es) no tienen registro de ultima sincronizacion.',
      );
    }

    return warnings;
  }

  int _compareBranchSyncStatus(
    SyncBranchStatus left,
    SyncBranchStatus right, {
    required String currentBranchId,
  }) {
    final severityComparison = _syncSeverityPriority(
      right.severity,
    ).compareTo(_syncSeverityPriority(left.severity));
    if (severityComparison != 0) {
      return severityComparison;
    }

    final leftIsCurrent = left.branch.id == currentBranchId;
    final rightIsCurrent = right.branch.id == currentBranchId;
    if (leftIsCurrent != rightIsCurrent) {
      return leftIsCurrent ? -1 : 1;
    }

    final rightSync = right.lastSyncAt;
    final leftSync = left.lastSyncAt;
    if (leftSync != null && rightSync != null) {
      final recency = rightSync.compareTo(leftSync);
      if (recency != 0) {
        return recency;
      }
    } else if (leftSync != null || rightSync != null) {
      return leftSync == null ? 1 : -1;
    }

    return left.branch.name.compareTo(right.branch.name);
  }

  int _syncSeverityPriority(SyncStatusSeverity value) {
    return switch (value) {
      SyncStatusSeverity.critical => 3,
      SyncStatusSeverity.warning => 2,
      SyncStatusSeverity.healthy => 1,
      SyncStatusSeverity.unknown => 0,
    };
  }

  bool _isSyncFailureStatus(String value) {
    return switch (value) {
      'failed' || 'error' || 'timeout' => true,
      _ => false,
    };
  }

  bool _isSyncRunningStatus(String value) {
    return switch (value) {
      'running' || 'in_progress' || 'pending' => true,
      _ => false,
    };
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
