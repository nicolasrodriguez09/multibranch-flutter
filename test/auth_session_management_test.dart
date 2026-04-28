import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_multibranch_proyect/src/features/auth/application/auth_session.dart';
import 'package:flutter_multibranch_proyect/src/features/auth/application/auth_service.dart';

void main() {
  test('stores session metadata securely for an authenticated user', () async {
    final store = InMemorySecureSessionStore();
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'session_user', email: 'session@empresa.com'),
    );
    final resolver = _FakeSessionSnapshotResolver(
      initialExpiry: const Duration(hours: 1),
    );
    final service = AuthService(
      auth: auth,
      firestore: FakeFirebaseFirestore(),
      secureSessionStore: store,
      sessionSnapshotResolver: resolver,
    );
    addTearDown(service.dispose);

    await Future<void>.delayed(const Duration(milliseconds: 20));

    final record = await service.readStoredSession();
    expect(record, isNotNull);
    expect(record!.userId, 'session_user');
    expect(record.email, 'session@empresa.com');
    expect(record.accessToken, 'token_initial');
    expect(record.refreshToken, 'refresh_initial');
  });

  test('refreshes the token before the session expires', () async {
    final store = InMemorySecureSessionStore();
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'refresh_user', email: 'refresh@empresa.com'),
    );
    final resolver = _FakeSessionSnapshotResolver(
      initialExpiry: const Duration(milliseconds: 60),
      refreshedExpiry: const Duration(hours: 2),
    );
    final service = AuthService(
      auth: auth,
      firestore: FakeFirebaseFirestore(),
      secureSessionStore: store,
      sessionSnapshotResolver: resolver,
      tokenRefreshBuffer: const Duration(milliseconds: 30),
      tokenRefreshRetryDelay: const Duration(milliseconds: 10),
    );
    addTearDown(service.dispose);

    await Future<void>.delayed(const Duration(milliseconds: 120));

    final record = await service.readStoredSession();
    expect(record, isNotNull);
    expect(record!.accessToken, 'token_refresh_1');
    expect(resolver.forceRefreshCalls, 1);
  });

  test('signs out automatically when refresh fails after expiration', () async {
    final store = InMemorySecureSessionStore();
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'expired_user', email: 'expired@empresa.com'),
    );
    final resolver = _FakeSessionSnapshotResolver(
      initialExpiry: const Duration(milliseconds: 40),
      failOnForceRefresh: true,
    );
    final service = AuthService(
      auth: auth,
      firestore: FakeFirebaseFirestore(),
      secureSessionStore: store,
      sessionSnapshotResolver: resolver,
      tokenRefreshBuffer: const Duration(milliseconds: 20),
      tokenRefreshRetryDelay: const Duration(milliseconds: 10),
    );
    addTearDown(service.dispose);

    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(auth.currentUser, isNull);
    expect(await service.readStoredSession(), isNull);
    expect(
      service.takePendingSessionNotice(),
      'Tu sesion expiro. Ingresa de nuevo para continuar.',
    );
  });
}

class _FakeSessionSnapshotResolver implements AuthSessionSnapshotResolver {
  _FakeSessionSnapshotResolver({
    required this.initialExpiry,
    this.refreshedExpiry = const Duration(hours: 1),
    this.failOnForceRefresh = false,
  });

  final Duration initialExpiry;
  final Duration refreshedExpiry;
  final bool failOnForceRefresh;
  int forceRefreshCalls = 0;

  @override
  Future<AuthSessionSnapshot> resolve(
    User user, {
    required bool forceRefresh,
  }) async {
    if (forceRefresh) {
      forceRefreshCalls++;
      if (failOnForceRefresh) {
        throw FirebaseAuthException(
          code: 'network-request-failed',
          message: 'No se pudo refrescar el token.',
        );
      }
    }

    final now = DateTime.now().toUtc();
    return AuthSessionSnapshot(
      accessToken: forceRefresh
          ? 'token_refresh_$forceRefreshCalls'
          : 'token_initial',
      refreshToken: forceRefresh ? 'refresh_rotated' : 'refresh_initial',
      authenticatedAt: now.subtract(const Duration(minutes: 5)),
      issuedAt: now,
      expiresAt: now.add(forceRefresh ? refreshedExpiry : initialExpiry),
    );
  }
}
