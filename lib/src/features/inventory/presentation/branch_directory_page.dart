import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../application/inventory_workflow_service.dart';
import '../domain/models.dart';
import 'branch_location_resolver.dart';

enum _BranchAvailabilityFilter { all, withStock, withoutStock }

enum _BranchSortMode { proximity, stock }

class _ResolvedBranchEntry {
  const _ResolvedBranchEntry({required this.entry, required this.distanceKm});

  final BranchDirectoryEntry entry;
  final double? distanceKm;
}

class BranchDirectoryPage extends StatefulWidget {
  const BranchDirectoryPage({
    super.key,
    required this.service,
    required this.currentUser,
    this.selectedProductId,
    this.locationResolver,
  });

  final InventoryWorkflowService service;
  final AppUser currentUser;
  final String? selectedProductId;
  final BranchLocationResolver? locationResolver;

  @override
  State<BranchDirectoryPage> createState() => _BranchDirectoryPageState();
}

class _BranchDirectoryPageState extends State<BranchDirectoryPage> {
  late Future<BranchDirectoryData> _directoryFuture;
  late final TextEditingController _searchController;
  late final BranchLocationResolver _locationResolver;
  String? _selectedCity;
  _BranchAvailabilityFilter _availabilityFilter = _BranchAvailabilityFilter.all;
  late _BranchSortMode _sortMode;
  BranchLocation? _deviceLocation;
  BranchLocationAccessStatus? _locationStatus;
  String _locationMessage =
      'Resolviendo tu ubicacion actual para ordenar las sucursales.';
  bool _isResolvingLocation = false;

  @override
  void initState() {
    super.initState();
    _locationResolver =
        widget.locationResolver ?? const GeolocatorBranchLocationResolver();
    _sortMode = widget.selectedProductId == null
        ? _BranchSortMode.proximity
        : _BranchSortMode.stock;
    _searchController = TextEditingController()
      ..addListener(() {
        setState(() {});
      });
    _directoryFuture = _loadDirectory();
    unawaited(_resolveDeviceLocation());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<BranchDirectoryData> _loadDirectory({bool forceRefresh = false}) {
    return widget.service.fetchBranchDirectory(
      actorUser: widget.currentUser,
      productId: widget.selectedProductId,
      forceRefresh: forceRefresh,
    );
  }

  void _refresh() {
    setState(() {
      _directoryFuture = _loadDirectory(forceRefresh: true);
    });
    unawaited(_resolveDeviceLocation());
  }

  Future<void> _resolveDeviceLocation() async {
    if (_isResolvingLocation) {
      return;
    }

    setState(() {
      _isResolvingLocation = true;
      _locationMessage =
          'Resolviendo tu ubicacion actual para ordenar las sucursales.';
    });

    final result = await _locationResolver.resolveCurrentLocation();
    if (!mounted) {
      return;
    }

    setState(() {
      _isResolvingLocation = false;
      _deviceLocation = result.location;
      _locationStatus = result.status;
      _locationMessage = result.message;
    });
  }

  Future<void> _openLocationSettings() async {
    final status = _locationStatus;
    if (status == BranchLocationAccessStatus.deniedForever) {
      await _locationResolver.openAppSettings();
    } else {
      await _locationResolver.openLocationSettings();
    }
  }

  BranchLocation? _resolveReferenceLocation(BranchDirectoryData data) {
    return _deviceLocation ?? data.currentBranch?.location;
  }

  String _distanceReferenceLabel(BranchDirectoryData data) {
    if (_deviceLocation != null) {
      return 'tu ubicacion actual';
    }
    if (data.currentBranch != null) {
      return data.currentBranch!.name;
    }
    return 'referencia no disponible';
  }

  Future<void> _handleLocationAction() async {
    final status = _locationStatus;
    if (status == BranchLocationAccessStatus.deniedForever ||
        status == BranchLocationAccessStatus.servicesDisabled) {
      await _openLocationSettings();
      return;
    }
    await _resolveDeviceLocation();
  }

  List<_ResolvedBranchEntry> _applyFilters(BranchDirectoryData data) {
    final query = _searchController.text.trim().toLowerCase();
    final referenceLocation = _resolveReferenceLocation(data);

    return data.entries
        .where((entry) {
          final matchesSearch =
              query.isEmpty ||
              entry.branch.name.toLowerCase().contains(query) ||
              entry.branch.code.toLowerCase().contains(query) ||
              entry.branch.address.toLowerCase().contains(query) ||
              entry.branch.city.toLowerCase().contains(query) ||
              entry.branch.phone.toLowerCase().contains(query) ||
              entry.branch.email.toLowerCase().contains(query);
          if (!matchesSearch) {
            return false;
          }

          if (_selectedCity != null && entry.branch.city != _selectedCity) {
            return false;
          }

          return switch (_availabilityFilter) {
            _BranchAvailabilityFilter.all => true,
            _BranchAvailabilityFilter.withStock =>
              data.selectedProduct == null || entry.availableStock > 0,
            _BranchAvailabilityFilter.withoutStock =>
              data.selectedProduct != null && entry.availableStock <= 0,
          };
        })
        .map(
          (entry) => _ResolvedBranchEntry(
            entry: entry,
            distanceKm: referenceLocation == null
                ? null
                : _deviceLocation != null
                ? widget.service.calculateDistanceKm(
                    origin: referenceLocation,
                    destination: entry.branch.location,
                  )
                : entry.distanceKm,
          ),
        )
        .toList(growable: false);
  }

  List<_ResolvedBranchEntry> _sortEntries(
    List<_ResolvedBranchEntry> entries,
    Product? selectedProduct,
  ) {
    final sorted = List<_ResolvedBranchEntry>.of(entries);
    sorted.sort((left, right) {
      if (_sortMode == _BranchSortMode.stock && selectedProduct != null) {
        final stockComparison = right.entry.availableStock.compareTo(
          left.entry.availableStock,
        );
        if (stockComparison != 0) {
          return stockComparison;
        }
      }

      final leftDistance = left.distanceKm;
      final rightDistance = right.distanceKm;
      if (leftDistance != null && rightDistance != null) {
        final distanceComparison = leftDistance.compareTo(rightDistance);
        if (distanceComparison != 0) {
          return distanceComparison;
        }
      } else if (leftDistance != null || rightDistance != null) {
        return leftDistance == null ? 1 : -1;
      }

      if (_sortMode == _BranchSortMode.proximity && selectedProduct != null) {
        final stockComparison = right.entry.availableStock.compareTo(
          left.entry.availableStock,
        );
        if (stockComparison != 0) {
          return stockComparison;
        }
      }

      return left.entry.branch.name.compareTo(right.entry.branch.name);
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sucursales'),
        actions: [
          IconButton(
            tooltip: 'Actualizar sucursales',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Container(
        color: const Color(0xFF08172D),
        child: SafeArea(
          top: false,
          child: FutureBuilder<BranchDirectoryData>(
            future: _directoryFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return _BranchDirectoryErrorState(
                  message:
                      'No se pudo cargar el catalogo de sucursales. ${snapshot.error}',
                  onRetry: _refresh,
                );
              }

              final data = snapshot.requireData;
              final filteredEntries = _sortEntries(
                _applyFilters(data),
                data.selectedProduct,
              );

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: [
                  _BranchDirectoryHeader(
                    data: data,
                    distanceReferenceLabel: _distanceReferenceLabel(data),
                    isUsingDeviceLocation: _deviceLocation != null,
                  ),
                  const SizedBox(height: 16),
                  _BranchDirectoryFilters(
                    searchController: _searchController,
                    selectedCity: _selectedCity,
                    cities: data.cities,
                    selectedProduct: data.selectedProduct,
                    availabilityFilter: _availabilityFilter,
                    sortMode: _sortMode,
                    isResolvingLocation: _isResolvingLocation,
                    locationStatus: _locationStatus,
                    locationMessage: _locationMessage,
                    onLocationAction: _handleLocationAction,
                    onSelectCity: (value) {
                      setState(() {
                        _selectedCity = value;
                      });
                    },
                    onSelectAvailability: (value) {
                      setState(() {
                        _availabilityFilter = value;
                      });
                    },
                    onSelectSort: (value) {
                      setState(() {
                        _sortMode = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  if (filteredEntries.isEmpty)
                    const _BranchDirectoryEmptyState()
                  else
                    ...filteredEntries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _BranchCard(
                          resolvedEntry: entry,
                          currentBranchId: data.currentBranch?.id,
                          selectedProduct: data.selectedProduct,
                          distanceReferenceLabel: _distanceReferenceLabel(data),
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

class _BranchDirectoryHeader extends StatelessWidget {
  const _BranchDirectoryHeader({
    required this.data,
    required this.distanceReferenceLabel,
    required this.isUsingDeviceLocation,
  });

  final BranchDirectoryData data;
  final String distanceReferenceLabel;
  final bool isUsingDeviceLocation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF102540),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x26FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Directorio de sucursales',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            data.selectedProduct == null
                ? 'Consulta direcciones, horarios y contactos. Abre esta vista desde el detalle de un producto para ver disponibilidad puntual.'
                : 'Disponibilidad de ${data.selectedProduct!.name} por sucursal.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoPill(label: '${data.entries.length} sucursales'),
              if (data.currentBranch != null)
                _InfoPill(label: 'Sucursal actual ${data.currentBranch!.name}'),
              _InfoPill(
                label: isUsingDeviceLocation
                    ? 'Distancia desde dispositivo'
                    : 'Distancia desde $distanceReferenceLabel',
              ),
              if (data.selectedProduct != null)
                _InfoPill(
                  label:
                      '${data.selectedProduct!.name} | SKU ${data.selectedProduct!.sku}',
                ),
              if (data.isFromCache) const _InfoPill(label: 'Catalogo en cache'),
            ],
          ),
        ],
      ),
    );
  }
}

class _BranchDirectoryFilters extends StatelessWidget {
  const _BranchDirectoryFilters({
    required this.searchController,
    required this.selectedCity,
    required this.cities,
    required this.selectedProduct,
    required this.availabilityFilter,
    required this.sortMode,
    required this.isResolvingLocation,
    required this.locationStatus,
    required this.locationMessage,
    required this.onLocationAction,
    required this.onSelectCity,
    required this.onSelectAvailability,
    required this.onSelectSort,
  });

  final TextEditingController searchController;
  final String? selectedCity;
  final List<String> cities;
  final Product? selectedProduct;
  final _BranchAvailabilityFilter availabilityFilter;
  final _BranchSortMode sortMode;
  final bool isResolvingLocation;
  final BranchLocationAccessStatus? locationStatus;
  final String locationMessage;
  final Future<void> Function() onLocationAction;
  final ValueChanged<String?> onSelectCity;
  final ValueChanged<_BranchAvailabilityFilter> onSelectAvailability;
  final ValueChanged<_BranchSortMode> onSelectSort;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF102540),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x26FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LocationStatusCard(
            isResolvingLocation: isResolvingLocation,
            locationStatus: locationStatus,
            message: locationMessage,
            actionLabel: _locationActionLabel(locationStatus),
            onPressed: onLocationAction,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Buscar por nombre, ciudad, direccion o contacto',
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Ordenar por',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Cercania'),
                selected: sortMode == _BranchSortMode.proximity,
                onSelected: (_) => onSelectSort(_BranchSortMode.proximity),
              ),
              if (selectedProduct != null)
                ChoiceChip(
                  label: const Text('Mayor stock'),
                  selected: sortMode == _BranchSortMode.stock,
                  onSelected: (_) => onSelectSort(_BranchSortMode.stock),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Ciudad',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Todas'),
                selected: selectedCity == null,
                onSelected: (_) => onSelectCity(null),
              ),
              ...cities.map(
                (city) => ChoiceChip(
                  label: Text(city),
                  selected: selectedCity == city,
                  onSelected: (_) => onSelectCity(city),
                ),
              ),
            ],
          ),
          if (selectedProduct != null) ...[
            const SizedBox(height: 16),
            Text(
              'Disponibilidad',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Todas'),
                  selected: availabilityFilter == _BranchAvailabilityFilter.all,
                  onSelected: (_) =>
                      onSelectAvailability(_BranchAvailabilityFilter.all),
                ),
                ChoiceChip(
                  label: const Text('Con stock'),
                  selected:
                      availabilityFilter == _BranchAvailabilityFilter.withStock,
                  onSelected: (_) =>
                      onSelectAvailability(_BranchAvailabilityFilter.withStock),
                ),
                ChoiceChip(
                  label: const Text('Sin stock'),
                  selected:
                      availabilityFilter ==
                      _BranchAvailabilityFilter.withoutStock,
                  onSelected: (_) => onSelectAvailability(
                    _BranchAvailabilityFilter.withoutStock,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _locationActionLabel(BranchLocationAccessStatus? status) {
    return switch (status) {
      BranchLocationAccessStatus.deniedForever => 'Abrir ajustes',
      BranchLocationAccessStatus.servicesDisabled => 'Activar ubicacion',
      BranchLocationAccessStatus.granted => 'Actualizar ubicacion',
      _ => 'Usar mi ubicacion',
    };
  }
}

class _LocationStatusCard extends StatelessWidget {
  const _LocationStatusCard({
    required this.isResolvingLocation,
    required this.locationStatus,
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

  final bool isResolvingLocation;
  final BranchLocationAccessStatus? locationStatus;
  final String message;
  final String actionLabel;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final tone = switch (locationStatus) {
      BranchLocationAccessStatus.granted => AppPalette.mint,
      BranchLocationAccessStatus.deniedForever ||
      BranchLocationAccessStatus.servicesDisabled => AppPalette.amber,
      BranchLocationAccessStatus.error => AppPalette.danger,
      _ => AppPalette.blue,
    };

    final icon = switch (locationStatus) {
      BranchLocationAccessStatus.granted => Icons.my_location_rounded,
      BranchLocationAccessStatus.deniedForever => Icons.settings_rounded,
      BranchLocationAccessStatus.servicesDisabled => Icons.location_disabled,
      BranchLocationAccessStatus.error => Icons.warning_amber_rounded,
      _ => Icons.location_searching_rounded,
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tone.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, color: tone, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
          ),
          const SizedBox(width: 10),
          if (isResolvingLocation)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            TextButton(
              onPressed: () {
                unawaited(onPressed());
              },
              child: Text(actionLabel),
            ),
        ],
      ),
    );
  }
}

class _BranchCard extends StatelessWidget {
  const _BranchCard({
    required this.resolvedEntry,
    required this.currentBranchId,
    required this.selectedProduct,
    required this.distanceReferenceLabel,
  });

  final _ResolvedBranchEntry resolvedEntry;
  final String? currentBranchId;
  final Product? selectedProduct;
  final String distanceReferenceLabel;

  @override
  Widget build(BuildContext context) {
    final entry = resolvedEntry.entry;
    final isCurrentBranch = entry.branch.id == currentBranchId;
    final reliability = entry.reliability;
    final lastUpdatedLabel = entry.lastUpdatedAt == null
        ? 'Sin actualizacion registrada'
        : 'Ultima actualizacion ${_formatDateTime(entry.lastUpdatedAt!)}';
    final distanceText = resolvedEntry.distanceKm == null
        ? 'Distancia no disponible'
        : '${resolvedEntry.distanceKm!.toStringAsFixed(1)} km desde $distanceReferenceLabel';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF102540),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x26FFFFFF)),
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
                      entry.branch.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${entry.branch.code} | ${entry.branch.city}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (isCurrentBranch)
                const _StatusTag(label: 'Tu sucursal', color: AppPalette.blue),
            ],
          ),
          const SizedBox(height: 12),
          _DetailLine(
            icon: Icons.location_on_outlined,
            text: entry.branch.address,
          ),
          const SizedBox(height: 8),
          _DetailLine(
            icon: Icons.schedule_rounded,
            text: entry.branch.openingHours,
          ),
          const SizedBox(height: 8),
          _DetailLine(
            icon: Icons.call_outlined,
            text: entry.branch.phone.isEmpty
                ? 'Sin telefono'
                : entry.branch.phone,
          ),
          const SizedBox(height: 8),
          _DetailLine(
            icon: Icons.mail_outline_rounded,
            text: entry.branch.email.isEmpty
                ? 'Sin correo'
                : entry.branch.email,
          ),
          const SizedBox(height: 8),
          _DetailLine(icon: Icons.route_rounded, text: distanceText),
          if (selectedProduct != null) ...[
            const SizedBox(height: 14),
            if (reliability != null)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatusTag(
                    label: reliability.statusLabel,
                    color: _reliabilityColor(reliability.level),
                  ),
                  _InfoPill(label: lastUpdatedLabel),
                ],
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _StockChip(
                  label: 'Disponible',
                  value: '${entry.availableStock}',
                ),
                _StockChip(label: 'Reservado', value: '${entry.reservedStock}'),
                _StockChip(
                  label: 'En transito',
                  value: '${entry.incomingStock}',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDateTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }
}

class _BranchDirectoryEmptyState extends StatelessWidget {
  const _BranchDirectoryEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF102540),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x26FFFFFF)),
      ),
      child: Text(
        'No hay sucursales que coincidan con los filtros actuales.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
      ),
    );
  }
}

class _BranchDirectoryErrorState extends StatelessWidget {
  const _BranchDirectoryErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF102540),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x26FFFFFF)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'No se pudieron cargar las sucursales',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
        ),
      ],
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.label, required this.color});

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
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: Colors.white),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x26FFFFFF)),
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

class _StockChip extends StatelessWidget {
  const _StockChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 6),
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

Color _reliabilityColor(InventoryDataReliabilityLevel level) {
  return switch (level) {
    InventoryDataReliabilityLevel.green => AppPalette.mint,
    InventoryDataReliabilityLevel.yellow => AppPalette.amber,
    InventoryDataReliabilityLevel.red => AppPalette.danger,
  };
}
