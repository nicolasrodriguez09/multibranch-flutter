import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_theme.dart';
import '../application/inventory_workflow_service.dart';
import '../domain/models.dart';
import 'branch_panel_drawer.dart';

class TransferRequestPage extends StatefulWidget {
  const TransferRequestPage({
    super.key,
    required this.service,
    required this.currentUser,
    this.initialProductId,
  });

  final InventoryWorkflowService service;
  final AppUser currentUser;
  final String? initialProductId;

  @override
  State<TransferRequestPage> createState() => _TransferRequestPageState();
}

class _TransferRequestPageState extends State<TransferRequestPage> {
  final _formKey = GlobalKey<FormState>();
  late Future<List<TransferRequestCatalogItem>> _catalogFuture;
  late final TextEditingController _quantityController;
  late final TextEditingController _reasonController;
  late final TextEditingController _notesController;

  Future<ProductDetailData>? _productDetailFuture;
  late Future<SyncStatusOverview?> _syncStatusFuture;
  String? _selectedProductId;
  String? _selectedSourceBranchId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(text: '1');
    _reasonController = TextEditingController();
    _notesController = TextEditingController();
    _selectedProductId = widget.initialProductId;
    _catalogFuture = _loadCatalog();
    _syncStatusFuture = _loadSyncStatus();
    if (_selectedProductId != null && _selectedProductId!.isNotEmpty) {
      _productDetailFuture = _loadProductDetail(_selectedProductId!);
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<List<TransferRequestCatalogItem>> _loadCatalog() {
    return widget.service.fetchTransferRequestCatalog(
      actorUser: widget.currentUser,
    );
  }

  Future<SyncStatusOverview?> _loadSyncStatus() async {
    try {
      return await widget.service.fetchSyncStatusOverview(
        actorUser: widget.currentUser,
      );
    } catch (_) {
      return null;
    }
  }

  Future<ProductDetailData> _loadProductDetail(
    String productId, {
    bool forceRefresh = false,
  }) {
    return widget.service.fetchProductDetail(
      actorUser: widget.currentUser,
      branchId: widget.currentUser.branchId,
      productId: productId,
      forceRefresh: forceRefresh,
    );
  }

  void _selectProduct(String? productId) {
    setState(() {
      _selectedProductId = productId;
      _selectedSourceBranchId = null;
      _productDetailFuture = productId == null || productId.isEmpty
          ? null
          : _loadProductDetail(productId);
    });
  }

  Future<void> _refreshSelectedProduct() async {
    final productId = _selectedProductId;
    if (productId == null || productId.isEmpty) {
      setState(() {
        _catalogFuture = _loadCatalog();
      });
      return;
    }

    setState(() {
      _catalogFuture = _loadCatalog();
      _syncStatusFuture = _loadSyncStatus();
      _productDetailFuture = _loadProductDetail(productId, forceRefresh: true);
    });
  }

  String? _effectiveSourceBranchId(ProductDetailData detail) {
    if (detail.branchSuggestions.isEmpty) {
      return null;
    }

    final requestedBranchId = _selectedSourceBranchId;
    if (requestedBranchId == null || requestedBranchId.isEmpty) {
      return detail.branchSuggestions.first.branch.id;
    }

    final exists = detail.branchSuggestions.any(
      (item) => item.branch.id == requestedBranchId,
    );
    if (!exists) {
      return detail.branchSuggestions.first.branch.id;
    }
    return requestedBranchId;
  }

  ProductBranchSuggestion? _selectedSource(ProductDetailData detail) {
    final sourceBranchId = _effectiveSourceBranchId(detail);
    if (sourceBranchId == null) {
      return null;
    }

    return detail.branchSuggestions.cast<ProductBranchSuggestion?>().firstWhere(
      (item) => item?.branch.id == sourceBranchId,
      orElse: () => null,
    );
  }

  Future<void> _submit(ProductDetailData detail) async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final productId = _selectedProductId;
    final selectedSource = _selectedSource(detail);
    if (productId == null || selectedSource == null) {
      _showStatusMessage(
        'Selecciona un producto y una sucursal origen con stock disponible.',
      );
      return;
    }

    final quantity = int.tryParse(_quantityController.text.trim()) ?? 0;
    if (quantity > selectedSource.availableStock) {
      _showStatusMessage(
        'La cantidad supera el stock disponible en ${selectedSource.branch.name}.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final transfer = await widget.service.requestTransfer(
        actorUser: widget.currentUser,
        productId: productId,
        fromBranchId: selectedSource.branch.id,
        toBranchId: widget.currentUser.branchId,
        quantity: quantity,
        reason: _reasonController.text.trim(),
        notes: _notesController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      _quantityController.text = '1';
      _reasonController.clear();
      _notesController.clear();
      setState(() {
        _catalogFuture = _loadCatalog();
        _productDetailFuture = _loadProductDetail(
          productId,
          forceRefresh: true,
        );
        _isSubmitting = false;
      });

      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Solicitud enviada'),
            content: Text(
              'Se envio el traslado ${transfer.id} desde ${transfer.fromBranchName} hacia ${transfer.toBranchName} por ${transfer.quantity} unidad(es).',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cerrar'),
              ),
            ],
          );
        },
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showStatusMessage('No se pudo enviar la solicitud: $error');
    } finally {
      if (mounted && _isSubmitting) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showStatusMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: BranchPanelDrawer(
        service: widget.service,
        currentUser: widget.currentUser,
        currentDestination: BranchPanelDestination.transferRequest,
      ),
      appBar: AppBar(
        title: const Text('Solicitar traslado'),
        actions: [
          IconButton(
            tooltip: 'Actualizar formulario',
            onPressed: _refreshSelectedProduct,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Container(
        color: const Color(0xFF08172D),
        child: SafeArea(
          top: false,
          child: FutureBuilder<List<TransferRequestCatalogItem>>(
            future: _catalogFuture,
            builder: (context, catalogSnapshot) {
              if (catalogSnapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }

              if (catalogSnapshot.hasError) {
                return _TransferRequestErrorState(
                  title: 'No se pudo cargar el formulario',
                  message:
                      'Ocurrio un problema preparando la solicitud de traslado. ${catalogSnapshot.error}',
                  onRetry: _refreshSelectedProduct,
                );
              }

              final catalog = catalogSnapshot.requireData;
              final selectedCatalogItem = catalog
                  .cast<TransferRequestCatalogItem?>()
                  .firstWhere(
                    (item) => item?.product.id == _selectedProductId,
                    orElse: () => null,
                  );

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: [
                  _TransferRequestHeader(
                    currentUser: widget.currentUser,
                    selectedCatalogItem: selectedCatalogItem,
                  ),
                  const SizedBox(height: 16),
                  _TransferProductSelectorCard(
                    catalog: catalog,
                    selectedProductId: _selectedProductId,
                    onChanged: _selectProduct,
                  ),
                  const SizedBox(height: 16),
                  if (_productDetailFuture == null)
                    const _TransferRequestEmptySelection()
                  else
                    FutureBuilder<ProductDetailData>(
                      future: _productDetailFuture,
                      builder: (context, detailSnapshot) {
                        if (detailSnapshot.connectionState !=
                            ConnectionState.done) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 36),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        if (detailSnapshot.hasError) {
                          return _TransferRequestErrorState(
                            title: 'No se pudo consultar el producto',
                            message:
                                'No fue posible cargar el detalle de inventario para esta solicitud. ${detailSnapshot.error}',
                            onRetry: _refreshSelectedProduct,
                          );
                        }

                        final detail = detailSnapshot.requireData;
                        return FutureBuilder<SyncStatusOverview?>(
                          future: _syncStatusFuture,
                          builder: (context, syncSnapshot) {
                            final syncStatuses = {
                              for (final status
                                  in syncSnapshot.data?.branches ??
                                      const <SyncBranchStatus>[])
                                status.branch.id: status,
                            };
                            final selectedSource = _selectedSource(detail);
                            return Column(
                              children: [
                                _TransferStockContextCard(
                                  detail: detail,
                                  selectedSource: selectedSource,
                                  syncStatuses: syncStatuses,
                                ),
                                const SizedBox(height: 16),
                                _TransferRequestFormCard(
                                  formKey: _formKey,
                                  detail: detail,
                                  syncStatuses: syncStatuses,
                                  selectedSourceBranchId:
                                      _effectiveSourceBranchId(detail),
                                  quantityController: _quantityController,
                                  reasonController: _reasonController,
                                  notesController: _notesController,
                                  isSubmitting: _isSubmitting,
                                  onChangedSource: (value) {
                                    setState(() {
                                      _selectedSourceBranchId = value;
                                    });
                                  },
                                  onSubmit: () => _submit(detail),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  const SizedBox(height: 16),
                  _RecentTransferRequestsCard(
                    service: widget.service,
                    branchId: widget.currentUser.branchId,
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

class _TransferRequestHeader extends StatelessWidget {
  const _TransferRequestHeader({
    required this.currentUser,
    required this.selectedCatalogItem,
  });

  final AppUser currentUser;
  final TransferRequestCatalogItem? selectedCatalogItem;

  @override
  Widget build(BuildContext context) {
    final stockLabel = selectedCatalogItem == null
        ? 'Selecciona un producto para validar disponibilidad en otras sedes.'
        : selectedCatalogItem!.isOutOfStock
        ? 'Sin stock en tu sede para ${selectedCatalogItem!.product.name}.'
        : 'Stock en tu sede: ${selectedCatalogItem!.currentAvailableStock} unidad(es).';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF102540),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x26FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Traslado hacia tu sucursal',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            'Solicita inventario disponible en otra sede para atender ventas sin stock en ${currentUser.branchId.toUpperCase()}.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TransferInfoPill(label: 'Destino ${currentUser.branchId}'),
              _TransferInfoPill(label: stockLabel),
            ],
          ),
        ],
      ),
    );
  }
}

class _TransferProductSelectorCard extends StatelessWidget {
  const _TransferProductSelectorCard({
    required this.catalog,
    required this.selectedProductId,
    required this.onChanged,
  });

  final List<TransferRequestCatalogItem> catalog;
  final String? selectedProductId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF102540),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x26FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Producto',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: ValueKey<String?>('product_$selectedProductId'),
            initialValue: selectedProductId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Selecciona el producto a reponer',
            ),
            items: catalog
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item.product.id,
                    child: Text(
                      '${item.product.name} | SKU ${item.product.sku} | local ${item.currentAvailableStock}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _TransferStockContextCard extends StatelessWidget {
  const _TransferStockContextCard({
    required this.detail,
    required this.selectedSource,
    required this.syncStatuses,
  });

  final ProductDetailData detail;
  final ProductBranchSuggestion? selectedSource;
  final Map<String, SyncBranchStatus> syncStatuses;

  @override
  Widget build(BuildContext context) {
    final currentAvailable = detail.inventory?.availableStock ?? 0;
    final incomingStock = detail.inventory?.incomingStock ?? 0;
    final hasSources = detail.branchSuggestions.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF102540),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x26FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contexto del inventario',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _TransferMetricChip(
                label: 'Disponible en tu sede',
                value: '$currentAvailable',
                accent: currentAvailable <= 0
                    ? AppPalette.danger
                    : AppPalette.blueSoft,
              ),
              _TransferMetricChip(
                label: 'En camino a tu sede',
                value: '$incomingStock',
                accent: AppPalette.amber,
              ),
              _TransferMetricChip(
                label: 'Sedes con stock',
                value: '${detail.branchSuggestions.length}',
                accent: hasSources ? AppPalette.mint : AppPalette.danger,
              ),
            ],
          ),
          if (selectedSource != null) ...[
            const SizedBox(height: 12),
            _TransferReliabilityChip(
              status: syncStatuses[selectedSource!.branch.id],
            ),
          ],
          const SizedBox(height: 14),
          Text(
            hasSources
                ? selectedSource == null
                      ? 'Selecciona la sede origen desde donde saldria el producto.'
                      : 'Sede origen seleccionada: ${selectedSource!.branch.name} | ${selectedSource!.availableStock} disponibles para enviar | ${_formatSourceReliability(syncStatuses[selectedSource!.branch.id])} | ${selectedSource!.distanceKm.toStringAsFixed(1)} km | ETA ${selectedSource!.etaLabel}'
                : 'No hay stock disponible en otras sedes para enviar este producto.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _TransferRequestFormCard extends StatelessWidget {
  const _TransferRequestFormCard({
    required this.formKey,
    required this.detail,
    required this.syncStatuses,
    required this.selectedSourceBranchId,
    required this.quantityController,
    required this.reasonController,
    required this.notesController,
    required this.isSubmitting,
    required this.onChangedSource,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final ProductDetailData detail;
  final Map<String, SyncBranchStatus> syncStatuses;
  final String? selectedSourceBranchId;
  final TextEditingController quantityController;
  final TextEditingController reasonController;
  final TextEditingController notesController;
  final bool isSubmitting;
  final ValueChanged<String?> onChangedSource;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final sourceSuggestions = detail.branchSuggestions;
    final effectiveSelectedSourceBranchId =
        selectedSourceBranchId ??
        (sourceSuggestions.isEmpty ? null : sourceSuggestions.first.branch.id);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF102540),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x26FFFFFF)),
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Formulario de solicitud',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Selecciona desde que sede saldra el producto, la cantidad y el motivo comercial del traslado hacia tu sede.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey<String?>(
                'source_${detail.product.id}_$effectiveSelectedSourceBranchId',
              ),
              initialValue: effectiveSelectedSourceBranchId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Sede origen (desde donde saldra)',
              ),
              items: sourceSuggestions
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item.branch.id,
                      child: Text(
                        '${item.branch.name} | ${item.availableStock} disp. | ${_formatSourceReliability(syncStatuses[item.branch.id])} | ${item.distanceKm.toStringAsFixed(1)} km | ETA ${item.etaLabel}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: sourceSuggestions.isEmpty ? null : onChangedSource,
              validator: (value) {
                if (sourceSuggestions.isNotEmpty &&
                    ((value ?? effectiveSelectedSourceBranchId) == null ||
                        (value ?? effectiveSelectedSourceBranchId)!.isEmpty)) {
                  return 'Selecciona la sede origen.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Cantidad solicitada',
              ),
              validator: (value) {
                final quantity = int.tryParse((value ?? '').trim());
                if (quantity == null || quantity <= 0) {
                  return 'Ingresa una cantidad valida.';
                }
                final selectedSource = sourceSuggestions
                    .cast<ProductBranchSuggestion?>()
                    .firstWhere(
                      (item) =>
                          item?.branch.id == effectiveSelectedSourceBranchId,
                      orElse: () => null,
                    );
                if (selectedSource != null &&
                    quantity > selectedSource.availableStock) {
                  return 'Supera el stock disponible en origen.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Motivo',
                hintText: 'Ejemplo: venta comprometida sin stock local',
              ),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Indica el motivo de la solicitud.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notas internas',
                hintText: 'Dato adicional para aprobacion o despacho',
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: sourceSuggestions.isEmpty || isSubmitting
                    ? null
                    : onSubmit,
                icon: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.local_shipping_rounded),
                label: Text(
                  isSubmitting ? 'Enviando solicitud' : 'Enviar solicitud',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentTransferRequestsCard extends StatelessWidget {
  const _RecentTransferRequestsCard({
    required this.service,
    required this.branchId,
  });

  final InventoryWorkflowService service;
  final String branchId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF102540),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x26FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Solicitudes recientes de tu sucursal',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Seguimiento rapido de solicitudes pendientes, aprobadas o en transito vinculadas a tu sede.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          StreamBuilder<List<TransferRequest>>(
            stream: service.transfers.watchTransfersForBranch(branchId),
            builder: (context, snapshot) {
              final items = (snapshot.data ?? const <TransferRequest>[])
                  .take(5)
                  .toList(growable: false);

              if (items.isEmpty) {
                return Text(
                  'No hay solicitudes recientes para esta sucursal.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                );
              }

              return Column(
                children: items
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _RecentTransferTile(
                          item: item,
                          branchId: branchId,
                        ),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RecentTransferTile extends StatelessWidget {
  const _RecentTransferTile({required this.item, required this.branchId});

  final TransferRequest item;
  final String branchId;

  @override
  Widget build(BuildContext context) {
    final isIncoming = item.toBranchId == branchId;
    final accent = switch (item.status) {
      TransferStatus.pending => AppPalette.amber,
      TransferStatus.approved => AppPalette.blueSoft,
      TransferStatus.inTransit => AppPalette.cyan,
      TransferStatus.received => AppPalette.mint,
      TransferStatus.rejected || TransferStatus.cancelled => AppPalette.danger,
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isIncoming ? Icons.south_west_rounded : Icons.north_east_rounded,
            color: accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.productName} | ${item.quantity} unidad(es)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isIncoming
                      ? 'Origen ${item.fromBranchName} -> destino ${item.toBranchName}'
                      : 'Salida ${item.fromBranchName} -> ${item.toBranchName}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatTransferStatus(item.status)} | ${_formatRelativeTime(item.requestedAt)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white60),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TransferRequestEmptySelection extends StatelessWidget {
  const _TransferRequestEmptySelection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF102540),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x26FFFFFF)),
      ),
      child: Text(
        'Selecciona un producto para validar sucursales origen, stock disponible y tiempos estimados de traslado.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
      ),
    );
  }
}

class _TransferRequestErrorState extends StatelessWidget {
  const _TransferRequestErrorState({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF102540),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x26FFFFFF)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}

class _TransferInfoPill extends StatelessWidget {
  const _TransferInfoPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
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

class _TransferMetricChip extends StatelessWidget {
  const _TransferMetricChip({
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
      width: 132,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
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

class _TransferReliabilityChip extends StatelessWidget {
  const _TransferReliabilityChip({required this.status});

  final SyncBranchStatus? status;

  @override
  Widget build(BuildContext context) {
    final label = _formatSourceReliability(status);
    final accent = _sourceReliabilityColor(status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_outlined, size: 18, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Confiabilidad del origen: $label',
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
}

String _formatSourceReliability(SyncBranchStatus? status) {
  if (status == null) {
    return 'sin estado';
  }
  return status.summary;
}

Color _sourceReliabilityColor(SyncBranchStatus? status) {
  return switch (status?.severity) {
    SyncStatusSeverity.healthy => AppPalette.mint,
    SyncStatusSeverity.warning => AppPalette.amber,
    SyncStatusSeverity.critical => AppPalette.danger,
    SyncStatusSeverity.unknown || null => AppPalette.blueSoft,
  };
}

String _formatTransferStatus(TransferStatus status) {
  return switch (status) {
    TransferStatus.pending => 'Pendiente',
    TransferStatus.approved => 'Aprobado',
    TransferStatus.rejected => 'Rechazado',
    TransferStatus.inTransit => 'En transito',
    TransferStatus.received => 'Recibido',
    TransferStatus.cancelled => 'Cancelado',
  };
}

String _formatRelativeTime(DateTime value) {
  final difference = DateTime.now().difference(value);
  if (difference.inMinutes < 1) {
    return 'Hace instantes';
  }
  if (difference.inHours < 1) {
    return 'Hace ${difference.inMinutes} min';
  }
  if (difference.inDays < 1) {
    return 'Hace ${difference.inHours} h';
  }
  return 'Hace ${difference.inDays} dia(s)';
}
