import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../auth/application/auth_service.dart';
import '../../auth/presentation/employee_management_page.dart';
import '../application/inventory_workflow_service.dart';
import '../domain/models.dart';
import '../domain/role_permissions.dart';
import 'create_branch_dialog.dart';

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
  static const _autoRefreshInterval = Duration(seconds: 60);

  bool _isCreating = false;
  bool _isCreatingBranch = false;
  bool _isRefreshing = false;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
      unawaited(_refreshDashboard(isManual: false));
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _showStatusMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _createBaseData() async {
    setState(() {
      _isCreating = true;
    });

    try {
      await widget.service.seedMasterData(actorUser: widget.currentUser);
      if (!mounted) {
        return;
      }
      _showStatusMessage(
        'Base inicial creada. Ya puedes revisar inventarios, solicitudes y sincronizaciones.',
      );
      await _refreshDashboard(isManual: true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showStatusMessage('Error creando la base inicial: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  Future<void> _openCreateBranchDialog() async {
    final request = await showDialog<CreateBranchRequest>(
      context: context,
      builder: (context) => const CreateBranchDialog(),
    );

    if (request == null) {
      return;
    }

    setState(() {
      _isCreatingBranch = true;
    });

    try {
      final branch = await widget.service.createBranch(
        actorUser: widget.currentUser,
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

      if (!mounted) {
        return;
      }
      _showStatusMessage('Sucursal creada correctamente: ${branch.name}.');
      await _refreshDashboard(isManual: true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showStatusMessage('No se pudo crear la sucursal: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingBranch = false;
        });
      }
    }
  }

  Future<void> _openEmployeeManagementPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => EmployeeManagementPage(
          authService: widget.authService,
          currentUser: widget.currentUser,
        ),
      ),
    );
  }

  Future<void> _refreshDashboard({required bool isManual}) async {
    if (_isRefreshing) {
      return;
    }

    final branchId = widget.currentUser.branchId;
    setState(() {
      _isRefreshing = true;
    });

    try {
      await Future.wait<void>([
        widget.service.inventories
            .watchBranchInventory(branchId)
            .first
            .then((_) {}),
        widget.service.inventories.watchLowStock(branchId).first.then((_) {}),
        widget.service.reservations
            .watchBranchReservations(branchId)
            .first
            .then((_) {}),
        widget.service.transfers.watchTransfers().first.then((_) {}),
        widget.service.catalog.watchBranches().first.then((_) {}),
        widget.service.system.watchBranchSyncLogs(branchId).first.then((_) {}),
      ]);

      if (!mounted) {
        return;
      }
      if (isManual) {
        _showStatusMessage('Dashboard actualizado correctamente.');
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showStatusMessage('No se pudo actualizar el dashboard: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _runDrawerAction(Future<void> Function() action) async {
    Navigator.of(context).pop();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) {
      return;
    }
    await action();
  }

  void _showAdminNotifications() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Revisa las solicitudes pendientes del dashboard.'),
      ),
    );
  }

  Widget _buildOperationalMetricsSection(
    AppUser user, {
    required String title,
  }) {
    if (!user.can(AppPermission.viewOperationalMetrics)) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<BranchOperationalStats>(
      stream: widget.service.watchOperationalStats(
        actorUser: user,
        branchId: user.branchId,
      ),
      builder: (context, snapshot) {
        final stats = snapshot.data;
        if (stats == null) {
          return const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AdminSectionHeader(title: title),
            const SizedBox(height: 12),
            _OperationalKpiStrip(stats: stats),
            const SizedBox(height: 16),
            _DashboardGrid(
              children: [
                _ConsultedOutOfStockPanel(stats: stats),
                _TransfersByDayPanel(stats: stats),
              ],
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildAdminSections(AppUser user) {
    return [
      const SizedBox(height: 12),
      _AdminRoleBar(user: user),
      const SizedBox(height: 20),
      Text(
        'Dashboard Administrativo',
        style: Theme.of(
          context,
        ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      Text(
        'Panel de control para monitorear el inventario multi-sucursal.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
      ),
      const SizedBox(height: 18),
      _AdminOperationalHero(
        service: widget.service,
        onPressed: _isRefreshing
            ? null
            : () => _refreshDashboard(isManual: true),
      ),
      const SizedBox(height: 18),
      const _AdminSectionHeader(title: 'Metricas', actionLabel: 'Ver todas'),
      const SizedBox(height: 12),
      _AdminMetricsStrip(service: widget.service),
      const SizedBox(height: 18),
      _buildOperationalMetricsSection(user, title: 'KPIs de supervision'),
      const SizedBox(height: 18),
      _AdminPendingSection(service: widget.service, branchId: user.branchId),
      const SizedBox(height: 18),
      _AdminAuditSection(service: widget.service),
      const SizedBox(height: 12),
      _AdminRefreshCard(
        service: widget.service,
        onPressed: _isRefreshing
            ? null
            : () => _refreshDashboard(isManual: true),
      ),
    ];
  }

  List<Widget> _buildSupervisorSections(AppUser user) {
    return [
      const SizedBox(height: 12),
      _AdminRoleBar(user: user),
      const SizedBox(height: 20),
      Text(
        'Control de sucursal',
        style: Theme.of(
          context,
        ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 18),
      _BranchOperationalHero(
        service: widget.service,
        branchId: user.branchId,
        role: user.role,
        onPressed: _isRefreshing
            ? null
            : () => _refreshDashboard(isManual: true),
      ),
      const SizedBox(height: 18),
      const _AdminSectionHeader(title: 'Resumen operativo'),
      const SizedBox(height: 12),
      _BranchMetricsStrip(
        service: widget.service,
        branchId: user.branchId,
        role: user.role,
      ),
      const SizedBox(height: 18),
      _buildOperationalMetricsSection(user, title: 'KPIs operativos'),
      const SizedBox(height: 18),
      _DashboardGrid(
        children: [
          _PendingRequestsPanel(
            service: widget.service,
            branchId: user.branchId,
            title: 'Solicitudes pendientes',
            subtitle:
                'Reservas activas y traslados que requieren seguimiento de la sucursal.',
          ),
          _LowStockPanel(
            service: widget.service,
            branchId: user.branchId,
            title: 'Alertas de inventario bajo',
            subtitle:
                'Productos con disponibilidad reducida que requieren reposicion o ajuste.',
          ),
          _OutOfStockPanel(
            service: widget.service,
            branchId: user.branchId,
            title: 'Productos sin stock',
            subtitle:
                'Quiebres detectados que afectan la atencion o los traslados internos.',
          ),
          _LatestSyncsPanel(
            service: widget.service,
            branchId: user.branchId,
            title: 'Ultimas sincronizaciones',
            subtitle:
                'Trazabilidad reciente de sincronizacion para validar continuidad operativa.',
          ),
          _TopConsultedPanel(
            service: widget.service,
            branchId: user.branchId,
            title: 'Productos mas consultados',
            subtitle:
                'Priorizacion operativa basada en actividad y movimiento reciente.',
          ),
        ],
      ),
      const SizedBox(height: 18),
      _AdminRefreshCard(
        service: widget.service,
        branchId: user.branchId,
        onPressed: _isRefreshing
            ? null
            : () => _refreshDashboard(isManual: true),
      ),
      const SizedBox(height: 18),
      const _AdminSectionHeader(title: 'Modulos habilitados'),
      const SizedBox(height: 12),
      _ModulePanel(modules: user.visibleModules),
    ];
  }

  List<Widget> _buildSellerSections(AppUser user) {
    return [
      const SizedBox(height: 12),
      _AdminRoleBar(user: user),
      const SizedBox(height: 20),
      Text(
        'Panel de ventas',
        style: Theme.of(
          context,
        ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 18),
      _BranchOperationalHero(
        service: widget.service,
        branchId: user.branchId,
        role: user.role,
        onPressed: _isRefreshing
            ? null
            : () => _refreshDashboard(isManual: true),
      ),
      const SizedBox(height: 18),
      const _AdminSectionHeader(title: 'Resumen comercial'),
      const SizedBox(height: 12),
      _BranchMetricsStrip(
        service: widget.service,
        branchId: user.branchId,
        role: user.role,
      ),
      const SizedBox(height: 18),
      _DashboardGrid(
        children: [
          _TopConsultedPanel(
            service: widget.service,
            branchId: user.branchId,
            title: 'Productos mas consultados',
            subtitle:
                'Referencias con mayor actividad comercial reciente en tu sucursal.',
          ),
          _OutOfStockPanel(
            service: widget.service,
            branchId: user.branchId,
            title: 'Productos sin stock',
            subtitle:
                'Quiebres que pueden afectar la atencion de clientes en mostrador.',
          ),
          _LowStockPanel(
            service: widget.service,
            branchId: user.branchId,
            title: 'Alertas de inventario bajo',
            subtitle:
                'Productos con pocas unidades antes de llegar a quiebre total.',
          ),
          _PendingRequestsPanel(
            service: widget.service,
            branchId: user.branchId,
            title: 'Compromisos activos',
            subtitle:
                'Reservas activas y traslados pendientes vinculados a tus ventas.',
          ),
          _LatestSyncsPanel(
            service: widget.service,
            branchId: user.branchId,
            title: 'Ultimas sincronizaciones',
            subtitle:
                'Eventos recientes para validar que la informacion local este al dia.',
          ),
        ],
      ),
      const SizedBox(height: 18),
      _AdminRefreshCard(
        service: widget.service,
        branchId: user.branchId,
        onPressed: _isRefreshing
            ? null
            : () => _refreshDashboard(isManual: true),
      ),
      const SizedBox(height: 18),
      const _AdminSectionHeader(title: 'Modulos habilitados'),
      const SizedBox(height: 12),
      _ModulePanel(modules: user.visibleModules),
    ];
  }

  Widget _buildAdminScaffold(AppUser user) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        titleSpacing: 0,
        title: const Text('Dashboard'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _ToolbarButton(
              icon: _isRefreshing
                  ? Icons.hourglass_top_rounded
                  : Icons.sync_rounded,
              onPressed: _isRefreshing
                  ? () {}
                  : () => _refreshDashboard(isManual: true),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _AdminNotificationButton(
              service: widget.service,
              branchId: user.branchId,
              onPressed: _showAdminNotifications,
            ),
          ),
        ],
      ),
      drawer: _AdminDrawer(
        user: user,
        isCreating: _isCreating,
        isCreatingBranch: _isCreatingBranch,
        onCreateBaseData: _isCreating
            ? null
            : () => _runDrawerAction(_createBaseData),
        onCreateBranch: _isCreatingBranch
            ? null
            : () => _runDrawerAction(_openCreateBranchDialog),
        onManageEmployees: () => _runDrawerAction(_openEmployeeManagementPage),
        onSignOut: widget.authService.signOut,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF081A33), Color(0xFF0A2142), Color(0xFF08172D)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: () => _refreshDashboard(isManual: true),
            color: AppPalette.amber,
            backgroundColor: AppPalette.storm,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: _buildAdminSections(user),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBranchScaffold(AppUser user, List<Widget> content) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        titleSpacing: 0,
        title: const Text('Dashboard'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _ToolbarButton(
              icon: _isRefreshing
                  ? Icons.hourglass_top_rounded
                  : Icons.sync_rounded,
              onPressed: _isRefreshing
                  ? () {}
                  : () => _refreshDashboard(isManual: true),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _ToolbarButton(
              icon: Icons.logout_rounded,
              onPressed: widget.authService.signOut,
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF081A33), Color(0xFF0A2142), Color(0xFF08172D)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: () => _refreshDashboard(isManual: true),
            color: AppPalette.amber,
            backgroundColor: AppPalette.storm,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: content,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.currentUser;
    if (user.role == UserRole.admin) {
      return _buildAdminScaffold(user);
    }

    final content = switch (user.role) {
      UserRole.supervisor => _buildSupervisorSections(user),
      UserRole.seller => _buildSellerSections(user),
      UserRole.admin => const <Widget>[],
    };

    return _buildBranchScaffold(user, content);
  }
}

class _AdminRoleBar extends StatelessWidget {
  const _AdminRoleBar({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF13335F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF214A8D),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person, size: 14, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  user.role.displayName,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sucursal: ${user.branchId.toUpperCase()}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppPalette.textPrimary),
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.white70),
        ],
      ),
    );
  }
}

class _AdminOperationalHero extends StatelessWidget {
  const _AdminOperationalHero({required this.service, required this.onPressed});

  final InventoryWorkflowService service;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SyncLog>>(
      stream: service.system.watchRecentSyncLogs(limit: 1),
      builder: (context, snapshot) {
        final logs = snapshot.data ?? const <SyncLog>[];
        final latest = logs.isEmpty ? null : logs.first;
        final syncStatus = latest == null
            ? 'Sin sincronizaciones registradas'
            : '${_formatSyncStatus(latest.status)} | ${latest.recordsProcessed} registros';

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              colors: [Color(0xFF234C9A), Color(0xFF20457D), Color(0xFF122A4D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: const Color(0x33FFFFFF)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: -16,
                right: -4,
                child: Icon(
                  Icons.cloud_outlined,
                  size: 110,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              Positioned(
                top: 18,
                right: 24,
                child: Icon(
                  Icons.location_on_rounded,
                  color: AppPalette.amber,
                  size: 28,
                ),
              ),
              Positioned(
                top: 44,
                right: 56,
                child: Icon(
                  Icons.location_on_rounded,
                  color: AppPalette.cyan,
                  size: 18,
                ),
              ),
              Positioned(
                top: 78,
                right: 22,
                child: Icon(
                  Icons.location_on_rounded,
                  color: Colors.white70,
                  size: 18,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppPalette.mint,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Sincronizacion operativa',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      latest == null
                          ? 'Ultima sincronizacion: Sin registros'
                          : 'Ultima sincronizacion: ${_formatRelativeTime(latest.createdAt)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      latest == null
                          ? syncStatus
                          : '$syncStatus | ${_formatSyncType(latest.type)} en ${latest.branchName}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: onPressed,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF204C9B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('Ver estado detallado'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BranchOperationalHero extends StatelessWidget {
  const _BranchOperationalHero({
    required this.service,
    required this.branchId,
    required this.role,
    required this.onPressed,
  });

  final InventoryWorkflowService service;
  final String branchId;
  final UserRole role;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SyncLog>>(
      stream: service.system.watchBranchSyncLogs(branchId, limit: 1),
      builder: (context, syncSnapshot) {
        final syncLogs = syncSnapshot.data ?? const <SyncLog>[];
        final latestSync = syncLogs.isEmpty ? null : syncLogs.first;
        return StreamBuilder<List<InventoryItem>>(
          stream: service.inventories.watchBranchInventory(branchId),
          builder: (context, inventorySnapshot) {
            final inventory = inventorySnapshot.data ?? const <InventoryItem>[];
            final outOfStock = inventory
                .where((item) => item.availableStock <= 0)
                .length;
            final lowStock = inventory
                .where((item) => item.isLowStock && item.availableStock > 0)
                .length;

            return StreamBuilder<List<Reservation>>(
              stream: service.reservations.watchBranchReservations(branchId),
              builder: (context, reservationSnapshot) {
                final reservations =
                    reservationSnapshot.data ?? const <Reservation>[];
                final activeReservations = reservations
                    .where((item) => item.status == ReservationStatus.active)
                    .length;

                return StreamBuilder<List<TransferRequest>>(
                  stream: service.transfers.watchTransfers(),
                  builder: (context, transferSnapshot) {
                    final transfers =
                        transferSnapshot.data ?? const <TransferRequest>[];
                    final pendingTransfers = transfers
                        .where(
                          (item) =>
                              item.status == TransferStatus.pending &&
                              _isTransferForBranch(item, branchId),
                        )
                        .length;

                    final title = switch (role) {
                      UserRole.seller => 'Disponibilidad comercial',
                      UserRole.supervisor => 'Operacion de sucursal',
                      UserRole.admin => 'Operacion general',
                    };
                    final colors = switch (role) {
                      UserRole.seller => const [
                        Color(0xFF1F4D91),
                        Color(0xFF1A3769),
                        Color(0xFF102543),
                      ],
                      UserRole.supervisor => const [
                        Color(0xFF205B83),
                        Color(0xFF174766),
                        Color(0xFF0F253C),
                      ],
                      UserRole.admin => const [
                        Color(0xFF234C9A),
                        Color(0xFF20457D),
                        Color(0xFF122A4D),
                      ],
                    };
                    final iconColor = switch (role) {
                      UserRole.seller => AppPalette.blueSoft,
                      UserRole.supervisor => AppPalette.amber,
                      UserRole.admin => AppPalette.mint,
                    };
                    final icon = switch (role) {
                      UserRole.seller => Icons.storefront_rounded,
                      UserRole.supervisor => Icons.manage_accounts_rounded,
                      UserRole.admin => Icons.verified_user_rounded,
                    };
                    final summary = switch (role) {
                      UserRole.seller =>
                        'Reservas activas: $activeReservations | Sin stock: $outOfStock',
                      UserRole.supervisor =>
                        'Solicitudes activas: ${activeReservations + pendingTransfers} | Stock bajo: $lowStock',
                      UserRole.admin => 'Sin resumen disponible',
                    };

                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        gradient: LinearGradient(
                          colors: colors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(color: const Color(0x33FFFFFF)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 18,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: -18,
                            right: -4,
                            child: Icon(
                              icon,
                              size: 104,
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          Positioned(
                            top: 22,
                            right: 26,
                            child: Icon(
                              Icons.location_on_rounded,
                              color: iconColor,
                              size: 24,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: iconColor,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        icon,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  latestSync == null
                                      ? 'Ultima sincronizacion: Sin registros'
                                      : 'Ultima sincronizacion: ${_formatRelativeTime(latestSync.createdAt)}',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: 0.88,
                                        ),
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  latestSync == null
                                      ? summary
                                      : '$summary | ${_formatSyncStatus(latestSync.status)}',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: 0.88,
                                        ),
                                      ),
                                ),
                                const SizedBox(height: 18),
                                FilledButton(
                                  onPressed: onPressed,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF204C9B),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 12,
                                    ),
                                  ),
                                  child: const Text('Actualizar dashboard'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _AdminSectionHeader extends StatelessWidget {
  const _AdminSectionHeader({required this.title, this.actionLabel});

  final String title;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        if (actionLabel != null)
          Text(
            '$actionLabel >',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: Colors.white70),
          ),
      ],
    );
  }
}

class _BranchMetricsStrip extends StatelessWidget {
  const _BranchMetricsStrip({
    required this.service,
    required this.branchId,
    required this.role,
  });

  final InventoryWorkflowService service;
  final String branchId;
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<InventoryItem>>(
      stream: service.inventories.watchBranchInventory(branchId),
      builder: (context, inventorySnapshot) {
        final inventory = inventorySnapshot.data ?? const <InventoryItem>[];
        final inventoryCount = inventory.length;
        final outOfStock = inventory
            .where((item) => item.availableStock <= 0)
            .length;
        final lowStock = inventory
            .where((item) => item.isLowStock && item.availableStock > 0)
            .length;

        return StreamBuilder<List<Reservation>>(
          stream: service.reservations.watchBranchReservations(branchId),
          builder: (context, reservationSnapshot) {
            final reservations =
                reservationSnapshot.data ?? const <Reservation>[];
            final activeReservations = reservations
                .where((item) => item.status == ReservationStatus.active)
                .length;

            return StreamBuilder<List<TransferRequest>>(
              stream: service.transfers.watchTransfers(),
              builder: (context, transferSnapshot) {
                final transfers =
                    transferSnapshot.data ?? const <TransferRequest>[];
                final pendingTransfers = transfers
                    .where(
                      (item) =>
                          item.status == TransferStatus.pending &&
                          _isTransferForBranch(item, branchId),
                    )
                    .length;

                final tiles = switch (role) {
                  UserRole.seller => [
                    (
                      icon: Icons.inventory_2_rounded,
                      title: 'Productos\nvisibles',
                      value: '$inventoryCount',
                      helper: 'Inventario de sucursal',
                      colors: const [Color(0xFF214C9A), Color(0xFF183A79)],
                    ),
                    (
                      icon: Icons.remove_shopping_cart_rounded,
                      title: 'Productos\nsin stock',
                      value: '$outOfStock',
                      helper: 'Sin disponibilidad',
                      colors: const [Color(0xFF2E8B57), Color(0xFF256E49)],
                    ),
                    (
                      icon: Icons.bookmark_added_rounded,
                      title: 'Reservas\nactivas',
                      value: '$activeReservations',
                      helper: 'Compromisos vigentes',
                      colors: const [Color(0xFFFF8A24), Color(0xFFE66A11)],
                    ),
                  ],
                  UserRole.supervisor => [
                    (
                      icon: Icons.warning_amber_rounded,
                      title: 'Stock\nbajo',
                      value: '$lowStock',
                      helper: 'Reposicion prioritaria',
                      colors: const [Color(0xFF214C9A), Color(0xFF183A79)],
                    ),
                    (
                      icon: Icons.remove_shopping_cart_rounded,
                      title: 'Sin\nstock',
                      value: '$outOfStock',
                      helper: 'Quiebres detectados',
                      colors: const [Color(0xFF2E8B57), Color(0xFF256E49)],
                    ),
                    (
                      icon: Icons.pending_actions_rounded,
                      title: 'Solicitudes\nactivas',
                      value: '${activeReservations + pendingTransfers}',
                      helper:
                          '$activeReservations reservas y $pendingTransfers traslados',
                      colors: const [Color(0xFFFF8A24), Color(0xFFE66A11)],
                    ),
                  ],
                  UserRole.admin => [
                    (
                      icon: Icons.info_rounded,
                      title: 'Sin uso',
                      value: '0',
                      helper: '',
                      colors: const [Color(0xFF214C9A), Color(0xFF183A79)],
                    ),
                  ],
                };

                return Row(
                  children: [
                    for (var index = 0; index < tiles.length; index++) ...[
                      Expanded(
                        child: _AdminMetricTile(
                          icon: tiles[index].icon,
                          title: tiles[index].title,
                          value: tiles[index].value,
                          helper: tiles[index].helper,
                          colors: tiles[index].colors,
                        ),
                      ),
                      if (index != tiles.length - 1) const SizedBox(width: 10),
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _OperationalKpiStrip extends StatelessWidget {
  const _OperationalKpiStrip({required this.stats});

  final BranchOperationalStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _AdminMetricTile(
            icon: Icons.search_off_rounded,
            title: 'Consultas\nsin stock',
            value: '${stats.consultedOutOfStockCount}',
            helper: 'Referencias sin respuesta',
            colors: const [Color(0xFF214C9A), Color(0xFF183A79)],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _AdminMetricTile(
            icon: Icons.sync_alt_rounded,
            title: 'Traslados\nhoy',
            value: '${stats.transferRequestsToday}',
            helper: 'Solicitudes del dia',
            colors: const [Color(0xFF2E8B57), Color(0xFF256E49)],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _AdminMetricTile(
            icon: Icons.speed_rounded,
            title: 'Tiempo\npromedio API',
            value: _formatDurationCompact(stats.averageApiResponseTime),
            helper: 'Basado en sync logs',
            colors: const [Color(0xFFFF8A24), Color(0xFFE66A11)],
          ),
        ),
      ],
    );
  }
}

class _ConsultedOutOfStockPanel extends StatelessWidget {
  const _ConsultedOutOfStockPanel({required this.stats});

  final BranchOperationalStats stats;

  @override
  Widget build(BuildContext context) {
    final items = stats.outOfStockConsultations
        .map(
          (item) => _InsightItem(
            icon: Icons.search_off_rounded,
            iconColor: AppPalette.danger,
            title: item.productName,
            detail:
                'SKU ${item.sku} | score ${item.interestScore} | stock ${item.availableStock}',
            meta:
                'Reservas ${item.reservationHits} | traslados ${item.transferHits} | ${_formatRelativeTime(item.lastMovementAt)}',
          ),
        )
        .toList(growable: false);

    return _DashboardPanel(
      title: 'Consultas sin stock',
      subtitle:
          'Productos con mayor interes operativo o comercial que hoy no tienen disponibilidad.',
      accent: AppPalette.danger,
      child: _InsightList(
        items: items,
        emptyMessage:
            'No hay consultas prioritarias en productos agotados para esta sucursal.',
      ),
    );
  }
}

class _TransfersByDayPanel extends StatelessWidget {
  const _TransfersByDayPanel({required this.stats});

  final BranchOperationalStats stats;

  @override
  Widget build(BuildContext context) {
    final maxCount = stats.transferRequestsByDay.fold<int>(
      1,
      (current, item) => item.count > current ? item.count : current,
    );

    final rows = stats.transferRequestsByDay
        .map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 58,
                  child: Text(
                    _formatShortDay(item.day),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: item.count / maxCount,
                      minHeight: 10,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppPalette.amber,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${item.count}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        )
        .toList(growable: false);

    return _DashboardPanel(
      title: 'Solicitudes de traslado por dia',
      subtitle:
          'Carga reciente de solicitudes registradas para la sucursal en los ultimos cinco dias.',
      accent: AppPalette.amber,
      child: Column(children: rows),
    );
  }
}

class _AdminMetricsStrip extends StatelessWidget {
  const _AdminMetricsStrip({required this.service});

  final InventoryWorkflowService service;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppUser>>(
      stream: service.users.watchUsers(),
      builder: (context, snapshot) {
        final users = snapshot.data ?? const <AppUser>[];
        final activeUsers = users.where((item) => item.isActive).length;
        return StreamBuilder<List<Reservation>>(
          stream: service.reservations.watchReservations(),
          builder: (context, reservationSnapshot) {
            final reservations =
                reservationSnapshot.data ?? const <Reservation>[];
            final activeReservations = reservations
                .where((item) => item.status == ReservationStatus.active)
                .length;
            return StreamBuilder<List<TransferRequest>>(
              stream: service.transfers.watchTransfers(),
              builder: (context, transferSnapshot) {
                final transfers =
                    transferSnapshot.data ?? const <TransferRequest>[];
                final pendingTransfers = transfers
                    .where((item) => item.status == TransferStatus.pending)
                    .length;

                return Row(
                  children: [
                    Expanded(
                      child: _AdminMetricTile(
                        icon: Icons.groups_rounded,
                        title: 'Usuarios\nactivos',
                        value: '$activeUsers',
                        helper: 'Empleados habilitados',
                        colors: const [Color(0xFF214C9A), Color(0xFF183A79)],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _AdminMetricTile(
                        icon: Icons.bookmark_added_rounded,
                        title: 'Reservas\nactivas',
                        value: '$activeReservations',
                        helper: 'Vigentes en el sistema',
                        colors: const [Color(0xFF2E8B57), Color(0xFF256E49)],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _AdminMetricTile(
                        icon: Icons.sync_alt_rounded,
                        title: 'Traslados\npendientes',
                        value: '$pendingTransfers',
                        helper: 'Esperan aprobacion',
                        colors: const [Color(0xFFFF8A24), Color(0xFFE66A11)],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _AdminMetricTile extends StatelessWidget {
  const _AdminMetricTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.helper,
    required this.colors,
  });

  final IconData icon;
  final String title;
  final String value;
  final String helper;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 10),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            helper,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminPendingSection extends StatelessWidget {
  const _AdminPendingSection({required this.service, required this.branchId});

  final InventoryWorkflowService service;
  final String branchId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Reservation>>(
      stream: service.reservations.watchReservations(),
      builder: (context, reservationSnapshot) {
        final reservations = reservationSnapshot.data ?? const <Reservation>[];
        return StreamBuilder<List<TransferRequest>>(
          stream: service.transfers.watchTransfers(),
          builder: (context, transferSnapshot) {
            final transfers =
                transferSnapshot.data ?? const <TransferRequest>[];
            final items = _buildPendingRequestItems(
              reservations: reservations,
              transfers: transfers,
              branchId: branchId,
              includeAllBranches: true,
            );
            final preview = items.take(2).toList(growable: false);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Solicitudes pendientes',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (items.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5C67),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${items.length}',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: Colors.white),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (preview.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF102540),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0x26FFFFFF)),
                    ),
                    child: const Text('No hay solicitudes pendientes.'),
                  )
                else
                  ...preview.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AdminPendingTile(item: item),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _AdminPendingTile extends StatelessWidget {
  const _AdminPendingTile({required this.item});

  final _InsightItem item;

  @override
  Widget build(BuildContext context) {
    final isTransfer = item.title.startsWith('Traslado');
    final colors = isTransfer
        ? const [Color(0xFFEE7A1D), Color(0xFFC95B14)]
        : const [Color(0xFF4D5ED8), Color(0xFF3144A8)];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.detail,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.meta,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.white),
        ],
      ),
    );
  }
}

class _AdminAuditSection extends StatelessWidget {
  const _AdminAuditSection({required this.service});

  final InventoryWorkflowService service;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AuditLog>>(
      stream: service.system.watchRecentAuditLogs(limit: 4),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <AuditLog>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Actividad administrativa',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF102540),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0x26FFFFFF)),
                ),
                child: const Text(
                  'No hay eventos administrativos registrados.',
                ),
              )
            else
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _AdminAuditTile(auditLog: item),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AdminAuditTile extends StatelessWidget {
  const _AdminAuditTile({required this.auditLog});

  final AuditLog auditLog;

  @override
  Widget build(BuildContext context) {
    final accent = _auditActionColor(auditLog.action);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [accent.withValues(alpha: 0.85), const Color(0xFF162E53)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_auditActionIcon(auditLog.action), color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatAuditAction(auditLog.action),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${auditLog.message} ${auditLog.entityLabel}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${auditLog.actorName} | ${auditLog.actorRole.displayName} | ${auditLog.branchName ?? 'Global'} | ${_formatRelativeTime(auditLog.createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminRefreshCard extends StatelessWidget {
  const _AdminRefreshCard({
    required this.service,
    this.branchId,
    required this.onPressed,
  });

  final InventoryWorkflowService service;
  final String? branchId;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SyncLog>>(
      stream: branchId == null
          ? service.system.watchRecentSyncLogs(limit: 1)
          : service.system.watchBranchSyncLogs(branchId!, limit: 1),
      builder: (context, snapshot) {
        final logs = snapshot.data ?? const <SyncLog>[];
        final latest = logs.isEmpty ? null : logs.first;
        final subtitle = latest == null
            ? 'Sin sincronizaciones registradas'
            : 'Ultima sincronizacion real: ${_formatClock(latest.createdAt)} | ${_formatSyncStatus(latest.status)}';

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(18),
            child: Ink(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  colors: [Color(0xFF213452), Color(0xFF0F213D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: const Color(0x26FFFFFF)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.sync_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Actualizar datos',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white70,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AdminNotificationButton extends StatelessWidget {
  const _AdminNotificationButton({
    required this.service,
    required this.branchId,
    required this.onPressed,
  });

  final InventoryWorkflowService service;
  final String branchId;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Reservation>>(
      stream: service.reservations.watchReservations(),
      builder: (context, reservationSnapshot) {
        final reservations = reservationSnapshot.data ?? const <Reservation>[];
        return StreamBuilder<List<TransferRequest>>(
          stream: service.transfers.watchTransfers(),
          builder: (context, transferSnapshot) {
            final transfers =
                transferSnapshot.data ?? const <TransferRequest>[];
            final count = _buildPendingRequestItems(
              reservations: reservations,
              transfers: transfers,
              branchId: branchId,
              includeAllBranches: true,
            ).length;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                _ToolbarButton(
                  icon: Icons.notifications_none_rounded,
                  onPressed: onPressed,
                ),
                if (count > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF4C63),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${count > 9 ? '9+' : count}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _AdminDrawer extends StatelessWidget {
  const _AdminDrawer({
    required this.user,
    required this.isCreating,
    required this.isCreatingBranch,
    required this.onCreateBaseData,
    required this.onCreateBranch,
    required this.onManageEmployees,
    required this.onSignOut,
  });

  final AppUser user;
  final bool isCreating;
  final bool isCreatingBranch;
  final VoidCallback? onCreateBaseData;
  final VoidCallback? onCreateBranch;
  final VoidCallback? onManageEmployees;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF09192E),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Menu administrativo',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(
                '${user.fullName} | ${user.branchId}',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 22),
              _AdminDrawerTile(
                icon: Icons.person_add_alt_1_rounded,
                title: 'Gestion de empleados',
                onTap: onManageEmployees,
              ),
              const SizedBox(height: 10),
              _AdminDrawerTile(
                icon: Icons.add_business_rounded,
                title: 'Agregar sucursal',
                loading: isCreatingBranch,
                onTap: onCreateBranch,
              ),
              const SizedBox(height: 10),
              _AdminDrawerTile(
                icon: Icons.storage_rounded,
                title: 'Crear base de datos inicial',
                loading: isCreating,
                onTap: onCreateBaseData,
              ),
              const Spacer(),
              _AdminDrawerTile(
                icon: Icons.logout_rounded,
                title: 'Cerrar sesion',
                onTap: onSignOut,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminDrawerTile extends StatelessWidget {
  const _AdminDrawerTile({
    required this.icon,
    required this.title,
    this.loading = false,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0E2442),
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, color: Colors.white),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: Colors.white70,
        ),
      ),
    );
  }
}

class _TopConsultedPanel extends StatelessWidget {
  const _TopConsultedPanel({
    required this.service,
    required this.branchId,
    this.title = 'Productos mas consultados',
    this.subtitle =
        'Priorizacion inicial basada en reservas activas, traslados relacionados y movimiento reciente.',
  });

  final InventoryWorkflowService service;
  final String branchId;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<InventoryItem>>(
      stream: service.inventories.watchBranchInventory(branchId),
      builder: (context, inventorySnapshot) {
        final inventories = inventorySnapshot.data ?? const <InventoryItem>[];
        return StreamBuilder<List<Reservation>>(
          stream: service.reservations.watchBranchReservations(branchId),
          builder: (context, reservationSnapshot) {
            final reservations =
                reservationSnapshot.data ?? const <Reservation>[];
            return StreamBuilder<List<TransferRequest>>(
              stream: service.transfers.watchTransfers(),
              builder: (context, transferSnapshot) {
                final transfers =
                    transferSnapshot.data ?? const <TransferRequest>[];
                final items = _buildTopConsultedItems(
                  inventories: inventories,
                  reservations: reservations,
                  transfers: transfers,
                  branchId: branchId,
                );

                return _DashboardPanel(
                  title: title,
                  subtitle: subtitle,
                  accent: AppPalette.blue,
                  child: _InsightList(
                    items: items,
                    emptyMessage:
                        'Todavia no hay suficiente actividad para priorizar productos.',
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _OutOfStockPanel extends StatelessWidget {
  const _OutOfStockPanel({
    required this.service,
    required this.branchId,
    this.title = 'Productos sin stock',
    this.subtitle = 'Quiebres actuales detectados en la sucursal asignada.',
  });

  final InventoryWorkflowService service;
  final String branchId;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<InventoryItem>>(
      stream: service.inventories.watchBranchInventory(branchId),
      builder: (context, snapshot) {
        final items = (snapshot.data ?? const <InventoryItem>[])
            .where((item) => item.availableStock <= 0)
            .map(
              (item) => _InsightItem(
                icon: Icons.remove_shopping_cart_outlined,
                iconColor: AppPalette.danger,
                title: item.productName,
                detail: 'SKU ${item.sku} | minimo ${item.minimumStock}',
                meta:
                    'Disponible ${item.availableStock} | Ultimo movimiento ${_formatRelativeTime(item.lastMovementAt)}',
              ),
            )
            .toList(growable: false);

        return _DashboardPanel(
          title: title,
          subtitle: subtitle,
          accent: AppPalette.danger,
          child: _InsightList(
            items: items,
            emptyMessage: 'No hay productos en cero dentro de esta sucursal.',
          ),
        );
      },
    );
  }
}

class _LowStockPanel extends StatelessWidget {
  const _LowStockPanel({
    required this.service,
    required this.branchId,
    this.title = 'Alertas de inventario bajo',
    this.subtitle =
        'Productos que aun tienen unidades pero ya requieren reposicion.',
  });

  final InventoryWorkflowService service;
  final String branchId;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<InventoryItem>>(
      stream: service.inventories.watchLowStock(branchId),
      builder: (context, snapshot) {
        final items = (snapshot.data ?? const <InventoryItem>[])
            .where((item) => item.availableStock > 0)
            .map(
              (item) => _InsightItem(
                icon: Icons.warning_amber_rounded,
                iconColor: AppPalette.amber,
                title: item.productName,
                detail:
                    'Disponible ${item.availableStock} | minimo ${item.minimumStock}',
                meta:
                    'Reservado ${item.reservedStock} | Ultimo cambio ${_formatRelativeTime(item.lastMovementAt)}',
              ),
            )
            .toList(growable: false);

        return _DashboardPanel(
          title: title,
          subtitle: subtitle,
          accent: AppPalette.amber,
          child: _InsightList(
            items: items,
            emptyMessage: 'No hay alertas de stock bajo en este momento.',
          ),
        );
      },
    );
  }
}

class _PendingRequestsPanel extends StatelessWidget {
  const _PendingRequestsPanel({
    required this.service,
    required this.branchId,
    this.title = 'Solicitudes pendientes',
    this.subtitle =
        'Reservas activas y traslados pendientes relacionados con la sucursal actual.',
  });

  final InventoryWorkflowService service;
  final String branchId;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Reservation>>(
      stream: service.reservations.watchBranchReservations(branchId),
      builder: (context, reservationSnapshot) {
        final reservations = reservationSnapshot.data ?? const <Reservation>[];
        return StreamBuilder<List<TransferRequest>>(
          stream: service.transfers.watchTransfers(),
          builder: (context, transferSnapshot) {
            final transfers =
                transferSnapshot.data ?? const <TransferRequest>[];
            final items = _buildPendingRequestItems(
              reservations: reservations,
              transfers: transfers,
              branchId: branchId,
              includeAllBranches: false,
            );

            return _DashboardPanel(
              title: title,
              subtitle: subtitle,
              accent: AppPalette.blueSoft,
              child: _InsightList(
                items: items,
                emptyMessage:
                    'No hay reservas activas ni traslados pendientes para mostrar.',
              ),
            );
          },
        );
      },
    );
  }
}

class _LatestSyncsPanel extends StatelessWidget {
  const _LatestSyncsPanel({
    required this.service,
    required this.branchId,
    this.title = 'Ultimas sincronizaciones',
    this.subtitle = 'Eventos recientes registrados para esta sucursal.',
  });

  final InventoryWorkflowService service;
  final String branchId;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SyncLog>>(
      stream: service.system.watchBranchSyncLogs(branchId),
      builder: (context, snapshot) {
        final items = (snapshot.data ?? const <SyncLog>[])
            .map(
              (item) => _InsightItem(
                icon: Icons.sync_alt_rounded,
                iconColor: AppPalette.mint,
                title:
                    '${item.type.toUpperCase()} | ${item.status.toUpperCase()}',
                detail:
                    '${item.recordsProcessed} registros | ${item.branchName}',
                meta:
                    '${_formatClock(item.createdAt)} | ${_formatRelativeTime(item.createdAt)}',
              ),
            )
            .toList(growable: false);

        return _DashboardPanel(
          title: title,
          subtitle: subtitle,
          accent: AppPalette.mint,
          child: _InsightList(
            items: items,
            emptyMessage:
                'No hay sincronizaciones registradas para esta sucursal.',
          ),
        );
      },
    );
  }
}

class _DashboardGrid extends StatelessWidget {
  const _DashboardGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = _panelWidthFor(constraints.maxWidth);
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: children
              .map((child) => SizedBox(width: width, child: child))
              .toList(growable: false),
        );
      },
    );
  }
}

class _DashboardPanel extends StatelessWidget {
  const _DashboardPanel({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.22),
            const Color(0xFF132847),
            const Color(0xFF0C1D36),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0x26FFFFFF)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.dashboard_customize_rounded,
                    color: accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _ModulePanel extends StatelessWidget {
  const _ModulePanel({required this.modules});

  final List<AppModule> modules;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF15304F), Color(0xFF0C1D36)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0x26FFFFFF)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: modules
            .map(
              (module) => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x40132647),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0x26FFFFFF)),
                ),
                child: Text(
                  module.label,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _InsightList extends StatelessWidget {
  const _InsightList({required this.items, required this.emptyMessage});

  final List<_InsightItem> items;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0x40132647),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x26FFFFFF)),
        ),
        child: Text(
          emptyMessage,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
        ),
      );
    }

    return Column(
      children: items
          .map(
            (item) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0x40132647),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x26FFFFFF)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: item.iconColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(item.icon, color: item.iconColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.detail,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.meta,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppPalette.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppPalette.panelStrong,
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: AppPalette.panelBorder),
      ),
      child: IconButton(onPressed: onPressed, icon: Icon(icon)),
    );
  }
}

class _InsightItem {
  const _InsightItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.detail,
    required this.meta,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String detail;
  final String meta;
}

class _RankedInventoryItem {
  const _RankedInventoryItem({
    required this.inventory,
    required this.score,
    required this.reservationHits,
    required this.transferHits,
  });

  final InventoryItem inventory;
  final int score;
  final int reservationHits;
  final int transferHits;
}

List<_InsightItem> _buildTopConsultedItems({
  required List<InventoryItem> inventories,
  required List<Reservation> reservations,
  required List<TransferRequest> transfers,
  required String branchId,
}) {
  final reservationHits = <String, int>{};
  for (final reservation in reservations) {
    if (reservation.status != ReservationStatus.active) {
      continue;
    }
    reservationHits.update(
      reservation.productId,
      (value) => value + 1,
      ifAbsent: () => 1,
    );
  }

  final transferHits = <String, int>{};
  for (final transfer in transfers) {
    if (!_isTransferForBranch(transfer, branchId)) {
      continue;
    }
    if (transfer.status == TransferStatus.rejected ||
        transfer.status == TransferStatus.cancelled) {
      continue;
    }
    transferHits.update(
      transfer.productId,
      (value) => value + 1,
      ifAbsent: () => 1,
    );
  }

  final ranked =
      inventories
          .map((inventory) {
            final reservationsForProduct =
                reservationHits[inventory.productId] ?? 0;
            final transfersForProduct = transferHits[inventory.productId] ?? 0;
            final recencyScore = _recencyWeight(inventory.lastMovementAt);
            final score =
                reservationsForProduct * 4 +
                transfersForProduct * 3 +
                recencyScore +
                (inventory.isLowStock ? 1 : 0);

            return _RankedInventoryItem(
              inventory: inventory,
              score: score,
              reservationHits: reservationsForProduct,
              transferHits: transfersForProduct,
            );
          })
          .toList(growable: false)
        ..sort((a, b) {
          final scoreComparison = b.score.compareTo(a.score);
          if (scoreComparison != 0) {
            return scoreComparison;
          }

          final left =
              a.inventory.lastMovementAt ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final right =
              b.inventory.lastMovementAt ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return right.compareTo(left);
        });

  return ranked
      .take(5)
      .map((entry) {
        final inventory = entry.inventory;
        return _InsightItem(
          icon: Icons.query_stats_outlined,
          iconColor: AppPalette.blueSoft,
          title: inventory.productName,
          detail:
              'SKU ${inventory.sku} | disponible ${inventory.availableStock} | reservados ${inventory.reservedStock}',
          meta:
              'Score ${entry.score} | reservas ${entry.reservationHits} | traslados ${entry.transferHits}',
        );
      })
      .toList(growable: false);
}

List<_InsightItem> _buildPendingRequestItems({
  required List<Reservation> reservations,
  required List<TransferRequest> transfers,
  required String branchId,
  bool includeAllBranches = false,
}) {
  final entries = <({DateTime date, _InsightItem item})>[];

  for (final reservation in reservations) {
    if (reservation.status != ReservationStatus.active) {
      continue;
    }

    entries.add((
      date: reservation.createdAt,
      item: _InsightItem(
        icon: Icons.bookmark_added_outlined,
        iconColor: AppPalette.blueSoft,
        title: 'Reserva activa | ${reservation.productName}',
        detail:
            '${reservation.customerName} | ${reservation.quantity} unidad(es)',
        meta:
            'Creada ${_formatRelativeTime(reservation.createdAt)} | vence ${_formatClock(reservation.expiresAt)}',
      ),
    ));
  }

  for (final transfer in transfers) {
    final belongsToScope =
        includeAllBranches || _isTransferForBranch(transfer, branchId);
    if (transfer.status != TransferStatus.pending || !belongsToScope) {
      continue;
    }

    entries.add((
      date: transfer.requestedAt,
      item: _InsightItem(
        icon: Icons.sync_alt_rounded,
        iconColor: AppPalette.amber,
        title: 'Traslado pendiente | ${transfer.productName}',
        detail:
            '${transfer.fromBranchName} -> ${transfer.toBranchName} | ${transfer.quantity} unidad(es)',
        meta: 'Solicitado ${_formatRelativeTime(transfer.requestedAt)}',
      ),
    ));
  }

  entries.sort((a, b) => b.date.compareTo(a.date));
  return entries.take(6).map((entry) => entry.item).toList(growable: false);
}

bool _isTransferForBranch(TransferRequest transfer, String branchId) {
  return transfer.fromBranchId == branchId || transfer.toBranchId == branchId;
}

int _recencyWeight(DateTime? value) {
  if (value == null) {
    return 0;
  }

  final difference = DateTime.now().difference(value);
  if (difference.inHours < 6) {
    return 6;
  }
  if (difference.inHours < 24) {
    return 4;
  }
  if (difference.inDays < 7) {
    return 2;
  }
  return 0;
}

double _panelWidthFor(double maxWidth) {
  if (maxWidth >= 1080) {
    return (maxWidth - 16) / 2;
  }
  return maxWidth;
}

String _formatClock(DateTime value) {
  return '${_twoDigits(value.hour)}:${_twoDigits(value.minute)}';
}

String _formatDurationCompact(Duration value) {
  if (value == Duration.zero) {
    return '0 s';
  }
  if (value.inMinutes >= 1) {
    final seconds = value.inSeconds.remainder(60);
    if (seconds == 0) {
      return '${value.inMinutes} min';
    }
    return '${value.inMinutes}m ${seconds}s';
  }
  return '${value.inSeconds}s';
}

String _formatSyncStatus(String value) {
  return switch (value.trim().toLowerCase()) {
    'success' || 'completed' || 'ok' => 'Exitosa',
    'failed' || 'error' => 'Con error',
    'running' || 'in_progress' || 'pending' => 'En proceso',
    '' => 'Sin estado',
    _ => '${value[0].toUpperCase()}${value.substring(1)}',
  };
}

String _formatSyncType(String value) {
  return switch (value.trim().toLowerCase()) {
    'inventory' => 'Inventario',
    'catalog' => 'Catalogo',
    'users' => 'Usuarios',
    'transfers' => 'Traslados',
    '' => 'Sin tipo',
    _ => '${value[0].toUpperCase()}${value.substring(1)}',
  };
}

String _formatShortDay(DateTime value) {
  return switch (value.weekday) {
    DateTime.monday => 'Lun',
    DateTime.tuesday => 'Mar',
    DateTime.wednesday => 'Mie',
    DateTime.thursday => 'Jue',
    DateTime.friday => 'Vie',
    DateTime.saturday => 'Sab',
    DateTime.sunday => 'Dom',
    _ => '${value.day}/${value.month}',
  };
}

String _formatAuditAction(String value) {
  return switch (value.trim().toLowerCase()) {
    'employee_created' => 'Empleado creado',
    'employee_role_updated' => 'Rol actualizado',
    'employee_updated' => 'Empleado actualizado',
    'branch_created' => 'Sucursal creada',
    'master_data_seeded' => 'Base inicial creada',
    _ => 'Actividad administrativa',
  };
}

IconData _auditActionIcon(String value) {
  return switch (value.trim().toLowerCase()) {
    'employee_created' => Icons.person_add_alt_1_rounded,
    'employee_role_updated' => Icons.admin_panel_settings_rounded,
    'employee_updated' => Icons.manage_accounts_rounded,
    'branch_created' => Icons.add_business_rounded,
    'master_data_seeded' => Icons.storage_rounded,
    _ => Icons.history_rounded,
  };
}

Color _auditActionColor(String value) {
  return switch (value.trim().toLowerCase()) {
    'employee_created' => const Color(0xFF2E8B57),
    'employee_role_updated' => const Color(0xFF214C9A),
    'employee_updated' => const Color(0xFF2A5F89),
    'branch_created' => const Color(0xFFE67A16),
    'master_data_seeded' => const Color(0xFF6A5AE0),
    _ => const Color(0xFF31547D),
  };
}

String _formatRelativeTime(DateTime? value) {
  if (value == null) {
    return 'sin registro';
  }

  final difference = DateTime.now().difference(value);
  if (difference.inMinutes < 1) {
    return 'hace menos de 1 min';
  }
  if (difference.inHours < 1) {
    return 'hace ${difference.inMinutes} min';
  }
  if (difference.inDays < 1) {
    return 'hace ${difference.inHours} h';
  }
  return 'hace ${difference.inDays} d';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
