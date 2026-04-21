import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_multibranch_proyect/src/features/inventory/application/inventory_workflow_service.dart';
import 'package:flutter_multibranch_proyect/src/features/inventory/data/sample_seed_data.dart';
import 'package:flutter_multibranch_proyect/src/features/inventory/domain/models.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late InventoryWorkflowService service;
  late DateTime now;
  late SampleSeedData sampleData;

  setUp(() {
    now = DateTime.utc(2026, 3, 26, 12, 0);
    firestore = FakeFirebaseFirestore();
    service = InventoryWorkflowService(firestore: firestore, clock: () => now);
    sampleData = SampleSeedData.build(now);
  });

  test(
    'seedMasterData creates master documents and computed inventory fields',
    () async {
      await service.seedMasterData(actorUser: sampleData.users.first);
      final auditLogs = await firestore
          .collection('audit_logs')
          .where('action', isEqualTo: 'master_data_seeded')
          .get();

      final inventory = await service.inventories.fetchInventory(
        DemoIds.branchCenter,
        DemoIds.laptopProduct,
      );
      final lowStockInventory = await service.inventories.fetchInventory(
        DemoIds.branchCenter,
        DemoIds.phoneProduct,
      );

      expect(inventory, isNotNull);
      expect(inventory!.availableStock, 7);
      expect(inventory.isLowStock, isTrue);
      expect(lowStockInventory, isNotNull);
      expect(lowStockInventory!.isLowStock, isTrue);
      expect(auditLogs.docs, hasLength(1));
    },
  );

  test('admin can create a branch and the event is audited', () async {
    final admin = sampleData.users.first;

    final branch = await service.createBranch(
      actorUser: admin,
      name: 'Sucursal Sur',
      code: 'SUR-003',
      address: 'Calle 45 #10',
      city: 'Bogota',
      phone: '3000000000',
      email: 'sur@empresa.com',
      managerName: 'Julian Perez',
      openingHours: '09:00-18:00',
      latitude: 4.61,
      longitude: -74.08,
    );
    final storedBranch = await service.catalog.fetchBranch(branch.id);
    final auditLogs = await firestore
        .collection('audit_logs')
        .where('action', isEqualTo: 'branch_created')
        .get();

    expect(storedBranch, isNotNull);
    expect(storedBranch!.code, 'SUR_003');
    expect(auditLogs.docs, hasLength(1));
    expect(auditLogs.docs.first.data()['entityId'], branch.id);
    expect(auditLogs.docs.first.data()['actorUserId'], admin.id);
  });

  test(
    'supervisor operational stats expose KPIs and seller cannot access them',
    () async {
      await service.seedMasterData(actorUser: sampleData.users.first);
      final supervisor = sampleData.users.firstWhere(
        (user) => user.id == DemoIds.secondBranchSeller,
      );
      final seller = sampleData.users.firstWhere(
        (user) => user.id == DemoIds.branchSeller,
      );

      final stats = await service
          .watchOperationalStats(
            actorUser: supervisor,
            branchId: DemoIds.branchNorth,
          )
          .first;

      expect(stats.lowStockCount, 1);
      expect(stats.outOfStockCount, 1);
      expect(stats.pendingTransfersCount, 1);
      expect(stats.activeReservationsCount, 1);
      expect(stats.transferRequestsToday, 1);
      expect(stats.consultedOutOfStockCount, 1);
      expect(stats.averageApiResponseTime, const Duration(minutes: 3));
      expect(stats.transferRequestsByDay.last.count, 1);

      expect(
        () => service.watchOperationalStats(
          actorUser: seller,
          branchId: DemoIds.branchCenter,
        ),
        throwsA(
          isA<InventoryException>().having(
            (error) => error.message,
            'message',
            contains('no tiene permiso'),
          ),
        ),
      );
    },
  );

  test(
    'product search returns ranked results and persists recent searches',
    () async {
      await service.seedMasterData(actorUser: sampleData.users.first);
      final seller = sampleData.users.firstWhere(
        (user) => user.id == DemoIds.branchSeller,
      );

      final logitechResults = await service.searchProducts(
        actorUser: seller,
        branchId: DemoIds.branchCenter,
        query: 'logitech',
      );
      final samsungResults = await service.searchProducts(
        actorUser: seller,
        branchId: DemoIds.branchCenter,
        query: 'samsung a55',
      );

      expect(logitechResults, isNotEmpty);
      expect(logitechResults.first.product.id, DemoIds.mouseProduct);
      expect(
        logitechResults.any(
          (item) => item.product.id == DemoIds.headsetProduct,
        ),
        isTrue,
      );
      expect(samsungResults, isNotEmpty);
      expect(samsungResults.first.product.id, DemoIds.phoneProduct);
      expect(samsungResults.first.isOutOfStock, isTrue);

      await service.saveRecentSearch(actorUser: seller, query: 'Logitech');
      await service.saveRecentSearch(actorUser: seller, query: 'logitech');
      final history = await service
          .watchRecentSearches(actorUser: seller)
          .first;

      expect(history, hasLength(1));
      expect(history.first.query, 'logitech');
      expect(history.first.normalizedQuery, 'logitech');
      expect(history.first.hitCount, 2);
    },
  );

  test(
    'advanced product filters narrow results and persist favorite filters',
    () async {
      await service.seedMasterData(actorUser: sampleData.users.first);
      final seller = sampleData.users.firstWhere(
        (user) => user.id == DemoIds.branchSeller,
      );

      final options = await service.fetchSearchFilterOptions(actorUser: seller);
      final filters = ProductSearchFilters(
        categoryId: DemoIds.accessoriesCategory,
        brand: 'Samsung',
        availability: ProductAvailabilityFilter.available,
        minStock: 1,
        maxStock: 4,
      );

      final results = await service.searchProducts(
        actorUser: seller,
        branchId: DemoIds.branchCenter,
        query: '',
        filters: filters,
      );

      expect(
        options.categories.any(
          (item) => item.id == DemoIds.accessoriesCategory,
        ),
        isTrue,
      );
      expect(options.brands, containsAll(<String>['Logitech', 'Samsung']));
      expect(options.branches, hasLength(1));
      expect(options.branches.first.id, DemoIds.branchCenter);
      expect(results, hasLength(1));
      expect(results.first.product.id, DemoIds.monitorProduct);
      expect(results.first.inventory!.availableStock, 3);

      await service.saveSearchFilter(
        actorUser: seller,
        filters: filters,
        label: 'Samsung con stock bajo',
        favorite: true,
      );
      await service.saveSearchFilter(
        actorUser: seller,
        filters: filters,
        label: 'Etiqueta temporal',
      );

      final savedFilters = await service
          .watchRecentSearchFilters(actorUser: seller)
          .first;

      expect(savedFilters, hasLength(1));
      expect(savedFilters.first.label, 'Samsung con stock bajo');
      expect(savedFilters.first.isFavorite, isTrue);
      expect(savedFilters.first.usageCount, 2);
    },
  );

  test(
    'barcode lookup returns exact product for current branch inventory',
    () async {
      await service.seedMasterData(actorUser: sampleData.users.first);
      final seller = sampleData.users.firstWhere(
        (user) => user.id == DemoIds.branchSeller,
      );

      final found = await service.findProductByBarcode(
        actorUser: seller,
        branchId: DemoIds.branchCenter,
        barcode: '7501234567803',
      );
      final missing = await service.findProductByBarcode(
        actorUser: seller,
        branchId: DemoIds.branchCenter,
        barcode: '0000000000000',
      );

      expect(found, isNotNull);
      expect(found!.product.id, DemoIds.monitorProduct);
      expect(found.inventory, isNotNull);
      expect(found.inventory!.branchId, DemoIds.branchCenter);
      expect(missing, isNull);
    },
  );

  test(
    'product detail returns commercial data, branch stock summary and uses in-memory cache',
    () async {
      await service.seedMasterData(actorUser: sampleData.users.first);
      final seller = sampleData.users.firstWhere(
        (user) => user.id == DemoIds.branchSeller,
      );

      final firstDetail = await service.fetchProductDetail(
        actorUser: seller,
        branchId: DemoIds.branchCenter,
        productId: DemoIds.monitorProduct,
      );
      final secondDetail = await service.fetchProductDetail(
        actorUser: seller,
        branchId: DemoIds.branchCenter,
        productId: DemoIds.monitorProduct,
      );

      expect(firstDetail.product.id, DemoIds.monitorProduct);
      expect(firstDetail.category, isNotNull);
      expect(firstDetail.category!.id, DemoIds.accessoriesCategory);
      expect(firstDetail.branch, isNotNull);
      expect(firstDetail.branch!.id, DemoIds.branchCenter);
      expect(firstDetail.inventory, isNotNull);
      expect(firstDetail.inventory!.availableStock, 3);
      expect(
        firstDetail.reliability.level,
        InventoryDataReliabilityLevel.yellow,
      );
      expect(firstDetail.reliability.age, const Duration(minutes: 18));
      expect(firstDetail.isFromCache, isFalse);
      expect(firstDetail.stockByBranch, hasLength(2));
      expect(firstDetail.stockByBranch.first.branch.id, DemoIds.branchNorth);
      expect(firstDetail.stockByBranch.first.availableStock, 7);
      expect(firstDetail.stockByBranch.first.reservedStock, 1);
      expect(firstDetail.stockByBranch.first.physicalStock, 8);
      expect(
        firstDetail.stockByBranch.first.reliability.level,
        InventoryDataReliabilityLevel.red,
      );
      expect(firstDetail.stockByBranch.first.isStale, isTrue);
      expect(firstDetail.hasStaleStockByBranch, isTrue);
      expect(secondDetail.isFromCache, isTrue);
      expect(
        secondDetail.reliability.level,
        InventoryDataReliabilityLevel.yellow,
      );
    },
  );

  test(
    'stock reliability turns red when branch inventory data is incomplete',
    () async {
      await service.seedMasterData(actorUser: sampleData.users.first);
      final seller = sampleData.users.firstWhere(
        (user) => user.id == DemoIds.branchSeller,
      );

      await firestore
          .collection('inventories')
          .doc('${DemoIds.branchNorth}_${DemoIds.monitorProduct}')
          .delete();

      final detail = await service.fetchProductDetail(
        actorUser: seller,
        branchId: DemoIds.branchCenter,
        productId: DemoIds.monitorProduct,
        forceRefresh: true,
      );
      final northBranchEntry = detail.stockByBranch.firstWhere(
        (entry) => entry.branch.id == DemoIds.branchNorth,
      );

      expect(
        northBranchEntry.reliability.level,
        InventoryDataReliabilityLevel.red,
      );
      expect(northBranchEntry.reliability.isIncomplete, isTrue);
      expect(
        northBranchEntry.reliability.message,
        contains('No hay inventario consolidado'),
      );
    },
  );

  test(
    'product detail suggests an alternative branch when the current branch has no stock',
    () async {
      await service.seedMasterData(actorUser: sampleData.users.first);
      final seller = sampleData.users.firstWhere(
        (user) => user.id == DemoIds.branchSeller,
      );

      final detail = await service.fetchProductDetail(
        actorUser: seller,
        branchId: DemoIds.branchCenter,
        productId: DemoIds.phoneProduct,
      );

      expect(detail.isOutOfStock, isTrue);
      expect(detail.shouldShowAlternativeSuggestions, isTrue);
      expect(detail.branchSuggestions, hasLength(1));
      expect(detail.recommendedSuggestion, isNotNull);
      expect(detail.recommendedSuggestion!.branch.id, DemoIds.branchNorth);
      expect(detail.recommendedSuggestion!.availableStock, 15);
      expect(detail.recommendedSuggestion!.distanceKm, greaterThan(0));
      expect(
        detail.recommendedSuggestion!.estimatedTransferTime,
        greaterThan(Duration.zero),
      );
    },
  );

  test(
    'product detail reports no alternative branch when no branch has available stock',
    () async {
      await service.seedMasterData(actorUser: sampleData.users.first);
      final seller = sampleData.users.firstWhere(
        (user) => user.id == DemoIds.branchSeller,
      );
      final northPhoneInventory = await service.inventories.fetchInventory(
        DemoIds.branchNorth,
        DemoIds.phoneProduct,
      );

      await service.inventories.upsertInventory(
        northPhoneInventory!.recalculate(
          stock: 1,
          reservedStock: 1,
          updatedBy: sampleData.users.first.id,
          updatedAt: now,
          lastMovementAt: now,
        ),
      );

      final detail = await service.fetchProductDetail(
        actorUser: seller,
        branchId: DemoIds.branchCenter,
        productId: DemoIds.phoneProduct,
        forceRefresh: true,
      );

      expect(detail.isOutOfStock, isTrue);
      expect(detail.branchSuggestions, isEmpty);
      expect(detail.recommendedSuggestion, isNull);
    },
  );

  test(
    'branch directory returns branches, selected product stock and cache',
    () async {
      await service.seedMasterData(actorUser: sampleData.users.first);
      final seller = sampleData.users.firstWhere(
        (user) => user.id == DemoIds.branchSeller,
      );

      final firstDirectory = await service.fetchBranchDirectory(
        actorUser: seller,
        productId: DemoIds.phoneProduct,
      );
      final secondDirectory = await service.fetchBranchDirectory(
        actorUser: seller,
        productId: DemoIds.phoneProduct,
      );

      expect(firstDirectory.selectedProduct, isNotNull);
      expect(firstDirectory.selectedProduct!.id, DemoIds.phoneProduct);
      expect(firstDirectory.entries, hasLength(2));
      expect(firstDirectory.entries.first.branch.id, DemoIds.branchNorth);
      expect(firstDirectory.entries.first.availableStock, 15);
      expect(firstDirectory.entries.last.branch.id, DemoIds.branchCenter);
      expect(firstDirectory.entries.last.availableStock, 0);
      expect(firstDirectory.isFromCache, isFalse);
      expect(secondDirectory.isFromCache, isTrue);
    },
  );

  test(
    'reservation approval and completion keep inventory consistent',
    () async {
      await service.seedMasterData(actorUser: sampleData.users.first);
      final admin = sampleData.users.firstWhere(
        (user) => user.id == DemoIds.adminUser,
      );
      final supervisor = sampleData.users.firstWhere(
        (user) => user.id == DemoIds.secondBranchSeller,
      );
      final seller = sampleData.users.firstWhere(
        (user) => user.id == DemoIds.branchSeller,
      );

      final reservation = await service.createReservation(
        actorUser: seller,
        branchId: DemoIds.branchCenter,
        productId: DemoIds.laptopProduct,
        customerName: 'Cliente Test',
        customerPhone: '0999000111',
        quantity: 1,
        expiresIn: const Duration(hours: 24),
      );

      final reservedInventory = await service.inventories.fetchInventory(
        DemoIds.branchCenter,
        DemoIds.laptopProduct,
      );
      expect(reservation.status, ReservationStatus.pending);
      expect(reservedInventory!.reservedStock, 1);
      expect(reservedInventory.availableStock, 7);

      final approvedReservation = await service.approveReservation(
        actorUser: admin,
        reservationId: reservation.id,
      );
      final approvedInventory = await service.inventories.fetchInventory(
        DemoIds.branchCenter,
        DemoIds.laptopProduct,
      );

      expect(approvedReservation.status, ReservationStatus.active);
      expect(approvedInventory!.reservedStock, 2);
      expect(approvedInventory.availableStock, 6);

      await service.updateReservationStatus(
        actorUser: seller,
        reservationId: reservation.id,
        nextStatus: ReservationStatus.completed,
      );

      final releasedInventory = await service.inventories.fetchInventory(
        DemoIds.branchCenter,
        DemoIds.laptopProduct,
      );
      final storedReservation = await service.reservations.fetchReservation(
        reservation.id,
      );

      expect(releasedInventory!.reservedStock, 1);
      expect(releasedInventory.availableStock, 7);
      expect(storedReservation!.status, ReservationStatus.completed);
    },
  );

  test(
    'seller can reserve in another branch and the operation is audited',
    () async {
      await service.seedMasterData(actorUser: sampleData.users.first);
      final supervisor = sampleData.users.firstWhere(
        (user) => user.id == DemoIds.secondBranchSeller,
      );
      final seller = sampleData.users.firstWhere(
        (user) => user.id == DemoIds.branchSeller,
      );

      final reservation = await service.createReservation(
        actorUser: seller,
        branchId: DemoIds.branchNorth,
        productId: DemoIds.phoneProduct,
        customerName: 'Cliente Reserva Norte',
        customerPhone: '3001234567',
        quantity: 2,
        expiresIn: const Duration(hours: 24),
      );

      final reservedInventory = await service.inventories.fetchInventory(
        DemoIds.branchNorth,
        DemoIds.phoneProduct,
      );
      final auditLogs = await firestore
          .collection('audit_logs')
          .where('action', isEqualTo: 'reservation_created')
          .get();

      expect(reservation.branchId, DemoIds.branchNorth);
      expect(reservation.reservedBy, seller.id);
      expect(reservedInventory, isNotNull);
      expect(reservedInventory!.reservedStock, 1);
      expect(reservedInventory.availableStock, 15);
      expect(auditLogs.docs, hasLength(1));
      expect(auditLogs.docs.first.data()['actorUserId'], seller.id);
      expect(
        auditLogs.docs.first.data()['metadata']['requestingBranchId'],
        DemoIds.branchCenter,
      );

      final approvedReservation = await service.approveReservation(
        actorUser: supervisor,
        reservationId: reservation.id,
        reviewComment: 'Stock validado para mostrador.',
      );
      final approvedInventory = await service.inventories.fetchInventory(
        DemoIds.branchNorth,
        DemoIds.phoneProduct,
      );

      expect(approvedReservation.status, ReservationStatus.active);
      expect(approvedInventory!.reservedStock, 3);
      expect(approvedInventory.availableStock, 13);

      await service.updateReservationStatus(
        actorUser: seller,
        reservationId: reservation.id,
        nextStatus: ReservationStatus.cancelled,
      );

      final releasedInventory = await service.inventories.fetchInventory(
        DemoIds.branchNorth,
        DemoIds.phoneProduct,
      );
      final storedReservation = await service.reservations.fetchReservation(
        reservation.id,
      );
      final cancelledAuditLogs = await firestore
          .collection('audit_logs')
          .where('action', isEqualTo: 'reservation_cancelled')
          .get();

      expect(releasedInventory!.reservedStock, 1);
      expect(releasedInventory.availableStock, 15);
      expect(storedReservation!.status, ReservationStatus.cancelled);
      expect(cancelledAuditLogs.docs, hasLength(1));
      expect(cancelledAuditLogs.docs.first.data()['actorUserId'], seller.id);
    },
  );

  test(
    'reservation traceability exposes requester, inventory and audited timeline',
    () async {
      await service.seedMasterData(actorUser: sampleData.users.first);
      final admin = sampleData.users.firstWhere(
        (user) => user.id == DemoIds.adminUser,
      );
      final supervisor = sampleData.users.firstWhere(
        (user) => user.id == DemoIds.secondBranchSeller,
      );
      final seller = sampleData.users.firstWhere(
        (user) => user.id == DemoIds.branchSeller,
      );

      final reservation = await service.createReservation(
        actorUser: seller,
        branchId: DemoIds.branchNorth,
        productId: DemoIds.phoneProduct,
        customerName: 'Cliente Seguimiento',
        customerPhone: '3009990000',
        quantity: 2,
        expiresIn: const Duration(hours: 24),
      );
      await service.approveReservation(
        actorUser: supervisor,
        reservationId: reservation.id,
      );
      await service.updateReservationStatus(
        actorUser: seller,
        reservationId: reservation.id,
        nextStatus: ReservationStatus.completed,
      );

      final detail = await service.fetchReservationTraceability(
        actorUser: admin,
        reservationId: reservation.id,
      );

      expect(detail.reservation.status, ReservationStatus.completed);
      expect(detail.requesterUser?.id, seller.id);
      expect(detail.branchInventory, isNotNull);
      expect(detail.branchInventory!.branchId, DemoIds.branchNorth);
      expect(
        detail.auditTrail.map((item) => item.action).toList(growable: false),
        <String>[
          'reservation_created',
          'reservation_approved',
          'reservation_completed',
        ],
      );
      expect(
        detail.requestLog?.metadata['requestingBranchId'],
        DemoIds.branchCenter,
      );
      expect(
        detail.requestLog?.metadata['customerName'],
        'Cliente Seguimiento',
      );
      expect(detail.approvalLog?.actorUserId, DemoIds.secondBranchSeller);
    },
  );

  test(
    'supervisor can reject reservation requests without touching reserved stock',
    () async {
      await service.seedMasterData(actorUser: sampleData.users.first);
      final supervisor = sampleData.users.firstWhere(
        (user) => user.id == DemoIds.secondBranchSeller,
      );
      final seller = sampleData.users.firstWhere(
        (user) => user.id == DemoIds.branchSeller,
      );

      final reservation = await service.createReservation(
        actorUser: seller,
        branchId: DemoIds.branchNorth,
        productId: DemoIds.phoneProduct,
        customerName: 'Cliente Rechazado',
        customerPhone: '3002220000',
        quantity: 2,
        expiresIn: const Duration(hours: 24),
      );

      final rejectedReservation = await service.rejectReservation(
        actorUser: supervisor,
        reservationId: reservation.id,
        reviewComment: 'No hay prioridad comercial para liberar ese stock.',
      );
      final inventoryAfterRejection = await service.inventories.fetchInventory(
        DemoIds.branchNorth,
        DemoIds.phoneProduct,
      );
      final notifications = await firestore
          .collection('notifications')
          .where('userId', isEqualTo: seller.id)
          .get();

      expect(rejectedReservation.status, ReservationStatus.rejected);
      expect(rejectedReservation.reviewComment, contains('prioridad'));
      expect(inventoryAfterRejection!.reservedStock, 1);
      expect(inventoryAfterRejection.availableStock, 15);
      expect(notifications.docs, hasLength(1));
      expect(notifications.docs.first.data()['type'], 'reservation');
    },
  );

  test(
    'seller requests a transfer into own branch and source stock is validated',
    () async {
      await service.seedMasterData(actorUser: sampleData.users.first);
      final seller = sampleData.users.firstWhere(
        (user) => user.id == DemoIds.branchSeller,
      );

      final transfer = await service.requestTransfer(
        actorUser: seller,
        productId: DemoIds.phoneProduct,
        fromBranchId: DemoIds.branchNorth,
        toBranchId: DemoIds.branchCenter,
        quantity: 3,
        reason: 'Venta comprometida sin stock local',
      );

      expect(transfer.requestedBy, seller.id);
      expect(transfer.fromBranchId, DemoIds.branchNorth);
      expect(transfer.toBranchId, DemoIds.branchCenter);
      expect(transfer.status, TransferStatus.pending);

      expect(
        () => service.requestTransfer(
          actorUser: seller,
          productId: DemoIds.phoneProduct,
          fromBranchId: DemoIds.branchNorth,
          toBranchId: DemoIds.branchCenter,
          quantity: 18,
          reason: 'Prueba sin stock suficiente',
        ),
        throwsA(
          isA<InventoryException>().having(
            (error) => error.message,
            'message',
            contains('Stock insuficiente'),
          ),
        ),
      );
    },
  );

  test(
    'approve, ship and receive transfer updates source, destination and notifications',
    () async {
      await service.seedMasterData(actorUser: sampleData.users.first);
      final supervisor = sampleData.users.firstWhere(
        (user) => user.id == DemoIds.secondBranchSeller,
      );
      final seller = sampleData.users.firstWhere(
        (user) => user.id == DemoIds.branchSeller,
      );

      final transfer = await service.requestTransfer(
        actorUser: seller,
        productId: DemoIds.laptopProduct,
        fromBranchId: DemoIds.branchNorth,
        toBranchId: DemoIds.branchCenter,
        quantity: 2,
        reason: 'Reposicion de prueba',
      );

      final approvedTransfer = await service.approveTransfer(
        actorUser: supervisor,
        transferId: transfer.id,
      );
      final sourceInventoryAfterApproval = await service.inventories
          .fetchInventory(DemoIds.branchNorth, DemoIds.laptopProduct);
      final destinationInventoryAfterApproval = await service.inventories
          .fetchInventory(DemoIds.branchCenter, DemoIds.laptopProduct);

      expect(approvedTransfer.status, TransferStatus.approved);
      expect(sourceInventoryAfterApproval!.stock, 10);
      expect(sourceInventoryAfterApproval.availableStock, 10);
      expect(destinationInventoryAfterApproval!.incomingStock, 2);

      final inTransitTransfer = await service.markTransferInTransit(
        actorUser: supervisor,
        transferId: transfer.id,
      );
      expect(inTransitTransfer.status, TransferStatus.inTransit);

      final receivedTransfer = await service.receiveTransfer(
        actorUser: seller,
        transferId: transfer.id,
      );
      final destinationInventoryAfterReceipt = await service.inventories
          .fetchInventory(DemoIds.branchCenter, DemoIds.laptopProduct);
      final notifications = await firestore
          .collection('notifications')
          .where('userId', isEqualTo: DemoIds.branchSeller)
          .get();

      expect(receivedTransfer.status, TransferStatus.received);
      expect(destinationInventoryAfterReceipt!.stock, 10);
      expect(destinationInventoryAfterReceipt.availableStock, 9);
      expect(destinationInventoryAfterReceipt.incomingStock, 0);
      expect(notifications.docs, hasLength(2));
    },
  );

  test(
    'transfer traceability exposes actors, inventories and audited timeline',
    () async {
      await service.seedMasterData(actorUser: sampleData.users.first);
      final admin = sampleData.users.firstWhere(
        (user) => user.id == DemoIds.adminUser,
      );
      final supervisor = sampleData.users.firstWhere(
        (user) => user.id == DemoIds.secondBranchSeller,
      );
      final seller = sampleData.users.firstWhere(
        (user) => user.id == DemoIds.branchSeller,
      );

      final transfer = await service.requestTransfer(
        actorUser: seller,
        productId: DemoIds.laptopProduct,
        fromBranchId: DemoIds.branchNorth,
        toBranchId: DemoIds.branchCenter,
        quantity: 2,
        reason: 'Venta prioritaria',
        notes: 'Cliente confirmado en caja',
      );

      await service.approveTransfer(
        actorUser: supervisor,
        transferId: transfer.id,
      );
      await service.markTransferInTransit(
        actorUser: supervisor,
        transferId: transfer.id,
      );
      await service.receiveTransfer(actorUser: seller, transferId: transfer.id);

      final detail = await service.fetchTransferTraceability(
        actorUser: admin,
        transferId: transfer.id,
      );

      expect(detail.transfer.status, TransferStatus.received);
      expect(detail.requesterUser?.id, seller.id);
      expect(detail.approverUser?.id, supervisor.id);
      expect(detail.sourceInventory, isNotNull);
      expect(detail.sourceInventory!.stock, 10);
      expect(detail.destinationInventory, isNotNull);
      expect(detail.destinationInventory!.stock, 10);
      expect(
        detail.auditTrail.map((item) => item.action).toList(growable: false),
        <String>[
          'transfer_requested',
          'transfer_approved',
          'transfer_in_transit',
          'transfer_received',
        ],
      );
      expect(detail.requestLog?.metadata['fromBranchId'], DemoIds.branchNorth);
      expect(detail.requestLog?.metadata['toBranchId'], DemoIds.branchCenter);
      expect(detail.requestLog?.metadata['quantity'], '2');
      expect(detail.requestLog?.metadata['reason'], 'Venta prioritaria');
      expect(
        detail.dispatchLog?.metadata['dispatchedByUserId'],
        DemoIds.secondBranchSeller,
      );
      expect(
        detail.receiveLog?.metadata['receivedByUserId'],
        DemoIds.branchSeller,
      );
    },
  );

  test(
    'supervisor can reject transfer requests and notify the requester',
    () async {
      await service.seedMasterData(actorUser: sampleData.users.first);
      final supervisor = sampleData.users.firstWhere(
        (user) => user.id == DemoIds.secondBranchSeller,
      );
      final seller = sampleData.users.firstWhere(
        (user) => user.id == DemoIds.branchSeller,
      );

      final transfer = await service.requestTransfer(
        actorUser: seller,
        productId: DemoIds.laptopProduct,
        fromBranchId: DemoIds.branchNorth,
        toBranchId: DemoIds.branchCenter,
        quantity: 2,
        reason: 'Solicitud sin urgencia',
      );

      final rejectedTransfer = await service.rejectTransfer(
        actorUser: supervisor,
        transferId: transfer.id,
        reviewComment: 'Se prioriza stock para la demanda local.',
      );
      final sourceInventory = await service.inventories.fetchInventory(
        DemoIds.branchNorth,
        DemoIds.laptopProduct,
      );
      final destinationInventory = await service.inventories.fetchInventory(
        DemoIds.branchCenter,
        DemoIds.laptopProduct,
      );
      final notifications = await firestore
          .collection('notifications')
          .where('userId', isEqualTo: seller.id)
          .get();

      expect(rejectedTransfer.status, TransferStatus.rejected);
      expect(rejectedTransfer.reviewComment, contains('demanda local'));
      expect(sourceInventory!.stock, 12);
      expect(destinationInventory!.incomingStock, 0);
      expect(notifications.docs, hasLength(1));
      expect(notifications.docs.first.data()['type'], 'transfer');
    },
  );

  test(
    'users can read their notification inbox and mark notifications as read',
    () async {
      await service.seedMasterData(actorUser: sampleData.users.first);
      final supervisor = sampleData.users.firstWhere(
        (user) => user.id == DemoIds.secondBranchSeller,
      );
      final seller = sampleData.users.firstWhere(
        (user) => user.id == DemoIds.branchSeller,
      );

      final transfer = await service.requestTransfer(
        actorUser: seller,
        productId: DemoIds.laptopProduct,
        fromBranchId: DemoIds.branchNorth,
        toBranchId: DemoIds.branchCenter,
        quantity: 1,
        reason: 'Seguimiento de notificaciones',
      );
      await service.rejectTransfer(
        actorUser: supervisor,
        transferId: transfer.id,
        reviewComment: 'Se mantiene prioridad para ventas locales.',
      );

      final inbox = await service.watchNotifications(actorUser: seller).first;
      expect(inbox, hasLength(1));
      expect(inbox.first.isRead, isFalse);
      expect(inbox.first.message, contains('Motivo:'));
      expect(inbox.first.message, contains('ventas locales'));

      await service.markNotificationAsRead(
        actorUser: seller,
        notificationId: inbox.first.id,
      );

      final updatedInbox = await service
          .watchNotifications(actorUser: seller)
          .first;
      expect(updatedInbox.first.isRead, isTrue);

      final markedCount = await service.markAllNotificationsAsRead(
        actorUser: seller,
      );
      expect(markedCount, 0);
    },
  );

  test(
    'seller cannot initialize the master data or approve transfers',
    () async {
      final seller = sampleData.users.firstWhere(
        (user) => user.id == DemoIds.branchSeller,
      );

      expect(
        () => service.seedMasterData(actorUser: seller),
        throwsA(
          isA<InventoryException>().having(
            (error) => error.message,
            'message',
            contains('no tiene permiso'),
          ),
        ),
      );

      await service.seedMasterData(actorUser: sampleData.users.first);
      final transfer = await service.requestTransfer(
        actorUser: seller,
        productId: DemoIds.laptopProduct,
        fromBranchId: DemoIds.branchNorth,
        toBranchId: DemoIds.branchCenter,
        quantity: 1,
        reason: 'Prueba de permisos',
      );

      expect(
        () =>
            service.approveTransfer(actorUser: seller, transferId: transfer.id),
        throwsA(
          isA<InventoryException>().having(
            (error) => error.message,
            'message',
            contains('no tiene permiso'),
          ),
        ),
      );
    },
  );

  test('users cannot operate transfers outside their own branch', () async {
    await service.seedMasterData(actorUser: sampleData.users.first);
    final seller = sampleData.users.firstWhere(
      (user) => user.id == DemoIds.branchSeller,
    );

    final transfer = await service.requestTransfer(
      actorUser: seller,
      productId: DemoIds.laptopProduct,
      fromBranchId: DemoIds.branchNorth,
      toBranchId: DemoIds.branchCenter,
      quantity: 1,
      reason: 'Cruce entre sucursales',
    );

    expect(
      () => service.markTransferInTransit(
        actorUser: seller,
        transferId: transfer.id,
      ),
      throwsA(
        isA<InventoryException>().having(
          (error) => error.message,
          'message',
          contains('no tiene permiso'),
        ),
      ),
    );
  });
}
