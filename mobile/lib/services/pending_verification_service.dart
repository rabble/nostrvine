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
  });

  final String deviceCode;
  final String verifier;
  final String email;
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

  /// Save pending verification data to secure storage.
  ///
  /// Call this after successful registration when email verification is required.
  Future<void> save({
    required String deviceCode,
    required String verifier,
    required String email,
  }) async {
    try {
      await Future.wait([
        _storage.write(key: _keyDeviceCode, value: deviceCode),
        _storage.write(key: _keyVerifier, value: verifier),
        _storage.write(key: _keyEmail, value: email),
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
  /// Returns null if no pending verification exists or data is incomplete.
  Future<PendingVerification?> load() async {
    try {
      final results = await Future.wait([
        _storage.read(key: _keyDeviceCode),
        _storage.read(key: _keyVerifier),
        _storage.read(key: _keyEmail),
      ]);

      final deviceCode = results[0];
      final verifier = results[1];
      final email = results[2];

      // All fields required
      if (deviceCode == null || verifier == null || email == null) {
        return null;
      }

      Log.info(
        'Loaded pending verification for $email',
        name: 'PendingVerificationService',
        category: LogCategory.auth,
      );

      return PendingVerification(
        deviceCode: deviceCode,
        verifier: verifier,
        email: email,
      );
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
  /// Call this after successful login, cancellation, or logout.
  Future<void> clear() async {
    try {
      await Future.wait([
        _storage.delete(key: _keyDeviceCode),
        _storage.delete(key: _keyVerifier),
        _storage.delete(key: _keyEmail),
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
