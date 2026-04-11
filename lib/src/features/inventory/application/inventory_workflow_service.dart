import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firestore_collections.dart';
import '../data/repositories.dart';
import '../data/sample_seed_data.dart';
import '../domain/models.dart';
import '../domain/role_permissions.dart';

class InventoryWorkflowService {
  InventoryWorkflowService({
    required FirebaseFirestore firestore,
    DateTime Function()? clock,
  }) : _firestore = firestore,
       _clock = clock ?? DateTime.now,
       users = UserRepository(firestore),
       catalog = CatalogRepository(firestore),
       inventories = InventoryRepository(firestore),
       reservations = ReservationRepository(firestore),
       transfers = TransferRepository(firestore),
       system = SystemRepository(firestore);

  final FirebaseFirestore _firestore;
  final DateTime Function() _clock;

  final UserRepository users;
  final CatalogRepository catalog;
  final InventoryRepository inventories;
  final ReservationRepository reservations;
  final TransferRepository transfers;
  final SystemRepository system;

  CollectionReference<Map<String, dynamic>> get _inventoriesCollection =>
      _firestore.collection(FirestoreCollections.inventories);
  CollectionReference<Map<String, dynamic>> get _reservationsCollection =>
      _firestore.collection(FirestoreCollections.reservations);
  CollectionReference<Map<String, dynamic>> get _transfersCollection =>
      _firestore.collection(FirestoreCollections.transfers);
  CollectionReference<Map<String, dynamic>> get _notificationsCollection =>
      _firestore.collection(FirestoreCollections.notifications);

  void _ensurePermission(AppUser actorUser, AppPermission permission) {
    if (actorUser.can(permission)) {
      return;
    }

    throw InventoryException(
      'El rol ${actorUser.role.displayName} no tiene permiso para ${permission.label.toLowerCase()}.',
    );
  }

  void _ensureBranchAccess(AppUser actorUser, String branchId) {
    if (actorUser.canAccessBranch(branchId)) {
      return;
    }

    throw const InventoryException(
      'No puedes operar sobre una sucursal diferente a la asignada.',
    );
  }

  Future<void> seedMasterData({required AppUser actorUser}) async {
    _ensurePermission(actorUser, AppPermission.seedMasterData);

    final now = _clock();
    final seed = SampleSeedData.build(now);
    final batch = _firestore.batch();

    for (final user in seed.users) {
      batch.set(
        _firestore.collection(FirestoreCollections.users).doc(user.id),
        user.toFirestore(),
        SetOptions(merge: true),
      );
    }

    for (final branch in seed.branches) {
      batch.set(
        _firestore.collection(FirestoreCollections.branches).doc(branch.id),
        branch.toFirestore(),
        SetOptions(merge: true),
      );
    }

    for (final category in seed.categories) {
      batch.set(
        _firestore.collection(FirestoreCollections.categories).doc(category.id),
        category.toFirestore(),
        SetOptions(merge: true),
      );
    }

    for (final product in seed.products) {
      batch.set(
        _firestore.collection(FirestoreCollections.products).doc(product.id),
        product.toFirestore(),
        SetOptions(merge: true),
      );
    }

    for (final inventory in seed.inventories) {
      batch.set(
        _inventoriesCollection.doc(inventory.id),
        inventory.toFirestore(),
        SetOptions(merge: true),
      );
    }

    for (final reservation in seed.reservations) {
      batch.set(
        _reservationsCollection.doc(reservation.id),
        reservation.toFirestore(),
        SetOptions(merge: true),
      );
    }

    for (final transfer in seed.transfers) {
      batch.set(
        _transfersCollection.doc(transfer.id),
        transfer.toFirestore(),
        SetOptions(merge: true),
      );
    }

    for (final syncLog in seed.syncLogs) {
      batch.set(
        _firestore.collection(FirestoreCollections.syncLogs).doc(syncLog.id),
        syncLog.toFirestore(),
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  Future<InventoryItem> setInventoryStock({
    required AppUser actorUser,
    required String branchId,
    required String productId,
    required int stock,
    int? minimumStock,
  }) async {
    _ensurePermission(actorUser, AppPermission.manageInventory);
    _ensureBranchAccess(actorUser, branchId);

    final now = _clock();
    final inventoryRef = _inventoriesCollection.doc(
      inventories.inventoryId(branchId, productId),
    );

    return _firestore.runTransaction((transaction) async {
      final inventorySnapshot = await transaction.get(inventoryRef);
      if (!inventorySnapshot.exists) {
        throw const InventoryException(
          'El inventario no existe para la sucursal y producto indicados.',
        );
      }

      final inventory = InventoryItem.fromFirestore(
        inventorySnapshot.id,
        inventorySnapshot.data()!,
      );
      final updatedInventory = inventory.recalculate(
        stock: stock,
        minimumStock: minimumStock,
        updatedBy: actorUser.id,
        updatedAt: now,
        lastMovementAt: now,
      );

      transaction.set(inventoryRef, updatedInventory.toFirestore());
      return updatedInventory;
    });
  }

  Future<Reservation> createReservation({
    required AppUser actorUser,
    required String branchId,
    required String productId,
    required String customerName,
    required String customerPhone,
    required int quantity,
    required Duration expiresIn,
  }) async {
    _ensurePermission(actorUser, AppPermission.createReservation);
    _ensureBranchAccess(actorUser, branchId);

    if (quantity <= 0) {
      throw const InventoryException(
        'La cantidad reservada debe ser mayor que cero.',
      );
    }

    final now = _clock();
    final expiresAt = now.add(expiresIn);
    final inventoryRef = _inventoriesCollection.doc(
      inventories.inventoryId(branchId, productId),
    );
    final reservationRef = _reservationsCollection.doc();

    return _firestore.runTransaction((transaction) async {
      final inventorySnapshot = await transaction.get(inventoryRef);
      if (!inventorySnapshot.exists) {
        throw const InventoryException(
          'No existe inventario para la sucursal y producto indicados.',
        );
      }

      final inventory = InventoryItem.fromFirestore(
        inventorySnapshot.id,
        inventorySnapshot.data()!,
      );

      if (!inventory.isActive) {
        throw const InventoryException('El inventario se encuentra inactivo.');
      }

      if (inventory.availableStock < quantity) {
        throw InventoryException(
          'Stock insuficiente. Disponible: ${inventory.availableStock}, solicitado: $quantity.',
        );
      }

      final updatedInventory = inventory.recalculate(
        reservedStock: inventory.reservedStock + quantity,
        updatedBy: actorUser.id,
        updatedAt: now,
        lastMovementAt: now,
      );

      final reservation = Reservation(
        id: reservationRef.id,
        productId: inventory.productId,
        productName: inventory.productName,
        sku: inventory.sku,
        branchId: inventory.branchId,
        branchName: inventory.branchName,
        customerName: customerName,
        customerPhone: customerPhone,
        quantity: quantity,
        status: ReservationStatus.active,
        reservedBy: actorUser.id,
        expiresAt: expiresAt,
        createdAt: now,
        updatedAt: now,
      );

      transaction.set(inventoryRef, updatedInventory.toFirestore());
      transaction.set(reservationRef, reservation.toFirestore());

      return reservation;
    });
  }

  Future<Reservation> updateReservationStatus({
    required AppUser actorUser,
    required String reservationId,
    required ReservationStatus nextStatus,
  }) async {
    _ensurePermission(actorUser, AppPermission.updateReservation);

    if (nextStatus == ReservationStatus.active) {
      throw const InventoryException('La reserva ya se crea en estado activo.');
    }

    final now = _clock();
    final reservationRef = _reservationsCollection.doc(reservationId);

    return _firestore.runTransaction((transaction) async {
      final reservationSnapshot = await transaction.get(reservationRef);
      if (!reservationSnapshot.exists) {
        throw const InventoryException('La reserva no existe.');
      }

      final reservation = Reservation.fromFirestore(
        reservationSnapshot.id,
        reservationSnapshot.data()!,
      );
      _ensureBranchAccess(actorUser, reservation.branchId);

      if (reservation.status != ReservationStatus.active) {
        throw InventoryException(
          'Solo se pueden cerrar reservas activas. Estado actual: ${reservation.status.name}.',
        );
      }

      final inventoryRef = _inventoriesCollection.doc(
        inventories.inventoryId(reservation.branchId, reservation.productId),
      );
      final inventorySnapshot = await transaction.get(inventoryRef);
      if (!inventorySnapshot.exists) {
        throw const InventoryException(
          'El inventario vinculado a la reserva no existe.',
        );
      }

      final inventory = InventoryItem.fromFirestore(
        inventorySnapshot.id,
        inventorySnapshot.data()!,
      );
      final updatedReservedStock =
          inventory.reservedStock - reservation.quantity;
      if (updatedReservedStock < 0) {
        throw const InventoryException(
          'La reserva no puede liberar mas stock del que esta reservado.',
        );
      }

      final updatedInventory = inventory.recalculate(
        reservedStock: updatedReservedStock,
        updatedBy: actorUser.id,
        updatedAt: now,
        lastMovementAt: now,
      );
      final updatedReservation = reservation.copyWith(
        status: nextStatus,
        updatedAt: now,
      );

      transaction.set(inventoryRef, updatedInventory.toFirestore());
      transaction.set(reservationRef, updatedReservation.toFirestore());

      return updatedReservation;
    });
  }

  Future<TransferRequest> requestTransfer({
    required AppUser actorUser,
    required String productId,
    required String fromBranchId,
    required String toBranchId,
    required int quantity,
    required String reason,
    String notes = '',
  }) async {
    _ensurePermission(actorUser, AppPermission.requestTransfer);
    _ensureBranchAccess(actorUser, fromBranchId);

    if (quantity <= 0) {
      throw const InventoryException(
        'La cantidad del traslado debe ser mayor que cero.',
      );
    }
    if (fromBranchId == toBranchId) {
      throw const InventoryException(
        'El origen y destino del traslado no pueden ser iguales.',
      );
    }

    final product = await catalog.fetchProduct(productId);
    final sourceBranch = await catalog.fetchBranch(fromBranchId);
    final destinationBranch = await catalog.fetchBranch(toBranchId);

    if (product == null || sourceBranch == null || destinationBranch == null) {
      throw const InventoryException(
        'No se encontro el producto o alguna de las sucursales del traslado.',
      );
    }

    final now = _clock();
    final transferRef = _transfersCollection.doc();
    final transfer = TransferRequest(
      id: transferRef.id,
      productId: product.id,
      productName: product.name,
      sku: product.sku,
      fromBranchId: sourceBranch.id,
      fromBranchName: sourceBranch.name,
      toBranchId: destinationBranch.id,
      toBranchName: destinationBranch.name,
      requestedBy: actorUser.id,
      approvedBy: null,
      quantity: quantity,
      status: TransferStatus.pending,
      reason: reason,
      notes: notes,
      requestedAt: now,
      approvedAt: null,
      shippedAt: null,
      receivedAt: null,
      updatedAt: now,
    );

    await transferRef.set(transfer.toFirestore());
    return transfer;
  }

  Future<TransferRequest> approveTransfer({
    required AppUser actorUser,
    required String transferId,
  }) async {
    _ensurePermission(actorUser, AppPermission.approveTransfer);

    final now = _clock();
    final transferRef = _transfersCollection.doc(transferId);
    final notificationRef = _notificationsCollection.doc();

    return _firestore.runTransaction((transaction) async {
      final transferSnapshot = await transaction.get(transferRef);
      if (!transferSnapshot.exists) {
        throw const InventoryException('El traslado no existe.');
      }

      final transfer = TransferRequest.fromFirestore(
        transferSnapshot.id,
        transferSnapshot.data()!,
      );
      _ensureBranchAccess(actorUser, transfer.fromBranchId);

      if (transfer.status != TransferStatus.pending) {
        throw InventoryException(
          'Solo se pueden aprobar traslados pendientes. Estado: ${transfer.status.firestoreValue}.',
        );
      }

      final sourceInventoryRef = _inventoriesCollection.doc(
        inventories.inventoryId(transfer.fromBranchId, transfer.productId),
      );
      final destinationInventoryRef = _inventoriesCollection.doc(
        inventories.inventoryId(transfer.toBranchId, transfer.productId),
      );

      final sourceInventorySnapshot = await transaction.get(sourceInventoryRef);
      if (!sourceInventorySnapshot.exists) {
        throw const InventoryException(
          'No existe inventario origen para este traslado.',
        );
      }

      final sourceInventory = InventoryItem.fromFirestore(
        sourceInventorySnapshot.id,
        sourceInventorySnapshot.data()!,
      );
      if (sourceInventory.availableStock < transfer.quantity) {
        throw InventoryException(
          'Stock insuficiente para aprobar el traslado. Disponible: ${sourceInventory.availableStock}.',
        );
      }

      final destinationInventorySnapshot = await transaction.get(
        destinationInventoryRef,
      );
      final destinationInventory = destinationInventorySnapshot.exists
          ? InventoryItem.fromFirestore(
              destinationInventorySnapshot.id,
              destinationInventorySnapshot.data()!,
            )
          : InventoryItem.create(
              branchId: transfer.toBranchId,
              branchName: transfer.toBranchName,
              productId: transfer.productId,
              productName: transfer.productName,
              sku: transfer.sku,
              stock: 0,
              reservedStock: 0,
              incomingStock: 0,
              minimumStock: 0,
              updatedBy: actorUser.id,
              isActive: true,
              updatedAt: now,
              lastMovementAt: now,
            );

      final updatedSourceInventory = sourceInventory.recalculate(
        stock: sourceInventory.stock - transfer.quantity,
        updatedBy: actorUser.id,
        updatedAt: now,
        lastMovementAt: now,
      );
      final updatedDestinationInventory = destinationInventory.recalculate(
        incomingStock: destinationInventory.incomingStock + transfer.quantity,
        updatedBy: actorUser.id,
        updatedAt: now,
        lastMovementAt: now,
      );
      final updatedTransfer = transfer.copyWith(
        status: TransferStatus.approved,
        approvedBy: actorUser.id,
        approvedAt: now,
        updatedAt: now,
      );

      final notification = AppNotification(
        id: notificationRef.id,
        userId: transfer.requestedBy,
        title: 'Solicitud aprobada',
        message:
            'El traslado ${transfer.id} fue aprobado y quedo listo para despacho.',
        type: 'transfer',
        referenceId: transfer.id,
        isRead: false,
        createdAt: now,
      );

      transaction.set(sourceInventoryRef, updatedSourceInventory.toFirestore());
      transaction.set(
        destinationInventoryRef,
        updatedDestinationInventory.toFirestore(),
        SetOptions(merge: true),
      );
      transaction.set(transferRef, updatedTransfer.toFirestore());
      transaction.set(notificationRef, notification.toFirestore());

      return updatedTransfer;
    });
  }

  Future<TransferRequest> markTransferInTransit({
    required AppUser actorUser,
    required String transferId,
  }) async {
    _ensurePermission(actorUser, AppPermission.dispatchTransfer);

    final now = _clock();
    final transferRef = _transfersCollection.doc(transferId);

    return _firestore.runTransaction((transaction) async {
      final transferSnapshot = await transaction.get(transferRef);
      if (!transferSnapshot.exists) {
        throw const InventoryException('El traslado no existe.');
      }

      final transfer = TransferRequest.fromFirestore(
        transferSnapshot.id,
        transferSnapshot.data()!,
      );
      _ensureBranchAccess(actorUser, transfer.fromBranchId);

      if (transfer.status != TransferStatus.approved) {
        throw InventoryException(
          'Solo se puede despachar un traslado aprobado. Estado: ${transfer.status.firestoreValue}.',
        );
      }

      final updatedTransfer = transfer.copyWith(
        status: TransferStatus.inTransit,
        shippedAt: now,
        updatedAt: now,
        approvedBy: transfer.approvedBy ?? actorUser.id,
      );

      transaction.set(transferRef, updatedTransfer.toFirestore());
      return updatedTransfer;
    });
  }

  Future<TransferRequest> receiveTransfer({
    required AppUser actorUser,
    required String transferId,
  }) async {
    _ensurePermission(actorUser, AppPermission.receiveTransfer);

    final now = _clock();
    final transferRef = _transfersCollection.doc(transferId);
    final notificationRef = _notificationsCollection.doc();

    return _firestore.runTransaction((transaction) async {
      final transferSnapshot = await transaction.get(transferRef);
      if (!transferSnapshot.exists) {
        throw const InventoryException('El traslado no existe.');
      }

      final transfer = TransferRequest.fromFirestore(
        transferSnapshot.id,
        transferSnapshot.data()!,
      );
      _ensureBranchAccess(actorUser, transfer.toBranchId);

      if (transfer.status != TransferStatus.inTransit) {
        throw InventoryException(
          'Solo se puede recibir un traslado en transito. Estado: ${transfer.status.firestoreValue}.',
        );
      }

      final destinationInventoryRef = _inventoriesCollection.doc(
        inventories.inventoryId(transfer.toBranchId, transfer.productId),
      );
      final destinationInventorySnapshot = await transaction.get(
        destinationInventoryRef,
      );
      if (!destinationInventorySnapshot.exists) {
        throw const InventoryException(
          'No existe inventario destino para recibir el traslado.',
        );
      }

      final destinationInventory = InventoryItem.fromFirestore(
        destinationInventorySnapshot.id,
        destinationInventorySnapshot.data()!,
      );

      if (destinationInventory.incomingStock < transfer.quantity) {
        throw const InventoryException(
          'El inventario destino no tiene stock en camino suficiente para recibir.',
        );
      }

      final updatedDestinationInventory = destinationInventory.recalculate(
        stock: destinationInventory.stock + transfer.quantity,
        incomingStock: destinationInventory.incomingStock - transfer.quantity,
        updatedBy: actorUser.id,
        updatedAt: now,
        lastMovementAt: now,
      );
      final updatedTransfer = transfer.copyWith(
        status: TransferStatus.received,
        receivedAt: now,
        updatedAt: now,
      );

      final notification = AppNotification(
        id: notificationRef.id,
        userId: transfer.requestedBy,
        title: 'Traslado recibido',
        message:
            'El traslado ${transfer.id} fue recibido en ${transfer.toBranchName}.',
        type: 'transfer',
        referenceId: transfer.id,
        isRead: false,
        createdAt: now,
      );

      transaction.set(
        destinationInventoryRef,
        updatedDestinationInventory.toFirestore(),
      );
      transaction.set(transferRef, updatedTransfer.toFirestore());
      transaction.set(notificationRef, notification.toFirestore());

      return updatedTransfer;
    });
  }
}
