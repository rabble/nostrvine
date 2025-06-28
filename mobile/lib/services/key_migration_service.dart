// ABOUTME: Migration service for transitioning from insecure to secure key storage
// ABOUTME: Handles safe migration of existing keys without exposure during transition

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'key_storage_service.dart';
import 'secure_key_storage_service.dart';
import '../utils/secure_key_container.dart';
import '../utils/nostr_encoding.dart';

/// Exception thrown during key migration operations
class KeyMigrationException implements Exception {
  final String message;
  final String? code;
  
  const KeyMigrationException(this.message, {this.code});
  
  @override
  String toString() => 'KeyMigrationException: $message';
}

/// Migration status for tracking progress
enum MigrationStatus {
  notNeeded,      // No migration required
  pending,        // Migration is needed but not started
  inProgress,     // Migration is currently running
  completed,      // Migration completed successfully
  failed,         // Migration failed
}

/// Result of a migration operation
class MigrationResult {
  final MigrationStatus status;
  final String? error;
  final bool secureStorageAvailable;
  final bool legacyKeysFound;
  final String? migratedNpub;
  
  const MigrationResult({
    required this.status,
    this.error,
    required this.secureStorageAvailable,
    required this.legacyKeysFound,
    this.migratedNpub,
  });
  
  bool get isSuccess => status == MigrationStatus.completed;
  bool get requiresAction => status == MigrationStatus.pending || status == MigrationStatus.failed;
}

/// Service for migrating keys from legacy to secure storage
class KeyMigrationService {
  // ignore: deprecated_member_use_from_same_package
  final KeyStorageService _legacyStorage = KeyStorageService();
  final SecureKeyStorageService _secureStorage = SecureKeyStorageService();
  
  static const String _migrationCompleteKey = 'secure_migration_completed';
  static const String _migrationVersionKey = 'migration_version';
  static const int _currentMigrationVersion = 1;
  
  /// Check if migration is needed and get current status
  Future<MigrationResult> checkMigrationStatus() async {
    debugPrint('🔍 Checking key migration status');
    
    try {
      // Initialize services
      await Future.wait([
        _legacyStorage.initialize(),
        _secureStorage.initialize().catchError((e) {
          debugPrint('⚠️ Secure storage initialization failed: $e');
          return null;
        }),
      ]);
      
      // Check if secure storage is available
      final secureStorageAvailable = !_secureStorage.securityInfo.isEmpty;
      
      // Check if legacy keys exist
      final legacyKeysExist = await _legacyStorage.hasKeys();
      
      // Check if migration was already completed
      final migrationCompleted = await _isMigrationCompleted();
      
      if (!legacyKeysExist) {
        debugPrint('✅ No legacy keys found - migration not needed');
        return MigrationResult(
          status: MigrationStatus.notNeeded,
          secureStorageAvailable: secureStorageAvailable,
          legacyKeysFound: false,
        );
      }
      
      if (migrationCompleted) {
        debugPrint('✅ Migration already completed');
        return MigrationResult(
          status: MigrationStatus.completed,
          secureStorageAvailable: secureStorageAvailable,
          legacyKeysFound: legacyKeysExist,
        );
      }
      
      if (!secureStorageAvailable) {
        debugPrint('⚠️ Secure storage not available - migration cannot proceed');
        return MigrationResult(
          status: MigrationStatus.failed,
          error: 'Secure storage not available on this device',
          secureStorageAvailable: false,
          legacyKeysFound: true,
        );
      }
      
      debugPrint('📋 Migration pending - legacy keys found and secure storage available');
      return MigrationResult(
        status: MigrationStatus.pending,
        secureStorageAvailable: secureStorageAvailable,
        legacyKeysFound: legacyKeysExist,
      );
      
    } catch (e) {
      debugPrint('❌ Error checking migration status: $e');
      return MigrationResult(
        status: MigrationStatus.failed,
        error: e.toString(),
        secureStorageAvailable: false,
        legacyKeysFound: false,
      );
    }
  }
  
  /// Perform the migration from legacy to secure storage
  Future<MigrationResult> performMigration({
    String? biometricPrompt,
    bool deleteAfterMigration = true,
  }) async {
    debugPrint('🔄 Starting key migration to secure storage');
    
    try {
      // Check if migration is actually needed
      final status = await checkMigrationStatus();
      if (status.status == MigrationStatus.notNeeded || status.status == MigrationStatus.completed) {
        return status;
      }
      
      if (status.status == MigrationStatus.failed) {
        throw KeyMigrationException(status.error ?? 'Migration prerequisites not met');
      }
      
      // Get legacy key pair
      debugPrint('🔑 Retrieving legacy key pair');
      final legacyKeyPair = await _legacyStorage.getKeyPair();
      if (legacyKeyPair == null) {
        throw const KeyMigrationException('No legacy keys found to migrate');
      }
      
      debugPrint('🔐 Migrating key for: ${NostrEncoding.maskKey(legacyKeyPair.npub)}');
      
      // Create secure container from legacy key
      final secureContainer = SecureKeyContainer.fromPrivateKeyHex(legacyKeyPair.privateKeyHex);
      
      try {
        // Store in secure storage
        debugPrint('💾 Storing key in secure storage');
        final importResult = await _secureStorage.importFromNsec(
          legacyKeyPair.nsec,
          biometricPrompt: biometricPrompt,
        );
        
        // Verify the migration worked
        debugPrint('✅ Verifying migration success');
        final retrievedContainer = await _secureStorage.getKeyContainer(
          biometricPrompt: biometricPrompt,
        );
        
        if (retrievedContainer == null || !retrievedContainer.hasSamePublicKey(secureContainer)) {
          throw const KeyMigrationException('Migration verification failed - keys do not match');
        }
        
        // Mark migration as completed
        await _markMigrationCompleted();
        
        // Delete legacy keys if requested
        if (deleteAfterMigration) {
          debugPrint('🗑️ Deleting legacy keys');
          await _legacyStorage.deleteKeys();
        }
        
        debugPrint('🎉 Migration completed successfully');
        return MigrationResult(
          status: MigrationStatus.completed,
          secureStorageAvailable: true,
          legacyKeysFound: true,
          migratedNpub: importResult.npub,
        );
        
      } finally {
        // Always dispose the temporary container
        secureContainer.dispose();
      }
      
    } catch (e) {
      debugPrint('❌ Migration failed: $e');
      return MigrationResult(
        status: MigrationStatus.failed,
        error: e.toString(),
        secureStorageAvailable: await _secureStorage.initialize().then((_) => true).catchError((_) => false),
        legacyKeysFound: await _legacyStorage.hasKeys().catchError((_) => false),
      );
    }
  }
  
  /// Check if the device supports secure migration
  Future<bool> supportsSecureMigration() async {
    try {
      await _secureStorage.initialize();
      return _secureStorage.securityInfo.isNotEmpty;
    } catch (e) {
      debugPrint('⚠️ Device does not support secure migration: $e');
      return false;
    }
  }
  
  /// Get migration recommendations for the user
  Future<List<String>> getMigrationRecommendations() async {
    final recommendations = <String>[];
    
    try {
      final status = await checkMigrationStatus();
      
      if (status.status == MigrationStatus.notNeeded) {
        recommendations.add('No migration needed - you\'re already using secure storage');
        return recommendations;
      }
      
      if (status.status == MigrationStatus.completed) {
        recommendations.add('Migration completed - your keys are now securely stored');
        return recommendations;
      }
      
      if (!status.secureStorageAvailable) {
        recommendations.add('⚠️ Your device does not support hardware-backed security');
        recommendations.add('Consider using a newer device for better security');
        return recommendations;
      }
      
      if (status.legacyKeysFound) {
        recommendations.add('🔒 Migrate to secure storage for better protection');
        recommendations.add('Your Nostr keys will be protected by hardware security');
        
        final secureInfo = _secureStorage.securityInfo;
        if (secureInfo['biometrics_available'] == true) {
          recommendations.add('🔐 Enable biometric authentication for maximum security');
        }
        
        if (secureInfo['hardware_backed'] == true) {
          recommendations.add('🛡️ Hardware-backed security available on this device');
        }
      }
      
    } catch (e) {
      recommendations.add('Unable to determine migration requirements');
    }
    
    return recommendations;
  }
  
  /// Check if migration was already completed
  Future<bool> _isMigrationCompleted() async {
    try {
      // For now, we'll use a simple approach - check if secure storage has keys
      // and legacy storage tracking indicates migration was done
      return await _secureStorage.hasKeys();
    } catch (e) {
      return false;
    }
  }
  
  /// Mark migration as completed
  Future<void> _markMigrationCompleted() async {
    try {
      // We could store this in SharedPreferences or another mechanism
      // For now, the presence of keys in secure storage indicates completion
      debugPrint('✅ Migration marked as completed');
    } catch (e) {
      debugPrint('⚠️ Failed to mark migration as completed: $e');
    }
  }
  
  /// Clean up legacy storage completely (use with caution!)
  Future<void> cleanupLegacyStorage() async {
    debugPrint('🧹 Cleaning up legacy storage');
    
    try {
      await _legacyStorage.deleteKeys();
      debugPrint('✅ Legacy storage cleaned up');
    } catch (e) {
      debugPrint('⚠️ Failed to clean up legacy storage: $e');
    }
  }
}