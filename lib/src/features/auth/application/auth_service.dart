import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../inventory/data/repositories.dart';
import '../../inventory/domain/models.dart';

class AuthService {
  AuthService({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    EmployeeAccountCreator? employeeAccountCreator,
  })  : _auth = auth,
        users = UserRepository(firestore),
        catalog = CatalogRepository(firestore),
        _employeeAccountCreator = employeeAccountCreator ?? FirebaseEmployeeAccountCreator();

  final FirebaseAuth _auth;
  final EmployeeAccountCreator _employeeAccountCreator;

  final UserRepository users;
  final CatalogRepository catalog;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentAuthUser => _auth.currentUser;

  Stream<AppUser?> watchProfile(String uid) => users.watchUser(uid);

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthException(_mapAuthError(error));
    }
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> createEmployee({
    required AppUser currentUser,
    required String fullName,
    required String email,
    required String password,
    required String branchId,
    required UserRole role,
    String phone = '',
  }) async {
    if (currentUser.role != UserRole.admin) {
      throw const AuthException('Solo un administrador puede crear empleados.');
    }

    final branch = await catalog.fetchBranch(branchId);
    if (branch == null) {
      throw const AuthException('La sucursal seleccionada no existe.');
    }

    final createdAccount = await _employeeAccountCreator.createAccount(
      email: email.trim(),
      password: password,
      displayName: fullName.trim(),
    );

    final now = DateTime.now().toUtc();
    final profile = AppUser(
      id: createdAccount.uid,
      fullName: fullName.trim(),
      email: email.trim(),
      phone: phone.trim(),
      role: role,
      branchId: branchId,
      isActive: true,
      photoUrl: '',
      lastLoginAt: null,
      createdAt: now,
      updatedAt: now,
    );

    try {
      await users.upsertUser(profile);
      await createdAccount.complete();
    } catch (_) {
      await createdAccount.rollback();
      throw const AuthException('La cuenta se creo en Authentication, pero fallo el perfil en Firestore.');
    }
  }

  String _mapAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'El correo no tiene un formato valido.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Correo o contrasena incorrectos.';
      case 'email-already-in-use':
        return 'Ese correo ya esta registrado.';
      case 'weak-password':
        return 'La contrasena es demasiado debil.';
      case 'network-request-failed':
        return 'No fue posible conectar con Firebase.';
      default:
        return error.message ?? 'Ocurrio un error de autenticacion.';
    }
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class EmployeeAccountCreator {
  Future<CreatedEmployeeAccount> createAccount({
    required String email,
    required String password,
    required String displayName,
  });
}

class FirebaseEmployeeAccountCreator implements EmployeeAccountCreator {
  @override
  Future<CreatedEmployeeAccount> createAccount({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final defaultApp = Firebase.app();
    final appName = 'employee_creator_${DateTime.now().microsecondsSinceEpoch}';
    final secondaryApp = await Firebase.initializeApp(
      name: appName,
      options: defaultApp.options,
    );

    final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

    try {
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw const AuthException('No se pudo crear la cuenta del empleado.');
      }

      await user.updateDisplayName(displayName);

      Future<void> cleanup() async {
        await secondaryAuth.signOut();
        await secondaryApp.delete();
      }

      return CreatedEmployeeAccount(
        uid: user.uid,
        completeAction: cleanup,
        rollbackAction: () async {
          await user.delete();
          await cleanup();
        },
      );
    } on FirebaseAuthException catch (error) {
      await secondaryApp.delete();
      throw AuthException(_mapFirebaseAccountError(error));
    } catch (_) {
      await secondaryApp.delete();
      rethrow;
    }
  }

  static String _mapFirebaseAccountError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'El correo no tiene un formato valido.';
      case 'email-already-in-use':
        return 'Ese correo ya esta registrado.';
      case 'weak-password':
        return 'La contrasena es demasiado debil.';
      case 'operation-not-allowed':
        return 'Debes habilitar Email/Password en Firebase Authentication.';
      case 'network-request-failed':
        return 'No fue posible conectar con Firebase.';
      default:
        return error.message ?? 'No se pudo crear la cuenta del empleado.';
    }
  }
}

class CreatedEmployeeAccount {
  CreatedEmployeeAccount({
    required this.uid,
    required Future<void> Function() completeAction,
    required Future<void> Function() rollbackAction,
  })  : _completeAction = completeAction,
        _rollbackAction = rollbackAction;

  final String uid;
  final Future<void> Function() _completeAction;
  final Future<void> Function() _rollbackAction;

  Future<void> complete() => _completeAction();

  Future<void> rollback() => _rollbackAction();
}
