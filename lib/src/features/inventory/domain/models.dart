import '../../../core/firestore_serialization.dart';

enum UserRole {
  seller,
  supervisor,
  admin;

  static UserRole fromValue(String value) {
    final normalizedValue = value.trim().toLowerCase();
    return UserRole.values.firstWhere(
      (role) => role.name == normalizedValue,
      orElse: () => UserRole.seller,
    );
  }

  String get sectionTitle => switch (this) {
    UserRole.admin => 'Panel Administrativo',
    UserRole.supervisor => 'Panel Supervisor',
    UserRole.seller => 'Panel de Ventas',
  };
}

enum TransferStatus {
  pending,
  approved,
  rejected,
  inTransit,
  received,
  cancelled;

  String get firestoreValue => switch (this) {
    TransferStatus.inTransit => 'in_transit',
    _ => name,
  };

  static TransferStatus fromValue(String value) {
    return TransferStatus.values.firstWhere(
      (status) => status.firestoreValue == value,
      orElse: () => TransferStatus.pending,
    );
  }
}

enum ReservationStatus {
  pending,
  active,
  rejected,
  expired,
  completed,
  cancelled;

  static ReservationStatus fromValue(String value) {
    return ReservationStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => ReservationStatus.active,
    );
  }
}

class BranchLocation {
  const BranchLocation({required this.lat, required this.lng});

  final double lat;
  final double lng;

  Map<String, dynamic> toFirestore() => {'lat': lat, 'lng': lng};

  factory BranchLocation.fromFirestore(Map<String, dynamic> data) {
    return BranchLocation(
      lat: readDouble(data, 'lat'),
      lng: readDouble(data, 'lng'),
    );
  }
}

class AppUser {
  const AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    required this.branchId,
    required this.isActive,
    required this.photoUrl,
    required this.lastLoginAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String fullName;
  final String email;
  final String phone;
  final UserRole role;
  final String branchId;
  final bool isActive;
  final String photoUrl;
  final DateTime? lastLoginAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toFirestore() => {
    'fullName': fullName,
    'email': email,
    'phone': phone,
    'role': role.name,
    'branchId': branchId,
    'isActive': isActive,
    'photoUrl': photoUrl,
    'lastLoginAt': writeDateTime(lastLoginAt),
    'createdAt': writeDateTime(createdAt),
    'updatedAt': writeDateTime(updatedAt),
  };

  factory AppUser.fromFirestore(String id, Map<String, dynamic> data) {
    return AppUser(
      id: id,
      fullName: readString(data, 'fullName'),
      email: readString(data, 'email'),
      phone: readString(data, 'phone'),
      role: UserRole.fromValue(readString(data, 'role')),
      branchId: readString(data, 'branchId'),
      isActive: readBool(data, 'isActive'),
      photoUrl: readString(data, 'photoUrl'),
      lastLoginAt: readDateTime(data, 'lastLoginAt'),
      createdAt:
          readDateTime(data, 'createdAt') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          readDateTime(data, 'updatedAt') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class Branch {
  const Branch({
    required this.id,
    required this.name,
    required this.code,
    required this.address,
    required this.city,
    required this.phone,
    required this.email,
    required this.location,
    required this.isActive,
    required this.managerName,
    required this.openingHours,
    required this.lastSyncAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String code;
  final String address;
  final String city;
  final String phone;
  final String email;
  final BranchLocation location;
  final bool isActive;
  final String managerName;
  final String openingHours;
  final DateTime? lastSyncAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'code': code,
    'address': address,
    'city': city,
    'phone': phone,
    'email': email,
    'location': location.toFirestore(),
    'isActive': isActive,
    'managerName': managerName,
    'openingHours': openingHours,
    'lastSyncAt': writeDateTime(lastSyncAt),
    'createdAt': writeDateTime(createdAt),
    'updatedAt': writeDateTime(updatedAt),
  };

  factory Branch.fromFirestore(String id, Map<String, dynamic> data) {
    return Branch(
      id: id,
      name: readString(data, 'name'),
      code: readString(data, 'code'),
      address: readString(data, 'address'),
      city: readString(data, 'city'),
      phone: readString(data, 'phone'),
      email: readString(data, 'email'),
      location: BranchLocation.fromFirestore(
        (data['location'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      isActive: readBool(data, 'isActive'),
      managerName: readString(data, 'managerName'),
      openingHours: readString(data, 'openingHours'),
      lastSyncAt: readDateTime(data, 'lastSyncAt'),
      createdAt:
          readDateTime(data, 'createdAt') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          readDateTime(data, 'updatedAt') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.description,
    required this.lowStockThreshold,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String description;
  final int? lowStockThreshold;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'description': description,
    'lowStockThreshold': lowStockThreshold,
    'isActive': isActive,
    'createdAt': writeDateTime(createdAt),
    'updatedAt': writeDateTime(updatedAt),
  };

  factory Category.fromFirestore(String id, Map<String, dynamic> data) {
    return Category(
      id: id,
      name: readString(data, 'name'),
      description: readString(data, 'description'),
      lowStockThreshold: data.containsKey('lowStockThreshold')
          ? readInt(data, 'lowStockThreshold')
          : null,
      isActive: readBool(data, 'isActive'),
      createdAt:
          readDateTime(data, 'createdAt') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          readDateTime(data, 'updatedAt') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class Product {
  const Product({
    required this.id,
    required this.sku,
    required this.barcode,
    required this.name,
    required this.description,
    required this.categoryId,
    required this.brand,
    required this.imageUrl,
    required this.price,
    required this.cost,
    required this.currency,
    required this.tags,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String sku;
  final String barcode;
  final String name;
  final String description;
  final String categoryId;
  final String brand;
  final String imageUrl;
  final double price;
  final double cost;
  final String currency;
  final List<String> tags;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toFirestore() => {
    'sku': sku,
    'barcode': barcode,
    'name': name,
    'description': description,
    'categoryId': categoryId,
    'brand': brand,
    'imageUrl': imageUrl,
    'price': price,
    'cost': cost,
    'currency': currency,
    'tags': tags,
    'isActive': isActive,
    'createdAt': writeDateTime(createdAt),
    'updatedAt': writeDateTime(updatedAt),
  };

  factory Product.fromFirestore(String id, Map<String, dynamic> data) {
    return Product(
      id: id,
      sku: readString(data, 'sku'),
      barcode: readString(data, 'barcode'),
      name: readString(data, 'name'),
      description: readString(data, 'description'),
      categoryId: readString(data, 'categoryId'),
      brand: readString(data, 'brand'),
      imageUrl: readString(data, 'imageUrl'),
      price: readDouble(data, 'price'),
      cost: readDouble(data, 'cost'),
      currency: readString(data, 'currency'),
      tags: readStringList(data, 'tags'),
      isActive: readBool(data, 'isActive'),
      createdAt:
          readDateTime(data, 'createdAt') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          readDateTime(data, 'updatedAt') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.branchId,
    required this.branchName,
    required this.productId,
    required this.productName,
    required this.sku,
    required this.stock,
    required this.reservedStock,
    required this.availableStock,
    required this.incomingStock,
    required this.minimumStock,
    required this.lastMovementAt,
    required this.lastSyncAt,
    required this.updatedBy,
    required this.isActive,
    required this.updatedAt,
    required this.isLowStock,
  });

  final String id;
  final String branchId;
  final String branchName;
  final String productId;
  final String productName;
  final String sku;
  final int stock;
  final int reservedStock;
  final int availableStock;
  final int incomingStock;
  final int minimumStock;
  final DateTime? lastMovementAt;
  final DateTime? lastSyncAt;
  final String updatedBy;
  final bool isActive;
  final DateTime updatedAt;
  final bool isLowStock;

  factory InventoryItem.create({
    required String branchId,
    required String branchName,
    required String productId,
    required String productName,
    required String sku,
    required int stock,
    required int reservedStock,
    required int incomingStock,
    required int minimumStock,
    required String updatedBy,
    required bool isActive,
    required DateTime updatedAt,
    DateTime? lastMovementAt,
    DateTime? lastSyncAt,
  }) {
    final id = inventoryId(branchId, productId);
    final availableStock = stock - reservedStock;
    return InventoryItem(
      id: id,
      branchId: branchId,
      branchName: branchName,
      productId: productId,
      productName: productName,
      sku: sku,
      stock: stock,
      reservedStock: reservedStock,
      availableStock: availableStock,
      incomingStock: incomingStock,
      minimumStock: minimumStock,
      lastMovementAt: lastMovementAt,
      lastSyncAt: lastSyncAt,
      updatedBy: updatedBy,
      isActive: isActive,
      updatedAt: updatedAt,
      isLowStock: availableStock <= minimumStock,
    );
  }

  static String inventoryId(String branchId, String productId) =>
      '${branchId}_$productId';

  InventoryItem recalculate({
    String? branchName,
    String? productName,
    String? sku,
    int? stock,
    int? reservedStock,
    int? incomingStock,
    int? minimumStock,
    String? updatedBy,
    DateTime? updatedAt,
    DateTime? lastMovementAt,
    DateTime? lastSyncAt,
    bool? isActive,
  }) {
    final nextStock = stock ?? this.stock;
    final nextReservedStock = reservedStock ?? this.reservedStock;
    final nextAvailableStock = nextStock - nextReservedStock;
    final nextMinimumStock = minimumStock ?? this.minimumStock;

    return InventoryItem(
      id: id,
      branchId: branchId,
      branchName: branchName ?? this.branchName,
      productId: productId,
      productName: productName ?? this.productName,
      sku: sku ?? this.sku,
      stock: nextStock,
      reservedStock: nextReservedStock,
      availableStock: nextAvailableStock,
      incomingStock: incomingStock ?? this.incomingStock,
      minimumStock: nextMinimumStock,
      lastMovementAt: lastMovementAt ?? this.lastMovementAt,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      updatedBy: updatedBy ?? this.updatedBy,
      isActive: isActive ?? this.isActive,
      updatedAt: updatedAt ?? this.updatedAt,
      isLowStock: nextAvailableStock <= nextMinimumStock,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'branchId': branchId,
    'branchName': branchName,
    'productId': productId,
    'productName': productName,
    'sku': sku,
    'stock': stock,
    'reservedStock': reservedStock,
    'availableStock': availableStock,
    'incomingStock': incomingStock,
    'minimumStock': minimumStock,
    'lastMovementAt': writeDateTime(lastMovementAt),
    'lastSyncAt': writeDateTime(lastSyncAt),
    'updatedBy': updatedBy,
    'isActive': isActive,
    'updatedAt': writeDateTime(updatedAt),
    'isLowStock': isLowStock,
  };

  factory InventoryItem.fromFirestore(String id, Map<String, dynamic> data) {
    return InventoryItem(
      id: id,
      branchId: readString(data, 'branchId'),
      branchName: readString(data, 'branchName'),
      productId: readString(data, 'productId'),
      productName: readString(data, 'productName'),
      sku: readString(data, 'sku'),
      stock: readInt(data, 'stock'),
      reservedStock: readInt(data, 'reservedStock'),
      availableStock: readInt(data, 'availableStock'),
      incomingStock: readInt(data, 'incomingStock'),
      minimumStock: readInt(data, 'minimumStock'),
      lastMovementAt: readDateTime(data, 'lastMovementAt'),
      lastSyncAt: readDateTime(data, 'lastSyncAt'),
      updatedBy: readString(data, 'updatedBy'),
      isActive: readBool(data, 'isActive'),
      updatedAt:
          readDateTime(data, 'updatedAt') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      isLowStock: readBool(data, 'isLowStock'),
    );
  }
}

enum SalePaymentMethod {
  cash('Efectivo'),
  card('Tarjeta'),
  transfer('Transferencia'),
  mixed('Mixto'),
  other('Otro');

  const SalePaymentMethod(this.label);

  final String label;

  static SalePaymentMethod fromValue(String value) {
    final normalized = value.trim().toLowerCase();
    return SalePaymentMethod.values.firstWhere(
      (method) => method.name == normalized,
      orElse: () => SalePaymentMethod.other,
    );
  }
}

class SaleRecord {
  const SaleRecord({
    required this.id,
    required this.branchId,
    required this.branchName,
    required this.sellerId,
    required this.sellerName,
    required this.productId,
    required this.productName,
    required this.sku,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    required this.currency,
    required this.paymentMethod,
    required this.customerName,
    required this.customerPhone,
    required this.notes,
    required this.soldAt,
    required this.createdAt,
  });

  final String id;
  final String branchId;
  final String branchName;
  final String sellerId;
  final String sellerName;
  final String productId;
  final String productName;
  final String sku;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final String currency;
  final SalePaymentMethod paymentMethod;
  final String customerName;
  final String customerPhone;
  final String notes;
  final DateTime soldAt;
  final DateTime createdAt;

  Map<String, dynamic> toFirestore() => {
    'branchId': branchId,
    'branchName': branchName,
    'sellerId': sellerId,
    'sellerName': sellerName,
    'productId': productId,
    'productName': productName,
    'sku': sku,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'totalPrice': totalPrice,
    'currency': currency,
    'paymentMethod': paymentMethod.name,
    'customerName': customerName,
    'customerPhone': customerPhone,
    'notes': notes,
    'soldAt': writeDateTime(soldAt),
    'createdAt': writeDateTime(createdAt),
  };

  factory SaleRecord.fromFirestore(String id, Map<String, dynamic> data) {
    return SaleRecord(
      id: id,
      branchId: readString(data, 'branchId'),
      branchName: readString(data, 'branchName'),
      sellerId: readString(data, 'sellerId'),
      sellerName: readString(data, 'sellerName'),
      productId: readString(data, 'productId'),
      productName: readString(data, 'productName'),
      sku: readString(data, 'sku'),
      quantity: readInt(data, 'quantity'),
      unitPrice: readDouble(data, 'unitPrice'),
      totalPrice: readDouble(data, 'totalPrice'),
      currency: readString(data, 'currency'),
      paymentMethod: SalePaymentMethod.fromValue(
        readString(data, 'paymentMethod'),
      ),
      customerName: readString(data, 'customerName'),
      customerPhone: readString(data, 'customerPhone'),
      notes: readString(data, 'notes'),
      soldAt:
          readDateTime(data, 'soldAt') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      createdAt:
          readDateTime(data, 'createdAt') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class TransferRequest {
  const TransferRequest({
    required this.id,
    required this.productId,
    required this.productName,
    required this.sku,
    required this.fromBranchId,
    required this.fromBranchName,
    required this.toBranchId,
    required this.toBranchName,
    required this.requestedBy,
    this.requestedByName = '',
    required this.approvedBy,
    this.rejectedBy,
    required this.quantity,
    required this.status,
    required this.reason,
    required this.notes,
    this.reviewComment = '',
    required this.requestedAt,
    required this.approvedAt,
    this.rejectedAt,
    required this.shippedAt,
    required this.receivedAt,
    required this.updatedAt,
  });

  final String id;
  final String productId;
  final String productName;
  final String sku;
  final String fromBranchId;
  final String fromBranchName;
  final String toBranchId;
  final String toBranchName;
  final String requestedBy;
  final String requestedByName;
  final String? approvedBy;
  final String? rejectedBy;
  final int quantity;
  final TransferStatus status;
  final String reason;
  final String notes;
  final String reviewComment;
  final DateTime requestedAt;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final DateTime? shippedAt;
  final DateTime? receivedAt;
  final DateTime updatedAt;

  TransferRequest copyWith({
    String? id,
    String? requestedByName,
    String? approvedBy,
    String? rejectedBy,
    TransferStatus? status,
    String? reviewComment,
    DateTime? approvedAt,
    DateTime? rejectedAt,
    DateTime? shippedAt,
    DateTime? receivedAt,
    DateTime? updatedAt,
  }) {
    return TransferRequest(
      id: id ?? this.id,
      productId: productId,
      productName: productName,
      sku: sku,
      fromBranchId: fromBranchId,
      fromBranchName: fromBranchName,
      toBranchId: toBranchId,
      toBranchName: toBranchName,
      requestedBy: requestedBy,
      requestedByName: requestedByName ?? this.requestedByName,
      approvedBy: approvedBy ?? this.approvedBy,
      rejectedBy: rejectedBy ?? this.rejectedBy,
      quantity: quantity,
      status: status ?? this.status,
      reason: reason,
      notes: notes,
      reviewComment: reviewComment ?? this.reviewComment,
      requestedAt: requestedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      shippedAt: shippedAt ?? this.shippedAt,
      receivedAt: receivedAt ?? this.receivedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'productId': productId,
    'productName': productName,
    'sku': sku,
    'fromBranchId': fromBranchId,
    'fromBranchName': fromBranchName,
    'toBranchId': toBranchId,
    'toBranchName': toBranchName,
    'requestedBy': requestedBy,
    if (requestedByName.isNotEmpty) 'requestedByName': requestedByName,
    'approvedBy': approvedBy,
    'rejectedBy': rejectedBy,
    'quantity': quantity,
    'status': status.firestoreValue,
    'reason': reason,
    'notes': notes,
    if (reviewComment.isNotEmpty) 'reviewComment': reviewComment,
    'requestedAt': writeDateTime(requestedAt),
    'approvedAt': writeDateTime(approvedAt),
    'rejectedAt': writeDateTime(rejectedAt),
    'shippedAt': writeDateTime(shippedAt),
    'receivedAt': writeDateTime(receivedAt),
    'updatedAt': writeDateTime(updatedAt),
  };

  factory TransferRequest.fromFirestore(String id, Map<String, dynamic> data) {
    return TransferRequest(
      id: id,
      productId: readString(data, 'productId'),
      productName: readString(data, 'productName'),
      sku: readString(data, 'sku'),
      fromBranchId: readString(data, 'fromBranchId'),
      fromBranchName: readString(data, 'fromBranchName'),
      toBranchId: readString(data, 'toBranchId'),
      toBranchName: readString(data, 'toBranchName'),
      requestedBy: readString(data, 'requestedBy'),
      requestedByName: readString(data, 'requestedByName'),
      approvedBy: data['approvedBy'] as String?,
      rejectedBy: data['rejectedBy'] as String?,
      quantity: readInt(data, 'quantity'),
      status: TransferStatus.fromValue(readString(data, 'status')),
      reason: readString(data, 'reason'),
      notes: readString(data, 'notes'),
      reviewComment: readString(data, 'reviewComment'),
      requestedAt:
          readDateTime(data, 'requestedAt') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      approvedAt: readDateTime(data, 'approvedAt'),
      rejectedAt: readDateTime(data, 'rejectedAt'),
      shippedAt: readDateTime(data, 'shippedAt'),
      receivedAt: readDateTime(data, 'receivedAt'),
      updatedAt:
          readDateTime(data, 'updatedAt') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class Reservation {
  const Reservation({
    required this.id,
    required this.productId,
    required this.productName,
    required this.sku,
    required this.branchId,
    required this.branchName,
    this.requestingBranchId = '',
    this.requestingBranchName = '',
    required this.customerName,
    required this.customerPhone,
    required this.quantity,
    required this.status,
    required this.reservedBy,
    this.requestedByName = '',
    this.approvedBy,
    this.approvedAt,
    this.rejectedBy,
    this.rejectedAt,
    this.reviewComment = '',
    required this.expiresAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String productId;
  final String productName;
  final String sku;
  final String branchId;
  final String branchName;
  final String requestingBranchId;
  final String requestingBranchName;
  final String customerName;
  final String customerPhone;
  final int quantity;
  final ReservationStatus status;
  final String reservedBy;
  final String requestedByName;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectedBy;
  final DateTime? rejectedAt;
  final String reviewComment;
  final DateTime expiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Reservation copyWith({
    ReservationStatus? status,
    String? approvedBy,
    DateTime? approvedAt,
    String? rejectedBy,
    DateTime? rejectedAt,
    String? reviewComment,
    DateTime? updatedAt,
  }) {
    return Reservation(
      id: id,
      productId: productId,
      productName: productName,
      sku: sku,
      branchId: branchId,
      branchName: branchName,
      requestingBranchId: requestingBranchId,
      requestingBranchName: requestingBranchName,
      customerName: customerName,
      customerPhone: customerPhone,
      quantity: quantity,
      status: status ?? this.status,
      reservedBy: reservedBy,
      requestedByName: requestedByName,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectedBy: rejectedBy ?? this.rejectedBy,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      reviewComment: reviewComment ?? this.reviewComment,
      expiresAt: expiresAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'productId': productId,
    'productName': productName,
    'sku': sku,
    'branchId': branchId,
    'branchName': branchName,
    if (requestingBranchId.isNotEmpty) 'requestingBranchId': requestingBranchId,
    if (requestingBranchName.isNotEmpty)
      'requestingBranchName': requestingBranchName,
    'customerName': customerName,
    'customerPhone': customerPhone,
    'quantity': quantity,
    'status': status.name,
    'reservedBy': reservedBy,
    if (requestedByName.isNotEmpty) 'requestedByName': requestedByName,
    'approvedBy': approvedBy,
    'approvedAt': writeDateTime(approvedAt),
    'rejectedBy': rejectedBy,
    'rejectedAt': writeDateTime(rejectedAt),
    if (reviewComment.isNotEmpty) 'reviewComment': reviewComment,
    'expiresAt': writeDateTime(expiresAt),
    'createdAt': writeDateTime(createdAt),
    'updatedAt': writeDateTime(updatedAt),
  };

  factory Reservation.fromFirestore(String id, Map<String, dynamic> data) {
    return Reservation(
      id: id,
      productId: readString(data, 'productId'),
      productName: readString(data, 'productName'),
      sku: readString(data, 'sku'),
      branchId: readString(data, 'branchId'),
      branchName: readString(data, 'branchName'),
      requestingBranchId: readString(data, 'requestingBranchId'),
      requestingBranchName: readString(data, 'requestingBranchName'),
      customerName: readString(data, 'customerName'),
      customerPhone: readString(data, 'customerPhone'),
      quantity: readInt(data, 'quantity'),
      status: ReservationStatus.fromValue(readString(data, 'status')),
      reservedBy: readString(data, 'reservedBy'),
      requestedByName: readString(data, 'requestedByName'),
      approvedBy: data['approvedBy'] as String?,
      approvedAt: readDateTime(data, 'approvedAt'),
      rejectedBy: data['rejectedBy'] as String?,
      rejectedAt: readDateTime(data, 'rejectedAt'),
      reviewComment: readString(data, 'reviewComment'),
      expiresAt:
          readDateTime(data, 'expiresAt') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      createdAt:
          readDateTime(data, 'createdAt') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          readDateTime(data, 'updatedAt') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class SyncLog {
  const SyncLog({
    required this.id,
    required this.branchId,
    required this.branchName,
    required this.type,
    required this.status,
    required this.recordsProcessed,
    required this.startedAt,
    required this.finishedAt,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String branchId;
  final String branchName;
  final String type;
  final String status;
  final int recordsProcessed;
  final DateTime startedAt;
  final DateTime finishedAt;
  final String message;
  final DateTime createdAt;

  Map<String, dynamic> toFirestore() => {
    'branchId': branchId,
    'branchName': branchName,
    'type': type,
    'status': status,
    'recordsProcessed': recordsProcessed,
    'startedAt': writeDateTime(startedAt),
    'finishedAt': writeDateTime(finishedAt),
    'message': message,
    'createdAt': writeDateTime(createdAt),
  };

  factory SyncLog.fromFirestore(String id, Map<String, dynamic> data) {
    return SyncLog(
      id: id,
      branchId: readString(data, 'branchId'),
      branchName: readString(data, 'branchName'),
      type: readString(data, 'type'),
      status: readString(data, 'status'),
      recordsProcessed: readInt(data, 'recordsProcessed'),
      startedAt:
          readDateTime(data, 'startedAt') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      finishedAt:
          readDateTime(data, 'finishedAt') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      message: readString(data, 'message'),
      createdAt:
          readDateTime(data, 'createdAt') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.referenceId,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String title;
  final String message;
  final String type;
  final String referenceId;
  final bool isRead;
  final DateTime createdAt;

  Map<String, dynamic> toFirestore() => {
    'userId': userId,
    'title': title,
    'message': message,
    'type': type,
    'referenceId': referenceId,
    'isRead': isRead,
    'createdAt': writeDateTime(createdAt),
  };

  factory AppNotification.fromFirestore(String id, Map<String, dynamic> data) {
    return AppNotification(
      id: id,
      userId: readString(data, 'userId'),
      title: readString(data, 'title'),
      message: readString(data, 'message'),
      type: readString(data, 'type'),
      referenceId: readString(data, 'referenceId'),
      isRead: readBool(data, 'isRead'),
      createdAt:
          readDateTime(data, 'createdAt') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class StockAlertReadState {
  const StockAlertReadState({
    required this.id,
    required this.userId,
    required this.alertId,
    required this.branchId,
    required this.productId,
    required this.alertUpdatedAt,
    required this.readAt,
  });

  final String id;
  final String userId;
  final String alertId;
  final String branchId;
  final String productId;
  final DateTime alertUpdatedAt;
  final DateTime readAt;

  Map<String, dynamic> toFirestore() => {
    'userId': userId,
    'alertId': alertId,
    'branchId': branchId,
    'productId': productId,
    'alertUpdatedAt': writeDateTime(alertUpdatedAt),
    'readAt': writeDateTime(readAt),
  };

  factory StockAlertReadState.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return StockAlertReadState(
      id: id,
      userId: readString(data, 'userId'),
      alertId: readString(data, 'alertId'),
      branchId: readString(data, 'branchId'),
      productId: readString(data, 'productId'),
      alertUpdatedAt:
          readDateTime(data, 'alertUpdatedAt') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      readAt:
          readDateTime(data, 'readAt') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class AuditLog {
  const AuditLog({
    required this.id,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.entityLabel,
    required this.actorUserId,
    required this.actorName,
    required this.actorRole,
    required this.message,
    required this.metadata,
    required this.createdAt,
    this.branchId,
    this.branchName,
  });

  final String id;
  final String action;
  final String entityType;
  final String entityId;
  final String entityLabel;
  final String actorUserId;
  final String actorName;
  final UserRole actorRole;
  final String message;
  final Map<String, String> metadata;
  final DateTime createdAt;
  final String? branchId;
  final String? branchName;

  Map<String, dynamic> toFirestore() => {
    'action': action,
    'entityType': entityType,
    'entityId': entityId,
    'entityLabel': entityLabel,
    'actorUserId': actorUserId,
    'actorName': actorName,
    'actorRole': actorRole.name,
    'message': message,
    'metadata': metadata,
    'createdAt': writeDateTime(createdAt),
    'branchId': branchId,
    'branchName': branchName,
  };

  factory AuditLog.fromFirestore(String id, Map<String, dynamic> data) {
    final rawMetadata =
        (data['metadata'] as Map?)?.cast<Object?, Object?>() ?? const {};
    return AuditLog(
      id: id,
      action: readString(data, 'action'),
      entityType: readString(data, 'entityType'),
      entityId: readString(data, 'entityId'),
      entityLabel: readString(data, 'entityLabel'),
      actorUserId: readString(data, 'actorUserId'),
      actorName: readString(data, 'actorName'),
      actorRole: UserRole.fromValue(readString(data, 'actorRole')),
      message: readString(data, 'message'),
      metadata: rawMetadata.map(
        (key, value) =>
            MapEntry(key?.toString() ?? '', value?.toString() ?? ''),
      ),
      createdAt:
          readDateTime(data, 'createdAt') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      branchId: data['branchId'] as String?,
      branchName: data['branchName'] as String?,
    );
  }
}

enum RequestLogStatus {
  success,
  error;

  static RequestLogStatus fromValue(String value) {
    return RequestLogStatus.values.firstWhere(
      (status) => status.name == value.trim().toLowerCase(),
      orElse: () => RequestLogStatus.success,
    );
  }
}

class RequestLog {
  const RequestLog({
    required this.id,
    required this.operation,
    required this.source,
    required this.status,
    required this.actorUserId,
    required this.actorName,
    required this.actorRole,
    required this.durationMs,
    required this.requestSummary,
    required this.responseSummary,
    required this.createdAt,
    this.branchId,
    this.branchName,
    this.entityType,
    this.entityId,
    this.entityLabel,
    this.errorType,
    this.errorMessage,
  });

  final String id;
  final String operation;
  final String source;
  final RequestLogStatus status;
  final String actorUserId;
  final String actorName;
  final UserRole actorRole;
  final int durationMs;
  final Map<String, String> requestSummary;
  final Map<String, String> responseSummary;
  final DateTime createdAt;
  final String? branchId;
  final String? branchName;
  final String? entityType;
  final String? entityId;
  final String? entityLabel;
  final String? errorType;
  final String? errorMessage;

  bool get isError => status == RequestLogStatus.error;

  Map<String, dynamic> toFirestore() => {
    'operation': operation,
    'source': source,
    'status': status.name,
    'actorUserId': actorUserId,
    'actorName': actorName,
    'actorRole': actorRole.name,
    'durationMs': durationMs,
    'requestSummary': requestSummary,
    'responseSummary': responseSummary,
    'createdAt': writeDateTime(createdAt),
    'branchId': branchId,
    'branchName': branchName,
    'entityType': entityType,
    'entityId': entityId,
    'entityLabel': entityLabel,
    'errorType': errorType,
    'errorMessage': errorMessage,
  };

  factory RequestLog.fromFirestore(String id, Map<String, dynamic> data) {
    final rawRequestSummary =
        (data['requestSummary'] as Map?)?.cast<Object?, Object?>() ?? const {};
    final rawResponseSummary =
        (data['responseSummary'] as Map?)?.cast<Object?, Object?>() ?? const {};

    return RequestLog(
      id: id,
      operation: readString(data, 'operation'),
      source: readString(data, 'source'),
      status: RequestLogStatus.fromValue(readString(data, 'status')),
      actorUserId: readString(data, 'actorUserId'),
      actorName: readString(data, 'actorName'),
      actorRole: UserRole.fromValue(readString(data, 'actorRole')),
      durationMs: readInt(data, 'durationMs'),
      requestSummary: rawRequestSummary.map(
        (key, value) =>
            MapEntry(key?.toString() ?? '', value?.toString() ?? ''),
      ),
      responseSummary: rawResponseSummary.map(
        (key, value) =>
            MapEntry(key?.toString() ?? '', value?.toString() ?? ''),
      ),
      createdAt:
          readDateTime(data, 'createdAt') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      branchId: data['branchId'] as String?,
      branchName: data['branchName'] as String?,
      entityType: data['entityType'] as String?,
      entityId: data['entityId'] as String?,
      entityLabel: data['entityLabel'] as String?,
      errorType: data['errorType'] as String?,
      errorMessage: data['errorMessage'] as String?,
    );
  }
}

class SearchHistoryEntry {
  const SearchHistoryEntry({
    required this.id,
    required this.userId,
    required this.query,
    required this.normalizedQuery,
    required this.hitCount,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String query;
  final String normalizedQuery;
  final int hitCount;
  final DateTime updatedAt;

  Map<String, dynamic> toFirestore() => {
    'userId': userId,
    'query': query,
    'normalizedQuery': normalizedQuery,
    'hitCount': hitCount,
    'updatedAt': writeDateTime(updatedAt),
  };

  factory SearchHistoryEntry.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return SearchHistoryEntry(
      id: id,
      userId: readString(data, 'userId'),
      query: readString(data, 'query'),
      normalizedQuery: readString(data, 'normalizedQuery'),
      hitCount: readInt(data, 'hitCount'),
      updatedAt:
          readDateTime(data, 'updatedAt') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

enum ProductAvailabilityFilter {
  any,
  available,
  outOfStock,
  lowStock;

  static ProductAvailabilityFilter fromValue(String value) {
    final normalizedValue = value.trim().toLowerCase();
    return ProductAvailabilityFilter.values.firstWhere(
      (item) => item.name.toLowerCase() == normalizedValue,
      orElse: () => ProductAvailabilityFilter.any,
    );
  }
}

class ProductSearchFilters {
  const ProductSearchFilters({
    this.categoryId,
    this.brand,
    this.branchId,
    this.availability = ProductAvailabilityFilter.any,
    this.minStock,
    this.maxStock,
  });

  final String? categoryId;
  final String? brand;
  final String? branchId;
  final ProductAvailabilityFilter availability;
  final int? minStock;
  final int? maxStock;

  int get activeFilterCount =>
      ((categoryId?.isNotEmpty ?? false) ? 1 : 0) +
      ((brand?.isNotEmpty ?? false) ? 1 : 0) +
      ((branchId?.isNotEmpty ?? false) ? 1 : 0) +
      (availability == ProductAvailabilityFilter.any ? 0 : 1) +
      (minStock == null ? 0 : 1) +
      (maxStock == null ? 0 : 1);

  bool get isEmpty =>
      (categoryId == null || categoryId!.isEmpty) &&
      (brand == null || brand!.isEmpty) &&
      (branchId == null || branchId!.isEmpty) &&
      availability == ProductAvailabilityFilter.any &&
      minStock == null &&
      maxStock == null;

  ProductSearchFilters copyWith({
    String? categoryId,
    String? brand,
    String? branchId,
    ProductAvailabilityFilter? availability,
    int? minStock,
    int? maxStock,
    bool clearCategoryId = false,
    bool clearBrand = false,
    bool clearBranchId = false,
    bool clearMinStock = false,
    bool clearMaxStock = false,
  }) {
    return ProductSearchFilters(
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      brand: clearBrand ? null : (brand ?? this.brand),
      branchId: clearBranchId ? null : (branchId ?? this.branchId),
      availability: availability ?? this.availability,
      minStock: clearMinStock ? null : (minStock ?? this.minStock),
      maxStock: clearMaxStock ? null : (maxStock ?? this.maxStock),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'categoryId': categoryId,
    'brand': brand,
    'branchId': branchId,
    'availability': availability.name,
    'minStock': minStock,
    'maxStock': maxStock,
  };

  factory ProductSearchFilters.fromFirestore(Map<String, dynamic> data) {
    return ProductSearchFilters(
      categoryId: data['categoryId'] as String?,
      brand: data['brand'] as String?,
      branchId: data['branchId'] as String?,
      availability: ProductAvailabilityFilter.fromValue(
        readString(data, 'availability'),
      ),
      minStock: data['minStock'] is int ? data['minStock'] as int : null,
      maxStock: data['maxStock'] is int ? data['maxStock'] as int : null,
    );
  }
}

class SavedSearchFilter {
  const SavedSearchFilter({
    required this.id,
    required this.userId,
    required this.label,
    required this.filters,
    required this.isFavorite,
    required this.usageCount,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String label;
  final ProductSearchFilters filters;
  final bool isFavorite;
  final int usageCount;
  final DateTime updatedAt;

  Map<String, dynamic> toFirestore() => {
    'userId': userId,
    'label': label,
    'filters': filters.toFirestore(),
    'isFavorite': isFavorite,
    'usageCount': usageCount,
    'updatedAt': writeDateTime(updatedAt),
  };

  factory SavedSearchFilter.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return SavedSearchFilter(
      id: id,
      userId: readString(data, 'userId'),
      label: readString(data, 'label'),
      filters: ProductSearchFilters.fromFirestore(
        (data['filters'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      isFavorite: readBool(data, 'isFavorite'),
      usageCount: readInt(data, 'usageCount'),
      updatedAt:
          readDateTime(data, 'updatedAt') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class InventoryException implements Exception {
  const InventoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
