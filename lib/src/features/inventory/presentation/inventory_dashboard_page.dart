import 'package:flutter/material.dart';

import '../../auth/application/auth_service.dart';
import '../../auth/presentation/create_employee_dialog.dart';
import '../application/inventory_workflow_service.dart';
import '../domain/models.dart';

class InventoryDashboardPage extends StatefulWidget {
  const InventoryDashboardPage({
    super.key,
    required this.service,
    required this.authService,
    required this.currentUser,
  });

  final InventoryWorkflowService service;
  final AuthService authService;
  final AppUser currentUser;

  @override
  State<InventoryDashboardPage> createState() => _InventoryDashboardPageState();
}

class _InventoryDashboardPageState extends State<InventoryDashboardPage> {
  String _status = 'Sesion iniciada.';
  bool _isCreating = false;
  bool _isCreatingEmployee = false;

  Future<void> _createBaseData() async {
    setState(() {
      _isCreating = true;
      _status = 'Creando base inicial en Firestore...';
    });

    try {
      await widget.service.seedMasterData();
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Base inicial creada. Revisa Firestore y veras users, branches, categories, products e inventories.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Error creando la base inicial: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  Future<void> _openCreateEmployeeDialog() async {
    setState(() {
      _status = 'Cargando sucursales para nuevo empleado...';
    });

    final branches = await widget.service.catalog.watchBranches().first;
    if (!mounted) {
      return;
    }

    if (branches.isEmpty) {
      setState(() {
        _status = 'Primero debes crear la base inicial para tener sucursales disponibles.';
      });
      return;
    }

    final request = await showDialog<CreateEmployeeRequest>(
      context: context,
      builder: (context) => CreateEmployeeDialog(branches: branches),
    );

    if (request == null) {
      if (mounted) {
        setState(() {
          _status = 'Alta de empleado cancelada.';
        });
      }
      return;
    }

    setState(() {
      _isCreatingEmployee = true;
      _status = 'Creando empleado ${request.email}...';
    });

    try {
      await widget.authService.createEmployee(
        currentUser: widget.currentUser,
        fullName: request.fullName,
        email: request.email,
        password: request.password,
        phone: request.phone,
        branchId: request.branchId,
        role: request.role,
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Empleado creado correctamente: ${request.email} (${request.role.name}).';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'No se pudo crear el empleado: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingEmployee = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final branchId = widget.currentUser.branchId;
    final isAdmin = widget.currentUser.role == UserRole.admin;

    return Scaffold(
      appBar: AppBar(
        title: Text('Ingreso ${widget.currentUser.role.name}'),
        actions: [
          IconButton(
            onPressed: widget.authService.signOut,
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesion',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFF4EFE6),
              Color(0xFFE5ECE9),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusBanner(status: _status),
                const SizedBox(height: 20),
                _PanelShell(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Usuario: ${widget.currentUser.fullName}'),
                      const SizedBox(height: 6),
                      Text('Rol: ${widget.currentUser.role.name}'),
                      const SizedBox(height: 6),
                      Text('Sucursal: ${widget.currentUser.branchId}'),
                      const SizedBox(height: 6),
                      Text('Correo: ${widget.currentUser.email}'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (isAdmin) ...[
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: _isCreating ? null : _createBaseData,
                        icon: _isCreating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.storage_outlined),
                        label: const Text('Crear base inicial'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          backgroundColor: const Color(0xFF005F73),
                          foregroundColor: Colors.white,
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _isCreatingEmployee ? null : _openCreateEmployeeDialog,
                        icon: _isCreatingEmployee
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.person_add_alt_1),
                        label: const Text('Ingresar nuevo empleado'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          backgroundColor: const Color(0xFF0B3C49),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const _SectionTitle(title: 'Colecciones objetivo'),
                  const _PanelShell(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('users'),
                        SizedBox(height: 6),
                        Text('branches'),
                        SizedBox(height: 6),
                        Text('categories'),
                        SizedBox(height: 6),
                        Text('products'),
                        SizedBox(height: 6),
                        Text('inventories'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const _SectionTitle(title: 'Users'),
                  StreamBuilder<List<AppUser>>(
                    stream: widget.service.users.watchUsers(),
                    builder: (context, snapshot) {
                      return _SimpleListPanel(
                        items: snapshot.data
                                ?.map((user) => '${user.fullName} | ${user.role.name} | ${user.branchId}')
                                .toList() ??
                            const [],
                        emptyMessage: 'Todavia no hay usuarios cargados.',
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  const _SectionTitle(title: 'Branches'),
                  StreamBuilder<List<Branch>>(
                    stream: widget.service.catalog.watchBranches(),
                    builder: (context, snapshot) {
                      return _SimpleListPanel(
                        items: snapshot.data?.map((branch) => '${branch.name} | ${branch.code}').toList() ?? const [],
                        emptyMessage: 'Todavia no hay sucursales cargadas.',
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  const _SectionTitle(title: 'Categories'),
                  StreamBuilder<List<Category>>(
                    stream: widget.service.catalog.watchCategories(),
                    builder: (context, snapshot) {
                      return _SimpleListPanel(
                        items: snapshot.data?.map((category) => category.name).toList() ?? const [],
                        emptyMessage: 'Todavia no hay categorias cargadas.',
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  const _SectionTitle(title: 'Products'),
                  StreamBuilder<List<Product>>(
                    stream: widget.service.catalog.watchProducts(),
                    builder: (context, snapshot) {
                      return _SimpleListPanel(
                        items: snapshot.data?.map((product) => '${product.name} | ${product.sku}').toList() ?? const [],
                        emptyMessage: 'Todavia no hay productos cargados.',
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],
                const _SectionTitle(title: 'Inventories'),
                StreamBuilder<List<InventoryItem>>(
                  stream: widget.service.inventories.watchBranchInventory(branchId),
                  builder: (context, snapshot) {
                    return _SimpleListPanel(
                      items: snapshot.data
                              ?.map(
                                (inventory) =>
                                    '${inventory.productName} | stock ${inventory.stock} | disponible ${inventory.availableStock}',
                              )
                              .toList() ??
                          const [],
                      emptyMessage: 'Todavia no hay inventarios cargados.',
                    );
                  },
                ),
                if (!isAdmin) ...[
                  const SizedBox(height: 20),
                  const _SectionTitle(title: 'Stock bajo'),
                  StreamBuilder<List<InventoryItem>>(
                    stream: widget.service.inventories.watchLowStock(branchId),
                    builder: (context, snapshot) {
                      return _SimpleListPanel(
                        items: snapshot.data
                                ?.map(
                                  (inventory) =>
                                      '${inventory.productName} | disponible ${inventory.availableStock} | minimo ${inventory.minimumStock}',
                                )
                                .toList() ??
                            const [],
                        emptyMessage: 'No hay productos en nivel bajo para tu sucursal.',
                      );
                    },
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

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.status,
  });

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBCD4CE)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_done_outlined, color: Color(0xFF005F73)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              status,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0B3C49),
            ),
      ),
    );
  }
}

class _PanelShell extends StatelessWidget {
  const _PanelShell({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD9E7E1)),
      ),
      child: child,
    );
  }
}

class _SimpleListPanel extends StatelessWidget {
  const _SimpleListPanel({
    required this.items,
    required this.emptyMessage,
  });

  final List<String> items;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _PanelShell(
        child: Text(emptyMessage),
      );
    }

    return _PanelShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(item),
              ),
            )
            .toList(),
      ),
    );
  }
}
