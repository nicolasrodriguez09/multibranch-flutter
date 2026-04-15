import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firestore_collections.dart';
import '../data/repositories.dart';
import '../data/sample_seed_data.dart';
import '../domain/models.dart';
import '../domain/role_permissions.dart';

class DailyTransferRequestMetric {
  const DailyTransferRequestMetric({required this.day, required this.count});

  final DateTime day;
  final int count;
}

class OutOfStockConsultationMetric {
  const OutOfStockConsultationMetric({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.interestScore,
    required this.reservationHits,
    required this.transferHits,
    required this.availableStock,
    required this.lastMovementAt,
  });

  final String productId;
  final String productName;
  final String sku;
  final int interestScore;
  final int reservationHits;
  final int transferHits;
  final int availableStock;
  final DateTime? lastMovementAt;
}

class BranchOperationalStats {
  const BranchOperationalStats({
    required this.lowStockCount,
    required this.outOfStockCount,
    required this.pendingTransfersCount,
    required this.activeReservationsCount,
    required this.transferRequestsToday,
    required this.averageApiResponseTime,
    required this.transferRequestsByDay,
    required this.outOfStockConsultations,
  });

  final int lowStockCount;
  final int outOfStockCount;
  final int pendingTransfersCount;
  final int activeReservationsCount;
  final int transferRequestsToday;
  final Duration averageApiResponseTime;
  final List<DailyTransferRequestMetric> transferRequestsByDay;
  final List<OutOfStockConsultationMetric> outOfStockConsultations;

  int get consultedOutOfStockCount => outOfStockConsultations.length;
}

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
  CollectionReference<Map<String, dynamic>> get _auditLogsCollection =>
      _firestore.collection(FirestoreCollections.auditLogs);

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

  AuditLog _buildAuditLog({
    required AppUser actorUser,
    required String action,
    required String entityType,
    required String entityId,
    required String entityLabel,
    required String message,
    Map<String, String> metadata = const {},
    String? branchId,
    String? branchName,
  }) {
    final now = _clock();
    return AuditLog(
      id: _auditLogsCollection.doc().id,
      action: action,
      entityType: entityType,
      entityId: entityId,
      entityLabel: entityLabel,
      actorUserId: actorUser.id,
      actorName: actorUser.fullName,
      actorRole: actorUser.role,
      message: message,
      metadata: metadata,
      createdAt: now,
      branchId: branchId,
      branchName: branchName,
    );
  }

  Future<void> seedMasterData({required AppUser actorUser}) async {
    _ensurePermission(actorUser, AppPermission.seedMasterData);

    final now = _clock();
    final seed = SampleSeedData.build(now);
    final batch = _firestore.batch();
    final auditLog = _buildAuditLog(
      actorUser: actorUser,
      action: 'master_data_seeded',
      entityType: 'system',
      entityId: 'master_data',
      entityLabel: 'Base inicial',
      message: 'Creo o actualizo la base de datos inicial.',
      metadata: {
        'branches': '${seed.branches.length}',
        'products': '${seed.products.length}',
        'users': '${seed.users.length}',
      },
    );

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

    batch.set(_auditLogsCollection.doc(auditLog.id), auditLog.toFirestore());

    await batch.commit();
  }

  Future<Branch> createBranch({
    required AppUser actorUser,
    required String name,
    required String code,
    required String address,
    required String city,
    String phone = '',
    String email = '',
    String managerName = '',
    String openingHours = '08:00-18:00',
    double latitude = 0,
    double longitude = 0,
  }) async {
    _ensurePermission(actorUser, AppPermission.manageBranches);

    final normalizedCode = _normalizeBranchCode(code);
    final branchId = 'branch_$normalizedCode';
    final existingBranch = await catalog.fetchBranch(branchId);
    if (existingBranch != null) {
      throw InventoryException(
        'Ya existe una sucursal registrada con el codigo $normalizedCode.',
      );
    }

    final now = _clock();
    final branch = Branch(
      id: branchId,
      name: name.trim(),
      code: normalizedCode.toUpperCase(),
      address: address.trim(),
      city: city.trim(),
      phone: phone.trim(),
      email: email.trim(),
      location: BranchLocation(lat: latitude, lng: longitude),
      isActive: true,
      managerName: managerName.trim(),
      openingHours: openingHours.trim(),
      lastSyncAt: null,
      createdAt: now,
      updatedAt: now,
    );
    final auditLog = _buildAuditLog(
      actorUser: actorUser,
      action: 'branch_created',
      entityType: 'branch',
      entityId: branch.id,
      entityLabel: branch.name,
      message: 'Registro una nueva sucursal.',
      metadata: {
        'code': branch.code,
        'city': branch.city,
        'managerName': branch.managerName,
      },
      branchId: branch.id,
      branchName: branch.name,
    );

    final batch = _firestore.batch();
    batch.set(
      _firestore.collection(FirestoreCollections.branches).doc(branch.id),
      branch.toFirestore(),
    );
    batch.set(_auditLogsCollection.doc(auditLog.id), auditLog.toFirestore());
    await batch.commit();

    return branch;
  }

  Stream<BranchOperationalStats> watchOperationalStats({
    required AppUser actorUser,
    required String branchId,
  }) {
    _ensurePermission(actorUser, AppPermission.viewOperationalMetrics);
    _ensureBranchAccess(actorUser, branchId);

    final controller = StreamController<BranchOperationalStats>();
    var inventoriesState = const <InventoryItem>[];
    var reservationsState = const <Reservation>[];
    var transfersState = const <TransferRequest>[];
    var syncLogsState = const <SyncLog>[];
    var inventoriesReady = false;
    var reservationsReady = false;
    var transfersReady = false;
    var syncLogsReady = false;

    void emit() {
      if (controller.isClosed) {
        return;
      }
      if (!inventoriesReady ||
          !reservationsReady ||
          !transfersReady ||
          !syncLogsReady) {
        return;
      }
      controller.add(
        _buildOperationalStats(
          inventories: inventoriesState,
          reservations: reservationsState,
          transfers: transfersState,
          syncLogs: syncLogsState,
          branchId: branchId,
        ),
      );
    }

    final subscriptions = <StreamSubscription<Object?>>[
      inventories.watchBranchInventory(branchId).listen((items) {
        inventoriesState = items;
        inventoriesReady = true;
        emit();
      }, onError: controller.addError),
      reservations.watchBranchReservations(branchId).listen((items) {
        reservationsState = items;
        reservationsReady = true;
        emit();
      }, onError: controller.addError),
      transfers.watchTransfers().listen((items) {
        transfersState = items;
        transfersReady = true;
        emit();
      }, onError: controller.addError),
      system.watchBranchSyncLogs(branchId, limit: 30).listen((items) {
        syncLogsState = items;
        syncLogsReady = true;
        emit();
      }, onError: controller.addError),
    ];

    controller.onCancel = () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    };

    return controller.stream;
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

  String _normalizeBranchCode(String value) {
    final normalized = value.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '_',
    );
    final compact = normalized.replaceAll(RegExp(r'^_+|_+$'), '');
    if (compact.isEmpty) {
      throw const InventoryException(
        'El codigo de la sucursal debe incluir letras o numeros.',
      );
    }
    return compact;
  }

  BranchOperationalStats _buildOperationalStats({
    required List<InventoryItem> inventories,
    required List<Reservation> reservations,
    required List<TransferRequest> transfers,
    required List<SyncLog> syncLogs,
    required String branchId,
  }) {
    final lowStockCount = inventories
        .where((item) => item.isLowStock && item.availableStock > 0)
        .length;
    final outOfStockCount = inventories
        .where((item) => item.availableStock <= 0)
        .length;
    final activeReservationsCount = reservations
        .where((item) => item.status == ReservationStatus.active)
        .length;
    final branchTransfers = transfers
        .where((item) => _isTransferForBranch(item, branchId))
        .toList(growable: false);
    final pendingTransfersCount = branchTransfers
        .where((item) => item.status == TransferStatus.pending)
        .length;

    final transferRequestsByDay = _buildTransferRequestsByDay(branchTransfers);
    final transferRequestsToday = transferRequestsByDay.isEmpty
        ? 0
        : transferRequestsByDay.last.count;

    return BranchOperationalStats(
      lowStockCount: lowStockCount,
      outOfStockCount: outOfStockCount,
      pendingTransfersCount: pendingTransfersCount,
      activeReservationsCount: activeReservationsCount,
      transferRequestsToday: transferRequestsToday,
      averageApiResponseTime: _averageApiResponseTime(syncLogs),
      transferRequestsByDay: transferRequestsByDay,
      outOfStockConsultations: _buildOutOfStockConsultations(
        inventories: inventories,
        reservations: reservations,
        transfers: branchTransfers,
      ),
    );
  }

  List<DailyTransferRequestMetric> _buildTransferRequestsByDay(
    List<TransferRequest> transfers,
  ) {
    final now = _clock();
    final startDay = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 4));
    final counts = <DateTime, int>{};

    for (var index = 0; index < 5; index++) {
      final day = startDay.add(Duration(days: index));
      counts[DateTime(day.year, day.month, day.day)] = 0;
    }

    for (final transfer in transfers) {
      final requestedDay = DateTime(
        transfer.requestedAt.year,
        transfer.requestedAt.month,
        transfer.requestedAt.day,
      );
      if (requestedDay.isBefore(startDay)) {
        continue;
      }
      counts.update(requestedDay, (value) => value + 1, ifAbsent: () => 1);
    }

    final days = counts.keys.toList(growable: false)..sort();
    return days
        .map(
          (day) =>
              DailyTransferRequestMetric(day: day, count: counts[day] ?? 0),
        )
        .toList(growable: false);
  }

  Duration _averageApiResponseTime(List<SyncLog> syncLogs) {
    if (syncLogs.isEmpty) {
      return Duration.zero;
    }

    var totalMilliseconds = 0;
    for (final log in syncLogs) {
      totalMilliseconds += log.finishedAt
          .difference(log.startedAt)
          .inMilliseconds;
    }

    return Duration(
      milliseconds: (totalMilliseconds / syncLogs.length).round(),
    );
  }

  List<OutOfStockConsultationMetric> _buildOutOfStockConsultations({
    required List<InventoryItem> inventories,
    required List<Reservation> reservations,
    required List<TransferRequest> transfers,
  }) {
    final reservationHits = <String, int>{};
    for (final reservation in reservations) {
      if (reservation.status != ReservationStatus.active) {
        continue;
      }
      reservationHits.update(
        reservation.productId,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    final transferHits = <String, int>{};
    for (final transfer in transfers) {
      if (transfer.status == TransferStatus.rejected ||
          transfer.status == TransferStatus.cancelled) {
        continue;
      }
      transferHits.update(
        transfer.productId,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    final ranked =
        inventories
            .where((item) => item.availableStock <= 0)
            .map((inventory) {
              final reservationsForProduct =
                  reservationHits[inventory.productId] ?? 0;
              final transfersForProduct =
                  transferHits[inventory.productId] ?? 0;
              final recencyScore = _recencyWeight(
                inventory.lastMovementAt,
                _clock(),
              );
              final score =
                  reservationsForProduct * 4 +
                  transfersForProduct * 3 +
                  recencyScore +
                  (inventory.isLowStock ? 1 : 0);

              return OutOfStockConsultationMetric(
                productId: inventory.productId,
                productName: inventory.productName,
                sku: inventory.sku,
                interestScore: score,
                reservationHits: reservationsForProduct,
                transferHits: transfersForProduct,
                availableStock: inventory.availableStock,
                lastMovementAt: inventory.lastMovementAt,
              );
            })
            .toList(growable: false)
          ..sort((left, right) {
            final scoreComparison = right.interestScore.compareTo(
              left.interestScore,
            );
            if (scoreComparison != 0) {
              return scoreComparison;
            }

            final leftDate =
                left.lastMovementAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final rightDate =
                right.lastMovementAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return rightDate.compareTo(leftDate);
          });

    return ranked.take(5).toList(growable: false);
  }

  bool _isTransferForBranch(TransferRequest transfer, String branchId) {
    return transfer.fromBranchId == branchId || transfer.toBranchId == branchId;
  }

  int _recencyWeight(DateTime? value, DateTime now) {
    if (value == null) {
      return 0;
    }

    final difference = now.difference(value);
    if (difference.inHours < 6) {
      return 6;
    }
    if (difference.inHours < 24) {
      return 4;
    }
    if (difference.inDays < 7) {
      return 2;
    }
    return 0;
  }
}
