import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../auth/application/auth_service.dart';
import '../../auth/presentation/create_employee_dialog.dart';
import '../application/inventory_workflow_service.dart';
import '../domain/models.dart';
import '../domain/role_permissions.dart';

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

  String _status = 'Dashboard operativo listo.';
  bool _isCreating = false;
  bool _isCreatingEmployee = false;
  bool _isRefreshing = false;
  DateTime _lastDashboardRefreshAt = DateTime.now();
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _lastDashboardRefreshAt = DateTime.now();
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
      unawaited(_refreshDashboard(isManual: false));
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _createBaseData() async {
    setState(() {
      _isCreating = true;
      _status = 'Creando base inicial en Firestore...';
    });

    try {
      await widget.service.seedMasterData(actorUser: widget.currentUser);
      if (!mounted) {
        return;
      }
      setState(() {
        _status =
            'Base inicial creada. Ya puedes revisar inventarios, solicitudes y sincronizaciones.';
      });
      await _refreshDashboard(isManual: true);
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
        _status =
            'Primero debes crear la base inicial para tener sucursales disponibles.';
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
        _status =
            'Empleado creado correctamente: ${request.email} (${request.role.displayName}).';
      });
      await _refreshDashboard(isManual: true);
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

  Future<void> _refreshDashboard({required bool isManual}) async {
    if (_isRefreshing) {
      return;
    }

    final branchId = widget.currentUser.branchId;
    setState(() {
      _isRefreshing = true;
      _status = isManual
          ? 'Actualizando dashboard...'
          : 'Refrescando dashboard automaticamente...';
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

      final refreshedAt = DateTime.now();
      setState(() {
        _lastDashboardRefreshAt = refreshedAt;
        _status = isManual
            ? 'Dashboard actualizado a las ${_formatClock(refreshedAt)}.'
            : 'Dashboard sincronizado automaticamente a las ${_formatClock(refreshedAt)}.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'No se pudo actualizar el dashboard: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  String _dashboardTitleFor(UserRole role) => switch (role) {
    UserRole.admin => 'Control administrativo',
    UserRole.supervisor => 'Control de sucursal',
    UserRole.seller => 'Panel de ventas',
  };

  String _dashboardDescriptionFor(UserRole role) => switch (role) {
    UserRole.admin =>
      'Vista de supervision, personal y estado operativo para coordinar la plataforma.',
    UserRole.supervisor =>
      'Seguimiento operativo de solicitudes, alertas y sincronizaciones de la sucursal.',
    UserRole.seller =>
      'Disponibilidad rapida de productos y alertas clave para atencion y reserva inmediata.',
  };

  List<Widget> _buildAdminSections(AppUser user) {
    return [
      const SizedBox(height: 24),
      const _SectionTitle(
        title: 'Acciones administrativas',
        subtitle:
            'Operaciones de configuracion para habilitar la plataforma y el equipo.',
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _ActionPanel(
            title: 'Inicializar datos',
            subtitle:
                'Carga usuarios, sucursales, inventario base y primeras sincronizaciones.',
            icon: Icons.storage_rounded,
            accent: AppPalette.blue,
            label: 'Crear base inicial',
            loading: _isCreating,
            onPressed: _isCreating ? null : _createBaseData,
          ),
          _ActionPanel(
            title: 'Alta de personal',
            subtitle:
                'Asigna sucursal, rol y credenciales temporales desde el dashboard.',
            icon: Icons.person_add_alt_1_rounded,
            accent: AppPalette.amber,
            label: 'Ingresar nuevo empleado',
            loading: _isCreatingEmployee,
            onPressed: _isCreatingEmployee ? null : _openCreateEmployeeDialog,
          ),
        ],
      ),
      const SizedBox(height: 24),
      const _SectionTitle(
        title: 'Resumen ejecutivo',
        subtitle:
            'Indicadores globales para monitorear personal, sucursales, traslados y sincronizaciones.',
      ),
      const SizedBox(height: 12),
      _AdminSummaryMetricsRow(service: widget.service),
      const SizedBox(height: 24),
      _DashboardGrid(
        children: [
          _PendingRequestsPanel(
            service: widget.service,
            branchId: user.branchId,
            includeAllBranches: true,
            title: 'Solicitudes pendientes globales',
            subtitle:
                'Reservas activas y traslados pendientes visibles a nivel administrativo.',
          ),
          _LatestSyncsPanel(
            service: widget.service,
            branchId: user.branchId,
            includeAllBranches: true,
            title: 'Ultimas sincronizaciones globales',
            subtitle:
                'Eventos recientes reportados por cualquier sucursal del sistema.',
          ),
          _TopConsultedPanel(
            service: widget.service,
            branchId: user.branchId,
            title: 'Productos criticos de sucursal base',
            subtitle:
                'Referencia operativa de la sucursal asignada al administrador.',
          ),
        ],
      ),
      const SizedBox(height: 24),
      const _SectionTitle(
        title: 'Modulos habilitados',
        subtitle:
            'Vista disponible segun el rol actual y su matriz de permisos.',
      ),
      const SizedBox(height: 12),
      _ModulePanel(modules: user.visibleModules),
      const SizedBox(height: 24),
      const _SectionTitle(
        title: 'Matriz de permisos',
        subtitle: 'Resumen rapido de capacidades por tipo de usuario.',
      ),
      const SizedBox(height: 12),
      const _MatrixPanel(),
      const SizedBox(height: 24),
      const _SectionTitle(
        title: 'Usuarios',
        subtitle: 'Perfiles activos visibles para administracion.',
      ),
      const SizedBox(height: 12),
      StreamBuilder<List<AppUser>>(
        stream: widget.service.users.watchUsers(),
        builder: (context, snapshot) {
          final items = (snapshot.data ?? const <AppUser>[])
              .map(
                (item) => _InsightItem(
                  icon: Icons.person_outline_rounded,
                  iconColor: AppPalette.blueSoft,
                  title: item.fullName,
                  detail: '${item.role.displayName} | ${item.branchId}',
                  meta: item.email,
                ),
              )
              .toList(growable: false);

          return _DashboardPanel(
            title: 'Equipo registrado',
            subtitle: 'Usuarios creados y visibles desde la plataforma.',
            accent: AppPalette.blueSoft,
            child: _InsightList(
              items: items,
              emptyMessage: 'Todavia no hay usuarios cargados.',
            ),
          );
        },
      ),
    ];
  }

  List<Widget> _buildSupervisorSections(AppUser user) {
    return [
      const SizedBox(height: 24),
      const _SectionTitle(
        title: 'Resumen operativo',
        subtitle:
            'Lectura de supervision para inventario, solicitudes y sincronizaciones de tu sucursal.',
      ),
      const SizedBox(height: 12),
      _SummaryMetricsRow(service: widget.service, branchId: user.branchId),
      const SizedBox(height: 24),
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
      const SizedBox(height: 24),
      const _SectionTitle(
        title: 'Modulos habilitados',
        subtitle:
            'Vista disponible segun el rol actual y su matriz de permisos.',
      ),
      const SizedBox(height: 12),
      _ModulePanel(modules: user.visibleModules),
    ];
  }

  List<Widget> _buildSellerSections(AppUser user) {
    return [
      const SizedBox(height: 24),
      const _SectionTitle(
        title: 'Resumen comercial',
        subtitle:
            'Disponibilidad inmediata y alertas clave para ventas, reservas y reposicion.',
      ),
      const SizedBox(height: 12),
      _SummaryMetricsRow(service: widget.service, branchId: user.branchId),
      const SizedBox(height: 24),
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
      const SizedBox(height: 24),
      const _SectionTitle(
        title: 'Modulos habilitados',
        subtitle:
            'Vista disponible segun el rol actual y su matriz de permisos.',
      ),
      const SizedBox(height: 12),
      _ModulePanel(modules: user.visibleModules),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.currentUser;
    final headerTitle = _dashboardTitleFor(user.role);
    final headerDescription = _dashboardDescriptionFor(user.role);
    final content = switch (user.role) {
      UserRole.admin => _buildAdminSections(user),
      UserRole.supervisor => _buildSupervisorSections(user),
      UserRole.seller => _buildSellerSections(user),
    };

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppPalette.midnight,
        title: const Text('Dashboard'),
        actions: [
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
        color: AppPalette.midnight,
        child: SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: () => _refreshDashboard(isManual: true),
            color: AppPalette.blue,
            backgroundColor: AppPalette.storm,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1240),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DashboardHeader(
                          user: user,
                          title: headerTitle,
                          description: headerDescription,
                          status: _status,
                          isRefreshing: _isRefreshing,
                          lastRefreshedAt: _lastDashboardRefreshAt,
                          onRefresh: _isRefreshing
                              ? null
                              : () => _refreshDashboard(isManual: true),
                        ),
                        ...content,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.user,
    required this.title,
    required this.description,
    required this.status,
    required this.isRefreshing,
    required this.lastRefreshedAt,
    required this.onRefresh,
  });

  final AppUser user;
  final String title;
  final String description;
  final String status;
  final bool isRefreshing;
  final DateTime lastRefreshedAt;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppPalette.storm,
        border: Border.all(color: AppPalette.panelBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              height: 6,
              color: AppPalette.blue,
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _Tag(
                  label: user.role.displayName.toUpperCase(),
                  foreground: AppPalette.textPrimary,
                  background: AppPalette.blueDark,
                ),
                _Tag(
                  label: user.branchId.toUpperCase(),
                  foreground: AppPalette.textPrimary,
                  background: AppPalette.panelStrong,
                ),
                _Tag(
                  label: 'AUTO 60S',
                  foreground: AppPalette.textPrimary,
                  background: const Color(0xFF3F4756),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 36,
              ),
            ),
            const SizedBox(height: 20),
            _StatusCard(status: status),
            const SizedBox(height: 18),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _HeaderMetric(
                  label: 'Ultima actualizacion',
                  value: _formatClock(lastRefreshedAt),
                  helper: _formatRelativeTime(lastRefreshedAt),
                ),
                _HeaderMetric(
                  label: 'Permisos activos',
                  value: '${user.role.grantedPermissions.length}',
                  helper: 'Controlados por rol',
                ),
                _HeaderMetric(
                  label: 'Modulos visibles',
                  value: '${user.visibleModules.length}',
                  helper: 'Vista filtrada',
                ),
                FilledButton.icon(
                  onPressed: onRefresh == null ? null : () => onRefresh!.call(),
                  style: _buttonStyle(
                    backgroundColor: AppPalette.blue,
                    foregroundColor: Colors.white,
                  ),
                  icon: isRefreshing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: Text(
                    isRefreshing ? 'Actualizando' : 'Actualizar ahora',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetricsRow extends StatelessWidget {
  const _SummaryMetricsRow({required this.service, required this.branchId});

  final InventoryWorkflowService service;
  final String branchId;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = _metricWidthFor(constraints.maxWidth);

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: cardWidth,
              child: StreamBuilder<List<InventoryItem>>(
                stream: service.inventories.watchBranchInventory(branchId),
                builder: (context, snapshot) {
                  final items = snapshot.data ?? const <InventoryItem>[];
                  return _MetricCard(
                    label: 'Productos monitoreados',
                    value: '${items.length}',
                    helper: 'Inventario visible en sucursal',
                    icon: Icons.inventory_2_outlined,
                    accent: AppPalette.blue,
                  );
                },
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: StreamBuilder<List<InventoryItem>>(
                stream: service.inventories.watchBranchInventory(branchId),
                builder: (context, snapshot) {
                  final items = snapshot.data ?? const <InventoryItem>[];
                  final count = items
                      .where((item) => item.availableStock <= 0)
                      .length;
                  return _MetricCard(
                    label: 'Productos sin stock',
                    value: '$count',
                    helper: 'Sin disponibilidad inmediata',
                    icon: Icons.remove_shopping_cart_outlined,
                    accent: AppPalette.danger,
                  );
                },
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: StreamBuilder<List<InventoryItem>>(
                stream: service.inventories.watchLowStock(branchId),
                builder: (context, snapshot) {
                  final items = snapshot.data ?? const <InventoryItem>[];
                  final count = items
                      .where((item) => item.availableStock > 0)
                      .length;
                  return _MetricCard(
                    label: 'Alertas de bajo stock',
                    value: '$count',
                    helper: 'Reposicion prioritaria',
                    icon: Icons.warning_amber_rounded,
                    accent: AppPalette.amber,
                  );
                },
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: StreamBuilder<List<Reservation>>(
                stream: service.reservations.watchBranchReservations(branchId),
                builder: (context, reservationSnapshot) {
                  final reservations =
                      reservationSnapshot.data ?? const <Reservation>[];
                  return StreamBuilder<List<TransferRequest>>(
                    stream: service.transfers.watchTransfers(),
                    builder: (context, transferSnapshot) {
                      final transfers =
                          transferSnapshot.data ?? const <TransferRequest>[];
                      final activeReservations = reservations
                          .where(
                            (item) => item.status == ReservationStatus.active,
                          )
                          .length;
                      final pendingTransfers = transfers
                          .where(
                            (item) =>
                                item.status == TransferStatus.pending &&
                                _isTransferForBranch(item, branchId),
                          )
                          .length;
                      return _MetricCard(
                        label: 'Solicitudes pendientes',
                        value: '${activeReservations + pendingTransfers}',
                        helper:
                            '$activeReservations reservas y $pendingTransfers traslados',
                        icon: Icons.pending_actions_outlined,
                        accent: AppPalette.blueSoft,
                      );
                    },
                  );
                },
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: StreamBuilder<List<SyncLog>>(
                stream: service.system.watchBranchSyncLogs(branchId, limit: 1),
                builder: (context, snapshot) {
                  final logs = snapshot.data ?? const <SyncLog>[];
                  final latest = logs.isEmpty ? null : logs.first.createdAt;
                  return _MetricCard(
                    label: 'Ultima sincronizacion',
                    value: latest == null ? 'Sin dato' : _formatClock(latest),
                    helper: latest == null
                        ? 'Sin eventos registrados'
                        : _formatRelativeTime(latest),
                    icon: Icons.sync_alt_rounded,
                    accent: AppPalette.mint,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AdminSummaryMetricsRow extends StatelessWidget {
  const _AdminSummaryMetricsRow({required this.service});

  final InventoryWorkflowService service;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = _metricWidthFor(constraints.maxWidth);

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: cardWidth,
              child: StreamBuilder<List<AppUser>>(
                stream: service.users.watchUsers(),
                builder: (context, snapshot) {
                  final items = snapshot.data ?? const <AppUser>[];
                  return _MetricCard(
                    label: 'Usuarios activos',
                    value: '${items.where((item) => item.isActive).length}',
                    helper: 'Equipo registrado en plataforma',
                    icon: Icons.group_outlined,
                    accent: AppPalette.blue,
                  );
                },
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: StreamBuilder<List<Branch>>(
                stream: service.catalog.watchBranches(),
                builder: (context, snapshot) {
                  final items = snapshot.data ?? const <Branch>[];
                  return _MetricCard(
                    label: 'Sucursales activas',
                    value: '${items.where((item) => item.isActive).length}',
                    helper: 'Red operativa disponible',
                    icon: Icons.storefront_outlined,
                    accent: AppPalette.blueSoft,
                  );
                },
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: StreamBuilder<List<TransferRequest>>(
                stream: service.transfers.watchPendingTransfers(),
                builder: (context, snapshot) {
                  final items = snapshot.data ?? const <TransferRequest>[];
                  return _MetricCard(
                    label: 'Traslados pendientes',
                    value: '${items.length}',
                    helper: 'Solicitudes por aprobar o atender',
                    icon: Icons.pending_actions_outlined,
                    accent: AppPalette.amber,
                  );
                },
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: StreamBuilder<List<SyncLog>>(
                stream: service.system.watchRecentSyncLogs(limit: 1),
                builder: (context, snapshot) {
                  final logs = snapshot.data ?? const <SyncLog>[];
                  final latest = logs.isEmpty ? null : logs.first.createdAt;
                  return _MetricCard(
                    label: 'Ultima sincronizacion global',
                    value: latest == null ? 'Sin dato' : _formatClock(latest),
                    helper: latest == null
                        ? 'Sin eventos registrados'
                        : _formatRelativeTime(latest),
                    icon: Icons.sync_alt_rounded,
                    accent: AppPalette.mint,
                  );
                },
              ),
            ),
          ],
        );
      },
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
    this.includeAllBranches = false,
    this.title = 'Solicitudes pendientes',
    this.subtitle =
        'Reservas activas y traslados pendientes relacionados con la sucursal actual.',
  });

  final InventoryWorkflowService service;
  final String branchId;
  final bool includeAllBranches;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Reservation>>(
      stream: includeAllBranches
          ? service.reservations.watchReservations()
          : service.reservations.watchBranchReservations(branchId),
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
              includeAllBranches: includeAllBranches,
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
    this.includeAllBranches = false,
    this.title = 'Ultimas sincronizaciones',
    this.subtitle = 'Eventos recientes registrados para esta sucursal.',
  });

  final InventoryWorkflowService service;
  final String branchId;
  final bool includeAllBranches;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SyncLog>>(
      stream: includeAllBranches
          ? service.system.watchRecentSyncLogs()
          : service.system.watchBranchSyncLogs(branchId),
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
        color: AppPalette.storm,
        border: Border.all(color: AppPalette.panelBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 5, width: 72, color: accent),
            const SizedBox(height: 14),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.helper,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final String helper;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.storm,
        border: Border.all(color: AppPalette.panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            color: accent.withValues(alpha: 0.18),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            helper,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
          ),
        ],
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({
    required this.label,
    required this.value,
    required this.helper,
  });

  final String label;
  final String value;
  final String helper;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.panelStrong,
        border: Border.all(color: AppPalette.panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            helper,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
          ),
        ],
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 280, maxWidth: 520),
      child: Container(
        decoration: BoxDecoration(
          color: AppPalette.storm,
          border: Border.all(color: AppPalette.panelBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 5, width: 72, color: accent),
              const SizedBox(height: 16),
              Container(
                width: 44,
                height: 44,
                color: accent.withValues(alpha: 0.18),
                child: Icon(icon, color: accent, size: 24),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: onPressed,
                style: _buttonStyle(
                  backgroundColor: accent == AppPalette.amber
                      ? AppPalette.amber
                      : AppPalette.blue,
                  foregroundColor: accent == AppPalette.amber
                      ? AppPalette.deepNavy
                      : Colors.white,
                ),
                child: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(label),
              ),
            ],
          ),
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
        color: AppPalette.storm,
        border: Border.all(color: AppPalette.panelBorder),
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
                  color: AppPalette.panelStrong,
                  border: Border.all(color: AppPalette.panelBorder),
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

class _MatrixPanel extends StatelessWidget {
  const _MatrixPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.storm,
        border: Border.all(color: AppPalette.panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: UserRole.values
            .map(
              (role) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(
                  '${role.displayName}: ${role.grantedPermissions.map((item) => item.label).join(', ')}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
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
          color: AppPalette.panelStrong,
          border: Border.all(color: AppPalette.panelBorder),
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
                color: AppPalette.panelStrong,
                border: Border.all(color: AppPalette.panelBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    color: item.iconColor.withValues(alpha: 0.18),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.panelStrong,
        border: Border.all(color: AppPalette.panelBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            color: const Color(0xFF14345F),
            child: const Icon(
              Icons.cloud_done_outlined,
              color: AppPalette.cyan,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(status, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
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

class _Tag extends StatelessWidget {
  const _Tag({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: AppPalette.panelBorder),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
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

double _metricWidthFor(double maxWidth) {
  if (maxWidth >= 1120) {
    return (maxWidth - 48) / 4;
  }
  if (maxWidth >= 840) {
    return (maxWidth - 24) / 3;
  }
  if (maxWidth >= 560) {
    return (maxWidth - 12) / 2;
  }
  return maxWidth;
}

ButtonStyle _buttonStyle({
  required Color backgroundColor,
  required Color foregroundColor,
}) {
  return FilledButton.styleFrom(
    backgroundColor: backgroundColor,
    foregroundColor: foregroundColor,
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    shape: const RoundedRectangleBorder(),
    textStyle: const TextStyle(fontWeight: FontWeight.w700),
  );
}

String _formatClock(DateTime value) {
  return '${_twoDigits(value.hour)}:${_twoDigits(value.minute)}';
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
