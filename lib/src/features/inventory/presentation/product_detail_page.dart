import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../application/inventory_workflow_service.dart';

class ProductDetailPage extends StatelessWidget {
  const ProductDetailPage({
    super.key,
    required this.result,
    required this.categoryLabel,
    required this.branchLabel,
  });

  final ProductSearchResult result;
  final String categoryLabel;
  final String branchLabel;

  @override
  Widget build(BuildContext context) {
    final inventory = result.inventory;
    final isOutOfStock = result.isOutOfStock;
    final statusColor = isOutOfStock ? AppPalette.danger : AppPalette.mint;
    final statusLabel = inventory == null
        ? 'Sin inventario en esta sucursal'
        : inventory.availableStock <= 0
        ? 'Sin stock disponible'
        : inventory.isLowStock
        ? 'Stock bajo'
        : 'Disponible';

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del producto')),
      body: Container(
        color: const Color(0xFF08172D),
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _DetailPanel(
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
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${result.product.brand} | ${result.product.sku}',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.28),
                            ),
                          ),
                          child: Text(
                            statusLabel,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      result.product.description,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _DetailGrid(
                items: [
                  _DetailItem(
                    label: 'Sucursal',
                    value: inventory?.branchName ?? branchLabel,
                  ),
                  _DetailItem(label: 'Categoria', value: categoryLabel),
                  _DetailItem(
                    label: 'Codigo de barras',
                    value: result.product.barcode,
                  ),
                  _DetailItem(
                    label: 'Precio',
                    value:
                        '${result.product.currency} ${result.product.price.toStringAsFixed(2)}',
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
              if (inventory != null) ...[
                const SizedBox(height: 16),
                _DetailPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estado local',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _MetricPill(label: 'SKU ${inventory.sku}'),
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
          ),
        ),
      ),
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
