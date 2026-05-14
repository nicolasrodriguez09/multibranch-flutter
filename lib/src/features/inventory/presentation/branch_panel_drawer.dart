import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../auth/application/auth_service.dart';
import '../../auth/presentation/employee_management_page.dart';
import '../application/inventory_workflow_service.dart';
import '../domain/models.dart';
import '../domain/role_permissions.dart';
import 'admin_catalog_page.dart';
import 'approval_requests_page.dart';
import 'branch_directory_page.dart';
import 'create_branch_dialog.dart';
import 'inventory_adjustment_page.dart';
import 'notifications_page.dart';
import 'request_tracking_page.dart';
import 'reservation_request_page.dart';
import 'sales_register_page.dart';
import 'sales_report_page.dart';
import 'stock_alerts_page.dart';
import 'sync_status_page.dart';
import 'transfer_request_page.dart';

enum BranchPanelDestination {
  dashboard,
  branches,
  notifications,
  stockAlerts,
  syncStatus,
  approvals,
  inventoryAdjustment,
  salesRegister,
  salesReport,
  requestTracking,
  reservationRequest,
  transferRequest,
  adminCatalog,
  employeeManagement,
  adminTraceability,
}

class BranchPanelDrawer extends StatelessWidget {
  const BranchPanelDrawer({
    super.key,
    required this.service,
    required this.currentUser,
    required this.currentDestination,
    this.authService,
    this.onSignOut,
  });

  final InventoryWorkflowService service;
  final AppUser currentUser;
  final BranchPanelDestination currentDestination;
  final AuthService? authService;
  final VoidCallback? onSignOut;

  void _open(BuildContext context, BranchPanelDestination destination) {
    Navigator.of(context).pop();
    if (destination == currentDestination) {
      return;
    }

    Future<void>.delayed(const Duration(milliseconds: 120), () {
      if (!context.mounted) {
        return;
      }
      if (destination == BranchPanelDestination.dashboard) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (context) => _buildDestination(destination),
        ),
      );
    });
  }

  Widget _buildDestination(BranchPanelDestination destination) {
    return switch (destination) {
      BranchPanelDestination.branches => BranchDirectoryPage(
        service: service,
        currentUser: currentUser,
        authService: authService,
      ),
      BranchPanelDestination.notifications => NotificationInboxPage(
        service: service,
        currentUser: currentUser,
        authService: authService,
      ),
      BranchPanelDestination.stockAlerts => StockAlertsPage(
        service: service,
        currentUser: currentUser,
        authService: authService,
      ),
      BranchPanelDestination.syncStatus => SyncStatusPage(
        service: service,
        currentUser: currentUser,
        authService: authService,
      ),
      BranchPanelDestination.approvals => ApprovalRequestsPage(
        service: service,
        currentUser: currentUser,
        authService: authService,
      ),
      BranchPanelDestination.inventoryAdjustment => InventoryAdjustmentPage(
        service: service,
        currentUser: currentUser,
        authService: authService,
      ),
      BranchPanelDestination.salesRegister => SalesRegisterPage(
        service: service,
        currentUser: currentUser,
        authService: authService,
      ),
      BranchPanelDestination.salesReport => SalesReportPage(
        service: service,
        currentUser: currentUser,
        authService: authService,
      ),
      BranchPanelDestination.requestTracking => RequestTrackingPage(
        service: service,
        currentUser: currentUser,
        authService: authService,
      ),
      BranchPanelDestination.reservationRequest => ReservationRequestPage(
        service: service,
        currentUser: currentUser,
        authService: authService,
      ),
      BranchPanelDestination.transferRequest => TransferRequestPage(
        service: service,
        currentUser: currentUser,
        authService: authService,
      ),
      BranchPanelDestination.adminCatalog => AdminCatalogPage(
        service: service,
        currentUser: currentUser,
        authService: authService,
      ),
      BranchPanelDestination.employeeManagement =>
        authService == null
            ? _UnavailableAdminPage(
                title: 'Gestion de empleados',
                message:
                    'Vuelve al panel principal para abrir la gestion de empleados.',
              )
            : EmployeeManagementPage(
                authService: authService!,
                inventoryService: service,
                currentUser: currentUser,
              ),
      BranchPanelDestination.adminTraceability => RequestTrackingPage(
        service: service,
        currentUser: currentUser,
        authService: authService,
        drawerDestination: BranchPanelDestination.adminTraceability,
      ),
      BranchPanelDestination.dashboard => const SizedBox.shrink(),
    };
  }

  Future<void> _createBranch(BuildContext context) async {
    Navigator.of(context).pop();
    final request = await showDialog<CreateBranchRequest>(
      context: context,
      builder: (context) => const CreateBranchDialog(),
    );
    if (request == null || !context.mounted) {
      return;
    }

    try {
      final branch = await service.createBranch(
        actorUser: currentUser,
        name: request.name,
        code: request.code,
        address: request.address,
        city: request.city,
        phone: request.phone,
        email: request.email,
        managerName: request.managerName,
        openingHours: request.openingHours,
        latitude: request.latitude,
        longitude: request.longitude,
      );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sucursal creada correctamente: ${branch.name}.'),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo crear la sucursal: $error')),
      );
    }
  }

  Future<void> _createBaseData(BuildContext context) async {
    Navigator.of(context).pop();
    try {
      await service.seedMasterData(actorUser: currentUser);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Base inicial creada correctamente.')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creando la base inicial: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = currentUser.role == UserRole.admin;
    final canApprove =
        currentUser.can(AppPermission.approveTransfer) ||
        currentUser.can(AppPermission.approveReservation);
    final canAdjust = currentUser.can(AppPermission.manageInventory);
    final canRegisterSale =
        !isAdmin && currentUser.can(AppPermission.registerSale);
    final canViewSales = currentUser.can(AppPermission.viewBranchSales);

    return Drawer(
      backgroundColor: const Color(0xFF090A0D),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                switch (currentUser.role) {
                  UserRole.admin => 'Menu administrativo',
                  UserRole.seller => 'Menu de ventas',
                  UserRole.supervisor => 'Menu de sucursal',
                },
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(
                '${currentUser.fullName} | ${currentUser.branchId}',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 22),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DrawerSectionLabel(text: 'Navegacion'),
                      const SizedBox(height: 10),
                      _DrawerTile(
                        icon: Icons.space_dashboard_rounded,
                        title: 'Panel principal',
                        selected:
                            currentDestination ==
                            BranchPanelDestination.dashboard,
                        onTap: () =>
                            _open(context, BranchPanelDestination.dashboard),
                      ),
                      const SizedBox(height: 10),
                      _DrawerTile(
                        icon: Icons.store_mall_directory_rounded,
                        title: 'Sucursales',
                        selected:
                            currentDestination ==
                            BranchPanelDestination.branches,
                        onTap: () =>
                            _open(context, BranchPanelDestination.branches),
                      ),
                      const SizedBox(height: 18),
                      _DrawerSectionLabel(
                        text: isAdmin ? 'Monitoreo operativo' : 'Operacion',
                      ),
                      if (isAdmin) ...[
                        const SizedBox(height: 10),
                        _DrawerTile(
                          icon: Icons.notifications_rounded,
                          title: 'Notificaciones',
                          selected:
                              currentDestination ==
                              BranchPanelDestination.notifications,
                          onTap: () => _open(
                            context,
                            BranchPanelDestination.notifications,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _DrawerTile(
                          icon: Icons.notification_important_rounded,
                          title: 'Alertas de stock',
                          selected:
                              currentDestination ==
                              BranchPanelDestination.stockAlerts,
                          onTap: () => _open(
                            context,
                            BranchPanelDestination.stockAlerts,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _DrawerTile(
                          icon: Icons.cloud_done_rounded,
                          title: 'Estado de actualizacion',
                          selected:
                              currentDestination ==
                              BranchPanelDestination.syncStatus,
                          onTap: () =>
                              _open(context, BranchPanelDestination.syncStatus),
                        ),
                        const SizedBox(height: 10),
                        _DrawerTile(
                          icon: Icons.fact_check_rounded,
                          title: 'Bandeja de aprobaciones',
                          selected:
                              currentDestination ==
                              BranchPanelDestination.approvals,
                          onTap: () =>
                              _open(context, BranchPanelDestination.approvals),
                        ),
                        const SizedBox(height: 10),
                        _DrawerTile(
                          icon: Icons.receipt_long_rounded,
                          title: 'Ventas globales',
                          selected:
                              currentDestination ==
                              BranchPanelDestination.salesReport,
                          onTap: () => _open(
                            context,
                            BranchPanelDestination.salesReport,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _DrawerTile(
                          icon: Icons.track_changes_rounded,
                          title: 'Estado de solicitudes',
                          selected:
                              currentDestination ==
                              BranchPanelDestination.requestTracking,
                          onTap: () => _open(
                            context,
                            BranchPanelDestination.requestTracking,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _DrawerSectionLabel(text: 'Administracion'),
                        const SizedBox(height: 10),
                        _DrawerTile(
                          icon: Icons.inventory_2_rounded,
                          title: 'Catalogo maestro',
                          selected:
                              currentDestination ==
                              BranchPanelDestination.adminCatalog,
                          onTap: () => _open(
                            context,
                            BranchPanelDestination.adminCatalog,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _DrawerTile(
                          icon: Icons.person_add_alt_1_rounded,
                          title: 'Gestion de empleados',
                          selected:
                              currentDestination ==
                              BranchPanelDestination.employeeManagement,
                          onTap: () => _open(
                            context,
                            BranchPanelDestination.employeeManagement,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _DrawerTile(
                          icon: Icons.tune_rounded,
                          title: 'Ajuste global de inventario',
                          selected:
                              currentDestination ==
                              BranchPanelDestination.inventoryAdjustment,
                          onTap: () => _open(
                            context,
                            BranchPanelDestination.inventoryAdjustment,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _DrawerTile(
                          icon: Icons.account_tree_rounded,
                          title: 'Trazabilidad operativa',
                          selected:
                              currentDestination ==
                              BranchPanelDestination.adminTraceability,
                          onTap: () => _open(
                            context,
                            BranchPanelDestination.adminTraceability,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _DrawerTile(
                          icon: Icons.add_business_rounded,
                          title: 'Agregar sucursal',
                          onTap: () => unawaited(_createBranch(context)),
                        ),
                        const SizedBox(height: 10),
                        _DrawerTile(
                          icon: Icons.storage_rounded,
                          title: 'Crear base de datos inicial',
                          onTap: () => unawaited(_createBaseData(context)),
                        ),
                      ],
                      if (canRegisterSale) ...[
                        const SizedBox(height: 10),
                        _DrawerTile(
                          icon: Icons.point_of_sale_rounded,
                          title: 'Registrar venta',
                          selected:
                              currentDestination ==
                              BranchPanelDestination.salesRegister,
                          onTap: () => _open(
                            context,
                            BranchPanelDestination.salesRegister,
                          ),
                        ),
                      ],
                      if (!isAdmin && canViewSales) ...[
                        const SizedBox(height: 10),
                        _DrawerTile(
                          icon: Icons.receipt_long_rounded,
                          title: isAdmin
                              ? 'Ventas globales'
                              : 'Ventas de sucursal',
                          selected:
                              currentDestination ==
                              BranchPanelDestination.salesReport,
                          onTap: () => _open(
                            context,
                            BranchPanelDestination.salesReport,
                          ),
                        ),
                      ],
                      if (!isAdmin) ...[
                        const SizedBox(height: 10),
                        _DrawerTile(
                          icon: Icons.track_changes_rounded,
                          title: 'Estado de solicitudes',
                          selected:
                              currentDestination ==
                              BranchPanelDestination.requestTracking,
                          onTap: () => _open(
                            context,
                            BranchPanelDestination.requestTracking,
                          ),
                        ),
                      ],
                      if (!isAdmin && canApprove) ...[
                        const SizedBox(height: 10),
                        _DrawerTile(
                          icon: Icons.fact_check_rounded,
                          title: 'Bandeja de aprobaciones',
                          selected:
                              currentDestination ==
                              BranchPanelDestination.approvals,
                          onTap: () =>
                              _open(context, BranchPanelDestination.approvals),
                        ),
                      ],
                      if (!isAdmin && canAdjust) ...[
                        const SizedBox(height: 10),
                        _DrawerTile(
                          icon: Icons.tune_rounded,
                          title: 'Ajuste de inventario',
                          selected:
                              currentDestination ==
                              BranchPanelDestination.inventoryAdjustment,
                          onTap: () => _open(
                            context,
                            BranchPanelDestination.inventoryAdjustment,
                          ),
                        ),
                      ],
                      if (currentUser.role == UserRole.seller) ...[
                        const SizedBox(height: 18),
                        _DrawerSectionLabel(text: 'Conseguir producto'),
                      ],
                      if (!isAdmin) ...[
                        const SizedBox(height: 10),
                        _DrawerTile(
                          icon: Icons.bookmark_add_rounded,
                          title: currentUser.role == UserRole.seller
                              ? 'Apartar en otra sede'
                              : 'Reservar producto',
                          selected:
                              currentDestination ==
                              BranchPanelDestination.reservationRequest,
                          onTap: () => _open(
                            context,
                            BranchPanelDestination.reservationRequest,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _DrawerTile(
                          icon: Icons.local_shipping_rounded,
                          title: currentUser.role == UserRole.seller
                              ? 'Traer a mi sede'
                              : 'Solicitar traslado',
                          selected:
                              currentDestination ==
                              BranchPanelDestination.transferRequest,
                          onTap: () => _open(
                            context,
                            BranchPanelDestination.transferRequest,
                          ),
                        ),
                      ],
                      if (!isAdmin) ...[
                        const SizedBox(height: 18),
                        _DrawerSectionLabel(text: 'Monitoreo'),
                        const SizedBox(height: 10),
                        _DrawerTile(
                          icon: Icons.notification_important_rounded,
                          title: 'Alertas de stock',
                          selected:
                              currentDestination ==
                              BranchPanelDestination.stockAlerts,
                          onTap: () => _open(
                            context,
                            BranchPanelDestination.stockAlerts,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _DrawerTile(
                          icon: Icons.cloud_done_rounded,
                          title: currentUser.role == UserRole.seller
                              ? 'Confiabilidad del inventario'
                              : 'Estado de actualizacion',
                          selected:
                              currentDestination ==
                              BranchPanelDestination.syncStatus,
                          onTap: () =>
                              _open(context, BranchPanelDestination.syncStatus),
                        ),
                        const SizedBox(height: 10),
                        _DrawerTile(
                          icon: Icons.notifications_rounded,
                          title: 'Notificaciones',
                          selected:
                              currentDestination ==
                              BranchPanelDestination.notifications,
                          onTap: () => _open(
                            context,
                            BranchPanelDestination.notifications,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const _DrawerBrandCard(),
              if (onSignOut != null) ...[
                const SizedBox(height: 12),
                _DrawerTile(
                  icon: Icons.logout_rounded,
                  title: 'Cerrar sesion',
                  onTap: () {
                    Navigator.of(context).pop();
                    unawaited(
                      Future<void>.delayed(
                        const Duration(milliseconds: 120),
                        onSignOut,
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _UnavailableAdminPage extends StatelessWidget {
  const _UnavailableAdminPage({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

class _DrawerBrandCard extends StatelessWidget {
  const _DrawerBrandCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppPalette.blue.withValues(alpha: 0.18),
            AppPalette.storm.withValues(alpha: 0.86),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppPalette.panelBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppPalette.blueSoft, AppPalette.blueDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.inventory_2_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Red Stock',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Control total. Inventario inteligente.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerSectionLabel extends StatelessWidget {
  const _DrawerSectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Colors.white70,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppPalette.amber.withValues(alpha: 0.16)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(icon, color: selected ? AppPalette.amber : Colors.white),
        title: Text(
          title,
          style: TextStyle(
            color: selected ? AppPalette.amber : Colors.white,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
