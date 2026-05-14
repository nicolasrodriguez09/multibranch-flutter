import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../application/inventory_workflow_service.dart';
import '../domain/models.dart';
import '../domain/role_permissions.dart';

Future<void> showRequestTraceabilityDialog(
  BuildContext context, {
  required InventoryWorkflowService service,
  required AppUser currentUser,
  required RequestTrackingItem item,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => switch (item.type) {
      RequestTrackingType.transfer => _TransferRequestTraceabilityDialog(
        service: service,
        currentUser: currentUser,
        transferId: item.id,
      ),
      RequestTrackingType.reservation => _ReservationRequestTraceabilityDialog(
        service: service,
        currentUser: currentUser,
        reservationId: item.id,
      ),
    },
  );
}

class _TransferRequestTraceabilityDialog extends StatefulWidget {
  const _TransferRequestTraceabilityDialog({
    required this.service,
    required this.currentUser,
    required this.transferId,
  });

  final InventoryWorkflowService service;
  final AppUser currentUser;
  final String transferId;

  @override
  State<_TransferRequestTraceabilityDialog> createState() =>
      _TransferRequestTraceabilityDialogState();
}

class _TransferRequestTraceabilityDialogState
    extends State<_TransferRequestTraceabilityDialog> {
  late Future<TransferTraceabilityData> _future;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _future = _loadDetail();
  }

  Future<TransferTraceabilityData> _loadDetail() {
    return widget.service.fetchTransferTraceability(
      actorUser: widget.currentUser,
      transferId: widget.transferId,
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _runTransferAction({
    required Future<TransferRequest> Function() action,
    required String successMessage,
  }) async {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await action();
      if (!mounted) {
        return;
      }
      setState(() {
        _future = _loadDetail();
      });
      _showMessage(successMessage);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('No fue posible completar la accion: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF08090C),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880, maxHeight: 780),
        child: FutureBuilder<TransferTraceabilityData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _TraceabilityErrorState(
                title: 'No se pudo cargar la trazabilidad del traslado.',
                identifier: widget.transferId,
                error: snapshot.error,
              );
            }

            final detail = snapshot.requireData;
            final transfer = detail.transfer;
            final canDispatch =
                widget.currentUser.can(AppPermission.dispatchTransfer) &&
                widget.currentUser.canAccessBranch(transfer.fromBranchId) &&
                transfer.status == TransferStatus.approved;
            final canReceive =
                widget.currentUser.can(AppPermission.receiveTransfer) &&
                widget.currentUser.canAccessBranch(transfer.toBranchId) &&
                transfer.status == TransferStatus.inTransit;

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
                          _TraceabilityActionPanel(
                            title: 'Operacion habilitada',
                            message: _transferActionMessage(
                              transfer: transfer,
                              canDispatch: canDispatch,
                              canReceive: canReceive,
                            ),
                            actions: [
                              if (canDispatch)
                                FilledButton.icon(
                                  onPressed: _isSubmitting
                                      ? null
                                      : () => _runTransferAction(
                                          action: () => widget.service
                                              .markTransferInTransit(
                                                actorUser: widget.currentUser,
                                                transferId: transfer.id,
                                              ),
                                          successMessage:
                                              'El traslado fue marcado en transito.',
                                        ),
                                  icon: _isSubmitting
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.local_shipping_rounded,
                                        ),
                                  label: const Text('Marcar despachado'),
                                ),
                              if (canReceive)
                                FilledButton.icon(
                                  onPressed: _isSubmitting
                                      ? null
                                      : () => _runTransferAction(
                                          action: () =>
                                              widget.service.receiveTransfer(
                                                actorUser: widget.currentUser,
                                                transferId: transfer.id,
                                              ),
                                          successMessage:
                                              'El traslado fue recibido correctamente.',
                                        ),
                                  icon: _isSubmitting
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.inventory_2_rounded),
                                  label: const Text('Confirmar recepcion'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _TraceabilityMetricCard(
                                label: 'Cantidad pedida',
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
                              _TraceabilityMetricCard(
                                label: 'Movido',
                                value: transfer.approvedAt == null
                                    ? '0'
                                    : '${transfer.quantity}',
                                accent: AppPalette.cyan,
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
                                  label: 'Comentario de revision',
                                  value: transfer.reviewComment.trim().isEmpty
                                      ? 'Sin comentario'
                                      : transfer.reviewComment,
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
                                    transfer.requestedByName.ifEmpty(
                                      transfer.requestedBy,
                                    ),
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
                                'No hay eventos auditados para este traslado.',
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
                                      child: _AuditTimelineTile(auditLog: item),
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

class _ReservationRequestTraceabilityDialog extends StatelessWidget {
  const _ReservationRequestTraceabilityDialog({
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
      backgroundColor: const Color(0xFF08090C),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880, maxHeight: 780),
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
              return _TraceabilityErrorState(
                title: 'No se pudo cargar la trazabilidad de la solicitud.',
                identifier: reservationId,
                error: snapshot.error,
              );
            }

            final detail = snapshot.requireData;
            final reservation = detail.reservation;

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
                                label: 'Cantidad pedida',
                                value: '${reservation.quantity}',
                                accent: AppPalette.blueSoft,
                              ),
                              _TraceabilityMetricCard(
                                label: 'SKU',
                                value: reservation.sku,
                                accent: AppPalette.amber,
                              ),
                              _TraceabilityMetricCard(
                                label: 'Creada',
                                value: _formatDateTimeStamp(
                                  reservation.createdAt,
                                ),
                                accent: AppPalette.mint,
                              ),
                              _TraceabilityMetricCard(
                                label: 'Vigencia',
                                value: _formatDateTimeStamp(
                                  reservation.expiresAt,
                                ),
                                accent: AppPalette.cyan,
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
                                  label: 'Sucursal solicitante',
                                  value:
                                      reservation.requestingBranchName.isEmpty
                                      ? 'Sin sucursal solicitante'
                                      : '${reservation.requestingBranchName} | ${reservation.requestingBranchId}',
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
                                  label: 'Comentario de revision',
                                  value:
                                      reservation.reviewComment.trim().isEmpty
                                      ? 'Sin comentario'
                                      : reservation.reviewComment,
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
                                    reservation.requestedByName.ifEmpty(
                                      reservation.reservedBy,
                                    ),
                                role:
                                    detail.requestLog?.actorRole.displayName ??
                                    detail.requesterUser?.role.displayName ??
                                    'No disponible',
                                branch:
                                    detail.requestLog?.branchName ??
                                    detail.requesterUser?.branchId ??
                                    reservation.requestingBranchName.ifEmpty(
                                      reservation.branchName,
                                    ),
                                timestamp:
                                    detail.requestLog?.createdAt ??
                                    reservation.createdAt,
                              ),
                              _TraceabilityActorCard(
                                title: 'Aprobacion',
                                icon: Icons.verified_user_rounded,
                                name:
                                    detail.approvalLog?.actorName ??
                                    (reservation.approvedBy ?? 'Pendiente'),
                                role:
                                    detail.approvalLog?.actorRole.displayName ??
                                    (reservation.approvedBy == null
                                        ? 'Pendiente'
                                        : 'No disponible'),
                                branch:
                                    detail.approvalLog?.branchName ??
                                    reservation.branchName,
                                timestamp:
                                    detail.approvalLog?.createdAt ??
                                    reservation.approvedAt,
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          const _TraceabilitySectionTitle(
                            title: 'Inventario vinculado',
                          ),
                          const SizedBox(height: 10),
                          _InventoryTraceabilityCard(
                            title: 'Inventario actual',
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
                                'No hay eventos auditados para esta solicitud.',
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
                                      child: _AuditTimelineTile(auditLog: item),
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

class _TraceabilityErrorState extends StatelessWidget {
  const _TraceabilityErrorState({
    required this.title,
    required this.identifier,
    required this.error,
  });

  final String title;
  final String identifier;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Text(
            '$identifier\n$error',
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
}

class _TraceabilityActionPanel extends StatelessWidget {
  const _TraceabilityActionPanel({
    required this.title,
    required this.message,
    required this.actions,
  });

  final String title;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF3A1116), Color(0xFF151016)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0x33FF2636)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(spacing: 10, runSpacing: 10, children: actions),
          ],
        ],
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
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
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
        color: const Color(0xFF17191F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x26FF2636)),
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
      width: 170,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
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
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
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
            width: 152,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white60),
            ),
          ),
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
    return SizedBox(
      width: 190,
      child: _TraceabilityBlock(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppPalette.amber, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              name,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              role,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 4),
            Text(
              branch,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white60),
            ),
            const SizedBox(height: 8),
            Text(
              timestamp == null
                  ? 'Pendiente'
                  : _formatDateTimeStamp(timestamp!),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
          ],
        ),
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
    return SizedBox(
      width: 320,
      child: _TraceabilityBlock(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              branchLabel,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: accent),
            ),
            const SizedBox(height: 12),
            if (inventory == null)
              Text(
                'No existe inventario registrado para esta combinacion.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
              )
            else
              Column(
                children: [
                  _TraceabilityDataRow(
                    label: 'Fisico',
                    value: '${inventory!.stock}',
                  ),
                  _TraceabilityDataRow(
                    label: 'Reservado',
                    value: '${inventory!.reservedStock}',
                  ),
                  _TraceabilityDataRow(
                    label: 'Disponible',
                    value: '${inventory!.availableStock}',
                  ),
                  _TraceabilityDataRow(
                    label: 'En camino',
                    value: '${inventory!.incomingStock}',
                  ),
                  _TraceabilityDataRow(
                    label: 'Minimo',
                    value: '${inventory!.minimumStock}',
                  ),
                  _TraceabilityDataRow(
                    label: 'Actualizado',
                    value: _formatDateTimeStamp(inventory!.updatedAt),
                    isLast: true,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _AuditTimelineTile extends StatelessWidget {
  const _AuditTimelineTile({required this.auditLog});

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
                                color: const Color(0x26FF2636),
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

String _transferActionMessage({
  required TransferRequest transfer,
  required bool canDispatch,
  required bool canReceive,
}) {
  if (canDispatch) {
    return 'La solicitud ya fue aprobada. Puedes marcar que el producto salio de ${transfer.fromBranchName} para dejar constancia operativa y auditada.';
  }
  if (canReceive) {
    return 'El traslado ya viene en camino a ${transfer.toBranchName}. Confirma la recepcion para impactar inventario y cerrar la trazabilidad.';
  }
  return switch (transfer.status) {
    TransferStatus.pending =>
      'El traslado sigue pendiente de aprobacion. Aun no debe impactar inventario.',
    TransferStatus.approved =>
      'El traslado esta aprobado y espera despacho desde la sucursal origen.',
    TransferStatus.inTransit =>
      'El traslado ya fue despachado y espera confirmacion de recepcion en destino.',
    TransferStatus.received =>
      'El traslado ya fue recibido. El inventario destino ya se actualizo.',
    TransferStatus.rejected =>
      'La solicitud fue rechazada. Revisa el comentario y la linea de tiempo auditada.',
    TransferStatus.cancelled =>
      'La solicitud fue cancelada y ya no admite acciones operativas.',
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

String _formatAuditAction(String value) {
  return switch (value.trim().toLowerCase()) {
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
    'transfer_requested' => const Color(0xFFFF3B47),
    'transfer_approved' => const Color(0xFFFF6B73),
    'transfer_rejected' => const Color(0xFFC24949),
    'transfer_in_transit' => const Color(0xFFFF9AA1),
    'transfer_received' => const Color(0xFFFF6B73),
    'reservation_created' => const Color(0xFFFF6B73),
    'reservation_approved' => const Color(0xFFFF6B73),
    'reservation_rejected' => const Color(0xFFC24949),
    'reservation_completed' => const Color(0xFFFF6B73),
    'reservation_cancelled' => const Color(0xFFC24949),
    'reservation_expired' => const Color(0xFFFF3B47),
    'reservation_updated' => const Color(0xFF5A1018),
    _ => const Color(0xFF5A1018),
  };
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

extension on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : this;
}
