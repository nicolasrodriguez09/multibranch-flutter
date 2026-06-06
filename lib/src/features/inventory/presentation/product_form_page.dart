import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/inventory_workflow_service.dart';
import '../domain/models.dart';
import 'barcode_scanner_page.dart';

class ProductInputData {
  const ProductInputData({
    required this.sku,
    required this.barcode,
    required this.name,
    required this.description,
    required this.categoryId,
    required this.brand,
    required this.imageUrl,
    required this.price,
    required this.cost,
    required this.currency,
    required this.tags,
    required this.minimumStock,
  });

  final String sku;
  final String barcode;
  final String name;
  final String description;
  final String categoryId;
  final String brand;
  final String imageUrl;
  final double price;
  final double cost;
  final String currency;
  final List<String> tags;
  final int? minimumStock;
}

class ProductFormPage extends StatefulWidget {
  const ProductFormPage({
    super.key,
    required this.service,
    required this.currentUser,
    required this.categories,
    this.initialProduct,
  });

  final InventoryWorkflowService service;
  final AppUser currentUser;
  final List<Category> categories;
  final Product? initialProduct;

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _skuController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _brandController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _priceController = TextEditingController();
  final _costController = TextEditingController();
  final _currencyController = TextEditingController(text: 'USD');
  final _tagsController = TextEditingController();
  final _minimumStockController = TextEditingController(text: '0');
  late String _categoryId;

  @override
  void initState() {
    super.initState();
    final product = widget.initialProduct;
    final categoryIds = widget.categories.map((category) => category.id).toSet();
    _categoryId = product != null && categoryIds.contains(product.categoryId)
        ? product.categoryId
        : widget.categories.first.id;
    if (product != null) {
      _skuController.text = product.sku;
      _barcodeController.text = product.barcode;
      _nameController.text = product.name;
      _descriptionController.text = product.description;
      _brandController.text = product.brand;
      _imageUrlController.text = product.imageUrl;
      _priceController.text = product.price.toStringAsFixed(2);
      _costController.text = product.cost.toStringAsFixed(2);
      _currencyController.text = product.currency;
      _tagsController.text = product.tags.join(', ');
      _minimumStockController.clear();
    }
  }

  @override
  void dispose() {
    _skuController.dispose();
    _barcodeController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _brandController.dispose();
    _imageUrlController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _currencyController.dispose();
    _tagsController.dispose();
    _minimumStockController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    Navigator.of(context).pop(
      ProductInputData(
        sku: _skuController.text.trim(),
        barcode: _barcodeController.text.trim(),
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        categoryId: _categoryId,
        brand: _brandController.text.trim(),
        imageUrl: _imageUrlController.text.trim(),
        price: double.parse(_priceController.text.trim()),
        cost: double.parse(_costController.text.trim()),
        currency: _currencyController.text.trim(),
        tags: _tagsController.text
            .split(',')
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toList(growable: false),
        minimumStock: _minimumStockController.text.trim().isEmpty
            ? null
            : int.parse(_minimumStockController.text.trim()),
      ),
    );
  }

  String? _requiredValidator(String? value) {
    return (value ?? '').trim().isEmpty ? 'Campo obligatorio.' : null;
  }

  String? _positiveMoneyValidator(String? value) {
    final parsed = double.tryParse((value ?? '').trim());
    return parsed == null || parsed <= 0 ? 'Ingresa un valor mayor que cero.' : null;
  }

  String? _nonNegativeMoneyValidator(String? value) {
    final parsed = double.tryParse((value ?? '').trim());
    return parsed == null || parsed < 0 ? 'Ingresa un valor valido.' : null;
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialProduct != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar producto' : 'Agregar producto'),
        actions: [
          FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.save_rounded, size: 20),
            label: Text(isEditing ? 'Guardar' : 'Crear'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Informacion principal',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _skuController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            labelText: 'SKU opcional',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.qr_code_scanner_rounded),
                              onPressed: () async {
                                final result = await Navigator.of(context).push<dynamic>(
                                  MaterialPageRoute<dynamic>(
                                    builder: (context) => BarcodeScannerPage(
                                      service: widget.service,
                                      currentUser: widget.currentUser,
                                      returnRawBarcode: true,
                                    ),
                                  ),
                                );
                                if (result is String) {
                                  setState(() {
                                    _skuController.text = result;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _barcodeController,
                          decoration: InputDecoration(
                            labelText: 'Codigo de barras opcional',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.qr_code_scanner_rounded),
                              onPressed: () async {
                                final result = await Navigator.of(context).push<dynamic>(
                                  MaterialPageRoute<dynamic>(
                                    builder: (context) => BarcodeScannerPage(
                                      service: widget.service,
                                      currentUser: widget.currentUser,
                                      returnRawBarcode: true,
                                    ),
                                  ),
                                );
                                if (result is String) {
                                  setState(() {
                                    _barcodeController.text = result;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Nombre del producto'),
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _categoryId,
                          decoration: const InputDecoration(labelText: 'Categoria'),
                          items: widget.categories
                              .map(
                                (category) => DropdownMenuItem<String>(
                                  value: category.id,
                                  child: Text(category.name),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _categoryId = value;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _brandController,
                          decoration: const InputDecoration(labelText: 'Marca'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Descripcion detallada'),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Precios e Inventario',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _costController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                          ],
                          decoration: const InputDecoration(labelText: 'Costo'),
                          validator: _nonNegativeMoneyValidator,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _priceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                          ],
                          decoration: const InputDecoration(labelText: 'Precio de venta'),
                          validator: _positiveMoneyValidator,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _currencyController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(labelText: 'Moneda (Ej: USD)'),
                          validator: _requiredValidator,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _minimumStockController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Minimo operativo',
                      helperText: 'El sistema alertara cuando el inventario baje de este limite',
                    ),
                    validator: widget.initialProduct == null ? _requiredValidator : null,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Multimedia y Etiquetas',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _tagsController,
                    decoration: const InputDecoration(
                      labelText: 'Etiquetas',
                      helperText: 'Separadas por coma (ej: verano, playa, oferta)',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _imageUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Imagen URL',
                      helperText: 'Enlace directo a la fotografia del producto',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
