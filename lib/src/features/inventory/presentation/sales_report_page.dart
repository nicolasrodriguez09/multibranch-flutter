import 'package:flutter/material.dart';

import '../application/inventory_workflow_service.dart';
import '../domain/models.dart';
import 'branch_panel_drawer.dart';

enum _SalesDateFilter { today, last7Days, last30Days, all }

class SalesReportPage extends StatefulWidget {
  const SalesReportPage({
    super.key,
    required this.service,
    required this.currentUser,
  });

  final InventoryWorkflowService service;
  final AppUser currentUser;

  @override
  State<SalesReportPage> createState() => _SalesReportPageState();
}

class _SalesReportPageState extends State<SalesReportPage> {
  _SalesDateFilter _filter = _SalesDateFilter.today;

  ({DateTime? from, DateTime? to}) _range() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (_filter) {
      _SalesDateFilter.today => (
        from: today,
        to: today.add(const Duration(days: 1)),
      ),
      _SalesDateFilter.last7Days => (
        from: today.subtract(const Duration(days: 6)),
        to: today.add(const Duration(days: 1)),
      ),
      _SalesDateFilter.last30Days => (
        from: today.subtract(const Duration(days: 29)),
        to: today.add(const Duration(days: 1)),
      ),
      _SalesDateFilter.all => (from: null, to: null),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: BranchPanelDrawer(
        service: widget.service,
        currentUser: widget.currentUser,
        currentDestination: BranchPanelDestination.salesReport,
      ),
      appBar: AppBar(title: const Text('Ventas de sucursal')),
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
          child: StreamBuilder<List<SaleRecord>>(
            stream: widget.service.watchSales(actorUser: widget.currentUser),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
                  children: [
                    _SalesPanel(
                      child: Text(
                        'No fue posible cargar ventas: ${snapshot.error}',
                      ),
                    ),
                  ],
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final range = _range();
              final report = widget.service.buildSalesReport(
                snapshot.requireData,
                from: range.from,
                to: range.to,
              );

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  _SalesReportHero(report: report, user: widget.currentUser),
                  const SizedBox(height: 16),
                  _SalesFilterBar(
                    selected: _filter,
                    onSelected: (value) {
                      setState(() {
                        _filter = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _DailySalesPanel(report: report),
                  const SizedBox(height: 16),
                  _SalesRecordsPanel(sales: report.sales),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SalesReportHero extends StatelessWidget {
  const _SalesReportHero({required this.report, required this.user});

  final SalesReportData report;
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final currency = _reportCurrency(report);
    return _SalesPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            user.role == UserRole.admin
                ? 'Ventas globales'
                : 'Ventas de tu sucursal',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'Trazabilidad comercial por fecha, vendedor, producto, cantidad, precio y metodo de pago.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MetricBox(
                  label: 'Ingresos',
                  value: _formatMoney(report.totalRevenue, currency),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricBox(
                  label: 'Unidades',
                  value: '${report.totalUnits}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricBox(
                  label: 'Ventas',
                  value: '${report.totalTransactions}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SalesFilterBar extends StatelessWidget {
  const _SalesFilterBar({required this.selected, required this.onSelected});

  final _SalesDateFilter selected;
  final ValueChanged<_SalesDateFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return _SalesPanel(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final filter in _SalesDateFilter.values)
            ChoiceChip(
              label: Text(_filterLabel(filter)),
              selected: selected == filter,
              onSelected: (_) => onSelected(filter),
            ),
        ],
      ),
    );
  }
}

class _DailySalesPanel extends StatelessWidget {
  const _DailySalesPanel({required this.report});

  final SalesReportData report;

  @override
  Widget build(BuildContext context) {
    final currency = _reportCurrency(report);
    return _SalesPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Clasificacion por dia',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (report.dailyMetrics.isEmpty)
            Text(
              'No hay ventas para el filtro seleccionado.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
            )
          else
            ...report.dailyMetrics.map(
              (metric) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DailySaleRow(metric: metric, currency: currency),
              ),
            ),
        ],
      ),
    );
  }
}

class _SalesRecordsPanel extends StatelessWidget {
  const _SalesRecordsPanel({required this.sales});

  final List<SaleRecord> sales;

  @override
  Widget build(BuildContext context) {
    return _SalesPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detalle trazable',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (sales.isEmpty)
            Text(
              'No hay ventas registradas en este periodo.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
            )
          else
            ...sales.map(
              (sale) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SaleRecordTile(sale: sale),
              ),
            ),
        ],
      ),
    );
  }
}

class _DailySaleRow extends StatelessWidget {
  const _DailySaleRow({required this.metric, required this.currency});

  final DailySalesMetric metric;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1D34),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x26FFFFFF)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(_formatDate(metric.day))),
          Text('${metric.quantity} uds'),
          const SizedBox(width: 16),
          Text(_formatMoney(metric.total, currency)),
        ],
      ),
    );
  }
}

class _SaleRecordTile extends StatelessWidget {
  const _SaleRecordTile({required this.sale});

  final SaleRecord sale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1D34),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x26FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${sale.productName} | ${sale.quantity} unidad(es)',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Vendedor: ${sale.sellerName} | Hora: ${_formatDateTime(sale.soldAt)}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Text(
            'Unitario ${_formatMoney(sale.unitPrice, sale.currency)} | Total ${_formatMoney(sale.totalPrice, sale.currency)} | ${sale.paymentMethod.label}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
          if (sale.customerName.isNotEmpty || sale.notes.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              [
                if (sale.customerName.isNotEmpty)
                  'Cliente: ${sale.customerName}',
                if (sale.notes.isNotEmpty) 'Notas: ${sale.notes}',
              ].join(' | '),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white60),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricBox extends StatelessWidget {
  const _MetricBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
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
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _SalesPanel extends StatelessWidget {
  const _SalesPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
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

String _filterLabel(_SalesDateFilter filter) {
  return switch (filter) {
    _SalesDateFilter.today => 'Hoy',
    _SalesDateFilter.last7Days => '7 dias',
    _SalesDateFilter.last30Days => '30 dias',
    _SalesDateFilter.all => 'Todas',
  };
}

String _formatMoney(double value, String currency) {
  return '$currency ${value.toStringAsFixed(2)}';
}

String _reportCurrency(SalesReportData report) {
  if (report.sales.isEmpty) {
    return 'USD';
  }
  final currencies = report.sales.map((sale) => sale.currency).toSet();
  return currencies.length == 1 ? currencies.first : 'Mixto';
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year}';
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
}
