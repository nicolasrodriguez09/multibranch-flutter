import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../auth/application/auth_service.dart';
import '../application/inventory_workflow_service.dart';
import '../domain/models.dart';
import 'branch_panel_drawer.dart';

enum _StockAlertFilter { all, unread, critical, warning }

class StockAlertsPage extends StatefulWidget {
  const StockAlertsPage({
    super.key,
    required this.service,
    required this.currentUser,
    this.authService,
  });

  final InventoryWorkflowService service;
  final AppUser currentUser;
  final AuthService? authService;

  @override
  State<StockAlertsPage> createState() => _StockAlertsPageState();
}

class _StockAlertsPageState extends State<StockAlertsPage> {
  late final Stream<StockAlertFeedData> _alertsStream;
  _StockAlertFilter _selectedFilter = _StockAlertFilter.all;
  bool _isRefreshing = false;
  bool _isMarkingAll = false;

  @override
  void initState() {
    super.initState();
    _alertsStream = widget.service.watchLowStockAlerts(
      actorUser: widget.currentUser,
    );
  }

  Future<void> _refreshAlerts({bool showFeedback = false}) async {
    if (_isRefreshing) {
      return;
    }
    setState(() {
      _isRefreshing = true;
    });

    try {
      await widget.service.fetchLowStockAlerts(actorUser: widget.currentUser);
      if (!mounted || !showFeedback) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Alertas actualizadas.')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No fue posible actualizar las alertas: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _markAlertAsRead(StockAlertItem alert) async {
    await widget.service.markStockAlertAsRead(
      actorUser: widget.currentUser,
      alert: alert,
    );
  }

  Future<void> _markAllAsRead(List<StockAlertItem> alerts) async {
    if (_isMarkingAll) {
      return;
    }

    setState(() {
      _isMarkingAll = true;
    });

    try {
      final marked = await widget.service.markAllStockAlertsAsRead(
        actorUser: widget.currentUser,
        alerts: alerts,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            marked == 0
                ? 'No habia alertas pendientes por marcar.'
                : marked == 1
                ? '1 alerta marcada como leida.'
                : '$marked alertas marcadas como leidas.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No fue posible marcar todas las alertas: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isMarkingAll = false;
        });
      }
    }
  }

  List<StockAlertItem> _filterAlerts(List<StockAlertItem> alerts) {
    return switch (_selectedFilter) {
      _StockAlertFilter.all => alerts,
      _StockAlertFilter.unread =>
        alerts.where((item) => !item.isRead).toList(growable: false),
      _StockAlertFilter.critical =>
        alerts.where((item) => item.isCritical).toList(growable: false),
      _StockAlertFilter.warning =>
        alerts.where((item) => item.isWarning).toList(growable: false),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: BranchPanelDrawer(
        service: widget.service,
        currentUser: widget.currentUser,
        currentDestination: BranchPanelDestination.stockAlerts,
        authService: widget.authService,
      ),
      appBar: AppBar(
        title: const Text('Alertas de stock'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _isRefreshing
                ? null
                : () => _refreshAlerts(showFeedback: true),
            icon: Icon(
              _isRefreshing ? Icons.hourglass_top_rounded : Icons.sync_rounded,
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
          child: StreamBuilder<StockAlertFeedData>(
            stream: _alertsStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return RefreshIndicator(
                  onRefresh: _refreshAlerts,
                  color: AppPalette.amber,
                  backgroundColor: AppPalette.storm,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                    children: [_AlertErrorCard(message: '$snapshot.error')],
                  ),
                );
              }

              final data = snapshot.data;
              if (data == null) {
                return const Center(child: CircularProgressIndicator());
              }

              final filteredAlerts = _filterAlerts(data.alerts);

              return RefreshIndicator(
                onRefresh: _refreshAlerts,
                color: AppPalette.amber,
                backgroundColor: AppPalette.storm,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: [
                    _AlertsHero(
                      data: data,
                      currentUser: widget.currentUser,
                      onMarkAllAsRead: data.unreadCount == 0 || _isMarkingAll
                          ? null
                          : () => _markAllAsRead(data.alerts),
                    ),
                    const SizedBox(height: 16),
                    _AlertFilterBar(
                      selectedFilter: _selectedFilter,
                      onSelected: (filter) {
                        setState(() {
                          _selectedFilter = filter;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    if (filteredAlerts.isEmpty)
                      const _EmptyAlertsCard()
                    else
                      ...filteredAlerts.map(
                        (alert) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _AlertCard(
                            alert: alert,
                            showBranch:
                                widget.currentUser.role == UserRole.admin,
                            onMarkAsRead: alert.isRead
                                ? null
                                : () => _markAlertAsRead(alert),
                          ),
                        ),
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

class _AlertsHero extends StatelessWidget {
  const _AlertsHero({
    required this.data,
    required this.currentUser,
    required this.onMarkAllAsRead,
  });

  final StockAlertFeedData data;
  final AppUser currentUser;
  final VoidCallback? onMarkAllAsRead;

  @override
  Widget build(BuildContext context) {
    final accent = data.hasCritical ? AppPalette.danger : AppPalette.amber;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.25),
            const Color(0xFF3A1116),
            const Color(0xFF121318),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0x33FF2636)),
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
                    color: accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    data.hasCritical
                        ? Icons.notification_important_rounded
                        : Icons.warning_amber_rounded,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentUser.role == UserRole.admin
                            ? 'Alertas multi-sucursal'
                            : 'Alertas de tu sucursal',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data.hasCritical
                            ? 'Hay alertas criticas activas y se generan notificaciones internas para supervision.'
                            : 'Revisa los productos con stock bajo antes de una ruptura operativa.',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _AlertMetric(label: 'Sin leer', value: '${data.unreadCount}'),
                _AlertMetric(label: 'Criticas', value: '${data.criticalCount}'),
                _AlertMetric(
                  label: 'Advertencia',
                  value: '${data.warningCount}',
                ),
                _AlertMetric(label: 'Total', value: '${data.alerts.length}'),
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onMarkAllAsRead,
                icon: const Icon(Icons.done_all_rounded),
                label: const Text('Marcar todas'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertMetric extends StatelessWidget {
  const _AlertMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 128,
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

class _AlertFilterBar extends StatelessWidget {
  const _AlertFilterBar({
    required this.selectedFilter,
    required this.onSelected,
  });

  final _StockAlertFilter selectedFilter;
  final ValueChanged<_StockAlertFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _AlertFilterChip(
          label: 'Todas',
          selected: selectedFilter == _StockAlertFilter.all,
          onTap: () => onSelected(_StockAlertFilter.all),
        ),
        _AlertFilterChip(
          label: 'No leidas',
          selected: selectedFilter == _StockAlertFilter.unread,
          onTap: () => onSelected(_StockAlertFilter.unread),
        ),
        _AlertFilterChip(
          label: 'Criticas',
          selected: selectedFilter == _StockAlertFilter.critical,
          onTap: () => onSelected(_StockAlertFilter.critical),
        ),
        _AlertFilterChip(
          label: 'Advertencia',
          selected: selectedFilter == _StockAlertFilter.warning,
          onTap: () => onSelected(_StockAlertFilter.warning),
        ),
      ],
    );
  }
}

class _AlertFilterChip extends StatelessWidget {
  const _AlertFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      label: Text(label),
      selectedColor: AppPalette.blue.withValues(alpha: 0.32),
      backgroundColor: AppPalette.panel,
      side: BorderSide(
        color: selected ? AppPalette.blueSoft : AppPalette.panelBorder,
      ),
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppPalette.textPrimary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.alert,
    required this.showBranch,
    required this.onMarkAsRead,
  });

  final StockAlertItem alert;
  final bool showBranch;
  final VoidCallback? onMarkAsRead;

  @override
  Widget build(BuildContext context) {
    final accent = alert.isCritical ? AppPalette.danger : AppPalette.amber;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color(0x221D1F26),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
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
                child: Icon(
                  alert.isCritical
                      ? Icons.notification_important_rounded
                      : Icons.warning_amber_rounded,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.productName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'SKU ${alert.sku} | ${alert.categoryName}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.white60),
                    ),
                  ],
                ),
              ),
              _SeverityPill(alert: alert),
            ],
          ),
          const SizedBox(height: 14),
          if (showBranch)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Sucursal: ${alert.branchName}',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.white),
              ),
            ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetaPill(
                label:
                    'Disponible ${alert.availableStock} | Umbral ${alert.resolvedThreshold}',
              ),
              _MetaPill(label: 'Reservado ${alert.reservedStock}'),
              _MetaPill(label: 'En camino ${alert.incomingStock}'),
              _MetaPill(
                label:
                    alert.thresholdSource == StockAlertThresholdSource.product
                    ? 'Umbral por producto'
                    : 'Umbral por categoria',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            alert.isCritical
                ? 'La disponibilidad ya esta en rango critico. Conviene actuar antes de afectar ventas o traslados.'
                : 'El inventario sigue operativo, pero ya entro en zona de reposicion preventiva.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Ultimo cambio ${_formatRelativeTime(alert.lastMovementAt ?? alert.updatedAt)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white60),
                ),
              ),
              TextButton.icon(
                onPressed: onMarkAsRead,
                icon: Icon(
                  alert.isRead
                      ? Icons.check_circle_rounded
                      : Icons.mark_email_read_rounded,
                ),
                label: Text(alert.isRead ? 'Leida' : 'Marcar leida'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SeverityPill extends StatelessWidget {
  const _SeverityPill({required this.alert});

  final StockAlertItem alert;

  @override
  Widget build(BuildContext context) {
    final color = alert.isCritical ? AppPalette.danger : AppPalette.amber;
    final label = alert.isCritical ? 'Critica' : 'Advertencia';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
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

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x22FF2636)),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: Colors.white),
      ),
    );
  }
}

class _EmptyAlertsCard extends StatelessWidget {
  const _EmptyAlertsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color(0x221D1F26),
        border: Border.all(color: AppPalette.panelBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppPalette.mint.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.inventory_2_rounded,
              color: AppPalette.mint,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No hay alertas para el filtro seleccionado.',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Cuando una referencia baje del umbral configurado, aparecera aqui.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _AlertErrorCard extends StatelessWidget {
  const _AlertErrorCard({required this.message});

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
          Text(
            'No fue posible cargar las alertas',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
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

String _formatRelativeTime(DateTime value) {
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
