import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_theme.dart';
import '../application/inventory_workflow_service.dart';
import '../domain/models.dart';

class ReservationRequestPage extends StatefulWidget {
  const ReservationRequestPage({
    super.key,
    required this.service,
    required this.currentUser,
    this.initialProductId,
  });

  final InventoryWorkflowService service;
  final AppUser currentUser;
  final String? initialProductId;

  @override
  State<ReservationRequestPage> createState() => _ReservationRequestPageState();
}

class _ReservationRequestPageState extends State<ReservationRequestPage> {
  final _formKey = GlobalKey<FormState>();
  late Future<List<ReservationRequestCatalogItem>> _catalogFuture;
  late final TextEditingController _quantityController;
  late final TextEditingController _customerNameController;
  late final TextEditingController _customerPhoneController;

  Future<ProductDetailData>? _productDetailFuture;
  String? _selectedProductId;
  String? _selectedBranchId;
  Duration _expiresIn = const Duration(hours: 24);
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(text: '1');
    _customerNameController = TextEditingController();
    _customerPhoneController = TextEditingController();
    _selectedProductId = widget.initialProductId;
    _catalogFuture = _loadCatalog();
    if (_selectedProductId != null && _selectedProductId!.isNotEmpty) {
      _productDetailFuture = _loadProductDetail(_selectedProductId!);
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    super.dispose();
  }

  Future<List<ReservationRequestCatalogItem>> _loadCatalog() {
    return widget.service.fetchReservationRequestCatalog(
      actorUser: widget.currentUser,
    );
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
      _selectedBranchId = null;
      _productDetailFuture = productId == null || productId.isEmpty
          ? null
          : _loadProductDetail(productId);
    });
  }

  ProductBranchSuggestion? _selectedBranch(ProductDetailData detail) {
    final effectiveId =
        _selectedBranchId ??
        (detail.branchSuggestions.isEmpty
            ? null
            : detail.branchSuggestions.first.branch.id);
    if (effectiveId == null) {
      return null;
    }
    return detail.branchSuggestions.cast<ProductBranchSuggestion?>().firstWhere(
      (item) => item?.branch.id == effectiveId,
      orElse: () => null,
    );
  }

  Future<void> _refresh() async {
    final productId = _selectedProductId;
    setState(() {
      _catalogFuture = _loadCatalog();
      if (productId != null && productId.isNotEmpty) {
        _productDetailFuture = _loadProductDetail(
          productId,
          forceRefresh: true,
        );
      }
    });
  }

  Future<void> _submit(ProductDetailData detail) async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final productId = _selectedProductId;
    final selectedBranch = _selectedBranch(detail);
    if (productId == null || selectedBranch == null) {
      _showStatusMessage(
        'Selecciona un producto y una sucursal con stock disponible.',
      );
      return;
    }

    final quantity = int.tryParse(_quantityController.text.trim()) ?? 0;
    if (quantity > selectedBranch.availableStock) {
      _showStatusMessage(
        'La cantidad supera el stock disponible en ${selectedBranch.branch.name}.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final reservation = await widget.service.createReservation(
        actorUser: widget.currentUser,
        branchId: selectedBranch.branch.id,
        productId: productId,
        customerName: _customerNameController.text.trim(),
        customerPhone: _customerPhoneController.text.trim(),
        quantity: quantity,
        expiresIn: _expiresIn,
      );

      if (!mounted) {
        return;
      }

      _quantityController.text = '1';
      _customerNameController.clear();
      _customerPhoneController.clear();
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
        builder: (context) => AlertDialog(
          title: const Text('Solicitud enviada'),
          content: Text(
            'La solicitud ${reservation.id} quedo pendiente de aprobacion en ${reservation.branchName} para ${reservation.customerName}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
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
      appBar: AppBar(
        title: const Text('Solicitar reserva'),
        actions: [
          IconButton(
            tooltip: 'Actualizar reservas',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Container(
        color: const Color(0xFF08172D),
        child: SafeArea(
          top: false,
          child: FutureBuilder<List<ReservationRequestCatalogItem>>(
            future: _catalogFuture,
            builder: (context, catalogSnapshot) {
              if (catalogSnapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (catalogSnapshot.hasError) {
                return _ReservationErrorState(
                  title: 'No se pudo preparar la reserva',
                  message:
                      'Ocurrio un problema cargando el formulario de reserva. ${catalogSnapshot.error}',
                  onRetry: _refresh,
                );
              }

              final catalog = catalogSnapshot.requireData;
              final selectedCatalogItem = catalog
                  .cast<ReservationRequestCatalogItem?>()
                  .firstWhere(
                    (item) => item?.product.id == _selectedProductId,
                    orElse: () => null,
                  );

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: [
                  _ReservationHeader(
                    currentUser: widget.currentUser,
                    selectedCatalogItem: selectedCatalogItem,
                  ),
                  const SizedBox(height: 16),
                  const _ReservationRulesCard(),
                  const SizedBox(height: 16),
                  _ReservationProductSelector(
                    catalog: catalog,
                    selectedProductId: _selectedProductId,
                    onChanged: _selectProduct,
                  ),
                  const SizedBox(height: 16),
                  if (_productDetailFuture == null)
                    const _ReservationEmptySelection()
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
                          return _ReservationErrorState(
                            title: 'No se pudo consultar el producto',
                            message:
                                'No fue posible validar el inventario para esta reserva. ${detailSnapshot.error}',
                            onRetry: _refresh,
                          );
                        }

                        final detail = detailSnapshot.requireData;
                        return Column(
                          children: [
                            _ReservationStockContextCard(
                              detail: detail,
                              selectedBranch: _selectedBranch(detail),
                            ),
                            const SizedBox(height: 16),
                            _ReservationFormCard(
                              formKey: _formKey,
                              detail: detail,
                              selectedBranchId: _selectedBranchId,
                              expiresIn: _expiresIn,
                              quantityController: _quantityController,
                              customerNameController: _customerNameController,
                              customerPhoneController: _customerPhoneController,
                              isSubmitting: _isSubmitting,
                              onBranchChanged: (value) {
                                setState(() {
                                  _selectedBranchId = value;
                                });
                              },
                              onExpiresChanged: (value) {
                                setState(() {
                                  _expiresIn = value;
                                });
                              },
                              onSubmit: () => _submit(detail),
                            ),
                          ],
                        );
                      },
                    ),
                  const SizedBox(height: 16),
                  _RecentReservationCard(
                    service: widget.service,
                    currentUser: widget.currentUser,
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

class _ReservationHeader extends StatelessWidget {
  const _ReservationHeader({
    required this.currentUser,
    required this.selectedCatalogItem,
  });

  final AppUser currentUser;
  final ReservationRequestCatalogItem? selectedCatalogItem;

  @override
  Widget build(BuildContext context) {
    final stockLabel = selectedCatalogItem == null
        ? 'Selecciona un producto para asegurar disponibilidad en otra sucursal.'
        : selectedCatalogItem!.isOutOfStock
        ? 'Sin stock local para ${selectedCatalogItem!.product.name}.'
        : 'Stock local actual: ${selectedCatalogItem!.currentAvailableStock} unidad(es).';

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
            'Solicitud de reserva',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            'Asegura unidades para el cliente cuando tu sede no tenga disponibilidad inmediata en ${currentUser.branchId.toUpperCase()}.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ReservationInfoPill(
                label: 'Solicitante ${currentUser.branchId}',
              ),
              _ReservationInfoPill(label: stockLabel),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReservationRulesCard extends StatelessWidget {
  const _ReservationRulesCard();

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
            'Reglas de reserva',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            'La solicitud queda pendiente hasta que un supervisor apruebe comprometer stock real en la sucursal origen.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ReservationInfoPill(label: 'Aprobacion por supervisor'),
              _ReservationInfoPill(label: 'Vigencia configurable'),
              _ReservationInfoPill(label: 'Trazabilidad administrativa'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReservationProductSelector extends StatelessWidget {
  const _ReservationProductSelector({
    required this.catalog,
    required this.selectedProductId,
    required this.onChanged,
  });

  final List<ReservationRequestCatalogItem> catalog;
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
            key: ValueKey<String?>('reservation_product_$selectedProductId'),
            initialValue: selectedProductId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Selecciona el producto a reservar',
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

class _ReservationStockContextCard extends StatelessWidget {
  const _ReservationStockContextCard({
    required this.detail,
    required this.selectedBranch,
  });

  final ProductDetailData detail;
  final ProductBranchSuggestion? selectedBranch;

  @override
  Widget build(BuildContext context) {
    final currentAvailable = detail.inventory?.availableStock ?? 0;
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
            'Contexto de disponibilidad',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ReservationMetricChip(
                label: 'Disponible local',
                value: '$currentAvailable',
                accent: currentAvailable <= 0
                    ? AppPalette.danger
                    : AppPalette.blueSoft,
              ),
              _ReservationMetricChip(
                label: 'Sucursales reservables',
                value: '${detail.branchSuggestions.length}',
                accent: hasSources ? AppPalette.mint : AppPalette.danger,
              ),
              _ReservationMetricChip(
                label: 'Dato',
                value: detail.reliability.statusLabel,
                accent: switch (detail.reliability.level) {
                  InventoryDataReliabilityLevel.green => AppPalette.mint,
                  InventoryDataReliabilityLevel.yellow => AppPalette.amber,
                  InventoryDataReliabilityLevel.red => AppPalette.danger,
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            hasSources
                ? selectedBranch == null
                      ? 'Selecciona una sucursal con stock disponible para enviar la solicitud.'
                      : 'Sucursal sugerida: ${selectedBranch!.branch.name} | ${selectedBranch!.availableStock} disponibles | ${selectedBranch!.distanceKm.toStringAsFixed(1)} km | ETA ${selectedBranch!.etaLabel}'
                : 'No hay stock disponible en otras sucursales para solicitar este producto.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _ReservationFormCard extends StatelessWidget {
  const _ReservationFormCard({
    required this.formKey,
    required this.detail,
    required this.selectedBranchId,
    required this.expiresIn,
    required this.quantityController,
    required this.customerNameController,
    required this.customerPhoneController,
    required this.isSubmitting,
    required this.onBranchChanged,
    required this.onExpiresChanged,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final ProductDetailData detail;
  final String? selectedBranchId;
  final Duration expiresIn;
  final TextEditingController quantityController;
  final TextEditingController customerNameController;
  final TextEditingController customerPhoneController;
  final bool isSubmitting;
  final ValueChanged<String?> onBranchChanged;
  final ValueChanged<Duration> onExpiresChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final suggestions = detail.branchSuggestions;
    final effectiveBranchId =
        selectedBranchId ??
        (suggestions.isEmpty ? null : suggestions.first.branch.id);

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
              'Formulario de reserva',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Selecciona la sucursal, la cantidad y los datos del cliente para enviar la solicitud a aprobacion.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey<String?>(
                'reservation_branch_${detail.product.id}_$effectiveBranchId',
              ),
              initialValue: effectiveBranchId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Sucursal de reserva',
              ),
              items: suggestions
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item.branch.id,
                      child: Text(
                        '${item.branch.name} | ${item.availableStock} disp. | ETA ${item.etaLabel}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: suggestions.isEmpty ? null : onBranchChanged,
              validator: (value) {
                if (suggestions.isNotEmpty &&
                    ((value ?? effectiveBranchId) == null ||
                        (value ?? effectiveBranchId)!.isEmpty)) {
                  return 'Selecciona la sucursal donde se reservara el producto.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<Duration>(
              key: ValueKey<String>('expires_${expiresIn.inHours}'),
              initialValue: expiresIn,
              decoration: const InputDecoration(labelText: 'Vigencia'),
              items: const [
                DropdownMenuItem(
                  value: Duration(hours: 24),
                  child: Text('24 horas'),
                ),
                DropdownMenuItem(
                  value: Duration(hours: 48),
                  child: Text('48 horas'),
                ),
                DropdownMenuItem(
                  value: Duration(hours: 72),
                  child: Text('72 horas'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  onExpiresChanged(value);
                }
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Cantidad a reservar',
              ),
              validator: (value) {
                final quantity = int.tryParse((value ?? '').trim());
                if (quantity == null || quantity <= 0) {
                  return 'Ingresa una cantidad valida.';
                }
                final selected = suggestions
                    .cast<ProductBranchSuggestion?>()
                    .firstWhere(
                      (item) => item?.branch.id == effectiveBranchId,
                      orElse: () => null,
                    );
                if (selected != null && quantity > selected.availableStock) {
                  return 'Supera el stock disponible en la sucursal elegida.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: customerNameController,
              decoration: const InputDecoration(labelText: 'Cliente'),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Ingresa el nombre o referencia del cliente.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: customerPhoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telefono del cliente',
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: suggestions.isEmpty || isSubmitting
                    ? null
                    : onSubmit,
                icon: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.bookmark_add_rounded),
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

class _RecentReservationCard extends StatelessWidget {
  const _RecentReservationCard({
    required this.service,
    required this.currentUser,
  });

  final InventoryWorkflowService service;
  final AppUser currentUser;

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
            'Estado de tus reservas',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Solicitudes y reservas creadas por tu usuario aunque esten en otra sucursal.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          StreamBuilder<List<Reservation>>(
            stream: service.reservations.watchReservationsByUser(
              currentUser.id,
            ),
            builder: (context, snapshot) {
              final items = (snapshot.data ?? const <Reservation>[])
                  .take(5)
                  .toList(growable: false);
              if (items.isEmpty) {
                return Text(
                  'Todavia no has creado reservas con este usuario.',
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
                        child: _RecentReservationTile(item: item),
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

class _RecentReservationTile extends StatelessWidget {
  const _RecentReservationTile({required this.item});

  final Reservation item;

  @override
  Widget build(BuildContext context) {
    final accent = switch (item.status) {
      ReservationStatus.pending => AppPalette.amber,
      ReservationStatus.active => AppPalette.mint,
      ReservationStatus.rejected => AppPalette.danger,
      ReservationStatus.completed => AppPalette.blueSoft,
      ReservationStatus.cancelled => AppPalette.danger,
      ReservationStatus.expired => AppPalette.amber,
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
          Icon(Icons.bookmark_rounded, color: accent),
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
                  '${item.branchName} | cliente ${item.customerName}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatReservationStatus(item.status)} | vence ${_formatReservationExpiry(item.expiresAt)}',
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

class _ReservationEmptySelection extends StatelessWidget {
  const _ReservationEmptySelection();

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
        'Selecciona un producto para validar sucursales disponibles y enviar la solicitud.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
      ),
    );
  }
}

class _ReservationErrorState extends StatelessWidget {
  const _ReservationErrorState({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
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
        ),
      ),
    );
  }
}

class _ReservationInfoPill extends StatelessWidget {
  const _ReservationInfoPill({required this.label});

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

class _ReservationMetricChip extends StatelessWidget {
  const _ReservationMetricChip({
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

String _formatReservationStatus(ReservationStatus status) {
  return switch (status) {
    ReservationStatus.pending => 'Pendiente',
    ReservationStatus.active => 'Activa',
    ReservationStatus.rejected => 'Rechazada',
    ReservationStatus.completed => 'Completada',
    ReservationStatus.cancelled => 'Cancelada',
    ReservationStatus.expired => 'Vencida',
  };
}

String _formatReservationExpiry(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
