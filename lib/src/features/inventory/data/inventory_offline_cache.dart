import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../domain/models.dart';

const _branchesKey = 'catalog|branches';
const _categoriesKey = 'catalog|categories';
const _productsKey = 'catalog|products';
const _recentProductsLimit = 12;

String _branchInventoryKey(String branchId) => 'inventory|branch|$branchId';
String _productInventoryKey(String productId) => 'inventory|product|$productId';
String _recentProductsKey(String userId) => 'recentProducts|$userId';
String _searchResultsKey(String cacheKey) => 'searchResults|$cacheKey';
String _stockByBranchKey(String cacheKey) => 'stockByBranch|$cacheKey';
String _productDetailKey(String cacheKey) => 'productDetail|$cacheKey';
String _branchDirectoryKey(String cacheKey) => 'branchDirectory|$cacheKey';

class CachedSearchResultRecord {
  const CachedSearchResultRecord({
    required this.product,
    required this.inventory,
    required this.relevanceScore,
  });

  final Product product;
  final InventoryItem? inventory;
  final int relevanceScore;
}

class CachedBranchStockRecord {
  const CachedBranchStockRecord({
    required this.branch,
    required this.inventory,
  });

  final Branch branch;
  final InventoryItem? inventory;
}

class CachedProductDetailRecord {
  const CachedProductDetailRecord({
    required this.product,
    required this.inventory,
    required this.category,
    required this.branch,
    required this.stockByBranch,
  });

  final Product product;
  final InventoryItem? inventory;
  final Category? category;
  final Branch? branch;
  final List<CachedBranchStockRecord> stockByBranch;
}

class CachedBranchDirectoryEntryRecord {
  const CachedBranchDirectoryEntryRecord({
    required this.branch,
    required this.distanceKm,
    required this.stockEntry,
  });

  final Branch branch;
  final double distanceKm;
  final CachedBranchStockRecord? stockEntry;
}

class CachedBranchDirectoryRecord {
  const CachedBranchDirectoryRecord({
    required this.entries,
    required this.selectedProduct,
    required this.currentBranch,
  });

  final List<CachedBranchDirectoryEntryRecord> entries;
  final Product? selectedProduct;
  final Branch? currentBranch;
}

abstract class InventoryOfflineCache {
  static InventoryOfflineCache shared = MemoryInventoryOfflineCache();

  static Future<void> initializeHiveShared() async {
    try {
      await Hive.initFlutter();
      final box = await Hive.openBox<dynamic>('inventory_offline_cache_v1');
      shared = HiveInventoryOfflineCache._(box);
    } catch (_) {}
  }

  List<Branch>? getBranches();
  Branch? getBranch(String branchId);
  Future<void> cacheBranches(List<Branch> branches);
  Future<void> cacheBranch(Branch branch);

  List<Category>? getCategories();
  Category? getCategory(String categoryId);
  Future<void> cacheCategories(List<Category> categories);
  Future<void> cacheCategory(Category category);

  List<Product>? getProducts();
  Product? getProduct(String productId);
  Future<void> cacheProducts(List<Product> products);
  Future<void> cacheProduct(Product product);

  List<InventoryItem>? getBranchInventory(String branchId);
  List<InventoryItem>? getProductInventory(String productId);
  InventoryItem? getInventory(String branchId, String productId);
  Future<void> cacheBranchInventory(String branchId, List<InventoryItem> items);
  Future<void> cacheProductInventory(
    String productId,
    List<InventoryItem> items,
  );
  Future<void> cacheInventoryItem(InventoryItem item);

  List<Product> getRecentProducts(String userId);
  Future<void> cacheRecentProducts(String userId, Iterable<Product> products);

  List<CachedSearchResultRecord>? getSearchResults(String key);
  Future<void> cacheSearchResults(
    String key,
    List<CachedSearchResultRecord> results,
  );

  List<CachedBranchStockRecord>? getStockByBranch(String key);
  Future<void> cacheStockByBranch(
    String key,
    List<CachedBranchStockRecord> records,
  );

  CachedProductDetailRecord? getProductDetail(String key);
  Future<void> cacheProductDetail(String key, CachedProductDetailRecord record);

  CachedBranchDirectoryRecord? getBranchDirectory(String key);
  Future<void> cacheBranchDirectory(
    String key,
    CachedBranchDirectoryRecord record,
  );

  Future<void> clearSearchResults();
  Future<void> clearProductScopedCaches(String productId);
  Future<void> clearBranchCatalogCaches();
  Future<void> clearAll();
}

class MemoryInventoryOfflineCache implements InventoryOfflineCache {
  final Map<String, dynamic> _store = <String, dynamic>{};

  @override
  List<Branch>? getBranches() => _readList(_branchesKey, _decodeBranch);

  @override
  Branch? getBranch(String branchId) {
    final branches = getBranches();
    if (branches == null) {
      return null;
    }
    return branches.cast<Branch?>().firstWhere(
      (branch) => branch?.id == branchId,
      orElse: () => null,
    );
  }

  @override
  Future<void> cacheBranches(List<Branch> branches) async {
    _store[_branchesKey] = branches.map(_encodeBranch).toList(growable: false);
  }

  @override
  Future<void> cacheBranch(Branch branch) async {
    final branches = getBranches() ?? const <Branch>[];
    _store[_branchesKey] = _mergeUniqueById(branches, <Branch>[
      branch,
    ], (item) => item.id).map(_encodeBranch).toList(growable: false);
  }

  @override
  List<Category>? getCategories() => _readList(_categoriesKey, _decodeCategory);

  @override
  Category? getCategory(String categoryId) {
    final categories = getCategories();
    if (categories == null) {
      return null;
    }
    return categories.cast<Category?>().firstWhere(
      (category) => category?.id == categoryId,
      orElse: () => null,
    );
  }

  @override
  Future<void> cacheCategories(List<Category> categories) async {
    _store[_categoriesKey] = categories
        .map(_encodeCategory)
        .toList(growable: false);
  }

  @override
  Future<void> cacheCategory(Category category) async {
    final categories = getCategories() ?? const <Category>[];
    _store[_categoriesKey] = _mergeUniqueById(categories, <Category>[
      category,
    ], (item) => item.id).map(_encodeCategory).toList(growable: false);
  }

  @override
  List<Product>? getProducts() => _readList(_productsKey, _decodeProduct);

  @override
  Product? getProduct(String productId) {
    final products = getProducts();
    if (products == null) {
      return null;
    }
    return products.cast<Product?>().firstWhere(
      (product) => product?.id == productId,
      orElse: () => null,
    );
  }

  @override
  Future<void> cacheProducts(List<Product> products) async {
    _store[_productsKey] = products.map(_encodeProduct).toList(growable: false);
  }

  @override
  Future<void> cacheProduct(Product product) async {
    final products = getProducts() ?? const <Product>[];
    _store[_productsKey] = _mergeUniqueById(products, <Product>[
      product,
    ], (item) => item.id).map(_encodeProduct).toList(growable: false);
  }

  @override
  List<InventoryItem>? getBranchInventory(String branchId) {
    return _readList(_branchInventoryKey(branchId), _decodeInventory);
  }

  @override
  List<InventoryItem>? getProductInventory(String productId) {
    return _readList(_productInventoryKey(productId), _decodeInventory);
  }

  @override
  InventoryItem? getInventory(String branchId, String productId) {
    final branchInventory = getBranchInventory(branchId);
    if (branchInventory != null) {
      final inventory = branchInventory.cast<InventoryItem?>().firstWhere(
        (item) => item?.productId == productId,
        orElse: () => null,
      );
      if (inventory != null) {
        return inventory;
      }
    }

    final productInventory = getProductInventory(productId);
    if (productInventory == null) {
      return null;
    }
    return productInventory.cast<InventoryItem?>().firstWhere(
      (item) => item?.branchId == branchId,
      orElse: () => null,
    );
  }

  @override
  Future<void> cacheBranchInventory(
    String branchId,
    List<InventoryItem> items,
  ) async {
    _store[_branchInventoryKey(branchId)] = items
        .map(_encodeInventory)
        .toList(growable: false);
  }

  @override
  Future<void> cacheProductInventory(
    String productId,
    List<InventoryItem> items,
  ) async {
    _store[_productInventoryKey(productId)] = items
        .map(_encodeInventory)
        .toList(growable: false);
  }

  @override
  Future<void> cacheInventoryItem(InventoryItem item) async {
    final branchInventory =
        getBranchInventory(item.branchId) ?? const <InventoryItem>[];
    _store[_branchInventoryKey(item.branchId)] = _mergeUniqueById(
      branchInventory,
      <InventoryItem>[item],
      (inventory) => inventory.id,
    ).map(_encodeInventory).toList(growable: false);

    final productInventory =
        getProductInventory(item.productId) ?? const <InventoryItem>[];
    _store[_productInventoryKey(item.productId)] = _mergeUniqueById(
      productInventory,
      <InventoryItem>[item],
      (inventory) => inventory.id,
    ).map(_encodeInventory).toList(growable: false);
  }

  @override
  List<Product> getRecentProducts(String userId) {
    return _readList(_recentProductsKey(userId), _decodeProduct) ??
        const <Product>[];
  }

  @override
  Future<void> cacheRecentProducts(
    String userId,
    Iterable<Product> products,
  ) async {
    final merged = _mergeUniqueById(
      products.toList(growable: false),
      getRecentProducts(userId),
      (product) => product.id,
      limit: _recentProductsLimit,
    );
    _store[_recentProductsKey(userId)] = merged
        .map(_encodeProduct)
        .toList(growable: false);
  }

  @override
  List<CachedSearchResultRecord>? getSearchResults(String key) {
    return _readList(_searchResultsKey(key), _decodeSearchResult);
  }

  @override
  Future<void> cacheSearchResults(
    String key,
    List<CachedSearchResultRecord> results,
  ) async {
    _store[_searchResultsKey(key)] = results
        .map(_encodeSearchResult)
        .toList(growable: false);
  }

  @override
  List<CachedBranchStockRecord>? getStockByBranch(String key) {
    return _readList(_stockByBranchKey(key), _decodeBranchStock);
  }

  @override
  Future<void> cacheStockByBranch(
    String key,
    List<CachedBranchStockRecord> records,
  ) async {
    _store[_stockByBranchKey(key)] = records
        .map(_encodeBranchStock)
        .toList(growable: false);
  }

  @override
  CachedProductDetailRecord? getProductDetail(String key) {
    final raw = _store[_productDetailKey(key)];
    if (raw == null) {
      return null;
    }
    return _decodeProductDetail(raw);
  }

  @override
  Future<void> cacheProductDetail(
    String key,
    CachedProductDetailRecord record,
  ) async {
    _store[_productDetailKey(key)] = _encodeProductDetail(record);
  }

  @override
  CachedBranchDirectoryRecord? getBranchDirectory(String key) {
    final raw = _store[_branchDirectoryKey(key)];
    if (raw == null) {
      return null;
    }
    return _decodeBranchDirectory(raw);
  }

  @override
  Future<void> cacheBranchDirectory(
    String key,
    CachedBranchDirectoryRecord record,
  ) async {
    _store[_branchDirectoryKey(key)] = _encodeBranchDirectory(record);
  }

  @override
  Future<void> clearSearchResults() async {
    _store.removeWhere((key, _) => key.startsWith('searchResults|'));
  }

  @override
  Future<void> clearProductScopedCaches(String productId) async {
    _store.removeWhere(
      (key, _) =>
          key == _productInventoryKey(productId) ||
          key.startsWith('stockByBranch|') && key.endsWith('_$productId') ||
          key.startsWith('productDetail|') && key.endsWith('_$productId') ||
          key.startsWith('branchDirectory|') && key.endsWith('_$productId'),
    );
    await clearSearchResults();
  }

  @override
  Future<void> clearBranchCatalogCaches() async {
    _store.remove(_branchesKey);
    _store.removeWhere((key, _) => key.startsWith('branchDirectory|'));
  }

  @override
  Future<void> clearAll() async {
    _store.clear();
  }

  List<T>? _readList<T>(String key, T Function(dynamic raw) decoder) {
    final raw = _store[key];
    if (raw is! List) {
      return null;
    }
    return raw.map(decoder).toList(growable: false);
  }
}

class HiveInventoryOfflineCache implements InventoryOfflineCache {
  HiveInventoryOfflineCache._(this._box);

  final Box<dynamic> _box;

  @override
  List<Branch>? getBranches() => _readList(_branchesKey, _decodeBranch);

  @override
  Branch? getBranch(String branchId) {
    final branches = getBranches();
    if (branches == null) {
      return null;
    }
    return branches.cast<Branch?>().firstWhere(
      (branch) => branch?.id == branchId,
      orElse: () => null,
    );
  }

  @override
  Future<void> cacheBranches(List<Branch> branches) async {
    await _box.put(
      _branchesKey,
      branches.map(_encodeBranch).toList(growable: false),
    );
  }

  @override
  Future<void> cacheBranch(Branch branch) async {
    final branches = getBranches() ?? const <Branch>[];
    await _box.put(
      _branchesKey,
      _mergeUniqueById(branches, <Branch>[
        branch,
      ], (item) => item.id).map(_encodeBranch).toList(growable: false),
    );
  }

  @override
  List<Category>? getCategories() => _readList(_categoriesKey, _decodeCategory);

  @override
  Category? getCategory(String categoryId) {
    final categories = getCategories();
    if (categories == null) {
      return null;
    }
    return categories.cast<Category?>().firstWhere(
      (category) => category?.id == categoryId,
      orElse: () => null,
    );
  }

  @override
  Future<void> cacheCategories(List<Category> categories) async {
    await _box.put(
      _categoriesKey,
      categories.map(_encodeCategory).toList(growable: false),
    );
  }

  @override
  Future<void> cacheCategory(Category category) async {
    final categories = getCategories() ?? const <Category>[];
    await _box.put(
      _categoriesKey,
      _mergeUniqueById(categories, <Category>[
        category,
      ], (item) => item.id).map(_encodeCategory).toList(growable: false),
    );
  }

  @override
  List<Product>? getProducts() => _readList(_productsKey, _decodeProduct);

  @override
  Product? getProduct(String productId) {
    final products = getProducts();
    if (products == null) {
      return null;
    }
    return products.cast<Product?>().firstWhere(
      (product) => product?.id == productId,
      orElse: () => null,
    );
  }

  @override
  Future<void> cacheProducts(List<Product> products) async {
    await _box.put(
      _productsKey,
      products.map(_encodeProduct).toList(growable: false),
    );
  }

  @override
  Future<void> cacheProduct(Product product) async {
    final products = getProducts() ?? const <Product>[];
    await _box.put(
      _productsKey,
      _mergeUniqueById(products, <Product>[
        product,
      ], (item) => item.id).map(_encodeProduct).toList(growable: false),
    );
  }

  @override
  List<InventoryItem>? getBranchInventory(String branchId) {
    return _readList(_branchInventoryKey(branchId), _decodeInventory);
  }

  @override
  List<InventoryItem>? getProductInventory(String productId) {
    return _readList(_productInventoryKey(productId), _decodeInventory);
  }

  @override
  InventoryItem? getInventory(String branchId, String productId) {
    final branchInventory = getBranchInventory(branchId);
    if (branchInventory != null) {
      final inventory = branchInventory.cast<InventoryItem?>().firstWhere(
        (item) => item?.productId == productId,
        orElse: () => null,
      );
      if (inventory != null) {
        return inventory;
      }
    }

    final productInventory = getProductInventory(productId);
    if (productInventory == null) {
      return null;
    }
    return productInventory.cast<InventoryItem?>().firstWhere(
      (item) => item?.branchId == branchId,
      orElse: () => null,
    );
  }

  @override
  Future<void> cacheBranchInventory(
    String branchId,
    List<InventoryItem> items,
  ) async {
    await _box.put(
      _branchInventoryKey(branchId),
      items.map(_encodeInventory).toList(growable: false),
    );
  }

  @override
  Future<void> cacheProductInventory(
    String productId,
    List<InventoryItem> items,
  ) async {
    await _box.put(
      _productInventoryKey(productId),
      items.map(_encodeInventory).toList(growable: false),
    );
  }

  @override
  Future<void> cacheInventoryItem(InventoryItem item) async {
    final branchInventory =
        getBranchInventory(item.branchId) ?? const <InventoryItem>[];
    await _box.put(
      _branchInventoryKey(item.branchId),
      _mergeUniqueById(
        branchInventory,
        <InventoryItem>[item],
        (inventory) => inventory.id,
      ).map(_encodeInventory).toList(growable: false),
    );

    final productInventory =
        getProductInventory(item.productId) ?? const <InventoryItem>[];
    await _box.put(
      _productInventoryKey(item.productId),
      _mergeUniqueById(
        productInventory,
        <InventoryItem>[item],
        (inventory) => inventory.id,
      ).map(_encodeInventory).toList(growable: false),
    );
  }

  @override
  List<Product> getRecentProducts(String userId) {
    return _readList(_recentProductsKey(userId), _decodeProduct) ??
        const <Product>[];
  }

  @override
  Future<void> cacheRecentProducts(
    String userId,
    Iterable<Product> products,
  ) async {
    final merged = _mergeUniqueById(
      products.toList(growable: false),
      getRecentProducts(userId),
      (product) => product.id,
      limit: _recentProductsLimit,
    );
    await _box.put(
      _recentProductsKey(userId),
      merged.map(_encodeProduct).toList(growable: false),
    );
  }

  @override
  List<CachedSearchResultRecord>? getSearchResults(String key) {
    return _readList(_searchResultsKey(key), _decodeSearchResult);
  }

  @override
  Future<void> cacheSearchResults(
    String key,
    List<CachedSearchResultRecord> results,
  ) async {
    await _box.put(
      _searchResultsKey(key),
      results.map(_encodeSearchResult).toList(growable: false),
    );
  }

  @override
  List<CachedBranchStockRecord>? getStockByBranch(String key) {
    return _readList(_stockByBranchKey(key), _decodeBranchStock);
  }

  @override
  Future<void> cacheStockByBranch(
    String key,
    List<CachedBranchStockRecord> records,
  ) async {
    await _box.put(
      _stockByBranchKey(key),
      records.map(_encodeBranchStock).toList(growable: false),
    );
  }

  @override
  CachedProductDetailRecord? getProductDetail(String key) {
    final raw = _box.get(_productDetailKey(key));
    if (raw == null) {
      return null;
    }
    return _decodeProductDetail(raw);
  }

  @override
  Future<void> cacheProductDetail(
    String key,
    CachedProductDetailRecord record,
  ) async {
    await _box.put(_productDetailKey(key), _encodeProductDetail(record));
  }

  @override
  CachedBranchDirectoryRecord? getBranchDirectory(String key) {
    final raw = _box.get(_branchDirectoryKey(key));
    if (raw == null) {
      return null;
    }
    return _decodeBranchDirectory(raw);
  }

  @override
  Future<void> cacheBranchDirectory(
    String key,
    CachedBranchDirectoryRecord record,
  ) async {
    await _box.put(_branchDirectoryKey(key), _encodeBranchDirectory(record));
  }

  @override
  Future<void> clearSearchResults() async {
    final keys = _box.keys
        .whereType<String>()
        .where((key) => key.startsWith('searchResults|'))
        .toList(growable: false);
    if (keys.isEmpty) {
      return;
    }
    await _box.deleteAll(keys);
  }

  @override
  Future<void> clearProductScopedCaches(String productId) async {
    final keys = _box.keys
        .whereType<String>()
        .where(
          (key) =>
              key == _productInventoryKey(productId) ||
              key.startsWith('stockByBranch|') && key.endsWith('_$productId') ||
              key.startsWith('productDetail|') && key.endsWith('_$productId') ||
              key.startsWith('branchDirectory|') && key.endsWith('_$productId'),
        )
        .toList(growable: false);
    if (keys.isNotEmpty) {
      await _box.deleteAll(keys);
    }
    await clearSearchResults();
  }

  @override
  Future<void> clearBranchCatalogCaches() async {
    final keys = _box.keys
        .whereType<String>()
        .where(
          (key) => key == _branchesKey || key.startsWith('branchDirectory|'),
        )
        .toList(growable: false);
    if (keys.isEmpty) {
      return;
    }
    await _box.deleteAll(keys);
  }

  @override
  Future<void> clearAll() => _box.clear();

  List<T>? _readList<T>(String key, T Function(dynamic raw) decoder) {
    final raw = _box.get(key);
    if (raw is! List) {
      return null;
    }
    return raw.map(decoder).toList(growable: false);
  }
}

List<T> _mergeUniqueById<T>(
  List<T> priorityItems,
  List<T> existingItems,
  String Function(T item) idSelector, {
  int? limit,
}) {
  final merged = <String, T>{};
  for (final item in priorityItems) {
    merged[idSelector(item)] = item;
  }
  for (final item in existingItems) {
    merged.putIfAbsent(idSelector(item), () => item);
  }
  final values = merged.values.toList(growable: false);
  if (limit == null || values.length <= limit) {
    return values;
  }
  return values.take(limit).toList(growable: false);
}

Map<String, dynamic> _encodeSearchResult(CachedSearchResultRecord record) => {
  'product': _encodeProduct(record.product),
  'inventory': record.inventory == null
      ? null
      : _encodeInventory(record.inventory!),
  'relevanceScore': record.relevanceScore,
};

CachedSearchResultRecord _decodeSearchResult(dynamic raw) {
  final map = _castMap(raw);
  return CachedSearchResultRecord(
    product: _decodeProduct(map['product']),
    inventory: map['inventory'] == null
        ? null
        : _decodeInventory(map['inventory']),
    relevanceScore: _readInt(map, 'relevanceScore'),
  );
}

Map<String, dynamic> _encodeBranchStock(CachedBranchStockRecord record) => {
  'branch': _encodeBranch(record.branch),
  'inventory': record.inventory == null
      ? null
      : _encodeInventory(record.inventory!),
};

CachedBranchStockRecord _decodeBranchStock(dynamic raw) {
  final map = _castMap(raw);
  return CachedBranchStockRecord(
    branch: _decodeBranch(map['branch']),
    inventory: map['inventory'] == null
        ? null
        : _decodeInventory(map['inventory']),
  );
}

Map<String, dynamic> _encodeProductDetail(CachedProductDetailRecord record) => {
  'product': _encodeProduct(record.product),
  'inventory': record.inventory == null
      ? null
      : _encodeInventory(record.inventory!),
  'category': record.category == null
      ? null
      : _encodeCategory(record.category!),
  'branch': record.branch == null ? null : _encodeBranch(record.branch!),
  'stockByBranch': record.stockByBranch
      .map(_encodeBranchStock)
      .toList(growable: false),
};

CachedProductDetailRecord _decodeProductDetail(dynamic raw) {
  final map = _castMap(raw);
  final stockByBranchRaw = map['stockByBranch'];
  final stockByBranch = stockByBranchRaw is List
      ? stockByBranchRaw.map(_decodeBranchStock).toList(growable: false)
      : const <CachedBranchStockRecord>[];
  return CachedProductDetailRecord(
    product: _decodeProduct(map['product']),
    inventory: map['inventory'] == null
        ? null
        : _decodeInventory(map['inventory']),
    category: map['category'] == null ? null : _decodeCategory(map['category']),
    branch: map['branch'] == null ? null : _decodeBranch(map['branch']),
    stockByBranch: stockByBranch,
  );
}

Map<String, dynamic> _encodeBranchDirectory(
  CachedBranchDirectoryRecord record,
) => {
  'entries': record.entries
      .map(_encodeBranchDirectoryEntry)
      .toList(growable: false),
  'selectedProduct': record.selectedProduct == null
      ? null
      : _encodeProduct(record.selectedProduct!),
  'currentBranch': record.currentBranch == null
      ? null
      : _encodeBranch(record.currentBranch!),
};

CachedBranchDirectoryRecord _decodeBranchDirectory(dynamic raw) {
  final map = _castMap(raw);
  final entriesRaw = map['entries'];
  final entries = entriesRaw is List
      ? entriesRaw.map(_decodeBranchDirectoryEntry).toList(growable: false)
      : const <CachedBranchDirectoryEntryRecord>[];
  return CachedBranchDirectoryRecord(
    entries: entries,
    selectedProduct: map['selectedProduct'] == null
        ? null
        : _decodeProduct(map['selectedProduct']),
    currentBranch: map['currentBranch'] == null
        ? null
        : _decodeBranch(map['currentBranch']),
  );
}

Map<String, dynamic> _encodeBranchDirectoryEntry(
  CachedBranchDirectoryEntryRecord record,
) => {
  'branch': _encodeBranch(record.branch),
  'distanceKm': record.distanceKm,
  'stockEntry': record.stockEntry == null
      ? null
      : _encodeBranchStock(record.stockEntry!),
};

CachedBranchDirectoryEntryRecord _decodeBranchDirectoryEntry(dynamic raw) {
  final map = _castMap(raw);
  return CachedBranchDirectoryEntryRecord(
    branch: _decodeBranch(map['branch']),
    distanceKm: _readDouble(map, 'distanceKm'),
    stockEntry: map['stockEntry'] == null
        ? null
        : _decodeBranchStock(map['stockEntry']),
  );
}

Map<String, dynamic> _encodeBranch(Branch branch) =>
    _encodeDocument(branch.id, branch.toFirestore());

Branch _decodeBranch(dynamic raw) {
  final record = _decodeDocument(raw);
  return Branch.fromFirestore(record.id, record.data);
}

Map<String, dynamic> _encodeCategory(Category category) =>
    _encodeDocument(category.id, category.toFirestore());

Category _decodeCategory(dynamic raw) {
  final record = _decodeDocument(raw);
  return Category.fromFirestore(record.id, record.data);
}

Map<String, dynamic> _encodeProduct(Product product) =>
    _encodeDocument(product.id, product.toFirestore());

Product _decodeProduct(dynamic raw) {
  final record = _decodeDocument(raw);
  return Product.fromFirestore(record.id, record.data);
}

Map<String, dynamic> _encodeInventory(InventoryItem inventory) =>
    _encodeDocument(inventory.id, inventory.toFirestore());

InventoryItem _decodeInventory(dynamic raw) {
  final record = _decodeDocument(raw);
  return InventoryItem.fromFirestore(record.id, record.data);
}

Map<String, dynamic> _encodeDocument(String id, Map<String, dynamic> data) => {
  'id': id,
  'data': _normalizeValue(data),
};

_DecodedDocument _decodeDocument(dynamic raw) {
  final map = _castMap(raw);
  final data = _castMap(map['data']);
  return _DecodedDocument(id: _readString(map, 'id'), data: data);
}

dynamic _normalizeValue(dynamic value) {
  if (value is Timestamp) {
    return value.toDate().toUtc().toIso8601String();
  }
  if (value is DateTime) {
    return value.toUtc().toIso8601String();
  }
  if (value is Map) {
    return value.map((key, nestedValue) {
      return MapEntry('$key', _normalizeValue(nestedValue));
    });
  }
  if (value is Iterable) {
    return value.map(_normalizeValue).toList(growable: false);
  }
  return value;
}

Map<String, dynamic> _castMap(dynamic value) {
  if (value is! Map) {
    return const <String, dynamic>{};
  }
  return value.map((key, nestedValue) {
    return MapEntry('$key', _castValue(nestedValue));
  });
}

dynamic _castValue(dynamic value) {
  if (value is Map) {
    return _castMap(value);
  }
  if (value is List) {
    return value.map(_castValue).toList(growable: false);
  }
  return value;
}

String _readString(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is String) {
    return value;
  }
  return '';
}

int _readInt(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return 0;
}

double _readDouble(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  return 0;
}

class _DecodedDocument {
  const _DecodedDocument({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;
}
