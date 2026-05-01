import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_theme.dart';
import '../../auth/application/auth_service.dart';
import '../application/inventory_workflow_service.dart';
import '../domain/models.dart';
import '../domain/role_permissions.dart';
import 'branch_panel_drawer.dart';

class AdminCatalogPage extends StatefulWidget {
  const AdminCatalogPage({
    super.key,
    required this.service,
    required this.currentUser,
    this.authService,
  });

  final InventoryWorkflowService service;
  final AppUser currentUser;
  final AuthService? authService;

  @override
  State<AdminCatalogPage> createState() => _AdminCatalogPageState();
}

class _AdminCatalogPageState extends State<AdminCatalogPage> {
  bool _isSaving = false;

  Future<void> _createCategory(List<Category> categories) async {
    final request = await showDialog<_CategoryInput>(
      context: context,
      builder: (context) => _CategoryDialog(existingCategories: categories),
    );
    if (request == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });
    try {
      final category = await widget.service.createCategory(
        actorUser: widget.currentUser,
        name: request.name,
        description: request.description,
        lowStockThreshold: request.lowStockThreshold,
      );
      if (!mounted) {
        return;
      }
      _showMessage('Categoria creada: ${category.name}.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('No se pudo crear la categoria: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _editCategory(
    Category category,
    List<Category> categories,
  ) async {
    final request = await showDialog<_CategoryInput>(
      context: context,
      builder: (context) => _CategoryDialog(
        existingCategories: categories,
        initialCategory: category,
      ),
    );
    if (request == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });
    try {
      final updated = await widget.service.updateCategory(
        actorUser: widget.currentUser,
        categoryId: category.id,
        name: request.name,
        description: request.description,
        lowStockThreshold: request.lowStockThreshold,
        isActive: category.isActive,
      );
      if (!mounted) {
        return;
      }
      _showMessage('Categoria actualizada: ${updated.name}.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('No se pudo actualizar la categoria: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _toggleCategory(Category category) async {
    setState(() {
      _isSaving = true;
    });
    try {
      final updated = await widget.service.updateCategory(
        actorUser: widget.currentUser,
        categoryId: category.id,
        name: category.name,
        description: category.description,
        lowStockThreshold: category.lowStockThreshold,
        isActive: !category.isActive,
      );
      if (!mounted) {
        return;
      }
      _showMessage(
        updated.isActive
            ? 'Categoria reactivada: ${updated.name}.'
            : 'Categoria desactivada: ${updated.name}.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('No se pudo cambiar el estado de la categoria: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _createProduct(List<Category> categories) async {
    if (categories.isEmpty) {
      _showMessage('Primero crea una categoria para asociar el producto.');
      return;
    }
    final request = await showDialog<_ProductInput>(
      context: context,
      builder: (context) => _ProductDialog(categories: categories),
    );
    if (request == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });
    try {
      final product = await widget.service.createProduct(
        actorUser: widget.currentUser,
        sku: request.sku,
        barcode: request.barcode,
        name: request.name,
        description: request.description,
        categoryId: request.categoryId,
        brand: request.brand,
        imageUrl: request.imageUrl,
        price: request.price,
        cost: request.cost,
        currency: request.currency,
        tags: request.tags,
        minimumStock: request.minimumStock ?? 0,
      );
      if (!mounted) {
        return;
      }
      _showMessage(
        'Producto creado: ${product.name}. Se inicializo inventario en sucursales activas.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('No se pudo crear el producto: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _editProduct(Product product, List<Category> categories) async {
    final activeCategories = categories
        .where((category) => category.isActive)
        .toList(growable: false);
    if (activeCategories.isEmpty) {
      _showMessage('Activa o crea una categoria antes de editar productos.');
      return;
    }
    final request = await showDialog<_ProductInput>(
      context: context,
      builder: (context) =>
          _ProductDialog(categories: activeCategories, initialProduct: product),
    );
    if (request == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });
    try {
      final updated = await widget.service.updateProduct(
        actorUser: widget.currentUser,
        productId: product.id,
        sku: request.sku,
        barcode: request.barcode,
        name: request.name,
        description: request.description,
        categoryId: request.categoryId,
        brand: request.brand,
        imageUrl: request.imageUrl,
        price: request.price,
        cost: request.cost,
        currency: request.currency,
        tags: request.tags,
        minimumStock: request.minimumStock,
        isActive: product.isActive,
      );
      if (!mounted) {
        return;
      }
      _showMessage('Producto actualizado: ${updated.name}.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('No se pudo actualizar el producto: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _toggleProduct(Product product) async {
    setState(() {
      _isSaving = true;
    });
    try {
      final updated = await widget.service.updateProduct(
        actorUser: widget.currentUser,
        productId: product.id,
        sku: product.sku,
        barcode: product.barcode,
        name: product.name,
        description: product.description,
        categoryId: product.categoryId,
        brand: product.brand,
        imageUrl: product.imageUrl,
        price: product.price,
        cost: product.cost,
        currency: product.currency,
        tags: product.tags,
        isActive: !product.isActive,
      );
      if (!mounted) {
        return;
      }
      _showMessage(
        updated.isActive
            ? 'Producto reactivado: ${updated.name}.'
            : 'Producto desactivado: ${updated.name}.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('No se pudo cambiar el estado del producto: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
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
    if (!widget.currentUser.can(AppPermission.manageMasterData)) {
      return Scaffold(
        drawer: BranchPanelDrawer(
          service: widget.service,
          currentUser: widget.currentUser,
          currentDestination: BranchPanelDestination.adminCatalog,
          authService: widget.authService,
        ),
        appBar: AppBar(title: const Text('Catalogo maestro')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Tu usuario no tiene permisos para gestionar el catalogo maestro.',
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
        currentDestination: BranchPanelDestination.adminCatalog,
        authService: widget.authService,
      ),
      appBar: AppBar(
        title: const Text('Catalogo maestro'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
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
          child: StreamBuilder<List<Category>>(
            stream: widget.service.catalog.watchCategories(),
            builder: (context, categorySnapshot) {
              return StreamBuilder<List<Product>>(
                stream: widget.service.catalog.watchProducts(),
                builder: (context, productSnapshot) {
                  if (categorySnapshot.hasError || productSnapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No se pudo cargar el catalogo. ${categorySnapshot.error ?? productSnapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  if (!categorySnapshot.hasData || !productSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final categories = categorySnapshot.requireData;
                  final products = productSnapshot.requireData;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    children: [
                      _CatalogHeader(
                        products: products,
                        categories: categories,
                        onCreateProduct: _isSaving
                            ? null
                            : () => _createProduct(categories),
                        onCreateCategory: _isSaving
                            ? null
                            : () => _createCategory(categories),
                      ),
                      const SizedBox(height: 16),
                      _CategoryPanel(
                        categories: categories,
                        onEdit: _isSaving
                            ? null
                            : (category) => _editCategory(category, categories),
                        onToggle: _isSaving ? null : _toggleCategory,
                      ),
                      const SizedBox(height: 16),
                      _ProductPanel(
                        products: products,
                        categories: categories,
                        onEdit: _isSaving
                            ? null
                            : (product) => _editProduct(product, categories),
                        onToggle: _isSaving ? null : _toggleProduct,
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CatalogHeader extends StatelessWidget {
  const _CatalogHeader({
    required this.products,
    required this.categories,
    required this.onCreateProduct,
    required this.onCreateCategory,
  });

  final List<Product> products;
  final List<Category> categories;
  final VoidCallback? onCreateProduct;
  final VoidCallback? onCreateCategory;

  @override
  Widget build(BuildContext context) {
    final activeProducts = products.where((item) => item.isActive).length;
    final activeCategories = categories.where((item) => item.isActive).length;
    return _CatalogPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppPalette.cyan.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.inventory_2_rounded,
                  color: AppPalette.cyan,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gestion de catalogo',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Administra productos, categorias y la base de inventario que usan todas las sedes.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MetricBox(label: 'Productos', value: '$activeProducts'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricBox(
                  label: 'Categorias',
                  value: '$activeCategories',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: onCreateProduct,
                icon: const Icon(Icons.add_shopping_cart_rounded),
                label: const Text('Agregar producto'),
              ),
              OutlinedButton.icon(
                onPressed: onCreateCategory,
                icon: const Icon(Icons.category_rounded),
                label: const Text('Agregar categoria'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryPanel extends StatelessWidget {
  const _CategoryPanel({
    required this.categories,
    required this.onEdit,
    required this.onToggle,
  });

  final List<Category> categories;
  final ValueChanged<Category>? onEdit;
  final ValueChanged<Category>? onToggle;

  @override
  Widget build(BuildContext context) {
    return _CatalogPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Categorias',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (categories.isEmpty)
            const Text('No hay categorias registradas.')
          else
            ...categories.map(
              (category) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CategoryTile(
                  category: category,
                  onEdit: onEdit == null ? null : () => onEdit!(category),
                  onToggle: onToggle == null ? null : () => onToggle!(category),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.onEdit,
    required this.onToggle,
  });

  final Category category;
  final VoidCallback? onEdit;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF14151A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x26FF2636)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  category.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (category.lowStockThreshold != null)
                  _SmallTag(label: 'min. ${category.lowStockThreshold}'),
                _SmallTag(
                  label: category.isActive ? 'Activa' : 'Inactiva',
                  color: category.isActive
                      ? AppPalette.mint
                      : AppPalette.danger,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Editar categoria',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_rounded),
          ),
          IconButton(
            tooltip: category.isActive
                ? 'Desactivar categoria'
                : 'Reactivar categoria',
            onPressed: onToggle,
            icon: Icon(
              category.isActive
                  ? Icons.block_rounded
                  : Icons.check_circle_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallTag extends StatelessWidget {
  const _SmallTag({required this.label, this.color = AppPalette.blueSoft});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ProductPanel extends StatelessWidget {
  const _ProductPanel({
    required this.products,
    required this.categories,
    required this.onEdit,
    required this.onToggle,
  });

  final List<Product> products;
  final List<Category> categories;
  final ValueChanged<Product>? onEdit;
  final ValueChanged<Product>? onToggle;

  @override
  Widget build(BuildContext context) {
    final categoriesById = {
      for (final category in categories) category.id: category.name,
    };
    final visibleProducts = products.take(40).toList(growable: false);
    return _CatalogPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Productos recientes',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (visibleProducts.isEmpty)
            const Text('No hay productos registrados.')
          else
            ...visibleProducts.map(
              (product) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ProductTile(
                  product: product,
                  categoryName:
                      categoriesById[product.categoryId] ?? 'Categoria',
                  onEdit: onEdit == null ? null : () => onEdit!(product),
                  onToggle: onToggle == null ? null : () => onToggle!(product),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.categoryName,
    required this.onEdit,
    required this.onToggle,
  });

  final Product product;
  final String categoryName;
  final VoidCallback? onEdit;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF14151A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x26FF2636)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      product.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    _SmallTag(
                      label: product.isActive ? 'Activo' : 'Inactivo',
                      color: product.isActive
                          ? AppPalette.mint
                          : AppPalette.danger,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${product.sku} | $categoryName | ${product.brand.isEmpty ? 'Sin marca' : product.brand}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          Text(_formatMoney(product.price, product.currency)),
          IconButton(
            tooltip: 'Editar producto',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_rounded),
          ),
          IconButton(
            tooltip: product.isActive
                ? 'Desactivar producto'
                : 'Reactivar producto',
            onPressed: onToggle,
            icon: Icon(
              product.isActive
                  ? Icons.block_rounded
                  : Icons.check_circle_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({
    required this.existingCategories,
    this.initialCategory,
  });

  final List<Category> existingCategories;
  final Category? initialCategory;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _thresholdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final category = widget.initialCategory;
    if (category != null) {
      _nameController.text = category.name;
      _descriptionController.text = category.description;
      _thresholdController.text = category.lowStockThreshold?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    Navigator.of(context).pop(
      _CategoryInput(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        lowStockThreshold: _thresholdController.text.trim().isEmpty
            ? null
            : int.parse(_thresholdController.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initialCategory == null
            ? 'Agregar categoria'
            : 'Editar categoria',
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (value) {
                  final normalized = (value ?? '').trim();
                  if (normalized.isEmpty) {
                    return 'Ingresa el nombre.';
                  }
                  final exists = widget.existingCategories.any(
                    (category) =>
                        category.id != widget.initialCategory?.id &&
                        category.name.trim().toLowerCase() ==
                            normalized.toLowerCase(),
                  );
                  return exists ? 'La categoria ya existe.' : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Descripcion'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _thresholdController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Umbral de stock bajo opcional',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.initialCategory == null ? 'Crear' : 'Guardar'),
        ),
      ],
    );
  }
}

class _ProductDialog extends StatefulWidget {
  const _ProductDialog({required this.categories, this.initialProduct});

  final List<Category> categories;
  final Product? initialProduct;

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
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
    final categoryIds = widget.categories
        .map((category) => category.id)
        .toSet();
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
      _ProductInput(
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initialProduct == null ? 'Agregar producto' : 'Editar producto',
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _skuController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'SKU'),
                validator: _requiredValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _barcodeController,
                decoration: const InputDecoration(
                  labelText: 'Codigo de barras opcional',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: _requiredValidator,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
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
              const SizedBox(height: 12),
              TextFormField(
                controller: _brandController,
                decoration: const InputDecoration(labelText: 'Marca'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Descripcion'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(labelText: 'Precio de venta'),
                validator: _positiveMoneyValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _costController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(labelText: 'Costo'),
                validator: _nonNegativeMoneyValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _currencyController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Moneda'),
                validator: _requiredValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _minimumStockController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Minimo operativo',
                ),
                validator: widget.initialProduct == null
                    ? _requiredValidator
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  labelText: 'Etiquetas separadas por coma',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _imageUrlController,
                decoration: const InputDecoration(labelText: 'Imagen URL'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.initialProduct == null ? 'Crear' : 'Guardar'),
        ),
      ],
    );
  }
}

class _MetricBox extends StatelessWidget {
  const _MetricBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _CatalogPanel extends StatelessWidget {
  const _CatalogPanel({required this.child});

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

class _CategoryInput {
  const _CategoryInput({
    required this.name,
    required this.description,
    required this.lowStockThreshold,
  });

  final String name;
  final String description;
  final int? lowStockThreshold;
}

class _ProductInput {
  const _ProductInput({
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

String? _requiredValidator(String? value) {
  return (value ?? '').trim().isEmpty ? 'Campo obligatorio.' : null;
}

String? _positiveMoneyValidator(String? value) {
  final parsed = double.tryParse((value ?? '').trim());
  return parsed == null || parsed <= 0
      ? 'Ingresa un valor mayor que cero.'
      : null;
}

String? _nonNegativeMoneyValidator(String? value) {
  final parsed = double.tryParse((value ?? '').trim());
  return parsed == null || parsed < 0 ? 'Ingresa un valor valido.' : null;
}

String _formatMoney(double value, String currency) {
  return '$currency ${value.toStringAsFixed(2)}';
}
