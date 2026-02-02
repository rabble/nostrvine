// ABOUTME: Service to persist pending email verification data across app restarts
// ABOUTME: Enables auto-login when app is cold-started via email verification deep link

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Data class representing pending email verification credentials
class PendingVerification {
  const PendingVerification({
    required this.deviceCode,
    required this.verifier,
    required this.email,
    required this.createdAt,
  });

  final String deviceCode;
  final String verifier;
  final String email;
  final DateTime createdAt;

  /// Expiration duration for pending verification data (30 minutes).
  /// OAuth device codes typically expire in 15-30 minutes.
  static const expirationDuration = Duration(minutes: 30);

  /// Check if this pending verification has expired
  bool get isExpired =>
      DateTime.now().difference(createdAt) > expirationDuration;
}

/// Service to persist and retrieve pending email verification data.
///
/// When a user registers and needs to verify their email, we persist the
/// deviceCode and verifier so that if the app is cold-started via the
/// verification deep link, we can complete the OAuth flow automatically
/// instead of requiring the user to log in manually.
class PendingVerificationService {
  PendingVerificationService(this._storage);

  final FlutterSecureStorage _storage;

  static const _keyDeviceCode = 'pending_verification_device_code';
  static const _keyVerifier = 'pending_verification_verifier';
  static const _keyEmail = 'pending_verification_email';
  static const _keyCreatedAt = 'pending_verification_created_at';

  /// Save pending verification data to secure storage.
  ///
  /// Call this after successful registration when email verification is required.
  Future<void> save({
    required String deviceCode,
    required String verifier,
    required String email,
  }) async {
    try {
      final createdAt = DateTime.now().toIso8601String();
      await Future.wait([
        _storage.write(key: _keyDeviceCode, value: deviceCode),
        _storage.write(key: _keyVerifier, value: verifier),
        _storage.write(key: _keyEmail, value: email),
        _storage.write(key: _keyCreatedAt, value: createdAt),
      ]);
      Log.info(
        'Saved pending verification for $email',
        name: 'PendingVerificationService',
        category: LogCategory.auth,
      );
    } catch (e) {
      Log.error(
        'Failed to save pending verification: $e',
        name: 'PendingVerificationService',
        category: LogCategory.auth,
      );
      rethrow;
    }
  }

  /// Load pending verification data from secure storage.
  ///
  /// Returns null if no pending verification exists, data is incomplete,
  /// or data has expired (after 30 minutes).
  Future<PendingVerification?> load() async {
    try {
      final results = await Future.wait([
        _storage.read(key: _keyDeviceCode),
        _storage.read(key: _keyVerifier),
        _storage.read(key: _keyEmail),
        _storage.read(key: _keyCreatedAt),
      ]);

      final deviceCode = results[0];
      final verifier = results[1];
      final email = results[2];
      final createdAtStr = results[3];

      // All fields required
      if (deviceCode == null || verifier == null || email == null) {
        return null;
      }

      // Parse createdAt, default to epoch if missing (legacy data)
      final createdAt = createdAtStr != null
          ? DateTime.tryParse(createdAtStr) ??
                DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.fromMillisecondsSinceEpoch(0);

      final pending = PendingVerification(
        deviceCode: deviceCode,
        verifier: verifier,
        email: email,
        createdAt: createdAt,
      );

      // Check expiration
      if (pending.isExpired) {
        Log.info(
          'Pending verification for $email has expired, clearing',
          name: 'PendingVerificationService',
          category: LogCategory.auth,
        );
        await clear();
        return null;
      }

      Log.info(
        'Loaded pending verification for $email',
        name: 'PendingVerificationService',
        category: LogCategory.auth,
      );

      return pending;
    } catch (e) {
      Log.error(
        'Failed to load pending verification: $e',
        name: 'PendingVerificationService',
        category: LogCategory.auth,
      );
      return null;
    }
  }

  /// Clear pending verification data from secure storage.
  ///
  /// Call this after successful login or logout. Note: This is NOT called
  /// when user taps Cancel on the verification screen - they may still
  /// verify via email link later.
  Future<void> clear() async {
    try {
      await Future.wait([
        _storage.delete(key: _keyDeviceCode),
        _storage.delete(key: _keyVerifier),
        _storage.delete(key: _keyEmail),
        _storage.delete(key: _keyCreatedAt),
      ]);
      Log.info(
        'Cleared pending verification',
        name: 'PendingVerificationService',
        category: LogCategory.auth,
      );
    } catch (e) {
      Log.error(
        'Failed to clear pending verification: $e',
        name: 'PendingVerificationService',
        category: LogCategory.auth,
      );
      // Don't rethrow - clearing is best-effort
    }
  }

  /// Check if there is pending verification data without loading it.
  Future<bool> hasPending() async {
    try {
      final deviceCode = await _storage.read(key: _keyDeviceCode);
      return deviceCode != null;
    } catch (e) {
      return false;
    }
  }
}
