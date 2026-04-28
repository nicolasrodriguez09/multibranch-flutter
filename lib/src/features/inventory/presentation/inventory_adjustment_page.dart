import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_theme.dart';
import '../application/inventory_workflow_service.dart';
import '../domain/models.dart';
import '../domain/role_permissions.dart';
import 'branch_panel_drawer.dart';

class InventoryAdjustmentPage extends StatefulWidget {
  const InventoryAdjustmentPage({
    super.key,
    required this.service,
    required this.currentUser,
  });

  final InventoryWorkflowService service;
  final AppUser currentUser;

  @override
  State<InventoryAdjustmentPage> createState() =>
      _InventoryAdjustmentPageState();
}

class _InventoryAdjustmentPageState extends State<InventoryAdjustmentPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String? _busyInventoryId;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleQueryChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleQueryChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleQueryChanged() {
    setState(() {
      _query = _searchController.text.trim().toLowerCase();
    });
  }

  Future<void> _openAdjustmentDialog(InventoryItem item) async {
    final request = await showDialog<_InventoryAdjustmentRequest>(
      context: context,
      builder: (context) => _InventoryAdjustmentDialog(item: item),
    );
    if (request == null) {
      return;
    }

    setState(() {
      _busyInventoryId = item.id;
    });

    try {
      await widget.service.setInventoryStock(
        actorUser: widget.currentUser,
        branchId: widget.currentUser.branchId,
        productId: item.productId,
        stock: request.stock,
        minimumStock: request.minimumStock,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Inventario actualizado para ${item.productName}. Stock ${request.stock}, minimo ${request.minimumStock}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar el inventario: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyInventoryId = null;
        });
      }
    }
  }

  bool _matchesQuery(InventoryItem item) {
    if (_query.isEmpty) {
      return true;
    }

    return item.productName.toLowerCase().contains(_query) ||
        item.sku.toLowerCase().contains(_query);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.currentUser.can(AppPermission.manageInventory)) {
      return Scaffold(
        drawer: BranchPanelDrawer(
          service: widget.service,
          currentUser: widget.currentUser,
          currentDestination: BranchPanelDestination.inventoryAdjustment,
        ),
        appBar: AppBar(title: const Text('Ajuste de inventario')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Tu usuario no tiene permisos para ajustar inventario.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      drawer: BranchPanelDrawer(
        service: widget.service,
        currentUser: widget.currentUser,
        currentDestination: BranchPanelDestination.inventoryAdjustment,
      ),
      appBar: AppBar(
        title: const Text('Ajuste de inventario'),
        actions: [
          IconButton(
            tooltip: 'Limpiar filtro',
            onPressed: _query.isEmpty ? null : () => _searchController.clear(),
            icon: const Icon(Icons.clear_rounded),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF081A33), Color(0xFF0A2142), Color(0xFF08172D)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          top: false,
          child: StreamBuilder<List<InventoryItem>>(
            stream: widget.service.inventories.watchBranchInventory(
              widget.currentUser.branchId,
            ),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No se pudo cargar el inventario de la sucursal. ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final allItems = snapshot.data ?? const <InventoryItem>[];
              final filteredItems = allItems
                  .where(_matchesQuery)
                  .toList(growable: false);

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: [
                  _InventoryAdjustmentHeader(
                    currentUser: widget.currentUser,
                    totalItems: allItems.length,
                    lowStockItems: allItems
                        .where((item) => item.isLowStock)
                        .length,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      labelText: 'Buscar por producto o SKU',
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (filteredItems.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF102540),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0x26FFFFFF)),
                      ),
                      child: Text(
                        _query.isEmpty
                            ? 'No hay inventario registrado para esta sucursal.'
                            : 'No hay coincidencias para el filtro actual.',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                      ),
                    )
                  else
                    ...filteredItems.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _InventoryAdjustmentCard(
                          item: item,
                          isBusy: _busyInventoryId == item.id,
                          onAdjust: () => _openAdjustmentDialog(item),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _InventoryAdjustmentHeader extends StatelessWidget {
  const _InventoryAdjustmentHeader({
    required this.currentUser,
    required this.totalItems,
    required this.lowStockItems,
  });

  final AppUser currentUser;
  final int totalItems;
  final int lowStockItems;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF214C9A), Color(0xFF173C78), Color(0xFF102543)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Operacion de inventario',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajusta stock fisico y minimos operativos de ${currentUser.branchId.toUpperCase()} sin salir del panel de sucursal.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InventoryInfoPill(label: 'Sucursal ${currentUser.branchId}'),
              _InventoryInfoPill(label: '$totalItems productos'),
              _InventoryInfoPill(label: '$lowStockItems con stock bajo'),
            ],
          ),
        ],
      ),
    );
  }
}

class _InventoryAdjustmentCard extends StatelessWidget {
  const _InventoryAdjustmentCard({
    required this.item,
    required this.isBusy,
    required this.onAdjust,
  });

  final InventoryItem item;
  final bool isBusy;
  final VoidCallback onAdjust;

  @override
  Widget build(BuildContext context) {
    final accent = item.availableStock <= 0
        ? AppPalette.danger
        : item.isLowStock
        ? AppPalette.amber
        : AppPalette.mint;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF102540),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.26)),
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
                      item.productName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'SKU ${item.sku}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: isBusy ? null : onAdjust,
                icon: isBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.tune_rounded),
                label: Text(isBusy ? 'Guardando' : 'Ajustar'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InventoryMetricChip(
                label: 'Stock fisico',
                value: '${item.stock}',
                accent: AppPalette.blueSoft,
              ),
              _InventoryMetricChip(
                label: 'Disponible',
                value: '${item.availableStock}',
                accent: accent,
              ),
              _InventoryMetricChip(
                label: 'Reservado',
                value: '${item.reservedStock}',
                accent: AppPalette.amber,
              ),
              _InventoryMetricChip(
                label: 'Minimo',
                value: '${item.minimumStock}',
                accent: AppPalette.cyan,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.isLowStock
                ? 'La disponibilidad esta en el umbral o por debajo del minimo.'
                : 'Inventario estable para la operacion actual.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _InventoryAdjustmentRequest {
  const _InventoryAdjustmentRequest({
    required this.stock,
    required this.minimumStock,
  });

  final int stock;
  final int minimumStock;
}

class _InventoryAdjustmentDialog extends StatefulWidget {
  const _InventoryAdjustmentDialog({required this.item});

  final InventoryItem item;

  @override
  State<_InventoryAdjustmentDialog> createState() =>
      _InventoryAdjustmentDialogState();
}

class _InventoryAdjustmentDialogState
    extends State<_InventoryAdjustmentDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _stockController;
  late final TextEditingController _minimumStockController;

  @override
  void initState() {
    super.initState();
    _stockController = TextEditingController(text: '${widget.item.stock}');
    _minimumStockController = TextEditingController(
      text: '${widget.item.minimumStock}',
    );
  }

  @override
  void dispose() {
    _stockController.dispose();
    _minimumStockController.dispose();
    super.dispose();
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    Navigator.of(context).pop(
      _InventoryAdjustmentRequest(
        stock: int.parse(_stockController.text.trim()),
        minimumStock: int.parse(_minimumStockController.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajustar inventario'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${widget.item.productName} | SKU ${widget.item.sku}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _stockController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Stock fisico'),
              validator: (value) {
                final stock = int.tryParse((value ?? '').trim());
                if (stock == null) {
                  return 'Ingresa un stock valido.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _minimumStockController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Stock minimo'),
              validator: (value) {
                final minimumStock = int.tryParse((value ?? '').trim());
                if (minimumStock == null) {
                  return 'Ingresa un minimo valido.';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }
}

class _InventoryInfoPill extends StatelessWidget {
  const _InventoryInfoPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: Colors.white),
      ),
    );
  }
}

class _InventoryMetricChip extends StatelessWidget {
  const _InventoryMetricChip({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
