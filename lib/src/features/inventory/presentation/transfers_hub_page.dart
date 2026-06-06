import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../auth/application/auth_service.dart';
import '../application/inventory_workflow_service.dart';
import '../domain/models.dart';
import '../domain/role_permissions.dart';
import 'branch_panel_drawer.dart';
import 'request_tracking_traceability_dialogs.dart';
import 'transfer_request_page.dart';

class TransfersHubPage extends StatefulWidget {
  const TransfersHubPage({
    super.key,
    required this.service,
    required this.currentUser,
    this.authService,
    this.initialProductId,
  });

  final InventoryWorkflowService service;
  final AppUser currentUser;
  final AuthService? authService;
  final String? initialProductId;

  @override
  State<TransfersHubPage> createState() => _TransfersHubPageState();
}

class _TransfersHubPageState extends State<TransfersHubPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final bool _isSupervisor;
  
  @override
  void initState() {
    super.initState();
    _isSupervisor = widget.currentUser.role == UserRole.supervisor || widget.currentUser.role == UserRole.admin;
    _tabController = TabController(length: _isSupervisor ? 3 : 1, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: BranchPanelDrawer(
        service: widget.service,
        currentUser: widget.currentUser,
        currentDestination: BranchPanelDestination.transfersHub,
        authService: widget.authService,
      ),
      appBar: AppBar(
        title: const Text('Gestión de traslados'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppPalette.amber,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppPalette.amber,
          tabs: _isSupervisor 
            ? const [
                Tab(text: 'Por Recibir'),
                Tab(text: 'Por Despachar'),
                Tab(text: 'Nueva Solicitud'),
              ]
            : const [
                Tab(text: 'Por Recibir'),
              ],
        ),
      ),
      body: Container(
        color: const Color(0xFF08090C),
        child: SafeArea(
          top: false,
          child: TabBarView(
            controller: _tabController,
            children: _isSupervisor
              ? [
                  _IncomingTransfersTab(service: widget.service, currentUser: widget.currentUser),
                  _OutgoingTransfersTab(service: widget.service, currentUser: widget.currentUser),
                  TransferRequestPage(
                    service: widget.service, 
                    currentUser: widget.currentUser, 
                    authService: widget.authService, 
                    initialProductId: widget.initialProductId,
                    isTab: true,
                  ),
                ]
              : [
                  _IncomingTransfersTab(service: widget.service, currentUser: widget.currentUser),
                ],
          ),
        ),
      ),
    );
  }
}

class _IncomingTransfersTab extends StatelessWidget {
  const _IncomingTransfersTab({required this.service, required this.currentUser});

  final InventoryWorkflowService service;
  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TransferRequest>>(
      stream: service.watchIncomingTransfers(actorUser: currentUser),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final transfers = snapshot.requireData.where((t) {
          if (currentUser.role != UserRole.admin && t.toBranchId != currentUser.branchId) return false;
          return t.status == TransferStatus.pending || 
                 t.status == TransferStatus.approved || 
                 t.status == TransferStatus.inTransit;
        }).toList();

        if (transfers.isEmpty) {
          return _EmptyTabState(
            icon: Icons.inventory_2_rounded,
            title: 'No hay traslados entrantes',
            message: 'No tienes mercancía pendiente de recibir en tu sede en este momento.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: transfers.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return _TransferCard(
              transfer: transfers[index],
              service: service,
              currentUser: currentUser,
              isIncoming: true,
            );
          },
        );
      },
    );
  }
}

class _OutgoingTransfersTab extends StatelessWidget {
  const _OutgoingTransfersTab({required this.service, required this.currentUser});

  final InventoryWorkflowService service;
  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TransferRequest>>(
      stream: service.watchOutgoingTransfers(actorUser: currentUser),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final transfers = snapshot.requireData.where((t) {
          if (currentUser.role != UserRole.admin && t.fromBranchId != currentUser.branchId) return false;
          return t.status == TransferStatus.pending || 
                 t.status == TransferStatus.approved || 
                 t.status == TransferStatus.inTransit;
        }).toList();

        if (transfers.isEmpty) {
          return _EmptyTabState(
            icon: Icons.outbox_rounded,
            title: 'No hay traslados salientes',
            message: 'No tienes solicitudes pendientes por aprobar o despachar.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: transfers.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return _TransferCard(
              transfer: transfers[index],
              service: service,
              currentUser: currentUser,
              isIncoming: false,
            );
          },
        );
      },
    );
  }
}

class _TransferCard extends StatefulWidget {
  const _TransferCard({
    required this.transfer,
    required this.service,
    required this.currentUser,
    required this.isIncoming,
  });

  final TransferRequest transfer;
  final InventoryWorkflowService service;
  final AppUser currentUser;
  final bool isIncoming;

  @override
  State<_TransferCard> createState() => _TransferCardState();
}

class _TransferCardState extends State<_TransferCard> {
  bool _isBusy = false;

  Future<void> _handleAction(String action) async {
    setState(() => _isBusy = true);
    try {
      if (action == 'approve') {
        await widget.service.approveTransfer(
          actorUser: widget.currentUser, 
          transferId: widget.transfer.id, 
          reviewComment: 'Aprobado desde Gestión',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Traslado aprobado.')));
      } else if (action == 'reject') {
        await widget.service.rejectTransfer(
          actorUser: widget.currentUser, 
          transferId: widget.transfer.id, 
          reviewComment: 'Rechazado desde Gestión',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Traslado rechazado.')));
      } else if (action == 'dispatch') {
        await widget.service.markTransferInTransit(
          actorUser: widget.currentUser, 
          transferId: widget.transfer.id, 
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Traslado marcado como despachado.')));
      } else if (action == 'receive') {
        await widget.service.receiveTransfer(
          actorUser: widget.currentUser, 
          transferId: widget.transfer.id, 
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mercancía ingresada a tu inventario exitosamente.')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.transfer;
    
    Color statusColor = AppPalette.blueSoft;
    String statusLabel = '';
    
    if (t.status == TransferStatus.pending) {
      statusColor = AppPalette.amber;
      statusLabel = 'Pendiente';
    } else if (t.status == TransferStatus.approved) {
      statusColor = AppPalette.mint;
      statusLabel = 'Aprobado (Por despachar)';
    } else if (t.status == TransferStatus.inTransit) {
      statusColor = AppPalette.cyan;
      statusLabel = 'En Tránsito';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '${t.quantity} un.',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            t.productName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            widget.isIncoming 
                ? 'Viene desde: ${t.fromBranchName}' 
                : 'Va hacia: ${t.toBranchName}',
            style: const TextStyle(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Text(
            'Motivo: ${t.reason}',
            style: const TextStyle(fontSize: 13, color: Colors.white60),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                showTransferTraceabilityDialog(
                  context,
                  service: widget.service,
                  currentUser: widget.currentUser,
                  transferId: t.id,
                );
              },
              icon: const Icon(Icons.history_rounded, size: 16),
              label: const Text('Ver trazabilidad completa'),
              style: TextButton.styleFrom(
                foregroundColor: AppPalette.cyan,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_isBusy)
            const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
          else if (widget.isIncoming)
            if (t.status == TransferStatus.inTransit)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _handleAction('receive'),
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('Recibir Mercancía'),
                  style: FilledButton.styleFrom(backgroundColor: AppPalette.mint, foregroundColor: Colors.black),
                ),
              )
            else
              const Text('A la espera de despacho o aprobación.', style: TextStyle(color: Colors.amber, fontSize: 13))
          else // isOutgoing
            if (t.status == TransferStatus.pending)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _handleAction('reject'),
                      child: const Text('Rechazar', style: TextStyle(color: AppPalette.danger)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _handleAction('approve'),
                      child: const Text('Aprobar'),
                    ),
                  ),
                ],
              )
            else if (t.status == TransferStatus.approved)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _handleAction('dispatch'),
                  icon: const Icon(Icons.local_shipping_rounded),
                  label: const Text('Despachar ahora'),
                  style: FilledButton.styleFrom(backgroundColor: AppPalette.blueDark),
                ),
              )
            else if (t.status == TransferStatus.inTransit)
              const Text('En camino hacia destino. Esperando recepción.', style: TextStyle(color: Colors.white54, fontSize: 13)),
        ],
      ),
    );
  }
}

class _EmptyTabState extends StatelessWidget {
  const _EmptyTabState({required this.icon, required this.title, required this.message});

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60)),
          ],
        ),
      ),
    );
  }
}
