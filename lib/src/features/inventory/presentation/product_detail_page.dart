import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../application/inventory_workflow_service.dart';
import '../domain/models.dart';
import 'branch_directory_page.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({
    super.key,
    required this.service,
    required this.currentUser,
    required this.productId,
    this.branchId,
  });

  final InventoryWorkflowService service;
  final AppUser currentUser;
  final String productId;
  final String? branchId;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  late Future<ProductDetailData> _detailFuture;

  String get _effectiveBranchId =>
      widget.branchId ?? widget.currentUser.branchId;

  @override
  void initState() {
    super.initState();
    _detailFuture = _loadDetail();
  }

  Future<ProductDetailData> _loadDetail({bool forceRefresh = false}) {
    return widget.service.fetchProductDetail(
      actorUser: widget.currentUser,
      branchId: _effectiveBranchId,
      productId: widget.productId,
      forceRefresh: forceRefresh,
    );
  }

  void _retry() {
    setState(() {
      _detailFuture = _loadDetail(forceRefresh: true);
    });
  }

  Future<void> _openBranchDirectory() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => BranchDirectoryPage(
          service: widget.service,
          currentUser: widget.currentUser,
          selectedProductId: widget.productId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del producto'),
        actions: [
          IconButton(
            tooltip: 'Ver sucursales',
            onPressed: _openBranchDirectory,
            icon: const Icon(Icons.store_mall_directory_rounded),
          ),
          IconButton(
            tooltip: 'Actualizar detalle',
            onPressed: _retry,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Container(
        color: const Color(0xFF08172D),
        child: SafeArea(
          top: false,
          child: FutureBuilder<ProductDetailData>(
            future: _detailFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const _ProductDetailLoadingState();
              }

              if (snapshot.hasError) {
                return _ProductDetailErrorState(
                  message: 'No se pudo cargar el detalle. ${snapshot.error}',
                  onRetry: _retry,
                );
              }

              final detail = snapshot.requireData;
              return _ProductDetailContent(detail: detail);
            },
          ),
        ),
      ),
    );
  }
}

class _ProductDetailContent extends StatelessWidget {
  const _ProductDetailContent({required this.detail});

  final ProductDetailData detail;

  @override
  Widget build(BuildContext context) {
    final product = detail.product;
    final inventory = detail.inventory;
    final statusColor = detail.isOutOfStock
        ? AppPalette.danger
        : AppPalette.mint;
    final statusLabel = inventory == null
        ? 'Sin inventario en esta sucursal'
        : inventory.availableStock <= 0
        ? 'Sin stock disponible'
        : inventory.isLowStock
        ? 'Stock bajo'
        : 'Disponible';
    final branchLabel =
        detail.branch?.name ?? inventory?.branchName ?? 'Sucursal actual';
    final categoryLabel = detail.category?.name.isNotEmpty == true
        ? detail.category!.name
        : 'Sin categoria';
    final imageUrl = product.imageUrl.trim();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _DetailPanel(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProductImageBox(imageUrl: imageUrl),
              const SizedBox(width: 16),
              Expanded(
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
                                product.name,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${product.brand} | ${product.sku}',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        _StatusBadge(label: statusLabel, color: statusColor),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      product.description,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MetricPill(
                          label:
                              'Precio ${product.currency} ${product.price.toStringAsFixed(2)}',
                        ),
                        _MetricPill(
                          label:
                              'Costo ${product.currency} ${product.cost.toStringAsFixed(2)}',
                        ),
                        _MetricPill(label: 'Sucursal $branchLabel'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _DataReliabilityPanel(
          reliability: detail.reliability,
          isFromCache: detail.isFromCache,
        ),
        if (detail.shouldShowAlternativeSuggestions) ...[
          const SizedBox(height: 16),
          _AlternativeBranchSuggestionPanel(
            suggestions: detail.branchSuggestions,
            recommendedSuggestion: detail.recommendedSuggestion,
          ),
        ],
        const SizedBox(height: 16),
        _DetailGrid(
          items: [
            _DetailItem(label: 'SKU', value: product.sku),
            _DetailItem(label: 'Codigo de barras', value: product.barcode),
            _DetailItem(label: 'Categoria', value: categoryLabel),
            _DetailItem(label: 'Marca', value: product.brand),
            _DetailItem(
              label: 'Precio',
              value: '${product.currency} ${product.price.toStringAsFixed(2)}',
            ),
            _DetailItem(
              label: 'Costo',
              value: '${product.currency} ${product.cost.toStringAsFixed(2)}',
            ),
            _DetailItem(
              label: 'Stock disponible',
              value: '${inventory?.availableStock ?? 0}',
            ),
            _DetailItem(
              label: 'Stock reservado',
              value: '${inventory?.reservedStock ?? 0}',
            ),
            _DetailItem(
              label: 'Stock entrante',
              value: '${inventory?.incomingStock ?? 0}',
            ),
            _DetailItem(
              label: 'Stock minimo',
              value: '${inventory?.minimumStock ?? 0}',
            ),
          ],
        ),
        const SizedBox(height: 16),
        _StockByBranchPanel(entries: detail.stockByBranch),
        const SizedBox(height: 16),
        _DetailPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Atributos del producto',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              if (product.tags.isEmpty)
                Text(
                  'No hay atributos adicionales registrados.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: product.tags
                      .map((tag) => _MetricPill(label: tag))
                      .toList(growable: false),
                ),
            ],
          ),
        ),
        if (inventory != null) ...[
          const SizedBox(height: 16),
          _DetailPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estado de inventario',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetricPill(
                      label: inventory.isLowStock
                          ? 'Requiere reposicion'
                          : 'Cobertura estable',
                    ),
                    if (inventory.lastSyncAt != null)
                      _MetricPill(
                        label:
                            'Sincronizado ${_formatDateTime(inventory.lastSyncAt!)}',
                      ),
                    if (inventory.lastMovementAt != null)
                      _MetricPill(
                        label:
                            'Ultimo movimiento ${_formatDateTime(inventory.lastMovementAt!)}',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  static String _formatDateTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }
}

class _StockByBranchPanel extends StatelessWidget {
  const _StockByBranchPanel({required this.entries});

  final List<ProductBranchStockEntry> entries;

  @override
  Widget build(BuildContext context) {
    final yellowCount = entries
        .where(
          (entry) =>
              entry.reliability.level == InventoryDataReliabilityLevel.yellow,
        )
        .length;
    final redCount = entries
        .where(
          (entry) =>
              entry.reliability.level == InventoryDataReliabilityLevel.red,
        )
        .length;

    return _DetailPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Stock por sucursal',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              const _MetricPill(label: 'Ordenado por disponibilidad'),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _MetricPill(label: 'Verde <= 15 min'),
              _MetricPill(label: 'Amarillo <= 30 min'),
              _MetricPill(label: 'Rojo > 30 min o incompleto'),
            ],
          ),
          if (yellowCount > 0 || redCount > 0) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (redCount > 0 ? AppPalette.danger : AppPalette.amber)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (redCount > 0 ? AppPalette.danger : AppPalette.amber)
                      .withValues(alpha: 0.28),
                ),
              ),
              child: Text(
                _buildReliabilitySummary(
                  yellowCount: yellowCount,
                  redCount: redCount,
                ),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Text(
              'No hay datos consolidados por sucursal para este producto.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
            )
          else
            Column(
              children: entries
                  .map((entry) => _BranchStockCard(entry: entry))
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }

  static String _buildReliabilitySummary({
    required int yellowCount,
    required int redCount,
  }) {
    if (yellowCount > 0 && redCount > 0) {
      return 'Hay $yellowCount sucursales en amarillo y $redCount en rojo.';
    }
    if (redCount > 0) {
      return redCount == 1
          ? 'Hay 1 sucursal en rojo.'
          : 'Hay $redCount sucursales en rojo.';
    }
    return yellowCount == 1
        ? 'Hay 1 sucursal en amarillo.'
        : 'Hay $yellowCount sucursales en amarillo.';
  }
}

class _BranchStockCard extends StatelessWidget {
  const _BranchStockCard({required this.entry});

  final ProductBranchStockEntry entry;

  @override
  Widget build(BuildContext context) {
    final lastUpdatedLabel = entry.lastUpdatedAt == null
        ? 'Sin actualizacion registrada'
        : 'Ultima actualizacion ${_ProductDetailContent._formatDateTime(entry.lastUpdatedAt!)}';
    final statusColor = _reliabilityColor(entry.reliability.level);
    final statusLabel = entry.reliability.statusLabel;
    final ageLabel = _formatReliabilityAge(entry.reliability.age);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x1FFFFFFF)),
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
                      entry.branch.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${entry.branch.code} | ${entry.branch.city}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _StatusBadge(label: statusLabel, color: statusColor),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            lastUpdatedLabel,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 6),
          Text(
            'Antiguedad $ageLabel',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            entry.reliability.message,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StockMetricTile(
                label: 'Disponible',
                value: '${entry.availableStock}',
              ),
              _StockMetricTile(
                label: 'Fisico',
                value: '${entry.physicalStock}',
              ),
              _StockMetricTile(
                label: 'Reservado',
                value: '${entry.reservedStock}',
              ),
              _StockMetricTile(
                label: 'En transito',
                value: '${entry.inTransitStock}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DataReliabilityPanel extends StatelessWidget {
  const _DataReliabilityPanel({
    required this.reliability,
    required this.isFromCache,
  });

  final InventoryDataReliability reliability;
  final bool isFromCache;

  @override
  Widget build(BuildContext context) {
    final statusColor = _reliabilityColor(reliability.level);
    final lastUpdatedLabel = reliability.lastUpdatedAt == null
        ? 'Sin timestamp de actualizacion'
        : 'Ultima actualizacion ${_ProductDetailContent._formatDateTime(reliability.lastUpdatedAt!)}';
    final ageLabel = _formatReliabilityAge(reliability.age);

    return _DetailPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Confiabilidad del dato',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              _StatusBadge(label: reliability.statusLabel, color: statusColor),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            reliability.message,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricPill(label: lastUpdatedLabel),
              _MetricPill(label: 'Antiguedad $ageLabel'),
              const _MetricPill(label: 'Verde <= 15 min'),
              const _MetricPill(label: 'Amarillo <= 30 min'),
              const _MetricPill(label: 'Rojo > 30 min o incompleto'),
            ],
          ),
          if (isFromCache) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x26FFFFFF)),
              ),
              child: Text(
                'Mostrando informacion desde cache local. Confirma antes de comunicar si el cliente necesita una validacion exacta.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AlternativeBranchSuggestionPanel extends StatefulWidget {
  const _AlternativeBranchSuggestionPanel({
    required this.suggestions,
    required this.recommendedSuggestion,
  });

  final List<ProductBranchSuggestion> suggestions;
  final ProductBranchSuggestion? recommendedSuggestion;

  @override
  State<_AlternativeBranchSuggestionPanel> createState() =>
      _AlternativeBranchSuggestionPanelState();
}

class _AlternativeBranchSuggestionPanelState
    extends State<_AlternativeBranchSuggestionPanel> {
  String? _selectedBranchId;

  @override
  void initState() {
    super.initState();
    _selectedBranchId = widget.recommendedSuggestion?.branch.id;
  }

  @override
  void didUpdateWidget(covariant _AlternativeBranchSuggestionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recommendedSuggestion?.branch.id !=
        widget.recommendedSuggestion?.branch.id) {
      _selectedBranchId = widget.recommendedSuggestion?.branch.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.suggestions.isEmpty) {
      return _DetailPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sucursal alternativa sugerida',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppPalette.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppPalette.danger.withValues(alpha: 0.28),
                ),
              ),
              child: Text(
                'No hay stock disponible en ninguna sucursal para este producto.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final selectedSuggestion = widget.suggestions.firstWhere(
      (suggestion) => suggestion.branch.id == _selectedBranchId,
      orElse: () => widget.recommendedSuggestion ?? widget.suggestions.first,
    );

    return _DetailPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Sucursal alternativa sugerida',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              const _StatusBadge(label: 'Recomendada', color: AppPalette.mint),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Tu sucursal no tiene stock disponible. Se prioriza cercania, stock y tiempo estimado de traslado.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x1FFFFFFF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedSuggestion.branch.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  selectedSuggestion.rationale,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _StockMetricTile(
                      label: 'Disponible',
                      value: '${selectedSuggestion.availableStock}',
                    ),
                    _StockMetricTile(
                      label: 'Distancia',
                      value:
                          '${selectedSuggestion.distanceKm.toStringAsFixed(1)} km',
                    ),
                    _StockMetricTile(
                      label: 'ETA traslado',
                      value: selectedSuggestion.etaLabel,
                    ),
                    _StockMetricTile(
                      label: 'Confiabilidad',
                      value:
                          selectedSuggestion.stockEntry.reliability.statusLabel,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (widget.suggestions.length > 1) ...[
            const SizedBox(height: 12),
            Text(
              'Otras opciones sugeridas',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.suggestions
                  .map(
                    (suggestion) => ChoiceChip(
                      label: Text(suggestion.branch.name),
                      selected: suggestion.branch.id == _selectedBranchId,
                      onSelected: (_) {
                        setState(() {
                          _selectedBranchId = suggestion.branch.id;
                        });
                      },
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

class _ProductDetailLoadingState extends StatelessWidget {
  const _ProductDetailLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _ProductDetailErrorState extends StatelessWidget {
  const _ProductDetailErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: _DetailPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'No se pudo cargar el producto',
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
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductImageBox extends StatelessWidget {
  const _ProductImageBox({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    const size = 120.0;
    final decoration = BoxDecoration(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0x26FFFFFF)),
    );

    if (imageUrl.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: decoration,
        alignment: Alignment.center,
        child: const Icon(
          Icons.inventory_2_outlined,
          color: Colors.white70,
          size: 40,
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: decoration,
      child: Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) {
          return const Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: Colors.white70,
              size: 36,
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        },
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DetailPanel extends StatelessWidget {
  const _DetailPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF102540),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x26FFFFFF)),
      ),
      child: child,
    );
  }
}

class _DetailGrid extends StatelessWidget {
  const _DetailGrid({required this.items});

  final List<_DetailItem> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items
          .map(
            (item) => SizedBox(
              width: 180,
              child: _DetailPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: Theme.of(
                        context,
                      ).textTheme.labelMedium?.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.value,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _DetailItem {
  const _DetailItem({required this.label, required this.value});

  final String label;
  final String value;
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x26FFFFFF)),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: Colors.white70),
      ),
    );
  }
}

class _StockMetricTile extends StatelessWidget {
  const _StockMetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

Color _reliabilityColor(InventoryDataReliabilityLevel level) {
  return switch (level) {
    InventoryDataReliabilityLevel.green => AppPalette.mint,
    InventoryDataReliabilityLevel.yellow => AppPalette.amber,
    InventoryDataReliabilityLevel.red => AppPalette.danger,
  };
}

String _formatReliabilityAge(Duration? age) {
  if (age == null) {
    return 'sin dato';
  }

  if (age.inMinutes < 1) {
    return '< 1 min';
  }

  if (age.inHours < 1) {
    return '${age.inMinutes} min';
  }

  final hours = age.inHours;
  final minutes = age.inMinutes.remainder(60);
  if (age.inDays < 1) {
    return minutes == 0 ? '$hours h' : '$hours h $minutes min';
  }

  final days = age.inDays;
  final remainingHours = age.inHours.remainder(24);
  return remainingHours == 0 ? '$days d' : '$days d $remainingHours h';
}
