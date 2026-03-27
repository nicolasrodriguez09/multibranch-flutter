import '../domain/models.dart';

abstract final class DemoIds {
  static const adminUser = 'uid_admin';
  static const branchSeller = 'uid_seller_branch_001';
  static const secondBranchSeller = 'uid_seller_branch_002';

  static const branchCenter = 'branch_001';
  static const branchNorth = 'branch_002';

  static const laptopsCategory = 'cat_laptops';
  static const phonesCategory = 'cat_phones';

  static const laptopProduct = 'prod_001';
  static const phoneProduct = 'prod_002';
}

class SampleSeedData {
  const SampleSeedData({
    required this.users,
    required this.branches,
    required this.categories,
    required this.products,
    required this.inventories,
  });

  final List<AppUser> users;
  final List<Branch> branches;
  final List<Category> categories;
  final List<Product> products;
  final List<InventoryItem> inventories;

  factory SampleSeedData.build(DateTime now) {
    final users = <AppUser>[
      AppUser(
        id: DemoIds.adminUser,
        fullName: 'Ana Admin',
        email: 'admin@empresa.com',
        phone: '0999000001',
        role: UserRole.admin,
        branchId: DemoIds.branchCenter,
        isActive: true,
        photoUrl: '',
        lastLoginAt: now,
        createdAt: now,
        updatedAt: now,
      ),
      AppUser(
        id: DemoIds.branchSeller,
        fullName: 'Juan Centro',
        email: 'juan@empresa.com',
        phone: '0999000002',
        role: UserRole.seller,
        branchId: DemoIds.branchCenter,
        isActive: true,
        photoUrl: '',
        lastLoginAt: now,
        createdAt: now,
        updatedAt: now,
      ),
      AppUser(
        id: DemoIds.secondBranchSeller,
        fullName: 'Maria Norte',
        email: 'maria@empresa.com',
        phone: '0999000003',
        role: UserRole.supervisor,
        branchId: DemoIds.branchNorth,
        isActive: true,
        photoUrl: '',
        lastLoginAt: now,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    final branches = <Branch>[
      Branch(
        id: DemoIds.branchCenter,
        name: 'Sucursal Centro',
        code: 'CENTRO',
        address: 'Av. Principal 123',
        city: 'Quito',
        phone: '022222222',
        email: 'centro@empresa.com',
        location: const BranchLocation(lat: -0.1807, lng: -78.4678),
        isActive: true,
        managerName: 'Maria Lopez',
        openingHours: '08:00-18:00',
        lastSyncAt: now,
        createdAt: now,
        updatedAt: now,
      ),
      Branch(
        id: DemoIds.branchNorth,
        name: 'Sucursal Norte',
        code: 'NORTE',
        address: 'Av. Norte 500',
        city: 'Quito',
        phone: '023333333',
        email: 'norte@empresa.com',
        location: const BranchLocation(lat: -0.1022, lng: -78.4304),
        isActive: true,
        managerName: 'Carlos Ruiz',
        openingHours: '09:00-19:00',
        lastSyncAt: now,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    final categories = <Category>[
      Category(
        id: DemoIds.laptopsCategory,
        name: 'Laptops',
        description: 'Equipos portatiles',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
      Category(
        id: DemoIds.phonesCategory,
        name: 'Phones',
        description: 'Telefonos inteligentes',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    final products = <Product>[
      Product(
        id: DemoIds.laptopProduct,
        sku: 'LAP-001',
        barcode: '7501234567890',
        name: 'Laptop HP 15',
        description: 'Laptop HP Ryzen 5, 8GB RAM, 512GB SSD',
        categoryId: DemoIds.laptopsCategory,
        brand: 'HP',
        imageUrl: '',
        price: 799.99,
        cost: 650,
        currency: 'USD',
        tags: const ['laptop', 'hp', 'ryzen'],
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
      Product(
        id: DemoIds.phoneProduct,
        sku: 'PHN-002',
        barcode: '7501234567801',
        name: 'Samsung A55',
        description: 'Telefono Samsung 256GB',
        categoryId: DemoIds.phonesCategory,
        brand: 'Samsung',
        imageUrl: '',
        price: 499.99,
        cost: 380,
        currency: 'USD',
        tags: const ['phone', 'samsung', 'android'],
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    final inventories = <InventoryItem>[
      InventoryItem.create(
        branchId: DemoIds.branchCenter,
        branchName: 'Sucursal Centro',
        productId: DemoIds.laptopProduct,
        productName: 'Laptop HP 15',
        sku: 'LAP-001',
        stock: 20,
        reservedStock: 2,
        incomingStock: 0,
        minimumStock: 10,
        updatedBy: DemoIds.adminUser,
        isActive: true,
        updatedAt: now,
        lastMovementAt: now,
        lastSyncAt: now,
      ),
      InventoryItem.create(
        branchId: DemoIds.branchCenter,
        branchName: 'Sucursal Centro',
        productId: DemoIds.phoneProduct,
        productName: 'Samsung A55',
        sku: 'PHN-002',
        stock: 4,
        reservedStock: 0,
        incomingStock: 0,
        minimumStock: 5,
        updatedBy: DemoIds.adminUser,
        isActive: true,
        updatedAt: now,
        lastMovementAt: now,
        lastSyncAt: now,
      ),
      InventoryItem.create(
        branchId: DemoIds.branchNorth,
        branchName: 'Sucursal Norte',
        productId: DemoIds.laptopProduct,
        productName: 'Laptop HP 15',
        sku: 'LAP-001',
        stock: 12,
        reservedStock: 0,
        incomingStock: 0,
        minimumStock: 6,
        updatedBy: DemoIds.adminUser,
        isActive: true,
        updatedAt: now,
        lastMovementAt: now,
        lastSyncAt: now,
      ),
      InventoryItem.create(
        branchId: DemoIds.branchNorth,
        branchName: 'Sucursal Norte',
        productId: DemoIds.phoneProduct,
        productName: 'Samsung A55',
        sku: 'PHN-002',
        stock: 16,
        reservedStock: 1,
        incomingStock: 0,
        minimumStock: 4,
        updatedBy: DemoIds.adminUser,
        isActive: true,
        updatedAt: now,
        lastMovementAt: now,
        lastSyncAt: now,
      ),
    ];

    return SampleSeedData(
      users: users,
      branches: branches,
      categories: categories,
      products: products,
      inventories: inventories,
    );
  }
}
