import 'models.dart';

enum AppPermission {
  viewOwnInventory('Ver inventario de sucursal'),
  viewNotifications('Ver notificaciones personales'),
  viewRequestTracking('Consultar estado de solicitudes'),
  viewSyncStatus('Ver estado de actualizacion'),
  viewStockByBranch('Ver stock por sucursal'),
  viewLowStock('Ver alertas de stock bajo'),
  viewBranchReservations('Ver reservas activas de la sucursal'),
  viewBranchTransfers('Ver traslados de la sucursal'),
  viewOperationalMetrics('Ver metricas operativas'),
  registerSale('Registrar ventas'),
  viewBranchSales('Ver ventas de sucursal'),
  createReservation('Crear reservas'),
  approveReservation('Aprobar reservas'),
  updateReservation('Cerrar o cancelar reservas'),
  requestTransfer('Solicitar traslados'),
  approveTransfer('Aprobar traslados'),
  dispatchTransfer('Despachar traslados'),
  receiveTransfer('Recibir traslados'),
  manageInventory('Ajustar inventario'),
  manageBranches('Gestionar sucursales'),
  viewMasterData('Ver catalogo maestro'),
  manageMasterData('Gestionar catalogo maestro'),
  manageEmployees('Gestionar empleados'),
  seedMasterData('Inicializar la base maestra'),
  viewUsers('Ver usuarios'),
  viewPermissionMatrix('Ver matriz de permisos');

  const AppPermission(this.label);

  final String label;
}

enum AppModule {
  inventory('Inventario', AppPermission.viewOwnInventory),
  notifications('Notificaciones', AppPermission.viewNotifications),
  requestTracking('Seguimiento', AppPermission.viewRequestTracking),
  syncStatus('Actualizacion', AppPermission.viewSyncStatus),
  lowStock('Stock bajo', AppPermission.viewLowStock),
  sales('Ventas', AppPermission.registerSale),
  salesReport('Reporte de ventas', AppPermission.viewBranchSales),
  reservations('Reservas', AppPermission.viewBranchReservations),
  transfers('Traslados', AppPermission.viewBranchTransfers),
  approvals('Aprobaciones', AppPermission.approveTransfer),
  metrics('Metricas', AppPermission.viewOperationalMetrics),
  masterData('Base maestra', AppPermission.manageMasterData),
  employees('Empleados', AppPermission.manageEmployees),
  users('Usuarios', AppPermission.viewUsers),
  permissionMatrix('Permisos', AppPermission.viewPermissionMatrix);

  const AppModule(this.label, this.requiredPermission);

  final String label;
  final AppPermission requiredPermission;
}

extension UserRolePresentation on UserRole {
  String get displayName => switch (this) {
    UserRole.seller => 'Vendedor',
    UserRole.supervisor => 'Supervisor',
    UserRole.admin => 'Administrador',
  };
}

extension UserRolePermissions on UserRole {
  bool can(AppPermission permission) => switch (this) {
    UserRole.seller => switch (permission) {
      AppPermission.viewNotifications ||
      AppPermission.viewRequestTracking ||
      AppPermission.viewSyncStatus ||
      AppPermission.viewOwnInventory ||
      AppPermission.viewStockByBranch ||
      AppPermission.viewLowStock ||
      AppPermission.registerSale ||
      AppPermission.createReservation ||
      AppPermission.updateReservation ||
      AppPermission.requestTransfer ||
      AppPermission.receiveTransfer => true,
      _ => false,
    },
    UserRole.supervisor => switch (permission) {
      AppPermission.viewNotifications ||
      AppPermission.viewRequestTracking ||
      AppPermission.viewSyncStatus ||
      AppPermission.viewOwnInventory ||
      AppPermission.viewStockByBranch ||
      AppPermission.viewLowStock ||
      AppPermission.viewBranchReservations ||
      AppPermission.viewBranchTransfers ||
      AppPermission.viewOperationalMetrics ||
      AppPermission.registerSale ||
      AppPermission.viewBranchSales ||
      AppPermission.createReservation ||
      AppPermission.approveReservation ||
      AppPermission.updateReservation ||
      AppPermission.requestTransfer ||
      AppPermission.approveTransfer ||
      AppPermission.dispatchTransfer ||
      AppPermission.receiveTransfer ||
      AppPermission.manageInventory => true,
      _ => false,
    },
    UserRole.admin => true,
  };

  List<AppPermission> get grantedPermissions =>
      AppPermission.values.where(can).toList(growable: false);

  List<AppModule> get visibleModules => AppModule.values
      .where((module) => can(module.requiredPermission))
      .toList(growable: false);
}

extension AppUserPermissions on AppUser {
  bool can(AppPermission permission) => isActive && role.can(permission);

  bool canAccessBranch(String branchId) {
    return isActive && (role == UserRole.admin || this.branchId == branchId);
  }

  List<AppModule> get visibleModules => role.visibleModules;
}
