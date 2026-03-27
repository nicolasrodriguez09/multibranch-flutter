import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_multibranch_proyect/src/features/inventory/application/inventory_workflow_service.dart';
import 'package:flutter_multibranch_proyect/src/features/inventory/data/sample_seed_data.dart';
import 'package:flutter_multibranch_proyect/src/features/inventory/domain/models.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late InventoryWorkflowService service;
  late DateTime now;

  setUp(() {
    now = DateTime.utc(2026, 3, 26, 12, 0);
    firestore = FakeFirebaseFirestore();
    service = InventoryWorkflowService(
      firestore: firestore,
      clock: () => now,
    );
  });

  test('seedMasterData creates master documents and computed inventory fields', () async {
    await service.seedMasterData();

    final inventory = await service.inventories.fetchInventory(DemoIds.branchCenter, DemoIds.laptopProduct);
    final lowStockInventory = await service.inventories.fetchInventory(DemoIds.branchCenter, DemoIds.phoneProduct);

    expect(inventory, isNotNull);
    expect(inventory!.availableStock, 18);
    expect(inventory.isLowStock, isFalse);
    expect(lowStockInventory, isNotNull);
    expect(lowStockInventory!.isLowStock, isTrue);
  });

  test('createReservation and completeReservation keep inventory consistent', () async {
    await service.seedMasterData();

    final reservation = await service.createReservation(
      branchId: DemoIds.branchCenter,
      productId: DemoIds.laptopProduct,
      actorUserId: DemoIds.branchSeller,
      customerName: 'Cliente Test',
      customerPhone: '0999000111',
      quantity: 1,
      expiresIn: const Duration(hours: 24),
    );

    final reservedInventory = await service.inventories.fetchInventory(DemoIds.branchCenter, DemoIds.laptopProduct);
    expect(reservation.status, ReservationStatus.active);
    expect(reservedInventory!.reservedStock, 3);
    expect(reservedInventory.availableStock, 17);

    await service.updateReservationStatus(
      reservationId: reservation.id,
      actorUserId: DemoIds.branchSeller,
      nextStatus: ReservationStatus.completed,
    );

    final releasedInventory = await service.inventories.fetchInventory(DemoIds.branchCenter, DemoIds.laptopProduct);
    final storedReservation = await service.reservations.fetchReservation(reservation.id);

    expect(releasedInventory!.reservedStock, 2);
    expect(releasedInventory.availableStock, 18);
    expect(storedReservation!.status, ReservationStatus.completed);
  });

  test('approve, ship and receive transfer updates source, destination and notifications', () async {
    await service.seedMasterData();

    final transfer = await service.requestTransfer(
      productId: DemoIds.laptopProduct,
      fromBranchId: DemoIds.branchNorth,
      toBranchId: DemoIds.branchCenter,
      actorUserId: DemoIds.branchSeller,
      quantity: 2,
      reason: 'Reposicion de prueba',
    );

    final approvedTransfer = await service.approveTransfer(
      transferId: transfer.id,
      approverUserId: DemoIds.adminUser,
    );
    final sourceInventoryAfterApproval =
        await service.inventories.fetchInventory(DemoIds.branchNorth, DemoIds.laptopProduct);
    final destinationInventoryAfterApproval =
        await service.inventories.fetchInventory(DemoIds.branchCenter, DemoIds.laptopProduct);

    expect(approvedTransfer.status, TransferStatus.approved);
    expect(sourceInventoryAfterApproval!.stock, 10);
    expect(sourceInventoryAfterApproval.availableStock, 10);
    expect(destinationInventoryAfterApproval!.incomingStock, 2);

    final inTransitTransfer = await service.markTransferInTransit(
      transferId: transfer.id,
      actorUserId: DemoIds.adminUser,
    );
    expect(inTransitTransfer.status, TransferStatus.inTransit);

    final receivedTransfer = await service.receiveTransfer(
      transferId: transfer.id,
      actorUserId: DemoIds.secondBranchSeller,
    );
    final destinationInventoryAfterReceipt =
        await service.inventories.fetchInventory(DemoIds.branchCenter, DemoIds.laptopProduct);
    final notifications = await firestore
        .collection('notifications')
        .where('userId', isEqualTo: DemoIds.branchSeller)
        .get();

    expect(receivedTransfer.status, TransferStatus.received);
    expect(destinationInventoryAfterReceipt!.stock, 22);
    expect(destinationInventoryAfterReceipt.availableStock, 20);
    expect(destinationInventoryAfterReceipt.incomingStock, 0);
    expect(notifications.docs, hasLength(2));
  });
}
