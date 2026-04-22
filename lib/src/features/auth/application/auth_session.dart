import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthSessionRecord {
  const AuthSessionRecord({
    required this.userId,
    required this.email,
    required this.accessToken,
    required this.refreshToken,
    required this.authenticatedAt,
    required this.issuedAt,
    required this.expiresAt,
    required this.lastSyncedAt,
  });

  final String userId;
  final String email;
  final String accessToken;
  final String refreshToken;
  final DateTime? authenticatedAt;
  final DateTime? issuedAt;
  final DateTime expiresAt;
  final DateTime lastSyncedAt;

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'email': email,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'authenticatedAt': authenticatedAt?.toUtc().toIso8601String(),
    'issuedAt': issuedAt?.toUtc().toIso8601String(),
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'lastSyncedAt': lastSyncedAt.toUtc().toIso8601String(),
  };

  factory AuthSessionRecord.fromJson(Map<String, dynamic> json) {
    return AuthSessionRecord(
      userId: json['userId'] as String? ?? '',
      email: json['email'] as String? ?? '',
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
      authenticatedAt: _readDateTime(json['authenticatedAt']),
      issuedAt: _readDateTime(json['issuedAt']),
      expiresAt:
          _readDateTime(json['expiresAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      lastSyncedAt:
          _readDateTime(json['lastSyncedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}

class AuthSessionSnapshot {
  const AuthSessionSnapshot({
    required this.accessToken,
    required this.refreshToken,
    required this.authenticatedAt,
    required this.issuedAt,
    required this.expiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime? authenticatedAt;
  final DateTime? issuedAt;
  final DateTime expiresAt;
}

abstract class AuthSessionSnapshotResolver {
  Future<AuthSessionSnapshot> resolve(User user, {required bool forceRefresh});
}

class FirebaseAuthSessionSnapshotResolver
    implements AuthSessionSnapshotResolver {
  const FirebaseAuthSessionSnapshotResolver({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  @override
  Future<AuthSessionSnapshot> resolve(
    User user, {
    required bool forceRefresh,
  }) async {
    final result = await user.getIdTokenResult(forceRefresh);
    final accessToken =
        result.token ?? await user.getIdToken(forceRefresh) ?? '';
    final expiresAt =
        result.expirationTime?.toUtc() ??
        _readJwtDate(accessToken, 'exp') ??
        _clock().toUtc().add(const Duration(minutes: 50));

    return AuthSessionSnapshot(
      accessToken: accessToken,
      refreshToken: user.refreshToken ?? '',
      authenticatedAt:
          result.authTime?.toUtc() ?? _readJwtDate(accessToken, 'auth_time'),
      issuedAt:
          result.issuedAtTime?.toUtc() ?? _readJwtDate(accessToken, 'iat'),
      expiresAt: expiresAt,
    );
  }

  DateTime? _readJwtDate(String token, String key) {
    if (token.isEmpty) {
      return null;
    }

    try {
      final segments = token.split('.');
      if (segments.length < 2) {
        return null;
      }
      final payload = segments[1];
      final normalized = base64.normalize(
        payload.replaceAll('-', '+').replaceAll('_', '/'),
      );
      final decoded = utf8.decode(base64.decode(normalized));
      final data = jsonDecode(decoded);
      if (data is! Map<String, dynamic>) {
        return null;
      }
      final rawValue = data[key];
      final seconds = rawValue is int
          ? rawValue
          : rawValue is num
          ? rawValue.toInt()
          : null;
      if (seconds == null) {
        return null;
      }
      return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
    } catch (_) {
      return null;
    }
  }
}

abstract class SecureSessionStore {
  Future<AuthSessionRecord?> read();
  Future<void> write(AuthSessionRecord record);
  Future<void> clear();
}

class FlutterSecureSessionStore implements SecureSessionStore {
  FlutterSecureSessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _sessionKey = 'redstock.auth.session.v1';

  final FlutterSecureStorage _storage;

  @override
  Future<AuthSessionRecord?> read() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    return AuthSessionRecord.fromJson(decoded);
  }

  @override
  Future<void> write(AuthSessionRecord record) {
    return _storage.write(key: _sessionKey, value: jsonEncode(record.toJson()));
  }

  @override
  Future<void> clear() => _storage.delete(key: _sessionKey);
}

class InMemorySecureSessionStore implements SecureSessionStore {
  AuthSessionRecord? _record;

  @override
  Future<AuthSessionRecord?> read() async => _record;

  @override
  Future<void> write(AuthSessionRecord record) async {
    _record = record;
  }

  @override
  Future<void> clear() async {
    _record = null;
  }
}

DateTime? _readDateTime(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value)?.toUtc();
}
