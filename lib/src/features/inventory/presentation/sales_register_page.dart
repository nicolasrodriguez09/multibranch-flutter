import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_theme.dart';
import '../../auth/application/auth_service.dart';
import '../application/inventory_workflow_service.dart';
import '../domain/models.dart';
import 'branch_panel_drawer.dart';

class SalesRegisterPage extends StatefulWidget {
  const SalesRegisterPage({
    super.key,
    required this.service,
    required this.currentUser,
    this.authService,
  });

  final InventoryWorkflowService service;
  final AppUser currentUser;
  final AuthService? authService;

  @override
  State<SalesRegisterPage> createState() => _SalesRegisterPageState();
}

class _SalesRegisterPageState extends State<SalesRegisterPage> {
  final _formKey = GlobalKey<FormState>();
  late Future<List<SalesCatalogItem>> _catalogFuture;
  late final TextEditingController _quantityController;
  late final TextEditingController _unitPriceController;
  late final TextEditingController _customerNameController;
  late final TextEditingController _customerPhoneController;
  late final TextEditingController _notesController;

  String? _selectedProductId;
  SalePaymentMethod _paymentMethod = SalePaymentMethod.cash;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _catalogFuture = _loadCatalog();
    _quantityController = TextEditingController(text: '1');
    _unitPriceController = TextEditingController();
    _customerNameController = TextEditingController();
    _customerPhoneController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _unitPriceController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<List<SalesCatalogItem>> _loadCatalog() {
    return widget.service.fetchSalesCatalog(actorUser: widget.currentUser);
  }

  void _selectProduct(String? productId, List<SalesCatalogItem> catalog) {
    final selected = catalog.cast<SalesCatalogItem?>().firstWhere(
      (item) => item?.product.id == productId,
      orElse: () => null,
    );
    setState(() {
      _selectedProductId = productId;
      if (selected != null) {
        _unitPriceController.text = selected.unitPrice.toStringAsFixed(2);
      }
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _catalogFuture = _loadCatalog();
    });
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    final productId = _selectedProductId;
    if (productId == null || productId.isEmpty) {
      _showMessage('Selecciona un producto para registrar la venta.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final sale = await widget.service.registerSale(
        actorUser: widget.currentUser,
        productId: productId,
        quantity: int.parse(_quantityController.text.trim()),
        unitPrice: double.parse(_unitPriceController.text.trim()),
        paymentMethod: _paymentMethod,
        customerName: _customerNameController.text.trim(),
        customerPhone: _customerPhoneController.text.trim(),
        notes: _notesController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      _quantityController.text = '1';
      _customerNameController.clear();
      _customerPhoneController.clear();
      _notesController.clear();
      setState(() {
        _catalogFuture = _loadCatalog();
      });
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Venta registrada'),
          content: Text(
            '${sale.productName} | ${sale.quantity} unidad(es) | Total ${_formatMoney(sale.totalPrice, sale.currency)}.',
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
      _showMessage('No se pudo registrar la venta: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showMessage(String message) {
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
        currentDestination: BranchPanelDestination.salesRegister,
        authService: widget.authService,
      ),
      appBar: AppBar(
        title: const Text('Registrar venta'),
        actions: [
          IconButton(
            tooltip: 'Actualizar productos',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF07080B), Color(0xFF101116), Color(0xFF08090C)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          top: false,
          child: FutureBuilder<List<SalesCatalogItem>>(
            future: _catalogFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _SalePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('No fue posible preparar ventas.'),
                      const SizedBox(height: 8),
                      Text('${snapshot.error}'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _refresh,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                );
              }

              final catalog = snapshot.requireData;
              final selected = catalog.cast<SalesCatalogItem?>().firstWhere(
                (item) => item?.product.id == _selectedProductId,
                orElse: () => null,
              );

              return RefreshIndicator(
                onRefresh: _refresh,
                color: AppPalette.amber,
                backgroundColor: AppPalette.storm,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: [
                    _SalesHero(currentUser: widget.currentUser),
                    const SizedBox(height: 16),
                    _SalesForm(
                      formKey: _formKey,
                      catalog: catalog,
                      selectedProductId: _selectedProductId,
                      selected: selected,
                      quantityController: _quantityController,
                      unitPriceController: _unitPriceController,
                      customerNameController: _customerNameController,
                      customerPhoneController: _customerPhoneController,
                      notesController: _notesController,
                      paymentMethod: _paymentMethod,
                      isSubmitting: _isSubmitting,
                      onProductChanged: (value) =>
                          _selectProduct(value, catalog),
                      onPaymentChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _paymentMethod = value;
                          });
                        }
                      },
                      onSubmit: _submit,
                    ),
                    const SizedBox(height: 16),
                    _RecentSalesPanel(
                      stream: widget.service.watchOwnSales(
                        actorUser: widget.currentUser,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SalesHero extends StatelessWidget {
  const _SalesHero({required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    return _SalePanel(
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppPalette.mint.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.point_of_sale_rounded,
              color: AppPalette.mint,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Venta en ${currentUser.branchId}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Registra ventas reales, descuenta stock de tu sede y deja trazabilidad con hora, vendedor, precio y cantidad.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SalesForm extends StatelessWidget {
  const _SalesForm({
    required this.formKey,
    required this.catalog,
    required this.selectedProductId,
    required this.selected,
    required this.quantityController,
    required this.unitPriceController,
    required this.customerNameController,
    required this.customerPhoneController,
    required this.notesController,
    required this.paymentMethod,
    required this.isSubmitting,
    required this.onProductChanged,
    required this.onPaymentChanged,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final List<SalesCatalogItem> catalog;
  final String? selectedProductId;
  final SalesCatalogItem? selected;
  final TextEditingController quantityController;
  final TextEditingController unitPriceController;
  final TextEditingController customerNameController;
  final TextEditingController customerPhoneController;
  final TextEditingController notesController;
  final SalePaymentMethod paymentMethod;
  final bool isSubmitting;
  final ValueChanged<String?> onProductChanged;
  final ValueChanged<SalePaymentMethod?> onPaymentChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return _SalePanel(
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Datos de venta',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey<String?>('sale_product_$selectedProductId'),
              initialValue: selectedProductId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Producto vendido'),
              items: catalog
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item.product.id,
                      child: Text(
                        '${item.product.name} | ${item.availableStock} disp. | ${_formatMoney(item.unitPrice, item.currency)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: catalog.isEmpty ? null : onProductChanged,
              validator: (value) =>
                  (value ?? '').isEmpty ? 'Selecciona un producto.' : null,
            ),
            if (selected != null) ...[
              const SizedBox(height: 10),
              Text(
                'Disponible en sede: ${selected!.availableStock} unidad(es). Precio base: ${_formatMoney(selected!.unitPrice, selected!.currency)}.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
              ),
            ],
            const SizedBox(height: 14),
            TextFormField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Cantidad vendida'),
              validator: (value) {
                final quantity = int.tryParse((value ?? '').trim());
                if (quantity == null || quantity <= 0) {
                  return 'Ingresa una cantidad valida.';
                }
                if (selected != null && quantity > selected!.availableStock) {
                  return 'La cantidad supera el stock disponible.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: unitPriceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(labelText: 'Precio unitario'),
              validator: (value) {
                final price = double.tryParse((value ?? '').trim());
                if (price == null || price <= 0) {
                  return 'Ingresa un precio unitario valido.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<SalePaymentMethod>(
              initialValue: paymentMethod,
              decoration: const InputDecoration(labelText: 'Metodo de pago'),
              items: SalePaymentMethod.values
                  .map(
                    (method) => DropdownMenuItem<SalePaymentMethod>(
                      value: method,
                      child: Text(method.label),
                    ),
                  )
                  .toList(growable: false),
              onChanged: onPaymentChanged,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: customerNameController,
              decoration: const InputDecoration(
                labelText: 'Cliente o referencia opcional',
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: customerPhoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telefono opcional'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: notesController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notas internas'),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: catalog.isEmpty || isSubmitting ? null : onSubmit,
                icon: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.point_of_sale_rounded),
                label: Text(
                  isSubmitting ? 'Registrando venta' : 'Registrar venta',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentSalesPanel extends StatelessWidget {
  const _RecentSalesPanel({required this.stream});

  final Stream<List<SaleRecord>> stream;

  @override
  Widget build(BuildContext context) {
    return _SalePanel(
      child: StreamBuilder<List<SaleRecord>>(
        stream: stream,
        builder: (context, snapshot) {
          final sales = (snapshot.data ?? const <SaleRecord>[])
              .take(5)
              .toList(growable: false);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tus ventas recientes',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              if (sales.isEmpty)
                Text(
                  'Aun no tienes ventas registradas.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                )
              else
                ...sales.map(
                  (sale) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SaleTile(sale: sale),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SaleTile extends StatelessWidget {
  const _SaleTile({required this.sale});

  final SaleRecord sale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF14151A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x26FF2636)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${sale.productName} | ${sale.quantity} unidad(es)',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '${_formatMoney(sale.totalPrice, sale.currency)} | ${sale.paymentMethod.label} | ${_formatDateTime(sale.soldAt)}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _SalePanel extends StatelessWidget {
  const _SalePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF17191F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x26FF2636)),
      ),
      child: child,
    );
  }
}

String _formatMoney(double value, String currency) {
  return '$currency ${value.toStringAsFixed(2)}';
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
}
