// ABOUTME: Service for managing age verification status across app sessions
// ABOUTME: Stores verification status per account in SharedPreferences

import 'package:flutter/material.dart';
import 'package:openvine/widgets/age_verification_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

class AgeVerificationService {
  AgeVerificationService({
    bool Function()? isProtectedMinor,
    String? Function()? currentPubkeyHex,
    Future<void> Function()? onAdultMediaAccessRevoked,
    VoidCallback? onAdultContentVerificationChanged,
  }) : _isProtectedMinor = isProtectedMinor ?? _notProtected,
       _currentPubkeyHex = currentPubkeyHex ?? _noPubkey,
       _onAdultMediaAccessRevoked = onAdultMediaAccessRevoked,
       _onAdultContentVerificationChanged = onAdultContentVerificationChanged;

  static bool _notProtected() => false;
  static String? _noPubkey() => null;

  /// Whether the current account is a protected minor. When true, adult content
  /// is force-locked off and the self-attestation bypass is unavailable (#175).
  final bool Function() _isProtectedMinor;

  /// The active account's pubkey hex, or null when unauthenticated.
  /// Verification is scoped per account (#7816); a null pubkey resolves to
  /// unverified and makes writes a no-op.
  final String? Function() _currentPubkeyHex;

  final Future<void> Function()? _onAdultMediaAccessRevoked;
  final VoidCallback? _onAdultContentVerificationChanged;

  static const String _ageVerifiedKey = 'age_verified';
  static const String _verificationDateKey = 'age_verification_date';
  static const String _adultContentVerifiedKey = 'adult_content_verified';
  static const String _adultContentVerificationDateKey =
      'adult_content_verification_date';

  /// Legacy device-global keys, pre-#7816. Adopted for the first authenticated
  /// account that loads after upgrade, then deleted so no other account can
  /// inherit them.
  static const List<String> _globalBaseKeys = [
    _ageVerifiedKey,
    _verificationDateKey,
    _adultContentVerifiedKey,
    _adultContentVerificationDateKey,
  ];

  /// Every per-account preference key for [pubkeyHex].
  static List<String> accountKeys(String pubkeyHex) =>
      _globalBaseKeys.map((base) => '${base}_$pubkeyHex').toList();

  /// Removes every age / adult-content verification key for [pubkeyHex].
  ///
  /// Called on destructive account deletion so a re-used identity does not
  /// resurrect a deleted account's verification (#7816).
  static Future<void> purgeAccount(
    SharedPreferences prefs,
    String pubkeyHex,
  ) async {
    for (final key in accountKeys(pubkeyHex)) {
      await prefs.remove(key);
    }
  }

  bool? _isAgeVerified;
  DateTime? _verificationDate;
  bool? _isAdultContentVerified;
  DateTime? _adultContentVerificationDate;
  Future<void>? _initializeFuture;

  bool get isAgeVerified => _isAgeVerified ?? false;
  DateTime? get verificationDate => _verificationDate;
  bool get isAdultContentVerified =>
      !_isProtectedMinor() && (_isAdultContentVerified ?? false);
  DateTime? get adultContentVerificationDate => _adultContentVerificationDate;

  /// Completes when persisted age-verification state has loaded.
  Future<void> get initialized =>
      _initializeFuture ??= _loadVerificationStatus();

  /// The scoped key for [base] under the active account, or null when no
  /// account is active.
  String? _scopedKey(String base) {
    final pubkey = _currentPubkeyHex();
    if (pubkey == null || pubkey.isEmpty) return null;
    return '${base}_$pubkey';
  }

  Future<void> initialize() async {
    await initialized;
  }

  Future<void> _loadVerificationStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _migrateGlobalKeys(prefs);

      final ageKey = _scopedKey(_ageVerifiedKey);
      if (ageKey == null) {
        _isAgeVerified = null;
        _verificationDate = null;
        _isAdultContentVerified = null;
        _adultContentVerificationDate = null;
        return;
      }

      _isAgeVerified = prefs.getBool(ageKey);
      _isAdultContentVerified = prefs.getBool(
        _scopedKey(_adultContentVerifiedKey)!,
      );

      final dateMillis = prefs.getInt(_scopedKey(_verificationDateKey)!);
      _verificationDate = dateMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(dateMillis);

      final adultDateMillis = prefs.getInt(
        _scopedKey(_adultContentVerificationDateKey)!,
      );
      _adultContentVerificationDate = adultDateMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(adultDateMillis);
      _onAdultContentVerificationChanged?.call();
    } catch (e) {
      Log.error(
        'Error loading age verification status: $e',
        name: 'AgeVerificationService',
        category: LogCategory.system,
      );
    }
  }

  /// Migrates legacy device-global verification keys to the active account.
  ///
  /// Adopts each global value for the current account when the account has no
  /// scoped value yet, then removes the global keys so a second account can
  /// never inherit them. No-op while unauthenticated, leaving the globals in
  /// place until an account claims them (#7816). Adopt-if-absent plus an
  /// idempotent delete makes a repeated run for the same account harmless.
  Future<void> _migrateGlobalKeys(SharedPreferences prefs) async {
    final pubkey = _currentPubkeyHex();
    if (pubkey == null || pubkey.isEmpty) return;
    if (!_globalBaseKeys.any(prefs.containsKey)) return;

    for (final base in _globalBaseKeys) {
      final scoped = '${base}_$pubkey';
      if (prefs.containsKey(base) && !prefs.containsKey(scoped)) {
        final value = prefs.get(base);
        if (value is bool) {
          await prefs.setBool(scoped, value);
        } else if (value is int) {
          await prefs.setInt(scoped, value);
        }
      }
      await prefs.remove(base);
    }
  }

  Future<void> setAgeVerified(bool verified) async {
    final key = _scopedKey(_ageVerifiedKey);
    final dateKey = _scopedKey(_verificationDateKey);
    if (key == null || dateKey == null) {
      Log.warning(
        'No active account; skipping age verification write',
        name: 'AgeVerificationService',
        category: LogCategory.system,
      );
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool(key, verified);

      if (verified) {
        final now = DateTime.now();
        await prefs.setInt(dateKey, now.millisecondsSinceEpoch);
        _verificationDate = now;
      } else {
        await prefs.remove(dateKey);
        _verificationDate = null;
      }

      _isAgeVerified = verified;

      Log.debug(
        'Age verification status updated: $verified',
        name: 'AgeVerificationService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Error saving age verification status: $e',
        name: 'AgeVerificationService',
        category: LogCategory.system,
      );
      rethrow;
    }
  }

  Future<bool> checkAgeVerification() async {
    if (_isAgeVerified == null) {
      await _loadVerificationStatus();
    }
    return isAgeVerified;
  }

  Future<void> setAdultContentVerified(bool verified) async {
    if (verified && _isProtectedMinor()) {
      Log.warning(
        'Blocked adult-content verification for a protected minor',
        name: 'AgeVerificationService',
        category: LogCategory.system,
      );
      return;
    }
    final key = _scopedKey(_adultContentVerifiedKey);
    final dateKey = _scopedKey(_adultContentVerificationDateKey);
    if (key == null || dateKey == null) {
      Log.warning(
        'No active account; skipping adult-content verification write',
        name: 'AgeVerificationService',
        category: LogCategory.system,
      );
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool(key, verified);

      if (verified) {
        final now = DateTime.now();
        await prefs.setInt(dateKey, now.millisecondsSinceEpoch);
        _adultContentVerificationDate = now;
      } else {
        await prefs.remove(dateKey);
        _adultContentVerificationDate = null;
      }

      _isAdultContentVerified = verified;
      _onAdultContentVerificationChanged?.call();
      if (!verified) {
        await _notifyAdultMediaAccessRevoked();
      }

      Log.debug(
        'Adult content verification status updated: $verified',
        name: 'AgeVerificationService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Error saving adult content verification status: $e',
        name: 'AgeVerificationService',
        category: LogCategory.system,
      );
      rethrow;
    }
  }

  Future<bool> checkAdultContentVerification() async {
    if (_isAdultContentVerified == null) {
      await _loadVerificationStatus();
    }
    return isAdultContentVerified;
  }

  /// Check if user can view adult content, showing verification dialog if needed
  Future<bool> verifyAdultContentAccess(BuildContext context) async {
    // Protected minors can never unlock adult content; no dialog.
    if (_isProtectedMinor()) return false;
    // First check if already verified
    if (await checkAdultContentVerification()) {
      return true;
    }

    if (!context.mounted) return false;

    // Show verification dialog
    final verified = await AgeVerificationDialog.show(
      context,
      type: AgeVerificationType.adultContent,
    );

    if (verified) {
      await setAdultContentVerified(true);
      return true;
    }

    return false;
  }

  Future<void> clearVerificationStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final base in _globalBaseKeys) {
        final key = _scopedKey(base);
        if (key != null) await prefs.remove(key);
      }

      _isAgeVerified = null;
      _verificationDate = null;
      _isAdultContentVerified = null;
      _adultContentVerificationDate = null;
      _onAdultContentVerificationChanged?.call();
      await _notifyAdultMediaAccessRevoked();

      Log.debug(
        'Age verification status cleared',
        name: 'AgeVerificationService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Error clearing age verification status: $e',
        name: 'AgeVerificationService',
        category: LogCategory.system,
      );
    }
  }

  Future<void> _notifyAdultMediaAccessRevoked() async {
    final callback = _onAdultMediaAccessRevoked;
    if (callback == null) return;
    try {
      await callback();
    } catch (e) {
      Log.error(
        'Error clearing adult media access caches: $e',
        name: 'AgeVerificationService',
        category: LogCategory.system,
      );
    }
  }
}
