import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:uuid/uuid.dart';

import '../../../core/firestore_collections.dart';
import '../domain/models.dart';

class SeederService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _uuid = const Uuid();
  final _random = Random();

  Future<void> seedDatabase() async {
    try {
      print('Iniciando borrado de base de datos...');
      await _deleteAll();
    } catch (e) {
      throw Exception('Error en _deleteAll: $e');
    }

    List<Branch> branches;
    try {
      print('Creando sucursales...');
      branches = await _createBranches();
    } catch (e) {
      throw Exception('Error en _createBranches: $e');
    }

    List<AppUser> users;
    try {
      print('Creando usuarios...');
      users = await _createUsers(branches);
    } catch (e) {
      throw Exception('Error en _createUsers: $e');
    }

    List<Category> categories;
    List<Product> products;
    try {
      print('Creando categorías y productos...');
      categories = await _createCategories();
      products = await _createProducts(categories);
    } catch (e) {
      throw Exception('Error en _createCategories/Products: $e');
    }

    try {
      print('Creando inventarios...');
      await _createInventories(branches, products);
    } catch (e) {
      throw Exception('Error en _createInventories: $e');
    }

    try {
      print('Creando traslados y reservas...');
      await _createTransfers(branches, products, users);
      await _createReservations(branches, products, users);
    } catch (e) {
      throw Exception('Error en _createTransfers/Reservations: $e');
    }

    print('Base de datos inicial creada con éxito.');
  }

  Future<void> _deleteAll() async {
    final collections = [
      FirestoreCollections.users,
      FirestoreCollections.branches,
      FirestoreCollections.categories,
      FirestoreCollections.products,
      FirestoreCollections.inventories,
      FirestoreCollections.transfers,
      FirestoreCollections.reservations,
    ];

    for (final col in collections) {
      final snapshot = await _firestore.collection(col).get();
      for (final doc in snapshot.docs) {
        // No borrar al usuario actual que está ejecutando el seeder
        if (col == FirestoreCollections.users && doc.id == FirebaseAuth.instance.currentUser?.uid) {
          continue;
        }
        await doc.reference.delete();
      }
    }
  }

  Future<List<Branch>> _createBranches() async {
    final branchConfigs = [
      {
        'name': 'Sede Bogotá',
        'code': 'BOG-01',
        'city': 'Bogotá',
        'lat': 4.7110,
        'lng': -74.0721,
      },
      {
        'name': 'Sede Medellín',
        'code': 'MED-01',
        'city': 'Medellín',
        'lat': 6.2442,
        'lng': -75.5812,
      },
      {
        'name': 'Sede Cali',
        'code': 'CAL-01',
        'city': 'Cali',
        'lat': 3.4516,
        'lng': -76.5320,
      },
      {
        'name': 'Sede Barranquilla',
        'code': 'BAQ-01',
        'city': 'Barranquilla',
        'lat': 10.9685,
        'lng': -74.7813,
      },
      {
        'name': 'Sede Bucaramanga',
        'code': 'BUC-01',
        'city': 'Bucaramanga',
        'lat': 7.1254,
        'lng': -73.1198,
      },
    ];

    final branches = <Branch>[];
    for (final config in branchConfigs) {
      final branchId = _uuid.v4();
      final branch = Branch(
        id: branchId,
        name: config['name'] as String,
        code: config['code'] as String,
        address: 'Carrera 12 # 34-56, ${config['city']}',
        city: config['city'] as String,
        phone: '3001234567',
        email: 'contacto.${(config['city'] as String).toLowerCase()}@empresa.com',
        location: BranchLocation(
          lat: config['lat'] as double,
          lng: config['lng'] as double,
        ),
        isActive: true,
        managerName: 'Gerente ${config['city']}',
        openingHours: 'Lunes a Viernes: 8:00 AM - 6:00 PM',
        lastSyncAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _firestore
          .collection(FirestoreCollections.branches)
          .doc(branchId)
          .set(branch.toFirestore());
      branches.add(branch);
    }
    return branches;
  }

  Future<List<AppUser>> _createUsers(List<Branch> branches) async {
    final users = <AppUser>[];
    
    // Crear instancia secundaria temporal
    final tempApp = await Firebase.initializeApp(
      name: 'TempSeederApp',
      options: Firebase.app().options,
    );
    final tempAuth = FirebaseAuth.instanceFor(app: tempApp);

    Future<AppUser?> createUserAuth(String email, String name, UserRole role, String branchId) async {
      try {
        final cred = await tempAuth.createUserWithEmailAndPassword(
          email: email,
          password: 'password',
        );
        if (cred.user != null) {
          final user = AppUser(
            id: cred.user!.uid,
            fullName: name,
            email: email,
            phone: '3000000000',
            role: role,
            branchId: branchId,
            isActive: true,
            photoUrl: '',
            lastLoginAt: DateTime.now(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          await _firestore
              .collection(FirestoreCollections.users)
              .doc(user.id)
              .set(user.toFirestore());
          return user;
        }
      } catch (e) {
        print('Error creando $email: $e');
        if (e is FirebaseAuthException && e.code == 'email-already-in-use') {
           final cred = await tempAuth.signInWithEmailAndPassword(email: email, password: 'password');
           if (cred.user != null) {
               final user = AppUser(
                  id: cred.user!.uid,
                  fullName: name,
                  email: email,
                  phone: '3000000000',
                  role: role,
                  branchId: branchId,
                  isActive: true,
                  photoUrl: '',
                  lastLoginAt: DateTime.now(),
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );
                await _firestore
                    .collection(FirestoreCollections.users)
                    .doc(user.id)
                    .set(user.toFirestore());
                return user;
           }
        }
      }
      return null;
    }

    final admin = await createUserAuth('admin1@gmail.com', 'Administrador General', UserRole.admin, branches.first.id);
    if (admin != null) users.add(admin);

    int superIndex = 1;
    for (final branch in branches) {
      final supEmail = 'supervisor$superIndex@gmail.com';
      final sup = await createUserAuth(supEmail, 'Supervisor ${branch.city}', UserRole.supervisor, branch.id);
      if (sup != null) users.add(sup);

      for (int i = 1; i <= 5; i++) {
        final sellerEmail = 'empleado${superIndex}_$i@gmail.com';
        final seller = await createUserAuth(sellerEmail, 'Vendedor $i ${branch.city}', UserRole.seller, branch.id);
        if (seller != null) users.add(seller);
      }
      superIndex++;
    }

    await tempApp.delete();
    return users;
  }

  Future<List<Category>> _createCategories() async {
    final catNames = ['Smartphones', 'Laptops', 'Audio', 'Accesorios', 'Tablets'];
    final categories = <Category>[];
    for (final name in catNames) {
      final id = _uuid.v4();
      final cat = Category(
        id: id,
        name: name,
        description: 'Categoría de $name',
        isActive: true,
        lowStockThreshold: 10,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _firestore
          .collection(FirestoreCollections.categories)
          .doc(id)
          .set(cat.toFirestore());
      categories.add(cat);
    }
    return categories;
  }

  Future<List<Product>> _createProducts(List<Category> categories) async {
    final products = <Product>[];

    for (int i = 1; i <= 25; i++) {
      final category = categories[_random.nextInt(categories.length)];
      final id = _uuid.v4();
      final product = Product(
        id: id,
        categoryId: category.id,
        sku: 'PRD-${DateTime.now().millisecondsSinceEpoch}-$i',
        barcode: '1000000000$i',
        name: 'Producto de Prueba $i (${category.name})',
        description: 'Descripción detallada del producto $i',
        brand: 'Marca ${_random.nextInt(5) + 1}',
        price: (_random.nextInt(500) + 50) * 1000.0,
        cost: (_random.nextInt(300) + 30) * 1000.0,
        currency: 'COP',
        imageUrl: '',
        tags: [],
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _firestore
          .collection(FirestoreCollections.products)
          .doc(id)
          .set(product.toFirestore());
      products.add(product);
    }
    return products;
  }

  Future<void> _createInventories(List<Branch> branches, List<Product> products) async {
    for (final product in products) {
      for (final branch in branches) {
        final id = '${branch.id}_${product.id}';
        final stock = _random.nextInt(50);
        final minStock = _random.nextInt(10) + 5;

        final inv = InventoryItem(
          id: id,
          productId: product.id,
          productName: product.name,
          sku: product.sku,
          branchId: branch.id,
          branchName: branch.name,
          stock: stock + _random.nextInt(5),
          reservedStock: _random.nextInt(5),
          availableStock: stock,
          incomingStock: _random.nextInt(5),
          minimumStock: minStock,
          lastMovementAt: DateTime.now(),
          lastSyncAt: DateTime.now().subtract(Duration(days: _random.nextInt(30))),
          updatedBy: 'system',
          isActive: true,
          updatedAt: DateTime.now(),
          isLowStock: stock <= minStock,
        );
        await _firestore
            .collection(FirestoreCollections.inventories)
            .doc(id)
            .set(inv.toFirestore());
      }
    }
  }

  Future<void> _createTransfers(List<Branch> branches, List<Product> products, List<AppUser> users) async {
    final supervisors = users.where((u) => u.role == UserRole.supervisor).toList();
    if (supervisors.isEmpty) return;

    final statuses = [
      TransferStatus.pending,
      TransferStatus.approved,
      TransferStatus.inTransit,
      TransferStatus.received,
      TransferStatus.rejected,
      TransferStatus.cancelled,
    ];

    for (int i = 0; i < 15; i++) {
      final origin = branches[_random.nextInt(branches.length)];
      var destination = branches[_random.nextInt(branches.length)];
      while (destination.id == origin.id) {
        destination = branches[_random.nextInt(branches.length)];
      }

      final product = products[_random.nextInt(products.length)];
      final requester = supervisors.firstWhere((s) => s.branchId == destination.id, orElse: () => supervisors.first);
      final approver = supervisors.firstWhere((s) => s.branchId == origin.id, orElse: () => supervisors.first);
      final status = statuses[_random.nextInt(statuses.length)];

      DateTime time = DateTime.now();
      
      final transferId = _uuid.v4();
      final transfer = TransferRequest(
        id: transferId,
        productId: product.id,
        productName: product.name,
        sku: product.sku,
        fromBranchId: origin.id,
        fromBranchName: origin.name,
        toBranchId: destination.id,
        toBranchName: destination.name,
        quantity: _random.nextInt(10) + 1,
        status: status,
        requestedBy: requester.id,
        requestedByName: requester.fullName,
        approvedBy: status != TransferStatus.pending && status != TransferStatus.cancelled ? approver.id : null,
        rejectedBy: status == TransferStatus.rejected ? approver.id : null,
        reason: 'Reabastecimiento de stock',
        notes: 'Necesitamos esto urgente.',
        reviewComment: status == TransferStatus.rejected ? 'No tenemos suficiente stock' : 'Aprobado',
        requestedAt: time.subtract(const Duration(days: 2)),
        approvedAt: (status != TransferStatus.pending && status != TransferStatus.cancelled) ? time.subtract(const Duration(days: 1)) : null,
        rejectedAt: status == TransferStatus.rejected ? time.subtract(const Duration(days: 1)) : null,
        shippedAt: (status == TransferStatus.inTransit || status == TransferStatus.received) ? time.subtract(const Duration(hours: 5)) : null,
        receivedAt: status == TransferStatus.received ? time : null,
        updatedAt: time,
      );

      await _firestore
          .collection(FirestoreCollections.transfers)
          .doc(transferId)
          .set(transfer.toFirestore());
    }
  }

  Future<void> _createReservations(List<Branch> branches, List<Product> products, List<AppUser> users) async {
    final sellers = users.where((u) => u.role == UserRole.seller).toList();
    if (sellers.isEmpty) return;

    final statuses = [
      ReservationStatus.active,
      ReservationStatus.completed,
      ReservationStatus.cancelled,
      ReservationStatus.expired,
    ];

    for (int i = 0; i < 20; i++) {
      final seller = sellers[_random.nextInt(sellers.length)];
      final product = products[_random.nextInt(products.length)];
      final status = statuses[_random.nextInt(statuses.length)];
      final branch = branches.firstWhere((b) => b.id == seller.branchId, orElse: () => branches.first);
      
      DateTime time = DateTime.now();

      final resId = _uuid.v4();
      final res = Reservation(
        id: resId,
        productId: product.id,
        productName: product.name,
        sku: product.sku,
        branchId: branch.id,
        branchName: branch.name,
        requestingBranchId: branch.id,
        requestingBranchName: branch.name,
        quantity: _random.nextInt(3) + 1,
        status: status,
        reservedBy: seller.id,
        requestedByName: seller.fullName,
        customerName: 'Cliente ${_random.nextInt(100)}',
        customerPhone: '3009999999',
        expiresAt: DateTime.now().add(const Duration(days: 1)),
        createdAt: time.subtract(const Duration(days: 1)),
        updatedAt: time,
        approvedAt: status == ReservationStatus.active || status == ReservationStatus.completed ? time.subtract(const Duration(hours: 20)) : null,
        approvedBy: seller.id,
      );

      await _firestore
          .collection(FirestoreCollections.reservations)
          .doc(resId)
          .set(res.toFirestore());
    }
  }
}
