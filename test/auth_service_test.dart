import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_multibranch_proyect/src/features/auth/application/auth_service.dart';
import 'package:flutter_multibranch_proyect/src/features/inventory/domain/models.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;
  late _FakeEmployeeAccountCreator employeeAccountCreator;
  late AuthService authService;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    auth = MockFirebaseAuth();
    employeeAccountCreator = _FakeEmployeeAccountCreator(
      uid: 'employee_uid_001',
    );
    authService = AuthService(
      auth: auth,
      firestore: firestore,
      employeeAccountCreator: employeeAccountCreator,
    );
  });

  test('admin can create employee profile with selected role', () async {
    await firestore.collection('branches').doc('branch_001').set({
      'name': 'Sucursal Centro',
      'code': 'CENTRO',
      'address': 'Av. Principal 123',
      'city': 'Quito',
      'phone': '022222222',
      'email': 'centro@empresa.com',
      'location': {'lat': 0.0, 'lng': 0.0},
      'isActive': true,
      'managerName': 'Maria Lopez',
      'openingHours': '08:00-18:00',
      'lastSyncAt': null,
      'createdAt': null,
      'updatedAt': null,
    });

    final admin = AppUser(
      id: 'admin_uid',
      fullName: 'Ana Admin',
      email: 'admin@empresa.com',
      phone: '',
      role: UserRole.admin,
      branchId: 'branch_001',
      isActive: true,
      photoUrl: '',
      lastLoginAt: null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );

    await authService.createEmployee(
      currentUser: admin,
      fullName: 'Laura Supervisor',
      email: 'laura@empresa.com',
      password: '123456',
      phone: '0999888777',
      branchId: 'branch_001',
      role: UserRole.supervisor,
    );

    final createdUser = await authService.users.fetchUser('employee_uid_001');
    final auditLogs = await firestore
        .collection('audit_logs')
        .where('action', isEqualTo: 'employee_created')
        .get();

    expect(createdUser, isNotNull);
    expect(createdUser!.email, 'laura@empresa.com');
    expect(createdUser.role, UserRole.supervisor);
    expect(createdUser.branchId, 'branch_001');
    expect(auditLogs.docs, hasLength(1));
    expect(auditLogs.docs.first.data()['actorUserId'], 'admin_uid');
    expect(
      auditLogs.docs.first.data()['metadata']['assignedRole'],
      'supervisor',
    );
    expect(employeeAccountCreator.completeCalls, 1);
    expect(employeeAccountCreator.rollbackCalls, 0);
  });

  test('admin can update employee role and audit the change', () async {
    await firestore.collection('branches').doc('branch_001').set({
      'name': 'Sucursal Centro',
      'code': 'CENTRO',
      'address': 'Av. Principal 123',
      'city': 'Quito',
      'phone': '022222222',
      'email': 'centro@empresa.com',
      'location': {'lat': 0.0, 'lng': 0.0},
      'isActive': true,
      'managerName': 'Maria Lopez',
      'openingHours': '08:00-18:00',
      'lastSyncAt': null,
      'createdAt': null,
      'updatedAt': null,
    });
    await firestore.collection('users').doc('employee_uid_001').set({
      'fullName': 'Laura Supervisor',
      'email': 'laura@empresa.com',
      'phone': '',
      'role': 'seller',
      'branchId': 'branch_001',
      'isActive': true,
      'photoUrl': '',
      'lastLoginAt': null,
      'createdAt': null,
      'updatedAt': null,
    });

    final admin = AppUser(
      id: 'admin_uid',
      fullName: 'Ana Admin',
      email: 'admin@empresa.com',
      phone: '',
      role: UserRole.admin,
      branchId: 'branch_001',
      isActive: true,
      photoUrl: '',
      lastLoginAt: null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );

    final updatedUser = await authService.updateEmployeeRole(
      currentUser: admin,
      userId: 'employee_uid_001',
      role: UserRole.supervisor,
    );
    final auditLogs = await firestore
        .collection('audit_logs')
        .where('action', isEqualTo: 'employee_role_updated')
        .get();

    expect(updatedUser.role, UserRole.supervisor);
    expect(auditLogs.docs, hasLength(1));
    expect(auditLogs.docs.first.data()['metadata']['previousRole'], 'seller');
    expect(auditLogs.docs.first.data()['metadata']['newRole'], 'supervisor');
  });

  test(
    'admin can update employee administrative data and audit changes',
    () async {
      await firestore.collection('branches').doc('branch_001').set({
        'name': 'Sucursal Centro',
        'code': 'CENTRO',
        'address': 'Av. Principal 123',
        'city': 'Quito',
        'phone': '022222222',
        'email': 'centro@empresa.com',
        'location': {'lat': 0.0, 'lng': 0.0},
        'isActive': true,
        'managerName': 'Maria Lopez',
        'openingHours': '08:00-18:00',
        'lastSyncAt': null,
        'createdAt': null,
        'updatedAt': null,
      });
      await firestore.collection('branches').doc('branch_002').set({
        'name': 'Sucursal Norte',
        'code': 'NORTE',
        'address': 'Av. Secundaria 45',
        'city': 'Quito',
        'phone': '023333333',
        'email': 'norte@empresa.com',
        'location': {'lat': 0.0, 'lng': 0.0},
        'isActive': true,
        'managerName': 'Carlos Ruiz',
        'openingHours': '08:00-18:00',
        'lastSyncAt': null,
        'createdAt': null,
        'updatedAt': null,
      });
      await firestore.collection('users').doc('employee_uid_001').set({
        'fullName': 'Laura Supervisor',
        'email': 'laura@empresa.com',
        'phone': '',
        'role': 'supervisor',
        'branchId': 'branch_001',
        'isActive': true,
        'photoUrl': '',
        'lastLoginAt': null,
        'createdAt': null,
        'updatedAt': null,
      });

      final admin = AppUser(
        id: 'admin_uid',
        fullName: 'Ana Admin',
        email: 'admin@empresa.com',
        phone: '',
        role: UserRole.admin,
        branchId: 'branch_001',
        isActive: true,
        photoUrl: '',
        lastLoginAt: null,
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

      final updatedUser = await authService.updateEmployee(
        currentUser: admin,
        userId: 'employee_uid_001',
        fullName: 'Laura Norte',
        phone: '0999000111',
        role: UserRole.supervisor,
        branchId: 'branch_002',
        isActive: false,
      );
      final auditLogs = await firestore
          .collection('audit_logs')
          .where('action', isEqualTo: 'employee_updated')
          .get();

      expect(updatedUser.fullName, 'Laura Norte');
      expect(updatedUser.phone, '0999000111');
      expect(updatedUser.branchId, 'branch_002');
      expect(updatedUser.isActive, isFalse);
      expect(auditLogs.docs, hasLength(1));
      expect(
        auditLogs.docs.first.data()['metadata']['updatedFields'],
        'fullName,phone,branchId,isActive',
      );
      expect(auditLogs.docs.first.data()['metadata']['newStatus'], 'inactive');
    },
  );

  test('non admin cannot create employee accounts', () async {
    final seller = AppUser(
      id: 'seller_uid',
      fullName: 'Juan Seller',
      email: 'seller@empresa.com',
      phone: '',
      role: UserRole.seller,
      branchId: 'branch_001',
      isActive: true,
      photoUrl: '',
      lastLoginAt: null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );

    expect(
      () => authService.createEmployee(
        currentUser: seller,
        fullName: 'Laura Supervisor',
        email: 'laura@empresa.com',
        password: '123456',
        branchId: 'branch_001',
        role: UserRole.supervisor,
      ),
      throwsA(
        isA<AuthException>().having(
          (error) => error.message,
          'message',
          'Solo un administrador puede crear empleados.',
        ),
      ),
    );
  });
}

class _FakeEmployeeAccountCreator implements EmployeeAccountCreator {
  _FakeEmployeeAccountCreator({required this.uid});

  final String uid;
  int completeCalls = 0;
  int rollbackCalls = 0;

  @override
  Future<CreatedEmployeeAccount> createAccount({
    required String email,
    required String password,
    required String displayName,
  }) async {
    return CreatedEmployeeAccount(
      uid: uid,
      completeAction: () async {
        completeCalls++;
      },
      rollbackAction: () async {
        rollbackCalls++;
      },
    );
  }
}
