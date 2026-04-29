import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../application/inventory_workflow_service.dart';
import '../domain/models.dart';
import '../domain/role_permissions.dart';
import 'approval_requests_page.dart';
import 'branch_directory_page.dart';
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
}

class BranchPanelDrawer extends StatelessWidget {
  const BranchPanelDrawer({
    super.key,
    required this.service,
    required this.currentUser,
    required this.currentDestination,
    this.onSignOut,
  });

  final InventoryWorkflowService service;
  final AppUser currentUser;
  final BranchPanelDestination currentDestination;
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
      ),
      BranchPanelDestination.notifications => NotificationInboxPage(
        service: service,
        currentUser: currentUser,
      ),
      BranchPanelDestination.stockAlerts => StockAlertsPage(
        service: service,
        currentUser: currentUser,
      ),
      BranchPanelDestination.syncStatus => SyncStatusPage(
        service: service,
        currentUser: currentUser,
      ),
      BranchPanelDestination.approvals => ApprovalRequestsPage(
        service: service,
        currentUser: currentUser,
      ),
      BranchPanelDestination.inventoryAdjustment => InventoryAdjustmentPage(
        service: service,
        currentUser: currentUser,
      ),
      BranchPanelDestination.salesRegister => SalesRegisterPage(
        service: service,
        currentUser: currentUser,
      ),
      BranchPanelDestination.salesReport => SalesReportPage(
        service: service,
        currentUser: currentUser,
      ),
      BranchPanelDestination.requestTracking => RequestTrackingPage(
        service: service,
        currentUser: currentUser,
      ),
      BranchPanelDestination.reservationRequest => ReservationRequestPage(
        service: service,
        currentUser: currentUser,
      ),
      BranchPanelDestination.transferRequest => TransferRequestPage(
        service: service,
        currentUser: currentUser,
      ),
      BranchPanelDestination.dashboard => const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final canApprove =
        currentUser.can(AppPermission.approveTransfer) ||
        currentUser.can(AppPermission.approveReservation);
    final canAdjust = currentUser.can(AppPermission.manageInventory);
    final canRegisterSale = currentUser.can(AppPermission.registerSale);
    final canViewSales = currentUser.can(AppPermission.viewBranchSales);

    return Drawer(
      backgroundColor: const Color(0xFF09192E),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                currentUser.role == UserRole.seller
                    ? 'Menu de ventas'
                    : 'Menu de sucursal',
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
                      _DrawerSectionLabel(text: 'Operacion'),
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
                      if (canViewSales) ...[
                        const SizedBox(height: 10),
                        _DrawerTile(
                          icon: Icons.receipt_long_rounded,
                          title: 'Ventas de sucursal',
                          selected:
                              currentDestination ==
                              BranchPanelDestination.salesReport,
                          onTap: () => _open(
                            context,
                            BranchPanelDestination.salesReport,
                          ),
                        ),
                      ],
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
                      if (canApprove) ...[
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
                      if (canAdjust) ...[
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
                      const SizedBox(height: 18),
                      _DrawerSectionLabel(text: 'Monitoreo'),
                      const SizedBox(height: 10),
                      _DrawerTile(
                        icon: Icons.notification_important_rounded,
                        title: 'Alertas de stock',
                        selected:
                            currentDestination ==
                            BranchPanelDestination.stockAlerts,
                        onTap: () =>
                            _open(context, BranchPanelDestination.stockAlerts),
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
                  ),
                ),
              ),
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
