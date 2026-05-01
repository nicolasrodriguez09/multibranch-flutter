import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../auth/application/auth_service.dart';
import '../application/inventory_workflow_service.dart';
import '../domain/models.dart';
import 'branch_panel_drawer.dart';

class NotificationInboxPage extends StatefulWidget {
  const NotificationInboxPage({
    super.key,
    required this.service,
    required this.currentUser,
    this.authService,
  });

  final InventoryWorkflowService service;
  final AppUser currentUser;
  final AuthService? authService;

  @override
  State<NotificationInboxPage> createState() => _NotificationInboxPageState();
}

class _NotificationInboxPageState extends State<NotificationInboxPage> {
  bool _showUnreadOnly = false;
  bool _isMarkingAll = false;
  final Set<String> _markingIds = <String>{};

  void _showStatusMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _markAsRead(AppNotification notification) async {
    if (notification.isRead || _markingIds.contains(notification.id)) {
      return;
    }

    setState(() {
      _markingIds.add(notification.id);
    });

    try {
      await widget.service.markNotificationAsRead(
        actorUser: widget.currentUser,
        notificationId: notification.id,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showStatusMessage('No se pudo actualizar la notificacion: $error');
    } finally {
      if (mounted) {
        setState(() {
          _markingIds.remove(notification.id);
        });
      }
    }
  }

  Future<void> _markAllAsRead(int unreadCount) async {
    if (_isMarkingAll || unreadCount == 0) {
      return;
    }

    setState(() {
      _isMarkingAll = true;
    });

    try {
      final updatedCount = await widget.service.markAllNotificationsAsRead(
        actorUser: widget.currentUser,
      );
      if (!mounted || updatedCount == 0) {
        return;
      }
      _showStatusMessage(
        updatedCount == 1
            ? '1 notificacion marcada como leida.'
            : '$updatedCount notificaciones marcadas como leidas.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showStatusMessage('No se pudo actualizar la bandeja: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isMarkingAll = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: BranchPanelDrawer(
        service: widget.service,
        currentUser: widget.currentUser,
        currentDestination: BranchPanelDestination.notifications,
        authService: widget.authService,
      ),
      appBar: AppBar(title: const Text('Notificaciones')),
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
          child: StreamBuilder<List<AppNotification>>(
            stream: widget.service.watchNotifications(
              actorUser: widget.currentUser,
              limit: 60,
            ),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _EmptyNotificationState(
                      icon: Icons.error_outline_rounded,
                      title: 'No fue posible cargar la bandeja',
                      message:
                          'Intenta nuevamente en unos segundos. El error recibido fue: ${snapshot.error}',
                    ),
                  ),
                );
              }

              final notifications = snapshot.data ?? const <AppNotification>[];
              final unreadCount = notifications
                  .where((item) => !item.isRead)
                  .length;
              final visibleNotifications = _showUnreadOnly
                  ? notifications.where((item) => !item.isRead).toList()
                  : notifications;

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  _NotificationSummaryCard(
                    totalCount: notifications.length,
                    unreadCount: unreadCount,
                    latestNotificationAt: notifications.isEmpty
                        ? null
                        : notifications.first.createdAt,
                    showUnreadOnly: _showUnreadOnly,
                    isMarkingAll: _isMarkingAll,
                    onToggleUnreadOnly: (value) {
                      setState(() {
                        _showUnreadOnly = value;
                      });
                    },
                    onMarkAllAsRead: unreadCount == 0
                        ? null
                        : () => _markAllAsRead(unreadCount),
                  ),
                  const SizedBox(height: 18),
                  if (visibleNotifications.isEmpty)
                    _EmptyNotificationState(
                      icon: _showUnreadOnly
                          ? Icons.mark_email_read_rounded
                          : Icons.notifications_off_rounded,
                      title: _showUnreadOnly
                          ? 'No tienes notificaciones sin leer'
                          : 'No hay notificaciones registradas',
                      message: _showUnreadOnly
                          ? 'Las aprobaciones, rechazos y eventos personales apareceran aqui cuando ocurran.'
                          : 'Cuando una reserva o un traslado cambie de estado, veras el resultado en esta bandeja.',
                    )
                  else
                    ...visibleNotifications.map(
                      (notification) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _NotificationCard(
                          notification: notification,
                          isUpdating: _markingIds.contains(notification.id),
                          onMarkAsRead: () => _markAsRead(notification),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NotificationSummaryCard extends StatelessWidget {
  const _NotificationSummaryCard({
    required this.totalCount,
    required this.unreadCount,
    required this.latestNotificationAt,
    required this.showUnreadOnly,
    required this.isMarkingAll,
    required this.onToggleUnreadOnly,
    required this.onMarkAllAsRead,
  });

  final int totalCount;
  final int unreadCount;
  final DateTime? latestNotificationAt;
  final bool showUnreadOnly;
  final bool isMarkingAll;
  final ValueChanged<bool> onToggleUnreadOnly;
  final VoidCallback? onMarkAllAsRead;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF8B121E), Color(0xFF551018), Color(0xFF151016)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0x33FF2636)),
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
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bandeja personal',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Aprobaciones, rechazos y eventos relevantes para tu operacion.',
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
                child: _SummaryMetric(
                  label: 'Sin leer',
                  value: '$unreadCount',
                  helper: unreadCount == 1 ? 'Pendiente' : 'Pendientes',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryMetric(
                  label: 'Total',
                  value: '$totalCount',
                  helper: 'En bandeja',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryMetric(
                  label: 'Ultimo evento',
                  value: latestNotificationAt == null
                      ? '-'
                      : _formatShortDateTime(latestNotificationAt!),
                  helper: latestNotificationAt == null
                      ? 'Sin actividad'
                      : _formatRelativeTime(latestNotificationAt!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilterChip(
                selected: showUnreadOnly,
                onSelected: onToggleUnreadOnly,
                label: const Text('Solo no leidas'),
              ),
              FilledButton.tonalIcon(
                onPressed: onMarkAllAsRead,
                icon: isMarkingAll
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.done_all_rounded),
                label: const Text('Marcar todo como leido'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
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
        border: Border.all(color: const Color(0x24FFFFFF)),
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

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.isUpdating,
    required this.onMarkAsRead,
  });

  final AppNotification notification;
  final bool isUpdating;
  final VoidCallback onMarkAsRead;

  @override
  Widget build(BuildContext context) {
    final visual = _resolveNotificationVisual(notification);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: notification.isRead || isUpdating ? null : onMarkAsRead,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: notification.isRead
                ? const Color(0xFF251114)
                : const Color(0xFF2A1014),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: notification.isRead
                  ? const Color(0x1FFF2636)
                  : visual.color.withValues(alpha: 0.48),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: visual.color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(visual.icon, color: visual.color),
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
                                notification.title,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _NotificationStatusChip(
                              label: notification.isRead ? 'Leida' : 'Nueva',
                              color: notification.isRead
                                  ? AppPalette.cyan
                                  : visual.color,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_formatNotificationType(notification.type)} | ${_formatRelativeTime(notification.createdAt)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                notification.message,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppPalette.textPrimary),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _NotificationMetaChip(
                    icon: Icons.sell_rounded,
                    label: 'Referencia ${notification.referenceId}',
                  ),
                  _NotificationMetaChip(
                    icon: Icons.schedule_rounded,
                    label: _formatShortDateTime(notification.createdAt),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      notification.isRead
                          ? 'La notificacion ya fue revisada.'
                          : 'Toca la tarjeta o usa el boton para marcarla como leida.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (isUpdating)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (!notification.isRead)
                    TextButton.icon(
                      onPressed: onMarkAsRead,
                      icon: const Icon(Icons.done_rounded),
                      label: const Text('Marcar leida'),
                    )
                  else
                    Icon(
                      Icons.done_all_rounded,
                      color: AppPalette.mint.withValues(alpha: 0.92),
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

class _NotificationStatusChip extends StatelessWidget {
  const _NotificationStatusChip({required this.label, required this.color});

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

class _NotificationMetaChip extends StatelessWidget {
  const _NotificationMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x18FFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _EmptyNotificationState extends StatelessWidget {
  const _EmptyNotificationState({
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
        color: const Color(0xFF17191F),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x26FF2636)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
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

class _NotificationVisual {
  const _NotificationVisual({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}

_NotificationVisual _resolveNotificationVisual(AppNotification notification) {
  final title = notification.title.toLowerCase();
  if (title.contains('rechazada')) {
    return const _NotificationVisual(
      icon: Icons.cancel_rounded,
      color: AppPalette.danger,
    );
  }
  if (title.contains('aprobada')) {
    return const _NotificationVisual(
      icon: Icons.check_circle_rounded,
      color: AppPalette.mint,
    );
  }
  return switch (notification.type) {
    'transfer' => const _NotificationVisual(
      icon: Icons.local_shipping_rounded,
      color: AppPalette.amber,
    ),
    'reservation' => const _NotificationVisual(
      icon: Icons.bookmark_added_rounded,
      color: AppPalette.blueSoft,
    ),
    _ => const _NotificationVisual(
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
