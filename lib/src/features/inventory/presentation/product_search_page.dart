import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../application/inventory_workflow_service.dart';
import '../domain/models.dart';
import 'auto_refresh_state_mixin.dart';
import 'barcode_scanner_page.dart';
import 'product_detail_page.dart';

class ProductSearchPage extends StatefulWidget {
  const ProductSearchPage({
    super.key,
    required this.service,
    required this.currentUser,
  });

  final InventoryWorkflowService service;
  final AppUser currentUser;

  @override
  State<ProductSearchPage> createState() => _ProductSearchPageState();
}

class _ProductSearchPageState extends State<ProductSearchPage>
    with AutoRefreshStateMixin {
  static const _debounceDuration = Duration(milliseconds: 350);
  static const _pageSize = 20;

  final TextEditingController _queryController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Timer? _debounce;
  late final Stream<List<SearchHistoryEntry>> _recentSearchesStream;
  late final Stream<List<SavedSearchFilter>> _savedFiltersStream;

  ProductSearchFilterOptions? _filterOptions;
  List<ProductSearchResult> _allResults = const <ProductSearchResult>[];
  ProductSearchFilters _filters = const ProductSearchFilters();
  int _visibleCount = 0;
  bool _isLoading = false;
  bool _isBackgroundRefreshing = false;
  bool _isLoadingFilterOptions = true;
  bool _isUsingCachedResults = false;
  bool _isUsingCachedFilterOptions = false;
  Object? _error;
  Object? _filterOptionsError;
  String _activeQuery = '';
  String _lastSavedQuery = '';
  int _requestVersion = 0;
  List<Product> _recentCachedProducts = const <Product>[];

  bool get _hasSearchCriteria =>
      _activeQuery.isNotEmpty || !_filters.isEmpty || _isLoading;

  String get _searchRefreshScope => widget.service.searchResultsRefreshScope(
    branchId: widget.currentUser.branchId,
    query: _activeQuery,
    filters: _filters,
  );

  @override
  Duration get autoRefreshInterval => widget.service
      .refreshPolicyFor(InventoryRefreshDataType.searchResults)
      .autoRefreshInterval;

  @override
  void initState() {
    super.initState();
    _recentSearchesStream = widget.service.watchRecentSearches(
      actorUser: widget.currentUser,
    );
    _savedFiltersStream = widget.service.watchRecentSearchFilters(
      actorUser: widget.currentUser,
    );
    _queryController.addListener(_onQueryChanged);
    _scrollController.addListener(_onScroll);
    _loadRecentCachedProducts();
    unawaited(_loadFilterOptions());
    configureAutoRefresh();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.removeListener(_onQueryChanged);
    _queryController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, _runSearch);
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoading) {
      return;
    }

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      _loadMore();
    }
  }

  Future<void> _loadFilterOptions({bool forceRefresh = false}) async {
    if (mounted) {
      setState(() {
        _isLoadingFilterOptions = true;
        _filterOptionsError = null;
      });
    }

    try {
      final options = await widget.service.fetchSearchFilterOptions(
        actorUser: widget.currentUser,
        forceRefresh: forceRefresh,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _filterOptions = options;
        _isLoadingFilterOptions = false;
        _isUsingCachedFilterOptions = options.isFromCache;
        _filterOptionsError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingFilterOptions = false;
        _filterOptionsError = error;
      });
    }
  }

  Future<bool> _ensureFilterOptionsLoaded() async {
    if (_filterOptions != null) {
      return true;
    }
    await _loadFilterOptions();
    return _filterOptions != null;
  }

  Future<void> _runSearch({
    String? forcedQuery,
    bool preserveResults = false,
    bool forceRefresh = false,
  }) async {
    final query = (forcedQuery ?? _queryController.text).trim();
    final requestVersion = ++_requestVersion;

    if (query.isEmpty && _filters.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _activeQuery = '';
        _allResults = const <ProductSearchResult>[];
        _visibleCount = 0;
        _isLoading = false;
        _isBackgroundRefreshing = false;
        _isUsingCachedResults = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _activeQuery = query;
      _isLoading = !preserveResults;
      _isBackgroundRefreshing = preserveResults;
      _error = null;
      if (!preserveResults) {
        _allResults = const <ProductSearchResult>[];
        _visibleCount = 0;
      }
    });

    try {
      final results = await widget.service.searchProducts(
        actorUser: widget.currentUser,
        branchId: widget.currentUser.branchId,
        query: query,
        filters: _filters,
        forceRefresh: forceRefresh,
      );

      if (!mounted || requestVersion != _requestVersion) {
        return;
      }

      setState(() {
        _allResults = results.results;
        _visibleCount = results.results.length > _pageSize
            ? _pageSize
            : results.results.length;
        _isLoading = false;
        _isBackgroundRefreshing = false;
        _isUsingCachedResults = results.isFromCache;
        _error = null;
      });
      _loadRecentCachedProducts();

      final normalizedQuery = query.toLowerCase();
      if (query.isNotEmpty && _lastSavedQuery != normalizedQuery) {
        _lastSavedQuery = normalizedQuery;
        unawaited(
          widget.service.saveRecentSearch(
            actorUser: widget.currentUser,
            query: query,
          ),
        );
      }
    } catch (error) {
      if (!mounted || requestVersion != _requestVersion) {
        return;
      }
      setState(() {
        _allResults = const <ProductSearchResult>[];
        _visibleCount = 0;
        _isLoading = false;
        _isBackgroundRefreshing = false;
        _isUsingCachedResults = false;
        _error = error;
      });
    }
  }

  void _loadRecentCachedProducts() {
    final recentProducts = widget.service.fetchRecentCachedProducts(
      actorUser: widget.currentUser,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _recentCachedProducts = recentProducts;
    });
  }

  @override
  Future<void> onAutoRefresh(
    AutoRefreshReason reason, {
    required bool force,
  }) async {
    if (_activeQuery.isNotEmpty || !_filters.isEmpty) {
      if (!force &&
          !widget.service.shouldRefreshData(
            type: InventoryRefreshDataType.searchResults,
            scope: _searchRefreshScope,
          )) {
        return;
      }
      await _runSearch(
        forcedQuery: _queryController.text,
        preserveResults: _allResults.isNotEmpty,
        forceRefresh: force,
      );
      return;
    }

    if (!force &&
        !widget.service.shouldRefreshData(
          type: InventoryRefreshDataType.searchFilters,
          scope: widget.service.searchFiltersRefreshScope(
            actorUser: widget.currentUser,
          ),
        )) {
      return;
    }

    await _loadFilterOptions(forceRefresh: force);
    _loadRecentCachedProducts();
  }

  Future<void> _openFilters() async {
    final hasOptions = await _ensureFilterOptionsLoaded();
    if (!mounted) {
      return;
    }

    if (!hasOptions || _filterOptions == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudieron cargar los filtros. ${_filterOptionsError ?? ''}'
                .trim(),
          ),
        ),
      );
      return;
    }

    final result = await showModalBottomSheet<_FilterSheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101116),
      builder: (context) => _ProductFiltersSheet(
        options: _filterOptions!,
        initialFilters: _filters,
      ),
    );

    if (result == null) {
      return;
    }

    setState(() {
      _filters = result.filters;
    });

    if (!result.filters.isEmpty) {
      final label = result.favoriteLabel ?? _buildFilterLabel(result.filters);
      unawaited(
        widget.service.saveSearchFilter(
          actorUser: widget.currentUser,
          filters: result.filters,
          label: label,
          favorite: result.favoriteLabel != null,
        ),
      );
    }

    _debounce?.cancel();
    await _runSearch(forcedQuery: _queryController.text);
  }

  void _loadMore() {
    if (_visibleCount >= _allResults.length) {
      return;
    }

    setState(() {
      final nextCount = _visibleCount + _pageSize;
      _visibleCount = nextCount > _allResults.length
          ? _allResults.length
          : nextCount;
    });
  }

  Future<void> _applyRecentSearch(String query) async {
    _queryController
      ..text = query
      ..selection = TextSelection.collapsed(offset: query.length);
    _debounce?.cancel();
    await _runSearch(forcedQuery: query);
  }

  Future<void> _applySavedFilter(SavedSearchFilter savedFilter) async {
    setState(() {
      _filters = savedFilter.filters;
    });
    unawaited(
      widget.service.saveSearchFilter(
        actorUser: widget.currentUser,
        filters: savedFilter.filters,
        label: savedFilter.label,
        favorite: savedFilter.isFavorite,
      ),
    );
    _debounce?.cancel();
    await _runSearch(forcedQuery: _queryController.text);
  }

  Future<void> _clearFilters() async {
    setState(() {
      _filters = const ProductSearchFilters();
    });
    _debounce?.cancel();
    await _runSearch(forcedQuery: _queryController.text);
  }

  Future<void> _openProductDetail(ProductSearchResult result) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ProductDetailPage(
          service: widget.service,
          currentUser: widget.currentUser,
          productId: result.product.id,
          branchId: result.inventory?.branchId ?? _filters.branchId,
        ),
      ),
    );
  }

  Future<void> _openBarcodeScanner() async {
    final result = await Navigator.of(context).push<ProductSearchResult>(
      MaterialPageRoute<ProductSearchResult>(
        builder: (context) => BarcodeScannerPage(
          service: widget.service,
          currentUser: widget.currentUser,
        ),
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    await _openProductDetail(result);
  }

  String _buildFilterLabel(ProductSearchFilters filters) {
    final parts = <String>[];

    if (filters.categoryId != null) {
      parts.add(_categoryName(filters.categoryId!));
    }
    if (filters.brand != null) {
      parts.add(filters.brand!);
    }
    if (filters.branchId != null) {
      parts.add(_branchName(filters.branchId!));
    }
    if (filters.availability != ProductAvailabilityFilter.any) {
      parts.add(_availabilityLabel(filters.availability));
    }
    if (filters.minStock != null || filters.maxStock != null) {
      parts.add(
        'Stock ${filters.minStock?.toString() ?? "0"}-${filters.maxStock?.toString() ?? "max"}',
      );
    }

    return parts.isEmpty ? 'Filtro guardado' : parts.join(' | ');
  }

  String _categoryName(String categoryId) {
    final category = _filterOptions?.categories.cast<Category?>().firstWhere(
      (item) => item?.id == categoryId,
      orElse: () => null,
    );
    return category?.name ?? categoryId;
  }

  String _branchName(String branchId) {
    final branch = _filterOptions?.branches.cast<Branch?>().firstWhere(
      (item) => item?.id == branchId,
      orElse: () => null,
    );
    return branch?.name ?? branchId;
  }

  String _availabilityLabel(ProductAvailabilityFilter filter) {
    return switch (filter) {
      ProductAvailabilityFilter.any => 'Cualquier disponibilidad',
      ProductAvailabilityFilter.available => 'Disponible',
      ProductAvailabilityFilter.outOfStock => 'Sin stock',
      ProductAvailabilityFilter.lowStock => 'Stock bajo',
    };
  }

  List<ProductSearchResult> get _visibleResults =>
      _allResults.take(_visibleCount).toList(growable: false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar productos'),
        actions: [
          IconButton(
            tooltip: 'Actualizar datos',
            onPressed: (_isLoading || _isBackgroundRefreshing)
                ? null
                : () => unawaited(triggerPullToRefresh()),
            icon: Icon(
              (_isLoading || _isBackgroundRefreshing)
                  ? Icons.hourglass_top_rounded
                  : Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      body: Container(
        color: const Color(0xFF08090C),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              if (_isBackgroundRefreshing)
                const LinearProgressIndicator(minHeight: 3),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _SearchField(
                        controller: _queryController,
                        isLoading: _isLoading,
                        onClear: () {
                          _queryController.clear();
                          _debounce?.cancel();
                          unawaited(_runSearch(forcedQuery: ''));
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    _FilterButton(
                      activeCount: _filters.activeFilterCount,
                      onPressed: _openFilters,
                    ),
                    const SizedBox(width: 12),
                    _IconShortcutButton(
                      icon: Icons.qr_code_scanner_rounded,
                      onPressed: _openBarcodeScanner,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _SearchSummary(
                  activeQuery: _activeQuery,
                  visibleCount: _visibleCount,
                  totalCount: _allResults.length,
                  filters: _filters,
                  isUsingCache: _isUsingCachedResults,
                ),
              ),
              if (_isUsingCachedResults ||
                  (!_hasSearchCriteria && _isUsingCachedFilterOptions)) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _CacheNoticeCard(
                    message: _isUsingCachedResults
                        ? 'Estas viendo resultados desde cache local. La app seguira intentando refrescar la informacion en segundo plano.'
                        : 'Las opciones de catalogo se cargaron desde cache local para que puedas seguir filtrando y consultando.',
                  ),
                ),
              ],
              if (!_filters.isEmpty) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _ActiveFiltersCard(
                    filters: _filters,
                    categoryName: _categoryName,
                    branchName: _branchName,
                    availabilityLabel: _availabilityLabel,
                    onClear: _clearFilters,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (!_hasSearchCriteria) {
      return StreamBuilder<List<SavedSearchFilter>>(
        stream: _savedFiltersStream,
        builder: (context, filtersSnapshot) {
          final savedFilters =
              filtersSnapshot.data ?? const <SavedSearchFilter>[];
          return StreamBuilder<List<SearchHistoryEntry>>(
            stream: _recentSearchesStream,
            builder: (context, searchSnapshot) {
              final searches =
                  searchSnapshot.data ?? const <SearchHistoryEntry>[];
              return RefreshIndicator(
                onRefresh: triggerPullToRefresh,
                color: AppPalette.amber,
                backgroundColor: AppPalette.storm,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  children: [
                    const _SearchHintCard(),
                    const SizedBox(height: 16),
                    _SavedFiltersCard(
                      items: savedFilters,
                      onTap: _applySavedFilter,
                      isLoadingOptions: _isLoadingFilterOptions,
                    ),
                    if (_recentCachedProducts.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _RecentCachedProductsCard(
                        items: _recentCachedProducts,
                        onTap: (product) {
                          unawaited(
                            _openProductDetail(
                              ProductSearchResult(
                                product: product,
                                inventory: null,
                                relevanceScore: 1,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    _RecentSearchesCard(
                      items: searches,
                      onTap: (query) {
                        unawaited(_applyRecentSearch(query));
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return RefreshIndicator(
        onRefresh: triggerPullToRefresh,
        color: AppPalette.amber,
        backgroundColor: AppPalette.storm,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
          children: [
            _SearchFeedbackCard(
              title: 'No se pudo completar la busqueda',
              message: 'Intenta nuevamente. $_error',
              actionLabel: 'Reintentar',
              onPressed: () => _runSearch(forceRefresh: true),
            ),
          ],
        ),
      );
    }

    if (_allResults.isEmpty) {
      return RefreshIndicator(
        onRefresh: triggerPullToRefresh,
        color: AppPalette.amber,
        backgroundColor: AppPalette.storm,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
          children: [
            _SearchFeedbackCard(
              title: 'Sin resultados',
              message: _activeQuery.isEmpty
                  ? 'No hay productos para los filtros aplicados en la sucursal seleccionada.'
                  : 'No se encontraron productos para "$_activeQuery" con los filtros actuales.',
            ),
          ],
        ),
      );
    }

    final visibleResults = _visibleResults;
    return RefreshIndicator(
      onRefresh: triggerPullToRefresh,
      color: AppPalette.amber,
      backgroundColor: AppPalette.storm,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        cacheExtent: 900,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemCount: visibleResults.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == visibleResults.length) {
            if (_visibleCount >= _allResults.length) {
              return const SizedBox(height: 8);
            }

            return Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: OutlinedButton(
                  onPressed: _loadMore,
                  child: Text(
                    'Cargar mas (${_allResults.length - _visibleCount} restantes)',
                  ),
                ),
              ),
            );
          }

          return _SearchResultCard(
            result: visibleResults[index],
            categoryName: _categoryName(
              visibleResults[index].product.categoryId,
            ),
            onTap: () {
              unawaited(_openProductDetail(visibleResults[index]));
            },
          );
        },
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.isLoading,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          style: const TextStyle(color: AppPalette.textPrimary),
          decoration: InputDecoration(
            labelText: 'Buscar por nombre, SKU, marca o tag',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: value.text.isEmpty
                ? (isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null)
                : IconButton(
                    onPressed: onClear,
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        );
      },
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.activeCount, required this.onPressed});

  final int activeCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      width: 56,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: const Color(0xFF1E2027),
              ),
              child: const Icon(Icons.tune_rounded),
            ),
          ),
          if (activeCount > 0)
            Positioned(
              top: -5,
              right: -5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppPalette.amber,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFF08090C), width: 2),
                ),
                child: Text(
                  '$activeCount',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _IconShortcutButton extends StatelessWidget {
  const _IconShortcutButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      width: 56,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: const Color(0xFF1E2027),
        ),
        child: Icon(icon),
      ),
    );
  }
}

class _SearchSummary extends StatelessWidget {
  const _SearchSummary({
    required this.activeQuery,
    required this.visibleCount,
    required this.totalCount,
    required this.filters,
    required this.isUsingCache,
  });

  final String activeQuery;
  final int visibleCount;
  final int totalCount;
  final ProductSearchFilters filters;
  final bool isUsingCache;

  @override
  Widget build(BuildContext context) {
    final message = activeQuery.isEmpty && filters.isEmpty
        ? 'Consulta catalogo, stock local y filtros guardados.'
        : activeQuery.isEmpty
        ? 'Mostrando $visibleCount de $totalCount resultado(s) con filtros aplicados.'
        : 'Mostrando $visibleCount de $totalCount resultado(s) para "$activeQuery".';

    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
          ),
          if (isUsingCache)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0x1AFF2636),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0x33FF2636)),
              ),
              child: Text(
                'CACHE LOCAL',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppPalette.amber,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CacheNoticeCard extends StatelessWidget {
  const _CacheNoticeCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF17191F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x33FF2636)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.offline_bolt_rounded, color: AppPalette.amber),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveFiltersCard extends StatelessWidget {
  const _ActiveFiltersCard({
    required this.filters,
    required this.categoryName,
    required this.branchName,
    required this.availabilityLabel,
    required this.onClear,
  });

  final ProductSearchFilters filters;
  final String Function(String id) categoryName;
  final String Function(String id) branchName;
  final String Function(ProductAvailabilityFilter filter) availabilityLabel;
  final Future<void> Function() onClear;

  @override
  Widget build(BuildContext context) {
    final chips = <String>[
      if (filters.categoryId != null)
        'Categoria: ${categoryName(filters.categoryId!)}',
      if (filters.brand != null) 'Marca: ${filters.brand}',
      if (filters.branchId != null)
        'Sucursal: ${branchName(filters.branchId!)}',
      if (filters.availability != ProductAvailabilityFilter.any)
        availabilityLabel(filters.availability),
      if (filters.minStock != null) 'Stock min: ${filters.minStock}',
      if (filters.maxStock != null) 'Stock max: ${filters.maxStock}',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF17191F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x26FF2636)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Filtros activos',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  unawaited(onClear());
                },
                child: const Text('Limpiar'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips
                .map((chip) => _SearchInfoPill(label: chip))
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _SearchHintCard extends StatelessWidget {
  const _SearchHintCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF17191F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x26FF2636)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Buscador de productos',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            'Busca por texto y combina filtros por categoria, marca, sucursal, disponibilidad o rango de stock.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _SavedFiltersCard extends StatelessWidget {
  const _SavedFiltersCard({
    required this.items,
    required this.onTap,
    required this.isLoadingOptions,
  });

  final List<SavedSearchFilter> items;
  final ValueChanged<SavedSearchFilter> onTap;
  final bool isLoadingOptions;

  @override
  Widget build(BuildContext context) {
    final favorites = items
        .where((item) => item.isFavorite)
        .toList(growable: false);
    final recents = items.take(6).toList(growable: false);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF17191F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x26FF2636)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filtros guardados',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          if (isLoadingOptions)
            Text(
              'Cargando opciones de filtros...',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
            )
          else if (items.isEmpty)
            Text(
              'Aun no has guardado filtros recientes o favoritos.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
            )
          else ...[
            if (favorites.isNotEmpty) ...[
              Text(
                'Favoritos',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: favorites
                    .map(
                      (item) => _SavedFilterChip(
                        label: item.label,
                        icon: Icons.star_rounded,
                        onPressed: () => onTap(item),
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              'Recientes',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: recents
                  .map(
                    (item) => _SavedFilterChip(
                      label: item.label,
                      icon: item.isFavorite
                          ? Icons.star_rounded
                          : Icons.history_rounded,
                      onPressed: () => onTap(item),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }
}

class _SavedFilterChip extends StatelessWidget {
  const _SavedFilterChip({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onPressed,
      avatar: Icon(icon, size: 18, color: Colors.white70),
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: Text(label, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _RecentSearchesCard extends StatelessWidget {
  const _RecentSearchesCard({required this.items, required this.onTap});

  final List<SearchHistoryEntry> items;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF17191F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x26FF2636)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Busquedas recientes',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            Text(
              'Aun no has realizado busquedas recientes.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: items
                  .map(
                    (item) => ActionChip(
                      onPressed: () => onTap(item.query),
                      label: Text('${item.query} (${item.hitCount})'),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class _RecentCachedProductsCard extends StatelessWidget {
  const _RecentCachedProductsCard({required this.items, required this.onTap});

  final List<Product> items;
  final ValueChanged<Product> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF17191F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x26FF2636)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Productos recientes en cache',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            'Abre rapidamente los productos que ya consultaste aunque la conexion falle.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: items
                .map(
                  (product) => ActionChip(
                    onPressed: () => onTap(product),
                    avatar: const Icon(
                      Icons.inventory_2_rounded,
                      size: 18,
                      color: Colors.white70,
                    ),
                    label: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Text(
                        product.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _SearchFeedbackCard extends StatelessWidget {
  const _SearchFeedbackCard({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onPressed,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final Future<void> Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF17191F),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x26FF2636)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                ),
                if (actionLabel != null && onPressed != null) ...[
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      unawaited(onPressed!());
                    },
                    child: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({
    required this.result,
    required this.categoryName,
    required this.onTap,
  });

  final ProductSearchResult result;
  final String categoryName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final inventory = result.inventory;
    final isOutOfStock = result.isOutOfStock;
    final statusColor = isOutOfStock ? AppPalette.danger : AppPalette.mint;
    final statusLabel = inventory == null
        ? 'Sin inventario en sucursal'
        : isOutOfStock
        ? 'Sin stock'
        : inventory.isLowStock
        ? 'Stock bajo ${inventory.availableStock}'
        : 'Disponible ${inventory.availableStock}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF17191F),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x26FF2636)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.product.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${result.product.brand} | ${result.product.sku}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Text(
                          statusLabel,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white70,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                result.product.description,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SearchInfoPill(label: categoryName),
                  _SearchInfoPill(
                    label:
                        'Precio ${result.product.currency} ${result.product.price.toStringAsFixed(2)}',
                  ),
                  if (inventory != null)
                    _SearchInfoPill(
                      label: 'Reservado ${inventory.reservedStock}',
                    ),
                  _SearchInfoPill(label: 'Relevancia ${result.relevanceScore}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchInfoPill extends StatelessWidget {
  const _SearchInfoPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x26FF2636)),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: Colors.white70),
      ),
    );
  }
}

class _FilterSheetResult {
  const _FilterSheetResult({required this.filters, this.favoriteLabel});

  final ProductSearchFilters filters;
  final String? favoriteLabel;
}

class _ProductFiltersSheet extends StatefulWidget {
  const _ProductFiltersSheet({
    required this.options,
    required this.initialFilters,
  });

  final ProductSearchFilterOptions options;
  final ProductSearchFilters initialFilters;

  @override
  State<_ProductFiltersSheet> createState() => _ProductFiltersSheetState();
}

class _ProductFiltersSheetState extends State<_ProductFiltersSheet> {
  late String? _selectedCategoryId;
  late String? _selectedBrand;
  late String? _selectedBranchId;
  late ProductAvailabilityFilter _availability;
  late final TextEditingController _minStockController;
  late final TextEditingController _maxStockController;
  late final TextEditingController _favoriteLabelController;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.initialFilters.categoryId;
    _selectedBrand = widget.initialFilters.brand;
    _selectedBranchId = widget.initialFilters.branchId;
    _availability = widget.initialFilters.availability;
    _minStockController = TextEditingController(
      text: widget.initialFilters.minStock?.toString() ?? '',
    );
    _maxStockController = TextEditingController(
      text: widget.initialFilters.maxStock?.toString() ?? '',
    );
    _favoriteLabelController = TextEditingController();
  }

  @override
  void dispose() {
    _minStockController.dispose();
    _maxStockController.dispose();
    _favoriteLabelController.dispose();
    super.dispose();
  }

  ProductSearchFilters _buildFilters() {
    int? parseStock(String value) {
      final parsed = int.tryParse(value.trim());
      if (parsed == null || parsed < 0) {
        return null;
      }
      return parsed;
    }

    return ProductSearchFilters(
      categoryId: _selectedCategoryId,
      brand: _selectedBrand,
      branchId: _selectedBranchId,
      availability: _availability,
      minStock: parseStock(_minStockController.text),
      maxStock: parseStock(_maxStockController.text),
    );
  }

  void _submit({required bool saveFavorite}) {
    final filters = _buildFilters();
    if (saveFavorite && filters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes seleccionar al menos un filtro para guardarlo.'),
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      _FilterSheetResult(
        filters: filters,
        favoriteLabel: saveFavorite
            ? _favoriteLabelController.text.trim().isEmpty
                  ? null
                  : _favoriteLabelController.text.trim()
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Filtros avanzados',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                key: ValueKey('category_${_selectedCategoryId ?? "all"}'),
                initialValue: _selectedCategoryId,
                decoration: const InputDecoration(labelText: 'Categoria'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Todas las categorias'),
                  ),
                  ...widget.options.categories.map(
                    (category) => DropdownMenuItem<String?>(
                      value: category.id,
                      child: Text(category.name),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedCategoryId = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                key: ValueKey('brand_${_selectedBrand ?? "all"}'),
                initialValue: _selectedBrand,
                decoration: const InputDecoration(labelText: 'Marca'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Todas las marcas'),
                  ),
                  ...widget.options.brands.map(
                    (brand) => DropdownMenuItem<String?>(
                      value: brand,
                      child: Text(brand),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedBrand = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                key: ValueKey('branch_${_selectedBranchId ?? "current"}'),
                initialValue: _selectedBranchId,
                decoration: const InputDecoration(labelText: 'Sucursal'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Sucursal actual'),
                  ),
                  ...widget.options.branches.map(
                    (branch) => DropdownMenuItem<String?>(
                      value: branch.id,
                      child: Text(branch.name),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedBranchId = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ProductAvailabilityFilter>(
                key: ValueKey('availability_${_availability.name}'),
                initialValue: _availability,
                decoration: const InputDecoration(labelText: 'Disponibilidad'),
                items: const [
                  DropdownMenuItem(
                    value: ProductAvailabilityFilter.any,
                    child: Text('Cualquier disponibilidad'),
                  ),
                  DropdownMenuItem(
                    value: ProductAvailabilityFilter.available,
                    child: Text('Disponible'),
                  ),
                  DropdownMenuItem(
                    value: ProductAvailabilityFilter.outOfStock,
                    child: Text('Sin stock'),
                  ),
                  DropdownMenuItem(
                    value: ProductAvailabilityFilter.lowStock,
                    child: Text('Stock bajo'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _availability = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minStockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Stock minimo',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _maxStockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Stock maximo',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _favoriteLabelController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del favorito',
                  hintText: 'Ejemplo: Marca Samsung sin stock',
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop(
                        const _FilterSheetResult(
                          filters: ProductSearchFilters(),
                        ),
                      );
                    },
                    child: const Text('Limpiar filtros'),
                  ),
                  FilledButton(
                    onPressed: () => _submit(saveFavorite: false),
                    child: const Text('Aplicar filtros'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _submit(saveFavorite: true),
                    icon: const Icon(Icons.star_rounded),
                    label: const Text('Guardar favorito'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
