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
    employeeAccountCreator = _FakeEmployeeAccountCreator(uid: 'employee_uid_001');
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

    expect(createdUser, isNotNull);
    expect(createdUser!.email, 'laura@empresa.com');
    expect(createdUser.role, UserRole.supervisor);
    expect(createdUser.branchId, 'branch_001');
    expect(employeeAccountCreator.completeCalls, 1);
    expect(employeeAccountCreator.rollbackCalls, 0);
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
