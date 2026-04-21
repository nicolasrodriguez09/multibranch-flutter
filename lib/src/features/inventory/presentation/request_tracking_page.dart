import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../application/inventory_workflow_service.dart';
import '../domain/models.dart';

enum _RequestTypeFilter { all, reservations, transfers }

enum _RequestStatusFilter {
  all,
  pending,
  approved,
  rejected,
  inTransit,
  received,
  completed,
  cancelled,
  expired,
}

enum _RequestDateFilter { all, today, last7Days, last30Days }

class RequestTrackingPage extends StatefulWidget {
  const RequestTrackingPage({
    super.key,
    required this.service,
    required this.currentUser,
  });

  final InventoryWorkflowService service;
  final AppUser currentUser;

  @override
  State<RequestTrackingPage> createState() => _RequestTrackingPageState();
}

class _RequestTrackingPageState extends State<RequestTrackingPage> {
  _RequestTypeFilter _typeFilter = _RequestTypeFilter.all;
  _RequestStatusFilter _statusFilter = _RequestStatusFilter.all;
  _RequestDateFilter _dateFilter = _RequestDateFilter.all;
  bool _isRefreshing = false;
  DateTime? _lastManualRefreshAt;

  Future<void> _refreshTracking({required bool showFeedback}) async {
    if (_isRefreshing) {
      return;
    }

    setState(() {
      _isRefreshing = true;
    });

    try {
      await widget.service
          .watchRequestTracking(actorUser: widget.currentUser)
          .first;
      if (!mounted) {
        return;
      }
      setState(() {
        _lastManualRefreshAt = DateTime.now();
      });
      if (showFeedback) {
        _showStatusMessage('Seguimiento actualizado correctamente.');
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showStatusMessage('No se pudo actualizar el seguimiento: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  void _showStatusMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _matchesType(RequestTrackingItem item) {
    return switch (_typeFilter) {
      _RequestTypeFilter.all => true,
      _RequestTypeFilter.reservations =>
        item.type == RequestTrackingType.reservation,
      _RequestTypeFilter.transfers => item.type == RequestTrackingType.transfer,
    };
  }

  bool _matchesStatus(RequestTrackingItem item) {
    return switch (_statusFilter) {
      _RequestStatusFilter.all => true,
      _RequestStatusFilter.pending =>
        item.status == RequestTrackingStatus.pending,
      _RequestStatusFilter.approved =>
        item.status == RequestTrackingStatus.approved,
      _RequestStatusFilter.rejected =>
        item.status == RequestTrackingStatus.rejected,
      _RequestStatusFilter.inTransit =>
        item.status == RequestTrackingStatus.inTransit,
      _RequestStatusFilter.received =>
        item.status == RequestTrackingStatus.received,
      _RequestStatusFilter.completed =>
        item.status == RequestTrackingStatus.completed,
      _RequestStatusFilter.cancelled =>
        item.status == RequestTrackingStatus.cancelled,
      _RequestStatusFilter.expired =>
        item.status == RequestTrackingStatus.expired,
    };
  }

  bool _matchesDate(RequestTrackingItem item) {
    if (_dateFilter == _RequestDateFilter.all) {
      return true;
    }

    final now = DateTime.now();
    final itemDate = item.requestedAt;
    final startOfToday = DateTime(now.year, now.month, now.day);

    return switch (_dateFilter) {
      _RequestDateFilter.all => true,
      _RequestDateFilter.today => !itemDate.isBefore(startOfToday),
      _RequestDateFilter.last7Days => !itemDate.isBefore(
        now.subtract(const Duration(days: 7)),
      ),
      _RequestDateFilter.last30Days => !itemDate.isBefore(
        now.subtract(const Duration(days: 30)),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estado de solicitudes'),
        actions: [
          IconButton(
            tooltip: 'Actualizar seguimiento',
            onPressed: _isRefreshing
                ? null
                : () => _refreshTracking(showFeedback: true),
            icon: Icon(
              _isRefreshing
                  ? Icons.hourglass_top_rounded
                  : Icons.refresh_rounded,
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
          child: StreamBuilder<List<RequestTrackingItem>>(
            stream: widget.service.watchRequestTracking(
              actorUser: widget.currentUser,
            ),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _TrackingEmptyState(
                      icon: Icons.error_outline_rounded,
                      title: 'No fue posible cargar el seguimiento',
                      message:
                          'Intenta nuevamente en unos segundos. Error: ${snapshot.error}',
                    ),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final allItems = snapshot.data ?? const <RequestTrackingItem>[];
              final filteredItems = allItems
                  .where(_matchesType)
                  .where(_matchesStatus)
                  .where(_matchesDate)
                  .toList(growable: false);

              return RefreshIndicator(
                onRefresh: () => _refreshTracking(showFeedback: false),
                color: AppPalette.amber,
                backgroundColor: AppPalette.storm,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: [
                    _TrackingSummaryCard(
                      items: allItems,
                      currentUser: widget.currentUser,
                      lastManualRefreshAt: _lastManualRefreshAt,
                    ),
                    const SizedBox(height: 18),
                    _TrackingFiltersCard(
                      typeFilter: _typeFilter,
                      statusFilter: _statusFilter,
                      dateFilter: _dateFilter,
                      onTypeChanged: (value) {
                        setState(() {
                          _typeFilter = value;
                        });
                      },
                      onStatusChanged: (value) {
                        setState(() {
                          _statusFilter = value;
                        });
                      },
                      onDateChanged: (value) {
                        setState(() {
                          _dateFilter = value;
                        });
                      },
                      filteredCount: filteredItems.length,
                    ),
                    const SizedBox(height: 18),
                    if (filteredItems.isEmpty)
                      const _TrackingEmptyState(
                        icon: Icons.track_changes_rounded,
                        title: 'No hay solicitudes para este filtro',
                        message:
                            'Ajusta el estado o la fecha para revisar otras solicitudes y su historial.',
                      )
                    else
                      ...filteredItems.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _TrackingRequestCard(item: item),
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

class _TrackingSummaryCard extends StatelessWidget {
  const _TrackingSummaryCard({
    required this.items,
    required this.currentUser,
    required this.lastManualRefreshAt,
  });

  final List<RequestTrackingItem> items;
  final AppUser currentUser;
  final DateTime? lastManualRefreshAt;

  @override
  Widget build(BuildContext context) {
    final openCount = items
        .where(
          (item) =>
              item.status == RequestTrackingStatus.pending ||
              item.status == RequestTrackingStatus.approved ||
              item.status == RequestTrackingStatus.inTransit,
        )
        .length;
    final latest = items.isEmpty ? null : items.first;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF214C9A), Color(0xFF173C78), Color(0xFF102543)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.track_changes_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seguimiento operativo',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currentUser.role == UserRole.seller
                          ? 'Consulta el estado real de tus solicitudes y la evolucion de cada cambio.'
                          : 'Monitorea solicitudes propias o de tu sucursal con historial de estados.',
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
          Row(
            children: [
              Expanded(
                child: _TrackingMetric(
                  label: 'Total',
                  value: '${items.length}',
                  helper: 'Solicitudes visibles',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TrackingMetric(
                  label: 'Abiertas',
                  value: '$openCount',
                  helper: 'Pendientes o en curso',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TrackingMetric(
                  label: 'Ultimo cambio',
                  value: latest == null
                      ? '-'
                      : _formatShortDateTime(latest.lastStatusAt),
                  helper: latest == null ? 'Sin historial' : latest.statusLabel,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            lastManualRefreshAt == null
                ? 'Actualizacion automatica activa por cambios en Firestore.'
                : 'Ultimo refresh manual: ${_formatShortDateTime(lastManualRefreshAt!)}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _TrackingMetric extends StatelessWidget {
  const _TrackingMetric({
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x20FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            helper,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _TrackingFiltersCard extends StatelessWidget {
  const _TrackingFiltersCard({
    required this.typeFilter,
    required this.statusFilter,
    required this.dateFilter,
    required this.onTypeChanged,
    required this.onStatusChanged,
    required this.onDateChanged,
    required this.filteredCount,
  });

  final _RequestTypeFilter typeFilter;
  final _RequestStatusFilter statusFilter;
  final _RequestDateFilter dateFilter;
  final ValueChanged<_RequestTypeFilter> onTypeChanged;
  final ValueChanged<_RequestStatusFilter> onStatusChanged;
  final ValueChanged<_RequestDateFilter> onDateChanged;
  final int filteredCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF102540),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x26FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filtros de seguimiento',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            '$filteredCount resultado(s) con los filtros actuales.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          _FilterSection<_RequestTypeFilter>(
            title: 'Tipo',
            currentValue: typeFilter,
            options: const [
              _FilterOption(value: _RequestTypeFilter.all, label: 'Todas'),
              _FilterOption(
                value: _RequestTypeFilter.reservations,
                label: 'Reservas',
              ),
              _FilterOption(
                value: _RequestTypeFilter.transfers,
                label: 'Traslados',
              ),
            ],
            onSelected: onTypeChanged,
          ),
          const SizedBox(height: 14),
          _FilterSection<_RequestStatusFilter>(
            title: 'Estado',
            currentValue: statusFilter,
            options: const [
              _FilterOption(value: _RequestStatusFilter.all, label: 'Todos'),
              _FilterOption(
                value: _RequestStatusFilter.pending,
                label: 'Pendiente',
              ),
              _FilterOption(
                value: _RequestStatusFilter.approved,
                label: 'Aprobada',
              ),
              _FilterOption(
                value: _RequestStatusFilter.rejected,
                label: 'Rechazada',
              ),
              _FilterOption(
                value: _RequestStatusFilter.inTransit,
                label: 'En transito',
              ),
              _FilterOption(
                value: _RequestStatusFilter.received,
                label: 'Recibida',
              ),
              _FilterOption(
                value: _RequestStatusFilter.completed,
                label: 'Completada',
              ),
              _FilterOption(
                value: _RequestStatusFilter.cancelled,
                label: 'Cancelada',
              ),
              _FilterOption(
                value: _RequestStatusFilter.expired,
                label: 'Vencida',
              ),
            ],
            onSelected: onStatusChanged,
          ),
          const SizedBox(height: 14),
          _FilterSection<_RequestDateFilter>(
            title: 'Fecha de solicitud',
            currentValue: dateFilter,
            options: const [
              _FilterOption(value: _RequestDateFilter.all, label: 'Todo'),
              _FilterOption(value: _RequestDateFilter.today, label: 'Hoy'),
              _FilterOption(
                value: _RequestDateFilter.last7Days,
                label: 'Ultimos 7 dias',
              ),
              _FilterOption(
                value: _RequestDateFilter.last30Days,
                label: 'Ultimos 30 dias',
              ),
            ],
            onSelected: onDateChanged,
          ),
        ],
      ),
    );
  }
}

class _TrackingRequestCard extends StatelessWidget {
  const _TrackingRequestCard({required this.item});

  final RequestTrackingItem item;

  @override
  Widget build(BuildContext context) {
    final accent = _trackingStatusColor(item.status);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF102540),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: Colors.white,
          collapsedIconColor: Colors.white70,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatusChip(label: item.statusLabel, color: accent),
                  const SizedBox(width: 8),
                  _TypeChip(
                    label: item.typeLabel,
                    color: item.type == RequestTrackingType.transfer
                        ? AppPalette.amber
                        : AppPalette.blueSoft,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${item.productName} | ${item.quantity} unidad(es)',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                item.type == RequestTrackingType.transfer
                    ? '${item.primaryBranchName} -> ${item.secondaryBranchName}'
                    : '${item.primaryBranchName}${item.secondaryBranchName.isEmpty ? '' : ' | solicita ${item.secondaryBranchName}'}',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 6),
              Text(
                'Solicitada ${_formatShortDateTime(item.requestedAt)} | ultimo cambio ${_formatRelativeTime(item.lastStatusAt)}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.white60),
              ),
            ],
          ),
          children: [
            const SizedBox(height: 4),
            _DetailInfoRow(label: 'Solicitante', value: item.requesterLabel),
            _DetailInfoRow(label: 'SKU', value: item.sku),
            _DetailInfoRow(label: 'Contexto', value: item.reasonLabel),
            if (item.customerLabel.isNotEmpty)
              _DetailInfoRow(label: 'Cliente', value: item.customerLabel),
            if (item.hasReviewComment)
              _DetailInfoRow(
                label: 'Comentario de revision',
                value: item.reviewComment,
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.history_rounded, color: accent, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Historial de cambios',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...item.history.map((entry) => _HistoryEntryRow(entry: entry)),
          ],
        ),
      ),
    );
  }
}

class _HistoryEntryRow extends StatelessWidget {
  const _HistoryEntryRow({required this.entry});

  final RequestStatusHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = _trackingStatusColor(entry.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _trackingStatusIcon(entry.status),
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatShortDateTime(entry.occurredAt),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white60),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.detail,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackingEmptyState extends StatelessWidget {
  const _TrackingEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF102540),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x26FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
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

class _DetailInfoRow extends StatelessWidget {
  const _DetailInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 136,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white60),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FilterSection<T> extends StatelessWidget {
  const _FilterSection({
    required this.title,
    required this.currentValue,
    required this.options,
    required this.onSelected,
  });

  final String title;
  final T currentValue;
  final List<_FilterOption<T>> options;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options
              .map(
                (option) => ChoiceChip(
                  selected: option.value == currentValue,
                  label: Text(option.label),
                  onSelected: (_) => onSelected(option.value),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _FilterOption<T> {
  const _FilterOption({required this.value, required this.label});

  final T value;
  final String label;
}

Color _trackingStatusColor(RequestTrackingStatus status) {
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

IconData _trackingStatusIcon(RequestTrackingStatus status) {
  return switch (status) {
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

String _formatShortDateTime(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day/$month/${value.year} $hour:$minute';
}

String _formatRelativeTime(DateTime value) {
  final difference = DateTime.now().difference(value);
  if (difference.inMinutes < 1) {
    return 'Hace unos segundos';
  }
  if (difference.inHours < 1) {
    return 'Hace ${difference.inMinutes} min';
  }
  if (difference.inDays < 1) {
    return 'Hace ${difference.inHours} h';
  }
  if (difference.inDays < 7) {
    return 'Hace ${difference.inDays} d';
  }
  return _formatShortDateTime(value);
}
