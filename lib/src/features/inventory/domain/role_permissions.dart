import 'models.dart';

enum AppPermission {
  viewOwnInventory('Ver inventario de sucursal'),
  viewStockByBranch('Ver stock por sucursal'),
  viewLowStock('Ver alertas de stock bajo'),
  viewBranchReservations('Ver reservas activas de la sucursal'),
  viewBranchTransfers('Ver traslados de la sucursal'),
  viewOperationalMetrics('Ver metricas operativas'),
  createReservation('Crear reservas'),
  updateReservation('Cerrar o cancelar reservas'),
  requestTransfer('Solicitar traslados'),
  approveTransfer('Aprobar traslados'),
  dispatchTransfer('Despachar traslados'),
  receiveTransfer('Recibir traslados'),
  manageInventory('Ajustar inventario'),
  manageBranches('Gestionar sucursales'),
  viewMasterData('Ver catalogo maestro'),
  manageEmployees('Gestionar empleados'),
  seedMasterData('Inicializar la base maestra'),
  viewUsers('Ver usuarios'),
  viewPermissionMatrix('Ver matriz de permisos');

  const AppPermission(this.label);

  final String label;
}

enum AppModule {
  inventory('Inventario', AppPermission.viewOwnInventory),
  lowStock('Stock bajo', AppPermission.viewLowStock),
  reservations('Reservas', AppPermission.viewBranchReservations),
  transfers('Traslados', AppPermission.viewBranchTransfers),
  metrics('Metricas', AppPermission.viewOperationalMetrics),
  masterData('Base maestra', AppPermission.viewMasterData),
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
      AppPermission.viewOwnInventory ||
      AppPermission.viewStockByBranch ||
      AppPermission.viewLowStock ||
      AppPermission.createReservation ||
      AppPermission.updateReservation ||
      AppPermission.requestTransfer ||
      AppPermission.receiveTransfer => true,
      _ => false,
    },
    UserRole.supervisor => switch (permission) {
      AppPermission.viewOwnInventory ||
      AppPermission.viewStockByBranch ||
      AppPermission.viewLowStock ||
      AppPermission.viewBranchReservations ||
      AppPermission.viewBranchTransfers ||
      AppPermission.viewOperationalMetrics ||
      AppPermission.createReservation ||
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
