import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../auth/application/auth_service.dart';
import '../application/inventory_workflow_service.dart';
import '../domain/models.dart';
import 'branch_panel_drawer.dart';

class SyncStatusPage extends StatefulWidget {
  const SyncStatusPage({
    super.key,
    required this.service,
    required this.currentUser,
    this.authService,
  });

  final InventoryWorkflowService service;
  final AppUser currentUser;
  final AuthService? authService;

  @override
  State<SyncStatusPage> createState() => _SyncStatusPageState();
}

class _SyncStatusPageState extends State<SyncStatusPage> {
  late final Stream<SyncStatusOverview> _syncStatusStream;
  bool _isRefreshing = false;
  bool _isRefreshingBranch = false;
  String? _busyMonitoringAlertId;

  bool get _canManageMonitoring => widget.currentUser.role == UserRole.admin;
  bool get _canRefreshOwnBranch =>
      widget.currentUser.role == UserRole.supervisor;

  @override
  void initState() {
    super.initState();
    _syncStatusStream = widget.service.watchSyncStatus(
      actorUser: widget.currentUser,
    );
  }

  Future<void> _refreshStatus({bool showFeedback = true}) async {
    if (_isRefreshing) {
      return;
    }

    setState(() {
      _isRefreshing = true;
    });

    try {
      await widget.service.fetchSyncStatusOverview(
        actorUser: widget.currentUser,
      );
      if (!mounted || !showFeedback) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Estado de actualizacion actualizado.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No fue posible actualizar el estado: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _refreshOwnBranchData() async {
    if (_isRefreshingBranch) {
      return;
    }

    setState(() {
      _isRefreshingBranch = true;
    });

    try {
      await widget.service.refreshOwnBranchData(actorUser: widget.currentUser);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sede actualizada correctamente.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No fue posible actualizar la sede: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingBranch = false;
        });
      }
    }
  }

  Future<void> _runMonitoringAction({
    required String alertId,
    required Future<void> Function() action,
    required String successMessage,
  }) async {
    if (_busyMonitoringAlertId != null) {
      return;
    }

    setState(() {
      _busyMonitoringAlertId = alertId;
    });

    try {
      await action();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No fue posible ejecutar la accion: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyMonitoringAlertId = null;
        });
      }
    }
  }

  Future<void> _openTechnicalDetail(SyncMonitoringAlert alert) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(alert.title),
          content: SingleChildScrollView(
            child: SelectableText(alert.technicalDetail),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _registerSyncError(SyncMonitoringAlert alert) async {
    final typeController = TextEditingController(
      text: alert.latestLog?.type ?? 'inventory',
    );
    final detailController = TextEditingController(
      text: alert.latestLog?.message ?? alert.summary,
    );

    final input = await showDialog<_SyncAdminActionInput>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Registrar evento de error'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: typeController,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de actualizacion',
                    hintText: 'inventory',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: detailController,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Detalle tecnico',
                    hintText:
                        'Timeout, error de esquema, proceso central no responde...',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(
                  _SyncAdminActionInput(
                    type: typeController.text,
                    note: detailController.text,
                  ),
                );
              },
              child: const Text('Registrar'),
            ),
          ],
        );
      },
    );

    typeController.dispose();
    detailController.dispose();

    if (input == null) {
      return;
    }

    await _runMonitoringAction(
      alertId: alert.id,
      action: () => widget.service.registerSyncError(
        actorUser: widget.currentUser,
        branchId: alert.branchId,
        type: input.type,
        technicalDetail: input.note,
      ),
      successMessage: 'Evento de error registrado en monitoreo.',
    );
  }

  Future<void> _requestSyncRetry(SyncMonitoringAlert alert) async {
    final noteController = TextEditingController(text: alert.summary);

    final input = await showDialog<_SyncAdminActionInput>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Solicitar reintento'),
          content: SizedBox(
            width: 420,
            child: TextField(
              controller: noteController,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Nota de seguimiento',
                hintText: 'Deja contexto para el reintento si aplica.',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(
                  _SyncAdminActionInput(
                    type: alert.latestLog?.type ?? 'inventory',
                    note: noteController.text,
                  ),
                );
              },
              child: const Text('Solicitar'),
            ),
          ],
        );
      },
    );

    noteController.dispose();

    if (input == null) {
      return;
    }

    await _runMonitoringAction(
      alertId: alert.id,
      action: () => widget.service.requestSyncRetry(
        actorUser: widget.currentUser,
        branchId: alert.branchId,
        preferredType: input.type,
        note: input.note,
      ),
      successMessage: 'Reintento registrado para la sucursal.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.currentUser.role == UserRole.admin;

    return Scaffold(
      drawer: BranchPanelDrawer(
        service: widget.service,
        currentUser: widget.currentUser,
        currentDestination: BranchPanelDestination.syncStatus,
        authService: widget.authService,
      ),
      appBar: AppBar(
        title: Text(
          isAdmin ? 'Estado de actualizacion' : 'Confiabilidad del inventario',
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              tooltip: 'Actualizar',
              onPressed: _isRefreshing ? null : _refreshStatus,
              icon: Icon(
                _isRefreshing
                    ? Icons.hourglass_top_rounded
                    : Icons.sync_rounded,
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
          child: StreamBuilder<SyncStatusOverview>(
            stream: _syncStatusStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return RefreshIndicator(
                  onRefresh: () => _refreshStatus(showFeedback: false),
                  color: AppPalette.amber,
                  backgroundColor: AppPalette.storm,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
                    children: [_ErrorCard(message: '$snapshot.error')],
                  ),
                );
              }

              final data = snapshot.data;
              if (data == null) {
                return const _LoadingState();
              }

              final currentBranchStatus = data.statusForBranch(
                widget.currentUser.branchId,
              );

              return RefreshIndicator(
                onRefresh: () => _refreshStatus(showFeedback: false),
                color: AppPalette.amber,
                backgroundColor: AppPalette.storm,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: [
                    _StatusHero(
                      data: data,
                      currentUser: widget.currentUser,
                      currentBranchStatus: currentBranchStatus,
                      canRefreshOwnBranch: _canRefreshOwnBranch,
                      isRefreshingBranch: _isRefreshingBranch,
                      onRefreshOwnBranch: _refreshOwnBranchData,
                    ),
                    if (_canManageMonitoring) ...[
                      const SizedBox(height: 16),
                      _MonitoringAlertsCard(
                        alerts: data.monitoringAlerts,
                        busyAlertId: _busyMonitoringAlertId,
                        onOpenTechnicalDetail: _openTechnicalDetail,
                        onRegisterSyncError: _registerSyncError,
                        onRequestRetry: _requestSyncRetry,
                      ),
                      const SizedBox(height: 16),
                      _FailureRulesCard(rules: data.failureRules),
                    ],
                    if (data.warnings.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _WarningsCard(warnings: data.warnings),
                    ],
                    if (data.criticalBranches.isNotEmpty ||
                        data.warningBranches.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _AttentionBranchesCard(
                        branches: [
                          ...data.criticalBranches,
                          ...data.warningBranches.where(
                            (item) => !data.criticalBranches.any(
                              (critical) =>
                                  critical.branch.id == item.branch.id,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    _BranchStatusList(
                      branches: data.branches,
                      currentBranchId: widget.currentUser.branchId,
                      showTechnicalDetails: isAdmin,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SyncAdminActionInput {
  const _SyncAdminActionInput({required this.type, required this.note});

  final String type;
  final String note;
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 72, 16, 28),
      children: const [Center(child: CircularProgressIndicator())],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0x33FF2636),
        border: Border.all(color: AppPalette.panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppPalette.danger.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.wifi_tethering_error_rounded,
                  color: AppPalette.danger,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No fue posible cargar el estado',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _StatusHero extends StatelessWidget {
  const _StatusHero({
    required this.data,
    required this.currentUser,
    required this.currentBranchStatus,
    required this.canRefreshOwnBranch,
    required this.isRefreshingBranch,
    required this.onRefreshOwnBranch,
  });

  final SyncStatusOverview data;
  final AppUser currentUser;
  final SyncBranchStatus? currentBranchStatus;
  final bool canRefreshOwnBranch;
  final bool isRefreshingBranch;
  final Future<void> Function() onRefreshOwnBranch;

  @override
  Widget build(BuildContext context) {
    final isAdmin = currentUser.role == UserRole.admin;
    final focusedStatus = isAdmin ? null : currentBranchStatus;
    final severity = focusedStatus?.severity ?? data.apiStatus.severity;
    final accent = _severityColor(severity);
    final title = isAdmin
        ? 'Monitoreo de actualizacion de datos'
        : 'Confiabilidad del inventario';
    final detail = focusedStatus?.detail ?? data.apiStatus.detail;
    final summary = focusedStatus?.summary ?? data.apiStatus.summary;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.28),
            const Color(0xFF3A1116),
            const Color(0xFF121318),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0x33FF2636)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_severityIcon(severity), color: accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        detail,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                _SeverityBadge(label: summary, severity: severity),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (isAdmin) ...[
                  _MetricBadge(
                    label: 'Ultimo evento',
                    value: _formatRelativeTime(data.apiStatus.lastUpdatedAt),
                  ),
                  _MetricBadge(
                    label: 'Tiempo medio',
                    value: _formatDurationCompact(
                      data.apiStatus.averageResponseTime,
                    ),
                  ),
                ] else ...[
                  _MetricBadge(
                    label: 'Tu estado',
                    value: currentBranchStatus?.summary ?? 'Sin datos',
                  ),
                  _MetricBadge(
                    label: 'Ultima sucursal',
                    value: _formatRelativeTime(currentBranchStatus?.lastSyncAt),
                  ),
                ],
                _MetricBadge(
                  label: 'Sucursales al dia',
                  value:
                      '${data.healthyBranches.length}/${data.branches.length}',
                ),
                _MetricBadge(
                  label: 'Con alerta',
                  value:
                      '${data.warningBranches.length + data.criticalBranches.length}',
                ),
              ],
            ),
            if (currentBranchStatus != null) ...[
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0x22FF2636)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentUser.role == UserRole.admin
                                ? 'Sucursal principal'
                                : 'Tu sucursal',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(color: Colors.white70),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentBranchStatus!.branch.name,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                    _SeverityBadge(
                      label: currentBranchStatus!.summary,
                      severity: currentBranchStatus!.severity,
                    ),
                  ],
                ),
              ),
            ],
            if (canRefreshOwnBranch && currentBranchStatus != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isRefreshingBranch
                      ? null
                      : () => unawaited(onRefreshOwnBranch()),
                  icon: isRefreshingBranch
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: const Text('Actualizar mi sede'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MonitoringAlertsCard extends StatelessWidget {
  const _MonitoringAlertsCard({
    required this.alerts,
    required this.busyAlertId,
    required this.onOpenTechnicalDetail,
    required this.onRegisterSyncError,
    required this.onRequestRetry,
  });

  final List<SyncMonitoringAlert> alerts;
  final String? busyAlertId;
  final Future<void> Function(SyncMonitoringAlert alert) onOpenTechnicalDetail;
  final Future<void> Function(SyncMonitoringAlert alert) onRegisterSyncError;
  final Future<void> Function(SyncMonitoringAlert alert) onRequestRetry;

  @override
  Widget build(BuildContext context) {
    final criticalCount = alerts.where((item) => item.isCritical).length;
    final retryCount = alerts
        .where((item) => item.kind == SyncMonitoringAlertKind.retryRequested)
        .length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            const Color(0x26FF2636),
            const Color(0x1AFF2636),
            const Color(0x141D1F26),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppPalette.panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppPalette.danger.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.monitor_heart_rounded,
                  color: AppPalette.danger,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alertas de monitoreo',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Vista exclusiva de administracion para anticipar fallos en la actualizacion de datos.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricBadge(label: 'Activas', value: '${alerts.length}'),
              _MetricBadge(label: 'Criticas', value: '$criticalCount'),
              _MetricBadge(label: 'Reintentos', value: '$retryCount'),
            ],
          ),
          const SizedBox(height: 16),
          if (alerts.isEmpty)
            Text(
              'No hay alertas de monitoreo activas en este momento.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
            )
          else
            ...alerts.map(
              (alert) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _MonitoringAlertTile(
                  alert: alert,
                  isBusy: busyAlertId == alert.id,
                  onOpenTechnicalDetail: onOpenTechnicalDetail,
                  onRegisterSyncError: onRegisterSyncError,
                  onRequestRetry: onRequestRetry,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MonitoringAlertTile extends StatelessWidget {
  const _MonitoringAlertTile({
    required this.alert,
    required this.isBusy,
    required this.onOpenTechnicalDetail,
    required this.onRegisterSyncError,
    required this.onRequestRetry,
  });

  final SyncMonitoringAlert alert;
  final bool isBusy;
  final Future<void> Function(SyncMonitoringAlert alert) onOpenTechnicalDetail;
  final Future<void> Function(SyncMonitoringAlert alert) onRegisterSyncError;
  final Future<void> Function(SyncMonitoringAlert alert) onRequestRetry;

  @override
  Widget build(BuildContext context) {
    final accent = _severityColor(alert.severity);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_severityIcon(alert.severity), color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alert.branchName,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.white60),
                    ),
                  ],
                ),
              ),
              _SeverityBadge(
                label: _monitoringKindLabel(alert),
                severity: alert.severity,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            alert.summary,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetaChip(
                icon: Icons.schedule_rounded,
                label: 'Detectada: ${_formatDateTime(alert.triggeredAt)}',
              ),
              if (alert.latestLog != null)
                _MetaChip(
                  icon: Icons.sync_alt_rounded,
                  label:
                      '${_formatSyncType(alert.latestLog!.type)} | ${_formatRawSyncStatus(alert.latestLog!.status)}',
                ),
              if (alert.recentFailureCount > 0)
                _MetaChip(
                  icon: Icons.error_outline_rounded,
                  label: 'Fallos recientes: ${alert.recentFailureCount}',
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: isBusy
                    ? null
                    : () => unawaited(onOpenTechnicalDetail(alert)),
                icon: const Icon(Icons.article_outlined),
                label: const Text('Ver detalle'),
              ),
              FilledButton.tonalIcon(
                onPressed: isBusy
                    ? null
                    : () => unawaited(onRegisterSyncError(alert)),
                icon: const Icon(Icons.bug_report_outlined),
                label: const Text('Registrar error'),
              ),
              FilledButton.icon(
                onPressed: isBusy
                    ? null
                    : () => unawaited(onRequestRetry(alert)),
                icon: isBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
                label: const Text('Solicitar reintento'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FailureRulesCard extends StatelessWidget {
  const _FailureRulesCard({required this.rules});

  final List<String> rules;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0x241D1F26),
        border: Border.all(color: AppPalette.panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reglas de fallo',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Estas reglas disparan el monitoreo cuando una sucursal deja de tener datos confiables.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          ...rules.map(
            (rule) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(
                      Icons.rule_folder_outlined,
                      size: 16,
                      color: AppPalette.cyan,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      rule,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningsCard extends StatelessWidget {
  const _WarningsCard({required this.warnings});

  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            AppPalette.amber.withValues(alpha: 0.24),
            const Color(0xFF251114),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppPalette.amber.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppPalette.amber.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppPalette.amber,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Advertencias activas',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...warnings.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(
                      Icons.circle,
                      size: 8,
                      color: AppPalette.amberSoft,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttentionBranchesCard extends StatelessWidget {
  const _AttentionBranchesCard({required this.branches});

  final List<SyncBranchStatus> branches;

  @override
  Widget build(BuildContext context) {
    final visibleBranches = branches.take(6).toList(growable: false);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0x241D1F26),
        border: Border.all(color: AppPalette.panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sucursales con alertas o atraso',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Prioriza estas sedes antes de confiar plenamente en la disponibilidad mostrada.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          ...visibleBranches.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _AttentionBranchRow(branch: item),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttentionBranchRow extends StatelessWidget {
  const _AttentionBranchRow({required this.branch});

  final SyncBranchStatus branch;

  @override
  Widget build(BuildContext context) {
    final accent = _severityColor(branch.severity);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_severityIcon(branch.severity), color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        branch.branch.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    _SeverityBadge(
                      label: branch.summary,
                      severity: branch.severity,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  branch.detail,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ultima actualizacion: ${_formatDateTime(branch.lastSyncAt)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white60),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BranchStatusList extends StatelessWidget {
  const _BranchStatusList({
    required this.branches,
    required this.currentBranchId,
    required this.showTechnicalDetails,
  });

  final List<SyncBranchStatus> branches;
  final String currentBranchId;
  final bool showTechnicalDetails;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0x241D1F26),
        border: Border.all(color: AppPalette.panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            showTechnicalDetails
                ? 'Ultima actualizacion por sucursal'
                : 'Confiabilidad por sucursal',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            showTechnicalDetails
                ? 'Cada fila resume el estado util para decidir si la informacion sigue siendo confiable.'
                : 'Estado operativo de cada sede para validar disponibilidad antes de comprometer stock.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          ...branches.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _BranchStatusTile(
                branch: item,
                isCurrentBranch: item.branch.id == currentBranchId,
                showTechnicalDetails: showTechnicalDetails,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BranchStatusTile extends StatelessWidget {
  const _BranchStatusTile({
    required this.branch,
    required this.isCurrentBranch,
    required this.showTechnicalDetails,
  });

  final SyncBranchStatus branch;
  final bool isCurrentBranch;
  final bool showTechnicalDetails;

  @override
  Widget build(BuildContext context) {
    final accent = _severityColor(branch.severity);
    final latestLog = branch.latestLog;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: const Color(0x22FF2636)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_severityIcon(branch.severity), color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            branch.branch.name,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (isCurrentBranch)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppPalette.blue.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Tu sucursal',
                              style: TextStyle(
                                color: AppPalette.blueSoft,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      branch.branch.city,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.white60),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _SeverityBadge(label: branch.summary, severity: branch.severity),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            branch.detail,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetaChip(
                icon: Icons.schedule_rounded,
                label:
                    'Actualizacion: ${_formatDateTime(branch.lastSyncAt)} (${_formatRelativeTime(branch.lastSyncAt)})',
              ),
              if (showTechnicalDetails && latestLog != null)
                _MetaChip(
                  icon: Icons.sync_alt_rounded,
                  label:
                      '${_formatSyncType(latestLog.type)} | ${_formatRawSyncStatus(latestLog.status)}',
                ),
              if (showTechnicalDetails && latestLog != null)
                _MetaChip(
                  icon: Icons.dns_rounded,
                  label: '${latestLog.recordsProcessed} registros',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SeverityBadge extends StatelessWidget {
  const _SeverityBadge({required this.label, required this.severity});

  final String label;
  final SyncStatusSeverity severity;

  @override
  Widget build(BuildContext context) {
    final background = _severityColor(severity).withValues(alpha: 0.16);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: _severityColor(severity).withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: _severityColor(severity),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MetricBadge extends StatelessWidget {
  const _MetricBadge({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x22FF2636)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white60),
          ),
          const SizedBox(height: 4),
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

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0x1FFF2636),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x22FF2636)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppPalette.cyan),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

Color _severityColor(SyncStatusSeverity severity) {
  return switch (severity) {
    SyncStatusSeverity.healthy => AppPalette.mint,
    SyncStatusSeverity.warning => AppPalette.amber,
    SyncStatusSeverity.critical => AppPalette.danger,
    SyncStatusSeverity.unknown => AppPalette.blueSoft,
  };
}

IconData _severityIcon(SyncStatusSeverity severity) {
  return switch (severity) {
    SyncStatusSeverity.healthy => Icons.cloud_done_rounded,
    SyncStatusSeverity.warning => Icons.cloud_sync_rounded,
    SyncStatusSeverity.critical => Icons.cloud_off_rounded,
    SyncStatusSeverity.unknown => Icons.help_outline_rounded,
  };
}

String _formatSyncType(String value) {
  return switch (value.trim().toLowerCase()) {
    'inventory' => 'Inventario',
    'catalog' => 'Catalogo',
    'users' => 'Usuarios',
    'reservations' => 'Reservas',
    'transfers' => 'Traslados',
    '' => 'Sin tipo',
    _ => '${value[0].toUpperCase()}${value.substring(1)}',
  };
}

String _formatRawSyncStatus(String value) {
  return switch (value.trim().toLowerCase()) {
    'success' || 'completed' || 'ok' => 'Exitosa',
    'failed' || 'error' || 'timeout' => 'Con error',
    'running' || 'in_progress' || 'pending' => 'En proceso',
    'retry_requested' || 'retry-requested' || 'retry' => 'Reintento solicitado',
    '' => 'Sin estado',
    _ => '${value[0].toUpperCase()}${value.substring(1)}',
  };
}

String _monitoringKindLabel(SyncMonitoringAlert alert) {
  return switch (alert.kind) {
    SyncMonitoringAlertKind.syncFailure => 'Fallo',
    SyncMonitoringAlertKind.staleData => 'Desactualizada',
    SyncMonitoringAlertKind.retryRequested => 'Reintento',
  };
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

String _formatDateTime(DateTime? value) {
  if (value == null) {
    return 'sin registro';
  }
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
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
