import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../auth/application/auth_service.dart';
import '../application/inventory_workflow_service.dart';
import '../domain/models.dart';
import 'branch_panel_drawer.dart';

class ApprovalRequestsPage extends StatefulWidget {
  const ApprovalRequestsPage({
    super.key,
    required this.service,
    required this.currentUser,
    this.authService,
  });

  final InventoryWorkflowService service;
  final AppUser currentUser;
  final AuthService? authService;

  @override
  State<ApprovalRequestsPage> createState() => _ApprovalRequestsPageState();
}

class _ApprovalRequestsPageState extends State<ApprovalRequestsPage> {
  final Set<String> _busyItems = <String>{};

  Future<void> _refresh() async {
    await widget.service
        .watchApprovalQueue(actorUser: widget.currentUser)
        .first;
  }

  Future<void> _decideReservation({
    required Reservation reservation,
    required bool approve,
  }) async {
    final comment = await _openDecisionDialog(
      title: approve ? 'Aprobar reserva' : 'Rechazar reserva',
      subtitle: approve
          ? 'Puedes registrar una observacion operativa antes de activar la reserva.'
          : 'Debes registrar el motivo del rechazo para notificar al solicitante.',
      actionLabel: approve ? 'Aprobar' : 'Rechazar',
      requireComment: !approve,
    );
    if (!mounted || comment == null) {
      return;
    }

    final key = 'reservation_${reservation.id}';
    setState(() {
      _busyItems.add(key);
    });

    try {
      if (approve) {
        await widget.service.approveReservation(
          actorUser: widget.currentUser,
          reservationId: reservation.id,
          reviewComment: comment,
        );
      } else {
        await widget.service.rejectReservation(
          actorUser: widget.currentUser,
          reservationId: reservation.id,
          reviewComment: comment,
        );
      }

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? 'Reserva ${reservation.id} aprobada.'
                : 'Reserva ${reservation.id} rechazada.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo actualizar: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _busyItems.remove(key);
        });
      }
    }
  }

  Future<void> _decideTransfer({
    required TransferRequest transfer,
    required bool approve,
  }) async {
    final comment = await _openDecisionDialog(
      title: approve ? 'Aprobar traslado' : 'Rechazar traslado',
      subtitle: approve
          ? 'Puedes dejar una observacion para despacho o coordinacion interna.'
          : 'Debes registrar el motivo del rechazo para notificar al solicitante.',
      actionLabel: approve ? 'Aprobar' : 'Rechazar',
      requireComment: !approve,
    );
    if (!mounted || comment == null) {
      return;
    }

    final key = 'transfer_${transfer.id}';
    setState(() {
      _busyItems.add(key);
    });

    try {
      if (approve) {
        await widget.service.approveTransfer(
          actorUser: widget.currentUser,
          transferId: transfer.id,
          reviewComment: comment,
        );
      } else {
        await widget.service.rejectTransfer(
          actorUser: widget.currentUser,
          transferId: transfer.id,
          reviewComment: comment,
        );
      }

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? 'Traslado ${transfer.id} aprobado.'
                : 'Traslado ${transfer.id} rechazado.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo actualizar: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _busyItems.remove(key);
        });
      }
    }
  }

  Future<String?> _openDecisionDialog({
    required String title,
    required String subtitle,
    required String actionLabel,
    required bool requireComment,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => _DecisionDialog(
        title: title,
        subtitle: subtitle,
        actionLabel: actionLabel,
        requireComment: requireComment,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: BranchPanelDrawer(
        service: widget.service,
        currentUser: widget.currentUser,
        currentDestination: BranchPanelDestination.approvals,
        authService: widget.authService,
      ),
      appBar: AppBar(
        title: const Text('Bandeja de aprobaciones'),
        actions: [
          IconButton(
            tooltip: 'Actualizar bandeja',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Container(
        color: const Color(0xFF08090C),
        child: SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: _refresh,
            color: AppPalette.amber,
            backgroundColor: AppPalette.storm,
            child: StreamBuilder<ApprovalQueueData>(
              stream: widget.service.watchApprovalQueue(
                actorUser: widget.currentUser,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    children: [
                      _ApprovalErrorCard(message: '${snapshot.error}'),
                    ],
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.requireData;
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  children: [
                    _ApprovalHeader(
                      currentUser: widget.currentUser,
                      data: data,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _ApprovalMetricTile(
                            label: 'Pendientes totales',
                            value: '${data.totalPending}',
                            accent: AppPalette.amber,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ApprovalMetricTile(
                            label: 'Reservas',
                            value: '${data.pendingReservations.length}',
                            accent: AppPalette.blueSoft,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ApprovalMetricTile(
                            label: 'Traslados',
                            value: '${data.pendingTransfers.length}',
                            accent: AppPalette.mint,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _ApprovalSectionCard(
                      title: 'Reservas pendientes',
                      subtitle:
                          'Solicitudes que deben validarse antes de comprometer stock real.',
                      emptyMessage:
                          'No hay reservas pendientes dentro del alcance actual.',
                      hasItems: data.pendingReservations.isNotEmpty,
                      child: Column(
                        children: data.pendingReservations
                            .map(
                              (reservation) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _PendingReservationCard(
                                  reservation: reservation,
                                  isBusy: _busyItems.contains(
                                    'reservation_${reservation.id}',
                                  ),
                                  onApprove: () => _decideReservation(
                                    reservation: reservation,
                                    approve: true,
                                  ),
                                  onReject: () => _decideReservation(
                                    reservation: reservation,
                                    approve: false,
                                  ),
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ApprovalSectionCard(
                      title: 'Traslados pendientes',
                      subtitle:
                          'Solicitudes entre sucursales que requieren decision del supervisor origen.',
                      emptyMessage:
                          'No hay traslados pendientes dentro del alcance actual.',
                      hasItems: data.pendingTransfers.isNotEmpty,
                      child: Column(
                        children: data.pendingTransfers
                            .map(
                              (transfer) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _PendingTransferCard(
                                  transfer: transfer,
                                  isBusy: _busyItems.contains(
                                    'transfer_${transfer.id}',
                                  ),
                                  onApprove: () => _decideTransfer(
                                    transfer: transfer,
                                    approve: true,
                                  ),
                                  onReject: () => _decideTransfer(
                                    transfer: transfer,
                                    approve: false,
                                  ),
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ApprovalHeader extends StatelessWidget {
  const _ApprovalHeader({required this.currentUser, required this.data});

  final AppUser currentUser;
  final ApprovalQueueData data;

  @override
  Widget build(BuildContext context) {
    final scopeLabel = data.scopeIsGlobal
        ? 'Vista global de aprobaciones'
        : 'Sucursal ${data.scopeLabel}';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF17191F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x26FF2636)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Control de solicitudes',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            currentUser.role == UserRole.admin
                ? 'Centraliza la decision sobre reservas y traslados pendientes en todas las sucursales.'
                : 'Aprueba o rechaza solicitudes que comprometen stock de tu sucursal antes de afectar la operacion.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ApprovalInfoPill(label: scopeLabel),
              _ApprovalInfoPill(
                label: data.hasItems
                    ? '${data.totalPending} solicitudes por revisar'
                    : 'Sin pendientes por revisar',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ApprovalMetricTile extends StatelessWidget {
  const _ApprovalMetricTile({
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _ApprovalSectionCard extends StatelessWidget {
  const _ApprovalSectionCard({
    required this.title,
    required this.subtitle,
    required this.emptyMessage,
    required this.child,
    required this.hasItems,
  });

  final String title;
  final String subtitle;
  final String emptyMessage;
  final Widget child;
  final bool hasItems;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF17191F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x26FF2636)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          if (hasItems)
            child
          else
            Text(
              emptyMessage,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
        ],
      ),
    );
  }
}

class _PendingReservationCard extends StatelessWidget {
  const _PendingReservationCard({
    required this.reservation,
    required this.isBusy,
    required this.onApprove,
    required this.onReject,
  });

  final Reservation reservation;
  final bool isBusy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final requestingBranch = reservation.requestingBranchName.isNotEmpty
        ? reservation.requestingBranchName
        : (reservation.requestingBranchId.isNotEmpty
              ? reservation.requestingBranchId
              : 'Sucursal solicitante');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x26FF2636)),
      ),
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
                      reservation.productName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${reservation.branchName} | ${reservation.quantity} unidad(es)',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const _StatusBadge(label: 'Pendiente', color: AppPalette.amber),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ApprovalInfoPill(label: 'Cliente ${reservation.customerName}'),
              _ApprovalInfoPill(label: 'Solicita $requestingBranch'),
              _ApprovalInfoPill(
                label:
                    'Creada ${_formatDateTime(reservation.createdAt)} | vence ${_formatDateTime(reservation.expiresAt)}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DetailRow(label: 'Solicitante', value: _requesterLabel(reservation)),
          _DetailRow(
            label: 'Sucursal reservada',
            value: reservation.branchName,
          ),
          if (reservation.customerPhone.isNotEmpty)
            _DetailRow(label: 'Telefono', value: reservation.customerPhone),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isBusy ? null : onReject,
                  child: Text(isBusy ? 'Procesando...' : 'Rechazar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: isBusy ? null : onApprove,
                  child: Text(isBusy ? 'Procesando...' : 'Aprobar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _requesterLabel(Reservation reservation) {
    if (reservation.requestedByName.isNotEmpty) {
      return reservation.requestedByName;
    }
    return reservation.reservedBy;
  }
}

class _PendingTransferCard extends StatelessWidget {
  const _PendingTransferCard({
    required this.transfer,
    required this.isBusy,
    required this.onApprove,
    required this.onReject,
  });

  final TransferRequest transfer;
  final bool isBusy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x26FF2636)),
      ),
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
                      transfer.productName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${transfer.fromBranchName} -> ${transfer.toBranchName} | ${transfer.quantity} unidad(es)',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const _StatusBadge(label: 'Pendiente', color: AppPalette.amber),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ApprovalInfoPill(label: 'SKU ${transfer.sku}'),
              _ApprovalInfoPill(
                label: 'Solicitado ${_formatDateTime(transfer.requestedAt)}',
              ),
              _ApprovalInfoPill(
                label:
                    'Solicita ${transfer.requestedByName.isNotEmpty ? transfer.requestedByName : transfer.requestedBy}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DetailRow(label: 'Motivo', value: transfer.reason),
          if (transfer.notes.isNotEmpty)
            _DetailRow(label: 'Notas internas', value: transfer.notes),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isBusy ? null : onReject,
                  child: Text(isBusy ? 'Procesando...' : 'Rechazar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: isBusy ? null : onApprove,
                  child: Text(isBusy ? 'Procesando...' : 'Aprobar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DecisionDialog extends StatefulWidget {
  const _DecisionDialog({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.requireComment,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final bool requireComment;

  @override
  State<_DecisionDialog> createState() => _DecisionDialogState();
}

class _DecisionDialogState extends State<_DecisionDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final comment = _controller.text.trim();
    if (widget.requireComment && comment.isEmpty) {
      setState(() {
        _error = 'Debes registrar un comentario para continuar.';
      });
      return;
    }
    Navigator.of(context).pop(comment);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF17191F),
      title: Text(widget.title),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              maxLines: 4,
              autofocus: true,
              decoration: InputDecoration(
                labelText: widget.requireComment
                    ? 'Motivo o comentario'
                    : 'Comentario opcional',
                errorText: _error,
              ),
              onChanged: (_) {
                if (_error != null) {
                  setState(() {
                    _error = null;
                  });
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.actionLabel)),
      ],
    );
  }
}

class _ApprovalErrorCard extends StatelessWidget {
  const _ApprovalErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF17191F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x26FF2636)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No se pudo cargar la bandeja',
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

class _ApprovalInfoPill extends StatelessWidget {
  const _ApprovalInfoPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x26FF2636)),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: Colors.white70),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

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
            width: 132,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white60),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day/$month ${value.year} $hour:$minute';
}
