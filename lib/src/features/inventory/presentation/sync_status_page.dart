import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../application/inventory_workflow_service.dart';
import '../domain/models.dart';

class SyncStatusPage extends StatefulWidget {
  const SyncStatusPage({
    super.key,
    required this.service,
    required this.currentUser,
  });

  final InventoryWorkflowService service;
  final AppUser currentUser;

  @override
  State<SyncStatusPage> createState() => _SyncStatusPageState();
}

class _SyncStatusPageState extends State<SyncStatusPage> {
  late final Stream<SyncStatusOverview> _syncStatusStream;
  bool _isRefreshing = false;

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
        const SnackBar(content: Text('Estado de sincronizacion actualizado.')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estado de sincronizacion'),
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
            colors: [Color(0xFF081A33), Color(0xFF0A2142), Color(0xFF08172D)],
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
                    ),
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
        color: const Color(0x331E2330),
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
  });

  final SyncStatusOverview data;
  final AppUser currentUser;
  final SyncBranchStatus? currentBranchStatus;

  @override
  Widget build(BuildContext context) {
    final severity = data.apiStatus.severity;
    final accent = _severityColor(severity);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.28),
            const Color(0xFF15365E),
            const Color(0xFF0C1D36),
          ],
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
                        'API de sincronizacion',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data.apiStatus.detail,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                _SeverityBadge(
                  label: data.apiStatus.summary,
                  severity: severity,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
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
                  border: Border.all(color: const Color(0x22FFFFFF)),
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
          ],
        ),
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
            const Color(0xFF2A2517),
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
        color: const Color(0x1D102545),
        border: Border.all(color: AppPalette.panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sucursales con fallo o retraso',
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
                  'Ultima sincronizacion: ${_formatDateTime(branch.lastSyncAt)}',
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
  });

  final List<SyncBranchStatus> branches;
  final String currentBranchId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0x1D102545),
        border: Border.all(color: AppPalette.panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ultima sincronizacion por sucursal',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Cada fila resume el estado util para decidir si la informacion sigue siendo confiable.',
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
  });

  final SyncBranchStatus branch;
  final bool isCurrentBranch;

  @override
  Widget build(BuildContext context) {
    final accent = _severityColor(branch.severity);
    final latestLog = branch.latestLog;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: const Color(0x22FFFFFF)),
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
                    'Ultima: ${_formatDateTime(branch.lastSyncAt)} (${_formatRelativeTime(branch.lastSyncAt)})',
              ),
              if (latestLog != null)
                _MetaChip(
                  icon: Icons.sync_alt_rounded,
                  label:
                      '${_formatSyncType(latestLog.type)} | ${_formatRawSyncStatus(latestLog.status)}',
                ),
              if (latestLog != null)
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
        border: Border.all(color: const Color(0x22FFFFFF)),
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
        color: const Color(0x1F173255),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x22FFFFFF)),
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
    '' => 'Sin estado',
    _ => '${value[0].toUpperCase()}${value.substring(1)}',
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
