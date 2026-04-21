import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../auth/application/auth_service.dart';
import '../../auth/presentation/employee_management_page.dart';
import '../application/inventory_workflow_service.dart';
import '../domain/models.dart';
import '../domain/role_permissions.dart';
import 'approval_requests_page.dart';
import 'auto_refresh_state_mixin.dart';
import 'branch_directory_page.dart';
import 'create_branch_dialog.dart';
import 'notifications_page.dart';
import 'product_search_page.dart';
import 'request_tracking_page.dart';
import 'reservation_request_page.dart';
import 'sync_status_page.dart';
import 'transfer_request_page.dart';

enum _BranchDashboardSection { overview, inventory, workflow, metrics, modules }

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

class _InventoryDashboardPageState extends State<InventoryDashboardPage>
    with AutoRefreshStateMixin {
  bool _isCreating = false;
  bool _isCreatingBranch = false;
  bool _isRefreshing = false;
  _BranchDashboardSection _selectedBranchSection =
      _BranchDashboardSection.overview;

  String get _dashboardRefreshScope =>
      widget.service.dashboardRefreshScope(actorUser: widget.currentUser);

  @override
  Duration get autoRefreshInterval => widget.service
      .refreshPolicyFor(InventoryRefreshDataType.dashboard)
      .autoRefreshInterval;

  @override
  void initState() {
    super.initState();
    configureAutoRefresh();
    unawaited(_refreshDashboard(isManual: false));
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
      await _refreshDashboard(isManual: true, forceRefresh: true);
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
      await _refreshDashboard(isManual: true, forceRefresh: true);
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

  Future<void> _openAdminTraceabilityPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _AdminTraceabilityPage(
          service: widget.service,
          currentUser: widget.currentUser,
        ),
      ),
    );
  }

  Future<void> _openProductSearchPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ProductSearchPage(
          service: widget.service,
          currentUser: widget.currentUser,
        ),
      ),
    );
  }

  Future<void> _openBranchDirectoryPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => BranchDirectoryPage(
          service: widget.service,
          currentUser: widget.currentUser,
        ),
      ),
    );
  }

  Future<void> _openTransferRequestPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => TransferRequestPage(
          service: widget.service,
          currentUser: widget.currentUser,
        ),
      ),
    );
  }

  Future<void> _openReservationRequestPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ReservationRequestPage(
          service: widget.service,
          currentUser: widget.currentUser,
        ),
      ),
    );
  }

  Future<void> _refreshDashboard({
    required bool isManual,
    bool forceRefresh = false,
  }) async {
    if (_isRefreshing) {
      return;
    }
    if (!forceRefresh &&
        !widget.service.shouldRefreshData(
          type: InventoryRefreshDataType.dashboard,
          scope: _dashboardRefreshScope,
        )) {
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
        widget.service
            .watchNotifications(actorUser: widget.currentUser)
            .first
            .then((_) {}),
      ]);

      if (!mounted) {
        return;
      }
      widget.service.markRefreshCompleted(
        type: InventoryRefreshDataType.dashboard,
        scope: _dashboardRefreshScope,
      );
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

  @override
  Future<void> onAutoRefresh(AutoRefreshReason reason, {required bool force}) {
    return _refreshDashboard(isManual: false, forceRefresh: force);
  }

  Future<void> _runDrawerAction(Future<void> Function() action) async {
    Navigator.of(context).pop();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) {
      return;
    }
    await action();
  }

  Future<void> _openApprovalRequestsPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ApprovalRequestsPage(
          service: widget.service,
          currentUser: widget.currentUser,
        ),
      ),
    );
  }

  Future<void> _openNotificationsPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => NotificationInboxPage(
          service: widget.service,
          currentUser: widget.currentUser,
        ),
      ),
    );
  }

  Future<void> _openRequestTrackingPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => RequestTrackingPage(
          service: widget.service,
          currentUser: widget.currentUser,
        ),
      ),
    );
  }

  Future<void> _openSyncStatusPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SyncStatusPage(
          service: widget.service,
          currentUser: widget.currentUser,
        ),
      ),
    );
  }

  List<_BranchDashboardSection> _branchSectionsFor(UserRole role) {
    return switch (role) {
      UserRole.seller => const <_BranchDashboardSection>[
        _BranchDashboardSection.overview,
        _BranchDashboardSection.inventory,
        _BranchDashboardSection.workflow,
        _BranchDashboardSection.modules,
      ],
      UserRole.supervisor => const <_BranchDashboardSection>[
        _BranchDashboardSection.overview,
        _BranchDashboardSection.metrics,
        _BranchDashboardSection.inventory,
        _BranchDashboardSection.workflow,
        _BranchDashboardSection.modules,
      ],
      UserRole.admin => const <_BranchDashboardSection>[],
    };
  }

  String _branchSectionLabel(UserRole role, _BranchDashboardSection section) {
    return switch (section) {
      _BranchDashboardSection.overview => 'Resumen',
      _BranchDashboardSection.inventory => 'Inventario y alertas',
      _BranchDashboardSection.workflow =>
        role == UserRole.seller
            ? 'Compromisos y sincronizacion'
            : 'Solicitudes y sincronizacion',
      _BranchDashboardSection.metrics => 'KPIs operativos',
      _BranchDashboardSection.modules => 'Modulos habilitados',
    };
  }

  IconData _branchSectionIcon(_BranchDashboardSection section) {
    return switch (section) {
      _BranchDashboardSection.overview => Icons.space_dashboard_rounded,
      _BranchDashboardSection.inventory => Icons.inventory_2_rounded,
      _BranchDashboardSection.workflow => Icons.sync_alt_rounded,
      _BranchDashboardSection.metrics => Icons.insights_rounded,
      _BranchDashboardSection.modules => Icons.widgets_rounded,
    };
  }

  void _ensureValidBranchSection(UserRole role) {
    final availableSections = _branchSectionsFor(role);
    if (!availableSections.contains(_selectedBranchSection) &&
        availableSections.isNotEmpty) {
      _selectedBranchSection = availableSections.first;
    }
  }

  Future<void> _selectBranchSection(_BranchDashboardSection section) async {
    Navigator.of(context).pop();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedBranchSection = section;
    });
  }

  List<Widget> _buildBranchSectionShell(AppUser user, String title) {
    return [
      const SizedBox(height: 12),
      _AdminRoleBar(user: user),
      const SizedBox(height: 20),
      Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
    ];
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
        onPressed: _openSyncStatusPage,
      ),
      const SizedBox(height: 18),
      const _AdminSectionHeader(title: 'Metricas', actionLabel: 'Ver todas'),
      const SizedBox(height: 12),
      _AdminMetricsStrip(service: widget.service),
      const SizedBox(height: 18),
      _NotificationsOverviewPanel(
        service: widget.service,
        currentUser: user,
        onOpen: _openNotificationsPage,
      ),
      const SizedBox(height: 18),
      _SyncStatusOverviewPanel(
        service: widget.service,
        currentUser: user,
        onOpen: _openSyncStatusPage,
      ),
      const SizedBox(height: 18),
      _WorkflowActionCard(
        title: 'Bandeja de aprobaciones',
        subtitle:
            'Consolida reservas y traslados pendientes para decidir rapido desde un solo lugar.',
        buttonLabel: 'Abrir bandeja',
        icon: Icons.fact_check_rounded,
        accent: AppPalette.amber,
        onPressed: _openApprovalRequestsPage,
      ),
      const SizedBox(height: 18),
      _OperationalMetricsSection(
        service: widget.service,
        user: user,
        title: 'KPIs de supervision',
      ),
      const SizedBox(height: 18),
      _AdminPendingSection(service: widget.service, branchId: user.branchId),
      const SizedBox(height: 18),
      _AdminAuditSection(
        service: widget.service,
        currentUser: widget.currentUser,
      ),
      const SizedBox(height: 12),
      _AdminRefreshCard(
        service: widget.service,
        onPressed: _isRefreshing
            ? null
            : () => _refreshDashboard(isManual: true),
      ),
    ];
  }

  List<Widget> _buildBranchOverviewSections(AppUser user) {
    final title = switch (user.role) {
      UserRole.seller => 'Panel de ventas',
      UserRole.supervisor => 'Control de sucursal',
      UserRole.admin => 'Dashboard',
    };
    final summaryTitle = switch (user.role) {
      UserRole.seller => 'Resumen comercial',
      UserRole.supervisor => 'Resumen operativo',
      UserRole.admin => 'Resumen',
    };

    return [
      ..._buildBranchSectionShell(user, title),
      const SizedBox(height: 18),
      _BranchOperationalHero(
        service: widget.service,
        branchId: user.branchId,
        role: user.role,
        onPressed: _openSyncStatusPage,
      ),
      const SizedBox(height: 18),
      _AdminSectionHeader(title: summaryTitle),
      const SizedBox(height: 12),
      _BranchMetricsStrip(
        service: widget.service,
        branchId: user.branchId,
        role: user.role,
      ),
      const SizedBox(height: 18),
      _NotificationsOverviewPanel(
        service: widget.service,
        currentUser: user,
        onOpen: _openNotificationsPage,
      ),
      const SizedBox(height: 18),
      _RequestTrackingOverviewPanel(
        service: widget.service,
        currentUser: user,
        onOpen: _openRequestTrackingPage,
      ),
      const SizedBox(height: 18),
      _SyncStatusOverviewPanel(
        service: widget.service,
        currentUser: user,
        onOpen: _openSyncStatusPage,
      ),
      if (user.role == UserRole.seller) ...[
        const SizedBox(height: 18),
        const _AdminSectionHeader(title: 'Prioridades inmediatas'),
        const SizedBox(height: 12),
        _DashboardGrid(
          children: [
            _LowStockPanel(
              service: widget.service,
              branchId: user.branchId,
              title: 'Stock bajo prioritario',
              subtitle:
                  'Productos con cobertura reducida que pueden afectar ventas hoy.',
            ),
            _OutOfStockPanel(
              service: widget.service,
              branchId: user.branchId,
              title: 'Quiebres de mostrador',
              subtitle:
                  'Productos agotados que requieren alternativa o seguimiento inmediato.',
            ),
            _PendingRequestsPanel(
              service: widget.service,
              branchId: user.branchId,
              title: 'Compromisos activos',
              subtitle:
                  'Reservas activas y traslados pendientes vinculados a la atencion comercial.',
            ),
          ],
        ),
      ],
      const SizedBox(height: 18),
      _AdminRefreshCard(
        service: widget.service,
        branchId: user.branchId,
        onPressed: _isRefreshing
            ? null
            : () => _refreshDashboard(isManual: true),
      ),
    ];
  }

  List<Widget> _buildBranchInventorySections(AppUser user) {
    final topConsultedSubtitle = user.role == UserRole.seller
        ? 'Referencias con mayor actividad comercial reciente en tu sucursal.'
        : 'Priorizacion operativa basada en actividad y movimiento reciente.';
    final outOfStockSubtitle = user.role == UserRole.seller
        ? 'Quiebres que pueden afectar la atencion de clientes en mostrador.'
        : 'Quiebres detectados que afectan la atencion o los traslados internos.';

    return [
      ..._buildBranchSectionShell(user, 'Inventario y alertas'),
      const SizedBox(height: 18),
      _DashboardGrid(
        children: [
          _TopConsultedPanel(
            service: widget.service,
            branchId: user.branchId,
            title: 'Productos mas consultados',
            subtitle: topConsultedSubtitle,
          ),
          _OutOfStockPanel(
            service: widget.service,
            branchId: user.branchId,
            title: 'Productos sin stock',
            subtitle: outOfStockSubtitle,
          ),
          _LowStockPanel(
            service: widget.service,
            branchId: user.branchId,
            title: 'Alertas de inventario bajo',
            subtitle:
                'Productos con disponibilidad reducida que requieren reposicion o ajuste.',
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildBranchWorkflowSections(AppUser user) {
    final title = user.role == UserRole.seller
        ? 'Compromisos y sincronizacion'
        : 'Solicitudes y sincronizacion';
    final pendingTitle = user.role == UserRole.seller
        ? 'Compromisos activos'
        : 'Solicitudes pendientes';
    final pendingSubtitle = user.role == UserRole.seller
        ? 'Reservas activas y traslados pendientes vinculados a tus ventas.'
        : 'Reservas activas y traslados que requieren seguimiento de la sucursal.';
    final syncSubtitle = user.role == UserRole.seller
        ? 'Eventos recientes para validar que la informacion local este al dia.'
        : 'Trazabilidad reciente de sincronizacion para validar continuidad operativa.';

    return [
      ..._buildBranchSectionShell(user, title),
      const SizedBox(height: 18),
      _DashboardGrid(
        children: [
          if (user.can(AppPermission.approveTransfer) ||
              user.can(AppPermission.approveReservation))
            _WorkflowActionCard(
              title: 'Bandeja de aprobaciones',
              subtitle:
                  'Revisa reservas y traslados pendientes que afectan el stock de tu sucursal.',
              buttonLabel: 'Abrir bandeja',
              icon: Icons.fact_check_rounded,
              accent: AppPalette.amber,
              onPressed: _openApprovalRequestsPage,
            ),
          _WorkflowActionCard(
            title: 'Estado de solicitudes',
            subtitle:
                'Consulta filtros, historial y cambios de estado para reservas y traslados.',
            buttonLabel: 'Ver seguimiento',
            icon: Icons.track_changes_rounded,
            accent: AppPalette.cyan,
            onPressed: _openRequestTrackingPage,
          ),
          _WorkflowActionCard(
            title: 'Estado de sincronizacion',
            subtitle:
                'Revisa la salud de la API y la ultima sincronizacion de cada sucursal.',
            buttonLabel: 'Ver estado',
            icon: Icons.cloud_done_rounded,
            accent: AppPalette.mint,
            onPressed: _openSyncStatusPage,
          ),
          _WorkflowActionCard(
            title: 'Reservar producto',
            subtitle:
                'Asegura unidades en otra sucursal para sostener una venta confirmada.',
            buttonLabel: 'Nueva reserva',
            icon: Icons.bookmark_add_rounded,
            accent: AppPalette.blueSoft,
            onPressed: _openReservationRequestPage,
          ),
          _WorkflowActionCard(
            title: 'Solicitar traslado',
            subtitle:
                'Crea una solicitud hacia tu sucursal cuando otra sede tenga disponibilidad.',
            buttonLabel: 'Nuevo traslado',
            icon: Icons.local_shipping_rounded,
            accent: AppPalette.amber,
            onPressed: _openTransferRequestPage,
          ),
        ],
      ),
      const SizedBox(height: 18),
      _DashboardGrid(
        children: [
          _PendingRequestsPanel(
            service: widget.service,
            branchId: user.branchId,
            title: pendingTitle,
            subtitle: pendingSubtitle,
          ),
          _LatestSyncsPanel(
            service: widget.service,
            branchId: user.branchId,
            title: 'Ultimas sincronizaciones',
            subtitle: syncSubtitle,
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
    ];
  }

  List<Widget> _buildBranchMetricsSections(AppUser user) {
    return [
      ..._buildBranchSectionShell(user, 'KPIs operativos'),
      const SizedBox(height: 18),
      _OperationalMetricsSection(
        service: widget.service,
        user: user,
        title: 'Indicadores de sucursal',
      ),
      const SizedBox(height: 18),
      _AdminRefreshCard(
        service: widget.service,
        branchId: user.branchId,
        onPressed: _isRefreshing
            ? null
            : () => _refreshDashboard(isManual: true),
      ),
    ];
  }

  List<Widget> _buildBranchModulesSections(AppUser user) {
    return [
      ..._buildBranchSectionShell(user, 'Modulos habilitados'),
      const SizedBox(height: 18),
      _ModulePanel(modules: user.visibleModules),
    ];
  }

  List<Widget> _buildBranchSectionContent(AppUser user) {
    return switch (_selectedBranchSection) {
      _BranchDashboardSection.overview => _buildBranchOverviewSections(user),
      _BranchDashboardSection.inventory => _buildBranchInventorySections(user),
      _BranchDashboardSection.workflow => _buildBranchWorkflowSections(user),
      _BranchDashboardSection.metrics => _buildBranchMetricsSections(user),
      _BranchDashboardSection.modules => _buildBranchModulesSections(user),
    };
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
              icon: Icons.search_rounded,
              onPressed: _openProductSearchPage,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _NotificationInboxButton(
              service: widget.service,
              currentUser: user,
              onPressed: () => unawaited(_openNotificationsPage()),
            ),
          ),
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
            child: _ApprovalInboxButton(
              service: widget.service,
              currentUser: user,
              onPressed: () => unawaited(_openApprovalRequestsPage()),
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
        onOpenNotifications: () => _runDrawerAction(_openNotificationsPage),
        onOpenSyncStatus: () => _runDrawerAction(_openSyncStatusPage),
        onOpenApprovals: () => _runDrawerAction(_openApprovalRequestsPage),
        onOpenTraceability: () => _runDrawerAction(_openAdminTraceabilityPage),
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

  Widget _buildBranchScaffold(AppUser user) {
    final availableSections = _branchSectionsFor(user.role);
    final selectedLabel = _branchSectionLabel(
      user.role,
      _selectedBranchSection,
    );
    final content = _buildBranchSectionContent(user);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        titleSpacing: 0,
        title: Text(selectedLabel),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _ToolbarButton(
              icon: Icons.search_rounded,
              onPressed: _openProductSearchPage,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _NotificationInboxButton(
              service: widget.service,
              currentUser: user,
              onPressed: () => unawaited(_openNotificationsPage()),
            ),
          ),
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
          if (user.can(AppPermission.approveTransfer) ||
              user.can(AppPermission.approveReservation))
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _ApprovalInboxButton(
                service: widget.service,
                currentUser: user,
                onPressed: () => unawaited(_openApprovalRequestsPage()),
              ),
            ),
        ],
      ),
      drawer: _BranchDrawer(
        user: user,
        sections: availableSections,
        selectedSection: _selectedBranchSection,
        sectionLabelBuilder: (section) =>
            _branchSectionLabel(user.role, section),
        sectionIconBuilder: _branchSectionIcon,
        onSelectSection: _selectBranchSection,
        onOpenBranches: () => _runDrawerAction(_openBranchDirectoryPage),
        onOpenNotifications: () => _runDrawerAction(_openNotificationsPage),
        onOpenSyncStatus: () => _runDrawerAction(_openSyncStatusPage),
        onOpenRequestTracking: () => _runDrawerAction(_openRequestTrackingPage),
        onOpenApprovalRequests:
            user.can(AppPermission.approveTransfer) ||
                user.can(AppPermission.approveReservation)
            ? () => _runDrawerAction(_openApprovalRequestsPage)
            : null,
        onOpenReservationRequests: () =>
            _runDrawerAction(_openReservationRequestPage),
        onOpenTransferRequests: () =>
            _runDrawerAction(_openTransferRequestPage),
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

    _ensureValidBranchSection(user.role);
    return _buildBranchScaffold(user);
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
                                  child: const Text('Ver sincronizacion'),
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

class _OperationalMetricsSection extends StatefulWidget {
  const _OperationalMetricsSection({
    required this.service,
    required this.user,
    required this.title,
  });

  final InventoryWorkflowService service;
  final AppUser user;
  final String title;

  @override
  State<_OperationalMetricsSection> createState() =>
      _OperationalMetricsSectionState();
}

class _OperationalMetricsSectionState
    extends State<_OperationalMetricsSection> {
  Stream<BranchOperationalStats>? _statsStream;

  @override
  void initState() {
    super.initState();
    _syncStream();
  }

  @override
  void didUpdateWidget(covariant _OperationalMetricsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service ||
        oldWidget.user.id != widget.user.id ||
        oldWidget.user.branchId != widget.user.branchId ||
        oldWidget.user.role != widget.user.role) {
      _syncStream();
    }
  }

  void _syncStream() {
    if (!widget.user.can(AppPermission.viewOperationalMetrics)) {
      _statsStream = null;
      return;
    }

    _statsStream = widget.service.watchOperationalStats(
      actorUser: widget.user,
      branchId: widget.user.branchId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final stream = _statsStream;
    if (stream == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<BranchOperationalStats>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _DashboardPanel(
            title: widget.title,
            subtitle: 'No fue posible cargar estas metricas por ahora.',
            accent: AppPalette.danger,
            child: Text(
              'Intenta actualizar nuevamente el dashboard.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
          );
        }

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
            _AdminSectionHeader(title: widget.title),
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
            final pendingReservationApprovals = reservations
                .where((item) => item.status == ReservationStatus.pending)
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
                      title: 'Aprobaciones\npendientes',
                      value:
                          '${pendingReservationApprovals + pendingTransfers}',
                      helper:
                          '$pendingReservationApprovals reservas y $pendingTransfers traslados',
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
            final pendingReservationApprovals = reservations
                .where((item) => item.status == ReservationStatus.pending)
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
                        icon: Icons.fact_check_rounded,
                        title: 'Aprobaciones\npendientes',
                        value:
                            '${pendingReservationApprovals + pendingTransfers}',
                        helper:
                            '$pendingReservationApprovals reservas y $pendingTransfers traslados',
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

class _NotificationsOverviewPanel extends StatelessWidget {
  const _NotificationsOverviewPanel({
    required this.service,
    required this.currentUser,
    required this.onOpen,
  });

  final InventoryWorkflowService service;
  final AppUser currentUser;
  final Future<void> Function() onOpen;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppNotification>>(
      stream: service.watchNotifications(actorUser: currentUser, limit: 3),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _DashboardPanel(
            title: 'Notificaciones',
            subtitle:
                'Eventos personales asociados a reservas y traslados recientes.',
            accent: AppPalette.danger,
            child: Text(
              'No fue posible cargar la bandeja personal.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
          );
        }

        final notifications = snapshot.data ?? const <AppNotification>[];
        final unreadCount = notifications.where((item) => !item.isRead).length;
        final items = notifications
            .map((notification) {
              final visual = _resolveNotificationVisual(notification);
              final statusLabel = notification.isRead ? 'Leida' : 'Sin leer';
              return _InsightItem(
                icon: visual.icon,
                iconColor: visual.color,
                title: notification.title,
                detail: notification.message,
                meta:
                    '${_formatNotificationType(notification.type)} | $statusLabel | ${_formatRelativeTime(notification.createdAt)}',
              );
            })
            .toList(growable: false);

        return _DashboardPanel(
          title: 'Notificaciones',
          subtitle:
              'Resultado de aprobaciones, rechazos y eventos que te afectan directamente.',
          accent: unreadCount > 0 ? AppPalette.amber : AppPalette.blueSoft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                unreadCount == 0
                    ? 'No tienes eventos pendientes por revisar.'
                    : unreadCount == 1
                    ? 'Tienes 1 notificacion sin leer.'
                    : 'Tienes $unreadCount notificaciones sin leer.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              _InsightList(
                items: items,
                emptyMessage:
                    'Cuando una solicitud cambie de estado, aparecera aqui.',
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => unawaited(onOpen()),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Abrir bandeja'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RequestTrackingOverviewPanel extends StatelessWidget {
  const _RequestTrackingOverviewPanel({
    required this.service,
    required this.currentUser,
    required this.onOpen,
  });

  final InventoryWorkflowService service;
  final AppUser currentUser;
  final Future<void> Function() onOpen;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RequestTrackingItem>>(
      stream: service.watchRequestTracking(actorUser: currentUser),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _DashboardPanel(
            title: 'Estado de solicitudes',
            subtitle:
                'Seguimiento de reservas y traslados con historial reciente.',
            accent: AppPalette.danger,
            child: Text(
              'No fue posible cargar el seguimiento de solicitudes.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
          );
        }

        final items = snapshot.data ?? const <RequestTrackingItem>[];
        final openCount = items
            .where(
              (item) =>
                  item.status == RequestTrackingStatus.pending ||
                  item.status == RequestTrackingStatus.approved ||
                  item.status == RequestTrackingStatus.inTransit,
            )
            .length;
        final recentItems = items
            .take(3)
            .map(
              (item) => _InsightItem(
                icon: _trackingRequestOverviewIcon(item),
                iconColor: _trackingRequestOverviewColor(item.status),
                title: '${item.typeLabel} | ${item.productName}',
                detail: item.type == RequestTrackingType.transfer
                    ? '${item.primaryBranchName} -> ${item.secondaryBranchName} | ${item.quantity} unidad(es)'
                    : '${item.primaryBranchName} | ${item.customerLabel}',
                meta:
                    '${item.statusLabel} | ultimo cambio ${_formatRelativeTime(item.lastStatusAt)}',
              ),
            )
            .toList(growable: false);

        return _DashboardPanel(
          title: 'Estado de solicitudes',
          subtitle:
              'Consulta rapida del estado actual y del ultimo movimiento de tus solicitudes.',
          accent: openCount > 0 ? AppPalette.cyan : AppPalette.blueSoft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                openCount == 0
                    ? 'No tienes solicitudes activas en este momento.'
                    : openCount == 1
                    ? 'Tienes 1 solicitud abierta para seguimiento.'
                    : 'Tienes $openCount solicitudes abiertas para seguimiento.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              _InsightList(
                items: recentItems,
                emptyMessage:
                    'Cuando registres reservas o traslados, apareceran aqui.',
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => unawaited(onOpen()),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Ver seguimiento'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SyncStatusOverviewPanel extends StatelessWidget {
  const _SyncStatusOverviewPanel({
    required this.service,
    required this.currentUser,
    required this.onOpen,
  });

  final InventoryWorkflowService service;
  final AppUser currentUser;
  final Future<void> Function() onOpen;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SyncStatusOverview>(
      stream: service.watchSyncStatus(actorUser: currentUser),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _DashboardPanel(
            title: 'Estado de sincronizacion',
            subtitle:
                'Salud de la API y de las sucursales para validar si el dato sigue confiable.',
            accent: AppPalette.danger,
            child: Text(
              'No fue posible cargar el estado de sincronizacion.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
          );
        }

        final data = snapshot.data;
        if (data == null) {
          return _DashboardPanel(
            title: 'Estado de sincronizacion',
            subtitle:
                'Salud de la API y de las sucursales para validar si el dato sigue confiable.',
            accent: AppPalette.cyan,
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final accent = switch (data.apiStatus.severity) {
          SyncStatusSeverity.healthy => AppPalette.mint,
          SyncStatusSeverity.warning => AppPalette.amber,
          SyncStatusSeverity.critical => AppPalette.danger,
          SyncStatusSeverity.unknown => AppPalette.blueSoft,
        };
        final highlightedBranches = [
          ...data.criticalBranches,
          ...data.warningBranches.where(
            (item) => !data.criticalBranches.any(
              (critical) => critical.branch.id == item.branch.id,
            ),
          ),
        ].take(3);
        final items = highlightedBranches
            .map(
              (item) => _InsightItem(
                icon: item.isCritical
                    ? Icons.cloud_off_rounded
                    : Icons.cloud_sync_rounded,
                iconColor: item.isCritical
                    ? AppPalette.danger
                    : AppPalette.amber,
                title: '${item.branch.name} | ${item.summary}',
                detail: item.detail,
                meta: 'Ultima: ${_formatRelativeTime(item.lastSyncAt)}',
              ),
            )
            .toList(growable: false);

        return _DashboardPanel(
          title: 'Estado de sincronizacion',
          subtitle:
              'Visibilidad rapida para saber si puedes confiar en el dato antes de actuar.',
          accent: accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'API: ${data.apiStatus.summary} | Al dia: ${data.healthyBranches.length}/${data.branches.length} | Alertas: ${data.warningBranches.length + data.criticalBranches.length}',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              _InsightList(
                items: items,
                emptyMessage:
                    'No hay sucursales con retraso o fallos de sincronizacion.',
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => unawaited(onOpen()),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Ver estado'),
                ),
              ),
            ],
          ),
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
  const _AdminAuditSection({required this.service, required this.currentUser});

  final InventoryWorkflowService service;
  final AppUser currentUser;

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
            Text(
              'Toca un traslado para revisar trazabilidad completa, actores y estados internos.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white70),
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
                  child: _AdminAuditTile(
                    auditLog: item,
                    onTap: item.entityType == 'transfer'
                        ? () => _showTransferTraceabilityDialog(
                            context,
                            service: service,
                            currentUser: currentUser,
                            transferId: item.entityId,
                          )
                        : null,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AdminAuditTile extends StatelessWidget {
  const _AdminAuditTile({required this.auditLog, this.onTap});

  final AuditLog auditLog;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = _auditActionColor(auditLog.action);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
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
                child: Icon(
                  _auditActionIcon(auditLog.action),
                  color: Colors.white,
                ),
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
              if (onTap != null) ...[
                const SizedBox(width: 8),
                const Icon(Icons.visibility_rounded, color: Colors.white70),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

void _showTransferTraceabilityDialog(
  BuildContext context, {
  required InventoryWorkflowService service,
  required AppUser currentUser,
  required String transferId,
}) {
  showDialog<void>(
    context: context,
    builder: (context) => _TransferTraceabilityDialog(
      service: service,
      currentUser: currentUser,
      transferId: transferId,
    ),
  );
}

class _TransferTraceabilityDialog extends StatelessWidget {
  const _TransferTraceabilityDialog({
    required this.service,
    required this.currentUser,
    required this.transferId,
  });

  final InventoryWorkflowService service;
  final AppUser currentUser;
  final String transferId;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF08172D),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 760),
        child: FutureBuilder<TransferTraceabilityData>(
          future: service.fetchTransferTraceability(
            actorUser: currentUser,
            transferId: transferId,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'No se pudo cargar la trazabilidad del traslado.',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$transferId\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cerrar'),
                    ),
                  ],
                ),
              );
            }

            final detail = snapshot.requireData;
            final transfer = detail.transfer;
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Trazabilidad del traslado',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${transfer.productName} | ${transfer.id}',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _TraceabilityStatusChip(
                        label: _formatTransferStatusLabel(transfer.status),
                        color: _transferStatusColor(transfer.status),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _TraceabilityMetricCard(
                                label: 'Cantidad',
                                value: '${transfer.quantity}',
                                accent: AppPalette.amber,
                              ),
                              _TraceabilityMetricCard(
                                label: 'SKU',
                                value: transfer.sku,
                                accent: AppPalette.blueSoft,
                              ),
                              _TraceabilityMetricCard(
                                label: 'Solicitado',
                                value: _formatDateTimeStamp(
                                  transfer.requestedAt,
                                ),
                                accent: AppPalette.mint,
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          const _TraceabilitySectionTitle(
                            title: 'Ruta del movimiento',
                          ),
                          const SizedBox(height: 10),
                          _TraceabilityBlock(
                            child: Column(
                              children: [
                                _TraceabilityDataRow(
                                  label: 'Sucursal origen',
                                  value:
                                      '${transfer.fromBranchName} | ${transfer.fromBranchId}',
                                ),
                                _TraceabilityDataRow(
                                  label: 'Sucursal destino',
                                  value:
                                      '${transfer.toBranchName} | ${transfer.toBranchId}',
                                ),
                                _TraceabilityDataRow(
                                  label: 'Motivo',
                                  value: transfer.reason,
                                ),
                                _TraceabilityDataRow(
                                  label: 'Notas internas',
                                  value: transfer.notes.isEmpty
                                      ? 'Sin notas registradas'
                                      : transfer.notes,
                                ),
                                _TraceabilityDataRow(
                                  label: 'Ultima actualizacion',
                                  value: _formatDateTimeStamp(
                                    transfer.updatedAt,
                                  ),
                                  isLast: true,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          const _TraceabilitySectionTitle(
                            title: 'Actores clave',
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _TraceabilityActorCard(
                                title: 'Solicitante',
                                icon: Icons.assignment_ind_rounded,
                                name:
                                    detail.requestLog?.actorName ??
                                    detail.requesterUser?.fullName ??
                                    transfer.requestedBy,
                                role:
                                    detail.requestLog?.actorRole.displayName ??
                                    detail.requesterUser?.role.displayName ??
                                    'No disponible',
                                branch:
                                    detail.requestLog?.branchName ??
                                    detail.requesterUser?.branchId ??
                                    transfer.toBranchName,
                                timestamp:
                                    detail.requestLog?.createdAt ??
                                    transfer.requestedAt,
                              ),
                              _TraceabilityActorCard(
                                title: 'Aprobacion',
                                icon: Icons.verified_user_rounded,
                                name:
                                    detail.approvalLog?.actorName ??
                                    detail.approverUser?.fullName ??
                                    (transfer.approvedBy ?? 'Pendiente'),
                                role:
                                    detail.approvalLog?.actorRole.displayName ??
                                    detail.approverUser?.role.displayName ??
                                    (transfer.approvedBy == null
                                        ? 'Pendiente'
                                        : 'No disponible'),
                                branch:
                                    detail.approvalLog?.branchName ??
                                    detail.approverUser?.branchId ??
                                    transfer.fromBranchName,
                                timestamp:
                                    detail.approvalLog?.createdAt ??
                                    transfer.approvedAt,
                              ),
                              _TraceabilityActorCard(
                                title: 'Despacho',
                                icon: Icons.local_shipping_rounded,
                                name:
                                    detail.dispatchLog?.actorName ??
                                    'Pendiente',
                                role:
                                    detail.dispatchLog?.actorRole.displayName ??
                                    'Pendiente',
                                branch:
                                    detail.dispatchLog?.branchName ??
                                    transfer.fromBranchName,
                                timestamp:
                                    detail.dispatchLog?.createdAt ??
                                    transfer.shippedAt,
                              ),
                              _TraceabilityActorCard(
                                title: 'Recepcion',
                                icon: Icons.inventory_2_rounded,
                                name:
                                    detail.receiveLog?.actorName ?? 'Pendiente',
                                role:
                                    detail.receiveLog?.actorRole.displayName ??
                                    'Pendiente',
                                branch:
                                    detail.receiveLog?.branchName ??
                                    transfer.toBranchName,
                                timestamp:
                                    detail.receiveLog?.createdAt ??
                                    transfer.receivedAt,
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          const _TraceabilitySectionTitle(
                            title: 'Inventario vinculado',
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _InventoryTraceabilityCard(
                                title: 'Origen actual',
                                branchLabel: transfer.fromBranchName,
                                inventory: detail.sourceInventory,
                                accent: AppPalette.amber,
                              ),
                              _InventoryTraceabilityCard(
                                title: 'Destino actual',
                                branchLabel: transfer.toBranchName,
                                inventory: detail.destinationInventory,
                                accent: AppPalette.blueSoft,
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          const _TraceabilitySectionTitle(
                            title: 'Timeline auditado',
                          ),
                          const SizedBox(height: 10),
                          if (detail.auditTrail.isEmpty)
                            _TraceabilityBlock(
                              child: Text(
                                'No hay eventos auditados para este traslado. Puede venir de datos previos o de la base inicial.',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: Colors.white70),
                              ),
                            )
                          else
                            Column(
                              children: detail.auditTrail
                                  .map(
                                    (item) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: _TransferAuditTimelineTile(
                                        auditLog: item,
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AdminTraceabilityPage extends StatelessWidget {
  const _AdminTraceabilityPage({
    required this.service,
    required this.currentUser,
  });

  final InventoryWorkflowService service;
  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trazabilidad operativa')),
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
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Text(
                'Trazabilidad de traslados y solicitudes',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Consulta movimientos auditados, abre el detalle y revisa actores, roles, ramas, cantidades y estados internos.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 18),
              _DashboardGrid(
                children: [
                  _AdminTransferTraceabilityPanel(
                    service: service,
                    currentUser: currentUser,
                  ),
                  _AdminReservationTraceabilityPanel(
                    service: service,
                    currentUser: currentUser,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminTransferTraceabilityPanel extends StatelessWidget {
  const _AdminTransferTraceabilityPanel({
    required this.service,
    required this.currentUser,
  });

  final InventoryWorkflowService service;
  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TransferRequest>>(
      stream: service.transfers.watchTransfers(),
      builder: (context, snapshot) {
        final items = (snapshot.data ?? const <TransferRequest>[]).toList(
          growable: false,
        )..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));

        return _DashboardPanel(
          title: 'Traslados auditados',
          subtitle:
              'Listado operativo para revisar solicitudes, aprobaciones, despachos y recepciones.',
          accent: AppPalette.amber,
          child: _TraceabilityEntryList(
            emptyMessage: 'No hay traslados registrados para auditar.',
            children: items
                .take(12)
                .map(
                  (item) => _AdminTraceabilityEntryCard(
                    icon: Icons.swap_horiz_rounded,
                    accent: _transferStatusColor(item.status),
                    title:
                        '${_formatTransferStatusLabel(item.status)} | ${item.productName}',
                    detail:
                        '${item.fromBranchName} -> ${item.toBranchName} | ${item.quantity} unidad(es)',
                    meta:
                        'Solicitado ${_formatDateTimeStamp(item.requestedAt)} | actualizado ${_formatRelativeTime(item.updatedAt)}',
                    onTap: () => _showTransferTraceabilityDialog(
                      context,
                      service: service,
                      currentUser: currentUser,
                      transferId: item.id,
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        );
      },
    );
  }
}

class _AdminReservationTraceabilityPanel extends StatelessWidget {
  const _AdminReservationTraceabilityPanel({
    required this.service,
    required this.currentUser,
  });

  final InventoryWorkflowService service;
  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Reservation>>(
      stream: service.reservations.watchReservations(),
      builder: (context, snapshot) {
        final items = (snapshot.data ?? const <Reservation>[]).toList(
          growable: false,
        )..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));

        return _DashboardPanel(
          title: 'Solicitudes auditadas',
          subtitle:
              'Reservas activas y cerradas con detalle de cliente, responsable y evolucion del estado.',
          accent: AppPalette.blueSoft,
          child: _TraceabilityEntryList(
            emptyMessage: 'No hay solicitudes registradas para auditar.',
            children: items
                .take(12)
                .map(
                  (item) => _AdminTraceabilityEntryCard(
                    icon: Icons.bookmark_added_rounded,
                    accent: _reservationStatusColor(item.status),
                    title:
                        '${_formatReservationStatusLabel(item.status)} | ${item.productName}',
                    detail:
                        '${item.branchName} | ${item.customerName} | ${item.quantity} unidad(es)',
                    meta:
                        'Creada ${_formatDateTimeStamp(item.createdAt)} | vence ${_formatDateTimeStamp(item.expiresAt)}',
                    onTap: () => _showReservationTraceabilityDialog(
                      context,
                      service: service,
                      currentUser: currentUser,
                      reservationId: item.id,
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        );
      },
    );
  }
}

class _TraceabilityEntryList extends StatelessWidget {
  const _TraceabilityEntryList({
    required this.children,
    required this.emptyMessage,
  });

  final List<Widget> children;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return _TraceabilityBlock(
        child: Text(
          emptyMessage,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
        ),
      );
    }

    return Column(
      children: children
          .map(
            (child) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: child,
            ),
          )
          .toList(growable: false),
    );
  }
}

class _AdminTraceabilityEntryCard extends StatelessWidget {
  const _AdminTraceabilityEntryCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.detail,
    required this.meta,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String detail;
  final String meta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0x40132647),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.28)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(detail, style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 4),
                    Text(
                      meta,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppPalette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}

void _showReservationTraceabilityDialog(
  BuildContext context, {
  required InventoryWorkflowService service,
  required AppUser currentUser,
  required String reservationId,
}) {
  showDialog<void>(
    context: context,
    builder: (context) => _ReservationTraceabilityDialog(
      service: service,
      currentUser: currentUser,
      reservationId: reservationId,
    ),
  );
}

class _ReservationTraceabilityDialog extends StatelessWidget {
  const _ReservationTraceabilityDialog({
    required this.service,
    required this.currentUser,
    required this.reservationId,
  });

  final InventoryWorkflowService service;
  final AppUser currentUser;
  final String reservationId;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF08172D),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 760),
        child: FutureBuilder<ReservationTraceabilityData>(
          future: service.fetchReservationTraceability(
            actorUser: currentUser,
            reservationId: reservationId,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'No se pudo cargar la trazabilidad de la solicitud.',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$reservationId\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cerrar'),
                    ),
                  ],
                ),
              );
            }

            final detail = snapshot.requireData;
            final reservation = detail.reservation;
            final latestLog = detail.latestStatusLog;

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Trazabilidad de la solicitud',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${reservation.productName} | ${reservation.id}',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _TraceabilityStatusChip(
                        label: _formatReservationStatusLabel(
                          reservation.status,
                        ),
                        color: _reservationStatusColor(reservation.status),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _TraceabilityMetricCard(
                                label: 'Cantidad',
                                value: '${reservation.quantity}',
                                accent: AppPalette.blueSoft,
                              ),
                              _TraceabilityMetricCard(
                                label: 'SKU',
                                value: reservation.sku,
                                accent: AppPalette.amber,
                              ),
                              _TraceabilityMetricCard(
                                label: 'Vigencia',
                                value: _formatDateTimeStamp(
                                  reservation.expiresAt,
                                ),
                                accent: AppPalette.mint,
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          const _TraceabilitySectionTitle(
                            title: 'Solicitud comercial',
                          ),
                          const SizedBox(height: 10),
                          _TraceabilityBlock(
                            child: Column(
                              children: [
                                _TraceabilityDataRow(
                                  label: 'Sucursal reservada',
                                  value:
                                      '${reservation.branchName} | ${reservation.branchId}',
                                ),
                                _TraceabilityDataRow(
                                  label: 'Cliente',
                                  value: reservation.customerName,
                                ),
                                _TraceabilityDataRow(
                                  label: 'Telefono',
                                  value: reservation.customerPhone.isEmpty
                                      ? 'Sin telefono'
                                      : reservation.customerPhone,
                                ),
                                _TraceabilityDataRow(
                                  label: 'Creada',
                                  value: _formatDateTimeStamp(
                                    reservation.createdAt,
                                  ),
                                ),
                                _TraceabilityDataRow(
                                  label: 'Ultima actualizacion',
                                  value: _formatDateTimeStamp(
                                    reservation.updatedAt,
                                  ),
                                  isLast: true,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          const _TraceabilitySectionTitle(
                            title: 'Actores y seguimiento',
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _TraceabilityActorCard(
                                title: 'Solicitante',
                                icon: Icons.assignment_ind_rounded,
                                name:
                                    detail.requestLog?.actorName ??
                                    detail.requesterUser?.fullName ??
                                    reservation.reservedBy,
                                role:
                                    detail.requestLog?.actorRole.displayName ??
                                    detail.requesterUser?.role.displayName ??
                                    'No disponible',
                                branch:
                                    detail
                                        .requestLog
                                        ?.metadata['requestingBranchName'] ??
                                    detail.requesterUser?.branchId ??
                                    reservation.branchName,
                                timestamp:
                                    detail.requestLog?.createdAt ??
                                    reservation.createdAt,
                              ),
                              _TraceabilityActorCard(
                                title: 'Ultima gestion',
                                icon: Icons.manage_history_rounded,
                                name: latestLog?.actorName ?? 'Sin cambios',
                                role:
                                    latestLog?.actorRole.displayName ??
                                    'Sin cambios',
                                branch:
                                    latestLog?.branchName ??
                                    reservation.branchName,
                                timestamp:
                                    latestLog?.createdAt ??
                                    reservation.updatedAt,
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          const _TraceabilitySectionTitle(
                            title: 'Inventario vinculado',
                          ),
                          const SizedBox(height: 10),
                          _InventoryTraceabilityCard(
                            title: 'Sucursal reservada',
                            branchLabel: reservation.branchName,
                            inventory: detail.branchInventory,
                            accent: AppPalette.blueSoft,
                          ),
                          const SizedBox(height: 18),
                          const _TraceabilitySectionTitle(
                            title: 'Timeline auditado',
                          ),
                          const SizedBox(height: 10),
                          if (detail.auditTrail.isEmpty)
                            _TraceabilityBlock(
                              child: Text(
                                'No hay eventos auditados para esta solicitud. Puede venir de datos previos o de la base inicial.',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: Colors.white70),
                              ),
                            )
                          else
                            Column(
                              children: detail.auditTrail
                                  .map(
                                    (item) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: _TransferAuditTimelineTile(
                                        auditLog: item,
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TraceabilitySectionTitle extends StatelessWidget {
  const _TraceabilitySectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _TraceabilityBlock extends StatelessWidget {
  const _TraceabilityBlock({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF102540),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x26FFFFFF)),
      ),
      child: child,
    );
  }
}

class _TraceabilityMetricCard extends StatelessWidget {
  const _TraceabilityMetricCard({
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
      width: 180,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF102540),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 8),
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

class _TraceabilityStatusChip extends StatelessWidget {
  const _TraceabilityStatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TraceabilityDataRow extends StatelessWidget {
  const _TraceabilityDataRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _TraceabilityActorCard extends StatelessWidget {
  const _TraceabilityActorCard({
    required this.title,
    required this.icon,
    required this.name,
    required this.role,
    required this.branch,
    required this.timestamp,
  });

  final String title;
  final IconData icon;
  final String name;
  final String role;
  final String branch;
  final DateTime? timestamp;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF102540),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x26FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white70),
          const SizedBox(height: 10),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(name, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            '$role | $branch',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Text(
            timestamp == null
                ? 'Sin fecha registrada'
                : _formatDateTimeStamp(timestamp!),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white60),
          ),
        ],
      ),
    );
  }
}

class _InventoryTraceabilityCard extends StatelessWidget {
  const _InventoryTraceabilityCard({
    required this.title,
    required this.branchLabel,
    required this.inventory,
    required this.accent,
  });

  final String title;
  final String branchLabel;
  final InventoryItem? inventory;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF102540),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            branchLabel,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          if (inventory == null)
            Text(
              'No hay inventario disponible para inspeccionar.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
            )
          else ...[
            _TraceabilityDataRow(label: 'Fisico', value: '${inventory!.stock}'),
            _TraceabilityDataRow(
              label: 'Reservado',
              value: '${inventory!.reservedStock}',
            ),
            _TraceabilityDataRow(
              label: 'Disponible',
              value: '${inventory!.availableStock}',
            ),
            _TraceabilityDataRow(
              label: 'En transito',
              value: '${inventory!.incomingStock}',
            ),
            _TraceabilityDataRow(
              label: 'Actualizado',
              value: _formatDateTimeStamp(inventory!.updatedAt),
              isLast: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _TransferAuditTimelineTile extends StatelessWidget {
  const _TransferAuditTimelineTile({required this.auditLog});

  final AuditLog auditLog;

  @override
  Widget build(BuildContext context) {
    final metadataEntries = auditLog.metadata.entries
        .where(
          (entry) =>
              entry.key != 'productId' &&
              entry.key != 'sku' &&
              entry.key != 'status',
        )
        .toList(growable: false);

    return _TraceabilityBlock(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _auditActionColor(auditLog.action).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _auditActionIcon(auditLog.action),
              color: _auditActionColor(auditLog.action),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatAuditAction(auditLog.action),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${auditLog.actorName} | ${auditLog.actorRole.displayName} | ${auditLog.branchName ?? 'Sin sucursal'}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDateTimeStamp(auditLog.createdAt),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white60),
                ),
                if (metadataEntries.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: metadataEntries
                        .map(
                          (entry) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0x26FFFFFF),
                              ),
                            ),
                            child: Text(
                              '${_formatAuditMetadataLabel(entry.key)}: ${entry.value}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
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

class _WorkflowActionCard extends StatelessWidget {
  const _WorkflowActionCard({
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.icon,
    required this.accent,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final String buttonLabel;
  final IconData icon;
  final Color accent;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF102540),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x26FFFFFF)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: () => unawaited(onPressed()),
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}

class _NotificationInboxButton extends StatelessWidget {
  const _NotificationInboxButton({
    required this.service,
    required this.currentUser,
    required this.onPressed,
  });

  final InventoryWorkflowService service;
  final AppUser currentUser;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppNotification>>(
      stream: service.watchNotifications(actorUser: currentUser, limit: 40),
      builder: (context, snapshot) {
        final unreadCount = (snapshot.data ?? const <AppNotification>[])
            .where((item) => !item.isRead)
            .length;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            _ToolbarButton(
              icon: Icons.notifications_none_rounded,
              onPressed: onPressed,
            ),
            if (unreadCount > 0)
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
                    '${unreadCount > 9 ? '9+' : unreadCount}',
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
  }
}

class _ApprovalInboxButton extends StatelessWidget {
  const _ApprovalInboxButton({
    required this.service,
    required this.currentUser,
    required this.onPressed,
  });

  final InventoryWorkflowService service;
  final AppUser currentUser;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ApprovalQueueData>(
      stream: service.watchApprovalQueue(actorUser: currentUser),
      builder: (context, reservationSnapshot) {
        final count = reservationSnapshot.data?.totalPending ?? 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            _ToolbarButton(
              icon: Icons.fact_check_rounded,
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
    required this.onOpenNotifications,
    required this.onOpenSyncStatus,
    required this.onOpenApprovals,
    required this.onOpenTraceability,
    required this.onSignOut,
  });

  final AppUser user;
  final bool isCreating;
  final bool isCreatingBranch;
  final VoidCallback? onCreateBaseData;
  final VoidCallback? onCreateBranch;
  final VoidCallback? onManageEmployees;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onOpenSyncStatus;
  final VoidCallback? onOpenApprovals;
  final VoidCallback? onOpenTraceability;
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
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AdminDrawerTile(
                        icon: Icons.person_add_alt_1_rounded,
                        title: 'Gestion de empleados',
                        onTap: onManageEmployees,
                      ),
                      const SizedBox(height: 10),
                      _AdminDrawerTile(
                        icon: Icons.notifications_none_rounded,
                        title: 'Notificaciones',
                        onTap: onOpenNotifications,
                      ),
                      const SizedBox(height: 10),
                      _AdminDrawerTile(
                        icon: Icons.cloud_done_rounded,
                        title: 'Estado de sincronizacion',
                        onTap: onOpenSyncStatus,
                      ),
                      const SizedBox(height: 10),
                      _AdminDrawerTile(
                        icon: Icons.fact_check_rounded,
                        title: 'Bandeja de aprobaciones',
                        onTap: onOpenApprovals,
                      ),
                      const SizedBox(height: 10),
                      _AdminDrawerTile(
                        icon: Icons.account_tree_rounded,
                        title: 'Trazabilidad operativa',
                        onTap: onOpenTraceability,
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
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
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

class _BranchDrawer extends StatelessWidget {
  const _BranchDrawer({
    required this.user,
    required this.sections,
    required this.selectedSection,
    required this.sectionLabelBuilder,
    required this.sectionIconBuilder,
    required this.onSelectSection,
    required this.onOpenBranches,
    required this.onOpenNotifications,
    required this.onOpenSyncStatus,
    required this.onOpenRequestTracking,
    required this.onOpenApprovalRequests,
    required this.onOpenReservationRequests,
    required this.onOpenTransferRequests,
    required this.onSignOut,
  });

  final AppUser user;
  final List<_BranchDashboardSection> sections;
  final _BranchDashboardSection selectedSection;
  final String Function(_BranchDashboardSection section) sectionLabelBuilder;
  final IconData Function(_BranchDashboardSection section) sectionIconBuilder;
  final Future<void> Function(_BranchDashboardSection section) onSelectSection;
  final VoidCallback onOpenBranches;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenSyncStatus;
  final VoidCallback onOpenRequestTracking;
  final VoidCallback? onOpenApprovalRequests;
  final VoidCallback onOpenReservationRequests;
  final VoidCallback onOpenTransferRequests;
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
                user.role == UserRole.seller
                    ? 'Menu de ventas'
                    : 'Menu de sucursal',
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
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...sections.map(
                        (section) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _BranchDrawerTile(
                            icon: sectionIconBuilder(section),
                            title: sectionLabelBuilder(section),
                            isSelected: section == selectedSection,
                            onTap: () => unawaited(onSelectSection(section)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _AdminDrawerTile(
                        icon: Icons.store_mall_directory_rounded,
                        title: 'Sucursales',
                        onTap: onOpenBranches,
                      ),
                      const SizedBox(height: 10),
                      _AdminDrawerTile(
                        icon: Icons.notifications_none_rounded,
                        title: 'Notificaciones',
                        onTap: onOpenNotifications,
                      ),
                      const SizedBox(height: 10),
                      _AdminDrawerTile(
                        icon: Icons.cloud_done_rounded,
                        title: 'Estado de sincronizacion',
                        onTap: onOpenSyncStatus,
                      ),
                      const SizedBox(height: 10),
                      _AdminDrawerTile(
                        icon: Icons.track_changes_rounded,
                        title: 'Estado de solicitudes',
                        onTap: onOpenRequestTracking,
                      ),
                      if (onOpenApprovalRequests != null) ...[
                        const SizedBox(height: 10),
                        _AdminDrawerTile(
                          icon: Icons.fact_check_rounded,
                          title: 'Bandeja de aprobaciones',
                          onTap: onOpenApprovalRequests,
                        ),
                      ],
                      const SizedBox(height: 10),
                      _AdminDrawerTile(
                        icon: Icons.bookmark_add_rounded,
                        title: 'Reservar producto',
                        onTap: onOpenReservationRequests,
                      ),
                      const SizedBox(height: 10),
                      _AdminDrawerTile(
                        icon: Icons.local_shipping_rounded,
                        title: 'Solicitar traslado',
                        onTap: onOpenTransferRequests,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
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

class _BranchDrawerTile extends StatelessWidget {
  const _BranchDrawerTile({
    required this.icon,
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? const Color(0xFF173660) : const Color(0xFF0E2442),
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Icon(
          icon,
          color: isSelected ? AppPalette.amber : Colors.white,
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        trailing: isSelected
            ? const Icon(Icons.check_rounded, color: AppPalette.amber)
            : const Icon(Icons.chevron_right_rounded, color: Colors.white70),
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

class _DashboardNotificationVisual {
  const _DashboardNotificationVisual({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}

_DashboardNotificationVisual _resolveNotificationVisual(
  AppNotification notification,
) {
  final title = notification.title.toLowerCase();
  if (title.contains('rechazada')) {
    return const _DashboardNotificationVisual(
      icon: Icons.cancel_rounded,
      color: AppPalette.danger,
    );
  }
  if (title.contains('aprobada')) {
    return const _DashboardNotificationVisual(
      icon: Icons.check_circle_rounded,
      color: AppPalette.mint,
    );
  }
  return switch (notification.type) {
    'transfer' => const _DashboardNotificationVisual(
      icon: Icons.local_shipping_rounded,
      color: AppPalette.amber,
    ),
    'reservation' => const _DashboardNotificationVisual(
      icon: Icons.bookmark_added_rounded,
      color: AppPalette.blueSoft,
    ),
    _ => const _DashboardNotificationVisual(
      icon: Icons.notifications_rounded,
      color: AppPalette.cyan,
    ),
  };
}

String _formatNotificationType(String type) {
  return switch (type) {
    'transfer' => 'Traslado',
    'reservation' => 'Reserva',
    _ => 'Sistema',
  };
}

Color _trackingRequestOverviewColor(RequestTrackingStatus status) {
  return switch (status) {
    RequestTrackingStatus.pending => AppPalette.amber,
    RequestTrackingStatus.approved => AppPalette.blueSoft,
    RequestTrackingStatus.rejected => AppPalette.danger,
    RequestTrackingStatus.inTransit => AppPalette.cyan,
    RequestTrackingStatus.received => AppPalette.mint,
    RequestTrackingStatus.completed => AppPalette.mint,
    RequestTrackingStatus.cancelled => AppPalette.danger,
    RequestTrackingStatus.expired => AppPalette.amber,
  };
}

IconData _trackingRequestOverviewIcon(RequestTrackingItem item) {
  if (item.type == RequestTrackingType.transfer) {
    return switch (item.status) {
      RequestTrackingStatus.pending => Icons.pending_actions_rounded,
      RequestTrackingStatus.approved => Icons.verified_rounded,
      RequestTrackingStatus.rejected => Icons.block_rounded,
      RequestTrackingStatus.inTransit => Icons.local_shipping_rounded,
      RequestTrackingStatus.received => Icons.inventory_2_rounded,
      RequestTrackingStatus.completed => Icons.check_circle_rounded,
      RequestTrackingStatus.cancelled => Icons.cancel_rounded,
      RequestTrackingStatus.expired => Icons.timer_off_rounded,
    };
  }

  return switch (item.status) {
    RequestTrackingStatus.pending => Icons.bookmark_added_rounded,
    RequestTrackingStatus.approved => Icons.verified_rounded,
    RequestTrackingStatus.rejected => Icons.block_rounded,
    RequestTrackingStatus.inTransit => Icons.sync_alt_rounded,
    RequestTrackingStatus.received => Icons.check_circle_rounded,
    RequestTrackingStatus.completed => Icons.check_circle_rounded,
    RequestTrackingStatus.cancelled => Icons.cancel_rounded,
    RequestTrackingStatus.expired => Icons.timer_off_rounded,
  };
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
    'transfer_requested' => 'Traslado solicitado',
    'transfer_approved' => 'Traslado aprobado',
    'transfer_rejected' => 'Traslado rechazado',
    'transfer_in_transit' => 'Traslado despachado',
    'transfer_received' => 'Traslado recibido',
    'reservation_created' => 'Reserva creada',
    'reservation_approved' => 'Reserva aprobada',
    'reservation_rejected' => 'Reserva rechazada',
    'reservation_completed' => 'Reserva completada',
    'reservation_cancelled' => 'Reserva cancelada',
    'reservation_expired' => 'Reserva vencida',
    'reservation_updated' => 'Reserva actualizada',
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
    'transfer_requested' => Icons.swap_horiz_rounded,
    'transfer_approved' => Icons.verified_rounded,
    'transfer_rejected' => Icons.block_rounded,
    'transfer_in_transit' => Icons.local_shipping_rounded,
    'transfer_received' => Icons.inventory_2_rounded,
    'reservation_created' => Icons.bookmark_add_rounded,
    'reservation_approved' => Icons.verified_rounded,
    'reservation_rejected' => Icons.block_rounded,
    'reservation_completed' => Icons.check_circle_rounded,
    'reservation_cancelled' => Icons.cancel_rounded,
    'reservation_expired' => Icons.timer_off_rounded,
    'reservation_updated' => Icons.bookmark_rounded,
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
    'transfer_requested' => const Color(0xFFD39B2A),
    'transfer_approved' => const Color(0xFF2E8B57),
    'transfer_rejected' => const Color(0xFFC24949),
    'transfer_in_transit' => const Color(0xFF2A8AC7),
    'transfer_received' => const Color(0xFF1F7A8C),
    'reservation_created' => const Color(0xFF1F7A8C),
    'reservation_approved' => const Color(0xFF2E8B57),
    'reservation_rejected' => const Color(0xFFC24949),
    'reservation_completed' => const Color(0xFF2E8B57),
    'reservation_cancelled' => const Color(0xFFC24949),
    'reservation_expired' => const Color(0xFFD39B2A),
    'reservation_updated' => const Color(0xFF31547D),
    _ => const Color(0xFF31547D),
  };
}

String _formatTransferStatusLabel(TransferStatus status) {
  return switch (status) {
    TransferStatus.pending => 'Pendiente',
    TransferStatus.approved => 'Aprobado',
    TransferStatus.rejected => 'Rechazado',
    TransferStatus.inTransit => 'En transito',
    TransferStatus.received => 'Recibido',
    TransferStatus.cancelled => 'Cancelado',
  };
}

Color _transferStatusColor(TransferStatus status) {
  return switch (status) {
    TransferStatus.pending => AppPalette.amber,
    TransferStatus.approved => AppPalette.mint,
    TransferStatus.rejected || TransferStatus.cancelled => AppPalette.danger,
    TransferStatus.inTransit => AppPalette.blueSoft,
    TransferStatus.received => AppPalette.cyan,
  };
}

String _formatReservationStatusLabel(ReservationStatus status) {
  return switch (status) {
    ReservationStatus.pending => 'Pendiente',
    ReservationStatus.active => 'Activa',
    ReservationStatus.rejected => 'Rechazada',
    ReservationStatus.completed => 'Completada',
    ReservationStatus.cancelled => 'Cancelada',
    ReservationStatus.expired => 'Vencida',
  };
}

Color _reservationStatusColor(ReservationStatus status) {
  return switch (status) {
    ReservationStatus.pending => AppPalette.amber,
    ReservationStatus.active => AppPalette.blueSoft,
    ReservationStatus.rejected => AppPalette.danger,
    ReservationStatus.completed => AppPalette.mint,
    ReservationStatus.cancelled => AppPalette.danger,
    ReservationStatus.expired => AppPalette.amber,
  };
}

String _formatDateTimeStamp(DateTime value) {
  final minute = value.minute.toString().padLeft(2, '0');
  return '${value.day}/${value.month}/${value.year} ${value.hour}:$minute';
}

String _formatAuditMetadataLabel(String value) {
  return switch (value.trim().toLowerCase()) {
    'quantity' => 'Unidades',
    'frombranchid' => 'Origen ID',
    'frombranchname' => 'Origen',
    'tobranchid' => 'Destino ID',
    'tobranchname' => 'Destino',
    'reason' => 'Motivo',
    'notes' => 'Notas',
    'requestingbranchid' => 'Rama solicitante ID',
    'requestingbranchname' => 'Rama solicitante',
    'requestedbyname' => 'Solicitante',
    'reservationbranchid' => 'Sucursal reserva ID',
    'reservationbranchname' => 'Sucursal reserva',
    'customername' => 'Cliente',
    'requestedbyuserid' => 'Solicitado por',
    'approvedbyuserid' => 'Aprobado por',
    'rejectedbyuserid' => 'Rechazado por',
    'dispatchedbyuserid' => 'Despachado por',
    'receivedbyuserid' => 'Recibido por',
    'reviewcomment' => 'Comentario de revision',
    'status' => 'Estado',
    _ => value,
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
