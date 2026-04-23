import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'auth_session.dart';
import '../../inventory/data/repositories.dart';
import '../../inventory/domain/models.dart';
import '../../inventory/domain/role_permissions.dart';

class AuthService {
  AuthService({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    EmployeeAccountCreator? employeeAccountCreator,
    SecureSessionStore? secureSessionStore,
    AuthSessionSnapshotResolver? sessionSnapshotResolver,
    DateTime Function()? clock,
    Duration tokenRefreshBuffer = const Duration(minutes: 5),
    Duration tokenRefreshRetryDelay = const Duration(minutes: 1),
    bool enableSessionRefreshMonitoring = true,
  }) : _auth = auth,
       users = UserRepository(firestore),
       catalog = CatalogRepository(firestore),
       system = SystemRepository(firestore),
       _employeeAccountCreator =
           employeeAccountCreator ?? FirebaseEmployeeAccountCreator(),
       _secureSessionStore = secureSessionStore ?? FlutterSecureSessionStore(),
       _sessionSnapshotResolver =
           sessionSnapshotResolver ??
           FirebaseAuthSessionSnapshotResolver(clock: clock),
       _clock = clock ?? DateTime.now,
       _tokenRefreshBuffer = tokenRefreshBuffer,
       _tokenRefreshRetryDelay = tokenRefreshRetryDelay,
       _enableSessionRefreshMonitoring = enableSessionRefreshMonitoring {
    _bindSessionLifecycle();
  }

  final FirebaseAuth _auth;
  final EmployeeAccountCreator _employeeAccountCreator;
  final SecureSessionStore _secureSessionStore;
  final AuthSessionSnapshotResolver _sessionSnapshotResolver;
  final DateTime Function() _clock;
  final Duration _tokenRefreshBuffer;
  final Duration _tokenRefreshRetryDelay;
  final bool _enableSessionRefreshMonitoring;
  StreamSubscription<User?>? _idTokenSubscription;
  Timer? _sessionRefreshTimer;
  String? _pendingSessionNotice;
  bool _isDisposed = false;

  final UserRepository users;
  final CatalogRepository catalog;
  final SystemRepository system;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentAuthUser => _auth.currentUser;

  Stream<AppUser?> watchProfile(String uid) => users.watchUser(uid);

  Future<AuthSessionRecord?> readStoredSession() => _secureSessionStore.read();

  String? takePendingSessionNotice() {
    final notice = _pendingSessionNotice;
    _pendingSessionNotice = null;
    return notice;
  }

  Future<void> signIn({required String email, required String password}) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user ?? _auth.currentUser;
      if (user != null) {
        await _captureAndPersistSession(user, forceRefresh: true);
      }
    } on FirebaseAuthException catch (error) {
      throw AuthException(_mapAuthError(error));
    }
  }

  Future<void> signOut() async {
    await _endCurrentSession(shouldSignOut: true);
  }

  Future<void> signOutWithReason(String reason) async {
    _pendingSessionNotice = reason;
    await _endCurrentSession(shouldSignOut: true);
  }

  Future<void> dispose() async {
    _isDisposed = true;
    _sessionRefreshTimer?.cancel();
    await _idTokenSubscription?.cancel();
  }

  Future<void> createEmployee({
    required AppUser currentUser,
    required String fullName,
    required String email,
    required String password,
    required String branchId,
    required UserRole role,
    String phone = '',
  }) async {
    if (!currentUser.can(AppPermission.manageEmployees)) {
      throw const AuthException('Solo un administrador puede crear empleados.');
    }

    final normalizedFullName = fullName.trim();
    final normalizedEmail = email.trim();
    final normalizedPhone = phone.trim();
    final branch = await catalog.fetchBranch(branchId);
    if (branch == null) {
      throw const AuthException('La sucursal seleccionada no existe.');
    }

    final createdAccount = await _employeeAccountCreator.createAccount(
      email: normalizedEmail,
      password: password,
      displayName: normalizedFullName,
    );

    final now = DateTime.now().toUtc();
    final profile = AppUser(
      id: createdAccount.uid,
      fullName: normalizedFullName,
      email: normalizedEmail,
      phone: normalizedPhone,
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
      await system.addAuditLog(
        AuditLog(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          action: 'employee_created',
          entityType: 'user',
          entityId: profile.id,
          entityLabel: profile.fullName,
          actorUserId: currentUser.id,
          actorName: currentUser.fullName,
          actorRole: currentUser.role,
          message:
              'Creo un empleado y asigno el rol ${role.displayName.toLowerCase()}.',
          metadata: {
            'email': profile.email,
            'assignedRole': role.name,
            'branchId': branchId,
          },
          createdAt: now,
          branchId: branchId,
          branchName: branch.name,
        ),
      );
      await createdAccount.complete();
    } catch (_) {
      await users.deleteUser(profile.id);
      await createdAccount.rollback();
      throw const AuthException(
        'La cuenta se creo en Authentication, pero fallo el perfil o la auditoria en Firestore.',
      );
    }
  }

  Future<AppUser> updateEmployee({
    required AppUser currentUser,
    required String userId,
    required String fullName,
    required String phone,
    required UserRole role,
    required String branchId,
    required bool isActive,
  }) async {
    if (!currentUser.can(AppPermission.manageEmployees)) {
      throw const AuthException(
        'Solo un administrador puede actualizar empleados.',
      );
    }

    final targetUser = await users.fetchUser(userId);
    if (targetUser == null) {
      throw const AuthException('El empleado seleccionado no existe.');
    }

    final normalizedFullName = fullName.trim();
    final normalizedPhone = phone.trim();
    if (normalizedFullName.isEmpty) {
      throw const AuthException('El nombre del empleado es obligatorio.');
    }

    if (currentUser.id == targetUser.id) {
      if (!isActive) {
        throw const AuthException(
          'No puedes desactivar tu propio usuario administrador.',
        );
      }
      if (role != UserRole.admin) {
        throw const AuthException(
          'No puedes cambiar tu propio rol administrador.',
        );
      }
    }

    final branch = await catalog.fetchBranch(branchId);
    if (branch == null) {
      throw const AuthException('La sucursal seleccionada no existe.');
    }

    final changedFields = <String>[];
    if (targetUser.fullName != normalizedFullName) {
      changedFields.add('fullName');
    }
    if (targetUser.phone != normalizedPhone) {
      changedFields.add('phone');
    }
    if (targetUser.role != role) {
      changedFields.add('role');
    }
    if (targetUser.branchId != branchId) {
      changedFields.add('branchId');
    }
    if (targetUser.isActive != isActive) {
      changedFields.add('isActive');
    }

    if (changedFields.isEmpty) {
      throw const AuthException('No se detectaron cambios para guardar.');
    }

    final roleChanged = targetUser.role != role;
    final roleRelatedOnly = changedFields.every(
      (field) => field == 'role' || field == 'branchId',
    );
    final auditAction = roleChanged && roleRelatedOnly
        ? 'employee_role_updated'
        : 'employee_updated';

    final now = DateTime.now().toUtc();
    final updatedUser = AppUser(
      id: targetUser.id,
      fullName: normalizedFullName,
      email: targetUser.email,
      phone: normalizedPhone,
      role: role,
      branchId: branchId,
      isActive: isActive,
      photoUrl: targetUser.photoUrl,
      lastLoginAt: targetUser.lastLoginAt,
      createdAt: targetUser.createdAt,
      updatedAt: now,
    );

    await users.upsertUser(updatedUser);
    await system.addAuditLog(
      AuditLog(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        action: auditAction,
        entityType: 'user',
        entityId: updatedUser.id,
        entityLabel: updatedUser.fullName,
        actorUserId: currentUser.id,
        actorName: currentUser.fullName,
        actorRole: currentUser.role,
        message: auditAction == 'employee_role_updated'
            ? 'Actualizo el rol del empleado a ${role.displayName.toLowerCase()}.'
            : 'Actualizo la informacion administrativa del empleado.',
        metadata: {
          'updatedFields': changedFields.join(','),
          'previousRole': targetUser.role.name,
          'newRole': updatedUser.role.name,
          'previousBranchId': targetUser.branchId,
          'newBranchId': updatedUser.branchId,
          'previousStatus': targetUser.isActive ? 'active' : 'inactive',
          'newStatus': updatedUser.isActive ? 'active' : 'inactive',
          'previousFullName': targetUser.fullName,
          'newFullName': updatedUser.fullName,
          'previousPhone': targetUser.phone,
          'newPhone': updatedUser.phone,
        },
        createdAt: now,
        branchId: updatedUser.branchId,
        branchName: branch.name,
      ),
    );

    return updatedUser;
  }

  Future<AppUser> updateEmployeeRole({
    required AppUser currentUser,
    required String userId,
    required UserRole role,
    String? branchId,
  }) async {
    final targetUser = await users.fetchUser(userId);
    if (targetUser == null) {
      throw const AuthException('El empleado seleccionado no existe.');
    }

    return updateEmployee(
      currentUser: currentUser,
      userId: userId,
      fullName: targetUser.fullName,
      phone: targetUser.phone,
      role: role,
      branchId: branchId ?? targetUser.branchId,
      isActive: targetUser.isActive,
    );
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
      case 'user-disabled':
        return 'Tu cuenta fue deshabilitada.';
      case 'too-many-requests':
        return 'Hay demasiados intentos. Espera un momento e intenta de nuevo.';
      default:
        return error.message ?? 'Ocurrio un error de autenticacion.';
    }
  }

  void _bindSessionLifecycle() {
    _idTokenSubscription = _auth.idTokenChanges().listen((user) {
      unawaited(_handleAuthenticatedUserChanged(user));
    });

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      unawaited(_secureSessionStore.clear());
      return;
    }
    unawaited(_handleAuthenticatedUserChanged(currentUser));
  }

  Future<void> _handleAuthenticatedUserChanged(User? user) async {
    if (_isDisposed) {
      return;
    }

    _sessionRefreshTimer?.cancel();
    if (user == null) {
      await _secureSessionStore.clear();
      return;
    }

    try {
      await _captureAndPersistSession(user, forceRefresh: false);
    } on FirebaseAuthException catch (_) {
      await _handleRefreshFailure();
    } catch (_) {
      await _handleRefreshFailure();
    }
  }

  Future<void> _captureAndPersistSession(
    User user, {
    required bool forceRefresh,
  }) async {
    final snapshot = await _sessionSnapshotResolver.resolve(
      user,
      forceRefresh: forceRefresh,
    );
    final record = AuthSessionRecord(
      userId: user.uid,
      email: user.email ?? '',
      accessToken: snapshot.accessToken,
      refreshToken: snapshot.refreshToken,
      authenticatedAt: snapshot.authenticatedAt,
      issuedAt: snapshot.issuedAt,
      expiresAt: snapshot.expiresAt.toUtc(),
      lastSyncedAt: _clock().toUtc(),
    );

    await _secureSessionStore.write(record);
    _scheduleSessionRefresh(record.expiresAt);
  }

  void _scheduleSessionRefresh(DateTime expiresAt) {
    if (_isDisposed || !_enableSessionRefreshMonitoring) {
      return;
    }

    _sessionRefreshTimer?.cancel();
    final now = _clock().toUtc();
    final refreshAt = expiresAt.subtract(_tokenRefreshBuffer);
    final delay = refreshAt.isAfter(now)
        ? refreshAt.difference(now)
        : Duration.zero;
    _sessionRefreshTimer = Timer(delay, () {
      unawaited(_refreshCurrentSession());
    });
  }

  Future<void> _refreshCurrentSession() async {
    if (_isDisposed) {
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      await _secureSessionStore.clear();
      return;
    }

    try {
      await _captureAndPersistSession(user, forceRefresh: true);
    } on FirebaseAuthException catch (_) {
      await _handleRefreshFailure();
    } catch (_) {
      await _handleRefreshFailure();
    }
  }

  Future<void> _handleRefreshFailure() async {
    final session = await _secureSessionStore.read();
    final now = _clock().toUtc();
    final expiresAt = session?.expiresAt;

    if (expiresAt != null && now.isBefore(expiresAt)) {
      final remaining = expiresAt.difference(now);
      final retryDelay = remaining < _tokenRefreshRetryDelay
          ? remaining
          : _tokenRefreshRetryDelay;
      _sessionRefreshTimer?.cancel();
      _sessionRefreshTimer = Timer(retryDelay, () {
        unawaited(_refreshCurrentSession());
      });
      return;
    }

    await signOutWithReason(
      'Tu sesion expiro. Ingresa de nuevo para continuar.',
    );
  }

  Future<void> _endCurrentSession({required bool shouldSignOut}) async {
    _sessionRefreshTimer?.cancel();
    await _secureSessionStore.clear();

    if (!shouldSignOut || _auth.currentUser == null) {
      return;
    }

    try {
      await _auth.signOut();
    } on FirebaseAuthException catch (error) {
      throw AuthException(_mapAuthError(error));
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
  }) : _completeAction = completeAction,
       _rollbackAction = rollbackAction;

  final String uid;
  final Future<void> Function() _completeAction;
  final Future<void> Function() _rollbackAction;

  Future<void> complete() => _completeAction();

  Future<void> rollback() => _rollbackAction();
}
