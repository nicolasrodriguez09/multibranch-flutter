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
    'createReservation and completeReservation keep inventory consistent',
    () async {
      await service.seedMasterData(actorUser: sampleData.users.first);
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
      expect(reservation.status, ReservationStatus.active);
      expect(reservedInventory!.reservedStock, 2);
      expect(reservedInventory.availableStock, 6);

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
        actorUser: supervisor,
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
          .where('userId', isEqualTo: DemoIds.secondBranchSeller)
          .get();

      expect(receivedTransfer.status, TransferStatus.received);
      expect(destinationInventoryAfterReceipt!.stock, 10);
      expect(destinationInventoryAfterReceipt.availableStock, 9);
      expect(destinationInventoryAfterReceipt.incomingStock, 0);
      expect(notifications.docs, hasLength(2));
    },
  );

  test(
    'seller cannot initialize the master data or approve transfers',
    () async {
      final seller = sampleData.users.firstWhere(
        (user) => user.id == DemoIds.branchSeller,
      );
      final supervisor = sampleData.users.firstWhere(
        (user) => user.id == DemoIds.secondBranchSeller,
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
        actorUser: supervisor,
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
    final supervisor = sampleData.users.firstWhere(
      (user) => user.id == DemoIds.secondBranchSeller,
    );
    final seller = sampleData.users.firstWhere(
      (user) => user.id == DemoIds.branchSeller,
    );

    final transfer = await service.requestTransfer(
      actorUser: supervisor,
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
