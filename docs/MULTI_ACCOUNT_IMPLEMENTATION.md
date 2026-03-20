Status: Historical

> Historical note
> Preserved for context during the P1 documentation refresh. This file may reference deleted screens, older branding, or superseded implementation details. Start with docs/README.md and docs/archive/README.md for current guidance.

# Multi-Account Support Implementation Guide

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Data Models](#data-models)
4. [Implementation Phases](#implementation-phases)
5. [Security Architecture](#security-architecture)
6. [API Reference](#api-reference)
7. [Migration Guide](#migration-guide)
8. [Testing Strategy](#testing-strategy)
9. [Performance Considerations](#performance-considerations)
10. [Troubleshooting](#troubleshooting)

## Overview

This document outlines the complete implementation strategy for adding multi-account support to OpenVine. The system allows users to manage multiple Nostr identities while maintaining a shared local relay and cached content.

### Key Features
- Multiple Nostr account management on a single device
- Secure private key storage with biometric protection
- Quick account switching (< 500ms)
- Shared video cache across accounts
- Account-specific subscriptions and settings
- State preservation during account switches

### Design Principles
- **Security First**: Private keys are encrypted and isolated
- **Performance**: Instant switching with shared infrastructure
- **User Experience**: Seamless transitions between accounts
- **Data Efficiency**: Shared cache for common content
- **Extensibility**: Support for future account types

## Architecture

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                         UI Layer                             │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │Account Switch│  │Profile Screen│  │  Feed Screens    │  │
│  │   Widget     │  │              │  │(Home/Discovery)  │  │
│  └──────┬───────┘  └──────┬───────┘  └────────┬─────────┘  │
│         │                  │                    │            │
└─────────┼──────────────────┼────────────────────┼────────────┘
          │                  │                    │
          └──────────────────▼────────────────────┘
                             │
          ┌──────────────────▼────────────────────┐
          │         AccountContext Provider        │
          │          (Riverpod State)             │
          └──────────────────┬────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────┐
│                    Account Manager Layer                     │
│                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────────────┐   │
│  │  Account    │  │   Account   │  │     Account      │   │
│  │   Storage   │  │   Manager   │  │  State Manager   │   │
│  └─────────────┘  └─────────────┘  └──────────────────┘   │
│                                                              │
└────────────────────────────┬────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────┐
│                      Service Layer                           │
│                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────────────┐   │
│  │NostrService │  │VideoService │  │  UploadManager   │   │
│  │  (Modified) │  │ (Account-   │  │  (Account-aware) │   │
│  │             │  │   aware)    │  │                  │   │
│  └─────────────┘  └─────────────┘  └──────────────────┘   │
│                                                              │
└────────────────────────────┬────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────┐
│                 Storage & Infrastructure                     │
│                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────────────┐   │
│  │   Secure    │  │   SQLite    │  │  Embedded Nostr  │   │
│  │   Storage   │  │  Database   │  │      Relay       │   │
│  │(Encrypted)  │  │ (Extended)  │  │   (Singleton)    │   │
│  └─────────────┘  └─────────────┘  └──────────────────┘   │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

#### AccountManager
- Central coordination for all account operations
- Maintains current account state
- Handles account switching logic
- Manages account lifecycle (create, update, delete)

#### SecureAccountStorage
- Encrypts and stores private keys
- Provides biometric authentication
- Ensures key isolation between accounts
- Handles secure key retrieval and cleanup

#### AccountContext Provider
- Riverpod provider for current account state
- Triggers UI rebuilds on account changes
- Provides account info to all app components
- Manages account-specific settings

## Data Models

### UserAccount Model

```dart
// lib/models/user_account.dart

import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_account.freezed.dart';
part 'user_account.g.dart';

@freezed
class UserAccount with _$UserAccount {
  const factory UserAccount({
    required String id,           // UUID v4
    required String pubkey,        // Nostr public key (hex)
    String? npub,                  // Bech32-encoded public key
    String? name,                  // Display name from profile
    String? displayName,           // Preferred display name
    String? avatar,                // Profile picture URL
    String? banner,                // Profile banner URL
    String? about,                 // Profile bio
    String? nip05,                 // NIP-05 identifier
    required DateTime createdAt,   // Account creation time
    required DateTime lastUsedAt,  // Last access time
    DateTime? lastSyncedAt,        // Last relay sync
    @Default({}) Map<String, dynamic> settings,  // Account settings
    @Default([]) List<String> relayUrls,        // Preferred relays
    @Default({}) Map<String, RelayConfig> relayConfigs, // Relay settings
    AccountStatus? status,         // Active, locked, archived
    @Default(false) bool isDefault, // Default account flag
    AccountTheme? theme,           // Account-specific theme
    NotificationSettings? notificationSettings,
  }) = _UserAccount;

  factory UserAccount.fromJson(Map<String, dynamic> json) =>
      _$UserAccountFromJson(json);
}

@freezed
class RelayConfig with _$RelayConfig {
  const factory RelayConfig({
    required String url,
    @Default(true) bool read,
    @Default(true) bool write,
    int? priority,
    DateTime? lastConnected,
    int? connectionAttempts,
    RelayStatus? status,
  }) = _RelayConfig;

  factory RelayConfig.fromJson(Map<String, dynamic> json) =>
      _$RelayConfigFromJson(json);
}

enum AccountStatus {
  active,
  locked,
  archived,
  suspended,
}

enum RelayStatus {
  connected,
  disconnected,
  error,
  unauthorized,
}

@freezed
class AccountTheme with _$AccountTheme {
  const factory AccountTheme({
    String? primaryColor,
    String? accentColor,
    ThemeMode? themeMode,
    Map<String, dynamic>? customColors,
  }) = _AccountTheme;

  factory AccountTheme.fromJson(Map<String, dynamic> json) =>
      _$AccountThemeFromJson(json);
}

@freezed
class NotificationSettings with _$NotificationSettings {
  const factory NotificationSettings({
    @Default(true) bool mentions,
    @Default(true) bool replies,
    @Default(true) bool reposts,
    @Default(true) bool likes,
    @Default(false) bool follows,
    @Default(false) bool unfollows,
    Map<String, bool>? customNotifications,
  }) = _NotificationSettings;

  factory NotificationSettings.fromJson(Map<String, dynamic> json) =>
      _$NotificationSettingsFromJson(json);
}
```

### Account State Model

```dart
// lib/models/account_state.dart

@freezed
class AccountState with _$AccountState {
  const factory AccountState({
    required String accountId,
    String? lastViewedFeed,      // home, discovery, hashtag
    int? lastScrollPosition,      // Feed scroll position
    String? lastViewedVideoId,    // Last watched video
    Map<String, dynamic>? draftContent,  // Unsaved drafts
    List<String>? recentSearches,
    Map<String, FilterSettings>? feedFilters,
    DateTime? stateUpdatedAt,
  }) = _AccountState;

  factory AccountState.fromJson(Map<String, dynamic> json) =>
      _$AccountStateFromJson(json);
}
```

### Database Schema

```sql
-- Accounts table
CREATE TABLE IF NOT EXISTS accounts (
  id TEXT PRIMARY KEY,
  pubkey TEXT NOT NULL UNIQUE,
  npub TEXT,
  name TEXT,
  display_name TEXT,
  avatar TEXT,
  banner TEXT,
  about TEXT,
  nip05 TEXT,
  created_at INTEGER NOT NULL,
  last_used_at INTEGER NOT NULL,
  last_synced_at INTEGER,
  settings TEXT,           -- JSON
  status TEXT DEFAULT 'active',
  is_default INTEGER DEFAULT 0,
  theme TEXT,              -- JSON
  notification_settings TEXT, -- JSON
  UNIQUE(pubkey)
);

-- Account relays table
CREATE TABLE IF NOT EXISTS account_relays (
  account_id TEXT NOT NULL,
  relay_url TEXT NOT NULL,
  read INTEGER DEFAULT 1,
  write INTEGER DEFAULT 1,
  priority INTEGER,
  last_connected INTEGER,
  connection_attempts INTEGER DEFAULT 0,
  status TEXT,
  config TEXT,             -- JSON for additional config
  PRIMARY KEY (account_id, relay_url),
  FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE
);

-- Account state table (for preserving UI state)
CREATE TABLE IF NOT EXISTS account_states (
  account_id TEXT PRIMARY KEY,
  last_viewed_feed TEXT,
  last_scroll_position INTEGER,
  last_viewed_video_id TEXT,
  draft_content TEXT,      -- JSON
  recent_searches TEXT,    -- JSON array
  feed_filters TEXT,       -- JSON
  state_updated_at INTEGER,
  FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE
);

-- Account-specific settings
CREATE TABLE IF NOT EXISTS account_settings (
  account_id TEXT NOT NULL,
  key TEXT NOT NULL,
  value TEXT,
  updated_at INTEGER,
  PRIMARY KEY (account_id, key),
  FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE
);

-- Create indexes for performance
CREATE INDEX idx_accounts_pubkey ON accounts(pubkey);
CREATE INDEX idx_accounts_last_used ON accounts(last_used_at DESC);
CREATE INDEX idx_account_relays_account ON account_relays(account_id);
CREATE INDEX idx_account_states_account ON account_states(account_id);
```

## Implementation Phases

### Phase 1: Foundation (Week 1-2)

#### 1.1 Project Setup
```bash
# Add dependencies to pubspec.yaml
dependencies:
  flutter_secure_storage: ^9.2.2
  uuid: ^4.3.3
  freezed_annotation: ^2.4.1
  json_annotation: ^4.8.1

dev_dependencies:
  build_runner: ^2.4.8
  freezed: ^2.4.7
  json_serializable: ^6.7.1
```

#### 1.2 Create Core Infrastructure

```dart
// lib/services/secure_account_storage.dart

import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';

class SecureAccountStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      sharedPreferencesName: 'openvine_secure_prefs',
      preferencesKeyPrefix: 'openvine_',
    ),
    iOptions: IOSOptions(
      accessibility: IOSAccessibility.first_unlock_this_device,
      accountName: 'OpenVineAccounts',
    ),
  );

  // Key derivation for additional security
  static String _deriveKey(String accountId, String purpose) {
    final bytes = utf8.encode('$accountId:$purpose:openvine');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Store private key with biometric protection
  static Future<void> storePrivateKey({
    required String accountId,
    required String privateKey,
    bool requireBiometric = true,
  }) async {
    final key = _deriveKey(accountId, 'privkey');
    
    // Additional encryption layer
    final encryptedKey = await _encryptPrivateKey(privateKey, accountId);
    
    await _storage.write(
      key: key,
      value: encryptedKey,
      aOptions: AndroidOptions(
        encryptedSharedPreferences: true,
        sharedPreferencesName: 'openvine_keys',
        preferencesKeyPrefix: 'key_',
        resetOnError: true,
      ),
      iOptions: IOSOptions(
        accessibility: requireBiometric
            ? IOSAccessibility.first_unlock_this_device_passcode
            : IOSAccessibility.first_unlock_this_device,
        accountName: 'OpenVineKeys',
        synchronizable: false,
      ),
    );
  }

  // Retrieve private key with secure cleanup
  static Future<String?> getPrivateKey(String accountId) async {
    final key = _deriveKey(accountId, 'privkey');
    
    try {
      final encryptedKey = await _storage.read(key: key);
      if (encryptedKey == null) return null;
      
      // Decrypt the key
      final privateKey = await _decryptPrivateKey(encryptedKey, accountId);
      
      // Return a secure string wrapper that clears on dispose
      return privateKey;
    } catch (e) {
      print('Error retrieving private key: $e');
      return null;
    }
  }

  // Delete account keys securely
  static Future<void> deleteAccountKeys(String accountId) async {
    final key = _deriveKey(accountId, 'privkey');
    await _storage.delete(key: key);
    
    // Also clear any cached keys from memory
    _clearMemoryCache(accountId);
  }

  // Check if biometric is available
  static Future<bool> canUseBiometric() async {
    try {
      return await _storage.containsKey(key: '_biometric_check');
    } catch (e) {
      return false;
    }
  }

  // Additional encryption layer
  static Future<String> _encryptPrivateKey(String privateKey, String accountId) async {
    // Implementation of AES encryption
    // This is a placeholder - implement proper AES-256-GCM encryption
    final key = _deriveKey(accountId, 'encryption');
    // ... encryption logic ...
    return base64.encode(utf8.encode(privateKey)); // Placeholder
  }

  static Future<String> _decryptPrivateKey(String encryptedKey, String accountId) async {
    // Implementation of AES decryption
    // This is a placeholder - implement proper AES-256-GCM decryption
    final key = _deriveKey(accountId, 'encryption');
    // ... decryption logic ...
    return utf8.decode(base64.decode(encryptedKey)); // Placeholder
  }

  static void _clearMemoryCache(String accountId) {
    // Clear any in-memory caches for this account
    // Implementation depends on your caching strategy
  }
}
```

### Phase 2: Account Management Core (Week 3-4)

#### 2.1 AccountManager Implementation

```dart
// lib/services/account_manager.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:nostr_sdk/nostr_sdk.dart' as nostr;

class AccountManager extends ChangeNotifier {
  static final AccountManager _instance = AccountManager._internal();
  factory AccountManager() => _instance;
  AccountManager._internal();

  final _uuid = const Uuid();
  UserAccount? _currentAccount;
  List<UserAccount> _accounts = [];
  final _accountSwitchController = StreamController<AccountSwitchEvent>.broadcast();
  bool _isSwitching = false;

  // Getters
  UserAccount? get currentAccount => _currentAccount;
  List<UserAccount> get allAccounts => List.unmodifiable(_accounts);
  Stream<AccountSwitchEvent> get accountSwitchStream => _accountSwitchController.stream;
  bool get hasAccounts => _accounts.isNotEmpty;
  bool get isSwitching => _isSwitching;

  // Initialize account manager
  Future<void> initialize() async {
    await _loadAccounts();
    await _restoreLastUsedAccount();
  }

  // Create new account
  Future<UserAccount> createAccount({
    String? privateKey,
    String? name,
    bool setAsDefault = false,
  }) async {
    try {
      // Generate or validate private key
      final keyPair = privateKey != null
          ? nostr.KeyPair.fromPrivateKey(privateKey)
          : nostr.KeyPair.generate();

      final account = UserAccount(
        id: _uuid.v4(),
        pubkey: keyPair.publicKey,
        npub: nostr.nip19.encodePubkey(keyPair.publicKey),
        name: name,
        createdAt: DateTime.now(),
        lastUsedAt: DateTime.now(),
        isDefault: setAsDefault || _accounts.isEmpty,
      );

      // Store private key securely
      await SecureAccountStorage.storePrivateKey(
        accountId: account.id,
        privateKey: keyPair.privateKey,
      );

      // Save account to database
      await _saveAccountToDatabase(account);
      
      _accounts.add(account);
      
      if (account.isDefault || _currentAccount == null) {
        await switchAccount(account.id);
      }
      
      notifyListeners();
      return account;
    } catch (e) {
      throw AccountCreationException('Failed to create account: $e');
    }
  }

  // Import account from nsec
  Future<UserAccount> importAccount(String nsecOrHex, {String? name}) async {
    try {
      String privateKey;
      
      // Handle both nsec and hex formats
      if (nsecOrHex.startsWith('nsec')) {
        privateKey = nostr.nip19.decodeNsec(nsecOrHex);
      } else {
        privateKey = nsecOrHex;
      }

      // Validate private key
      final keyPair = nostr.KeyPair.fromPrivateKey(privateKey);
      
      // Check if account already exists
      final existing = _accounts.firstWhere(
        (a) => a.pubkey == keyPair.publicKey,
        orElse: () => null,
      );
      
      if (existing != null) {
        throw AccountImportException('Account already exists');
      }

      return await createAccount(
        privateKey: privateKey,
        name: name,
      );
    } catch (e) {
      throw AccountImportException('Failed to import account: $e');
    }
  }

  // Switch to different account
  Future<void> switchAccount(String accountId) async {
    if (_isSwitching) {
      throw AccountSwitchException('Account switch already in progress');
    }

    try {
      _isSwitching = true;
      
      final targetAccount = _accounts.firstWhere(
        (a) => a.id == accountId,
        orElse: () => throw AccountNotFoundException('Account not found: $accountId'),
      );

      // Emit pre-switch event
      _accountSwitchController.add(AccountSwitchEvent.preSwitching(
        from: _currentAccount,
        to: targetAccount,
      ));

      // Save current account state
      if (_currentAccount != null) {
        await _saveAccountState(_currentAccount!.id);
      }

      // Clear current subscriptions
      await _clearCurrentSubscriptions();

      // Retrieve private key for new account
      final privateKey = await SecureAccountStorage.getPrivateKey(accountId);
      if (privateKey == null) {
        throw AccountSwitchException('Failed to retrieve account keys');
      }

      // Update NostrService with new identity
      await _updateNostrIdentity(privateKey, targetAccount.pubkey);

      // Update current account
      _currentAccount = targetAccount.copyWith(
        lastUsedAt: DateTime.now(),
      );
      
      // Update database
      await _updateAccountLastUsed(accountId);

      // Restore account state
      await _restoreAccountState(accountId);

      // Rebuild subscriptions
      await _rebuildSubscriptions();

      // Emit post-switch event
      _accountSwitchController.add(AccountSwitchEvent.switched(
        from: _currentAccount,
        to: targetAccount,
      ));

      notifyListeners();
    } catch (e) {
      _accountSwitchController.add(AccountSwitchEvent.error(
        message: e.toString(),
      ));
      throw AccountSwitchException('Failed to switch account: $e');
    } finally {
      _isSwitching = false;
    }
  }

  // Delete account
  Future<void> deleteAccount(String accountId) async {
    try {
      final account = _accounts.firstWhere(
        (a) => a.id == accountId,
        orElse: () => throw AccountNotFoundException('Account not found'),
      );

      // Prevent deleting the current account if it's the only one
      if (_accounts.length == 1) {
        throw AccountDeletionException('Cannot delete the only account');
      }

      // Switch to another account if deleting current
      if (_currentAccount?.id == accountId) {
        final nextAccount = _accounts.firstWhere((a) => a.id != accountId);
        await switchAccount(nextAccount.id);
      }

      // Delete from secure storage
      await SecureAccountStorage.deleteAccountKeys(accountId);

      // Delete from database
      await _deleteAccountFromDatabase(accountId);

      // Remove from memory
      _accounts.removeWhere((a) => a.id == accountId);

      notifyListeners();
    } catch (e) {
      throw AccountDeletionException('Failed to delete account: $e');
    }
  }

  // Update account profile
  Future<void> updateAccountProfile(String accountId, {
    String? name,
    String? displayName,
    String? avatar,
    String? banner,
    String? about,
    String? nip05,
  }) async {
    final accountIndex = _accounts.indexWhere((a) => a.id == accountId);
    if (accountIndex == -1) {
      throw AccountNotFoundException('Account not found');
    }

    final updatedAccount = _accounts[accountIndex].copyWith(
      name: name ?? _accounts[accountIndex].name,
      displayName: displayName ?? _accounts[accountIndex].displayName,
      avatar: avatar ?? _accounts[accountIndex].avatar,
      banner: banner ?? _accounts[accountIndex].banner,
      about: about ?? _accounts[accountIndex].about,
      nip05: nip05 ?? _accounts[accountIndex].nip05,
    );

    _accounts[accountIndex] = updatedAccount;
    
    if (_currentAccount?.id == accountId) {
      _currentAccount = updatedAccount;
    }

    await _updateAccountInDatabase(updatedAccount);
    notifyListeners();
  }

  // Private helper methods
  Future<void> _loadAccounts() async {
    // Load accounts from database
    final accounts = await AccountRepository.getAllAccounts();
    _accounts = accounts;
  }

  Future<void> _restoreLastUsedAccount() async {
    if (_accounts.isEmpty) return;

    // Find default or most recently used account
    final defaultAccount = _accounts.firstWhere(
      (a) => a.isDefault,
      orElse: () => _accounts.reduce((a, b) => 
        a.lastUsedAt.isAfter(b.lastUsedAt) ? a : b),
    );

    if (defaultAccount != null) {
      await switchAccount(defaultAccount.id);
    }
  }

  Future<void> _saveAccountState(String accountId) async {
    // Save current UI state for the account
    final state = AccountState(
      accountId: accountId,
      lastViewedFeed: getCurrentFeed(),
      lastScrollPosition: getCurrentScrollPosition(),
      lastViewedVideoId: getCurrentVideoId(),
      draftContent: getDraftContent(),
      recentSearches: getRecentSearches(),
      feedFilters: getFeedFilters(),
      stateUpdatedAt: DateTime.now(),
    );

    await AccountRepository.saveAccountState(state);
  }

  Future<void> _restoreAccountState(String accountId) async {
    final state = await AccountRepository.getAccountState(accountId);
    if (state != null) {
      // Restore UI state
      await restoreFeed(state.lastViewedFeed);
      await restoreScrollPosition(state.lastScrollPosition);
      await restoreDraftContent(state.draftContent);
      // ... etc
    }
  }

  Future<void> _clearCurrentSubscriptions() async {
    // Clear NostrService subscriptions
    await NostrService.instance.clearAllSubscriptions();
  }

  Future<void> _updateNostrIdentity(String privateKey, String pubkey) async {
    // Update NostrService with new identity
    await NostrService.instance.setIdentity(
      privateKey: privateKey,
      publicKey: pubkey,
    );
  }

  Future<void> _rebuildSubscriptions() async {
    // Rebuild subscriptions for new account
    await NostrService.instance.rebuildSubscriptions();
  }

  // Database operations
  Future<void> _saveAccountToDatabase(UserAccount account) async {
    await AccountRepository.saveAccount(account);
  }

  Future<void> _updateAccountInDatabase(UserAccount account) async {
    await AccountRepository.updateAccount(account);
  }

  Future<void> _deleteAccountFromDatabase(String accountId) async {
    await AccountRepository.deleteAccount(accountId);
  }

  Future<void> _updateAccountLastUsed(String accountId) async {
    await AccountRepository.updateLastUsed(accountId, DateTime.now());
  }

  @override
  void dispose() {
    _accountSwitchController.close();
    super.dispose();
  }
}

// Event classes
abstract class AccountSwitchEvent {
  const AccountSwitchEvent();
  
  factory AccountSwitchEvent.preSwitching({
    UserAccount? from,
    required UserAccount to,
  }) = PreSwitchingEvent;
  
  factory AccountSwitchEvent.switched({
    UserAccount? from,
    required UserAccount to,
  }) = SwitchedEvent;
  
  factory AccountSwitchEvent.error({
    required String message,
  }) = SwitchErrorEvent;
}

// Exception classes
class AccountException implements Exception {
  final String message;
  AccountException(this.message);
  
  @override
  String toString() => message;
}

class AccountCreationException extends AccountException {
  AccountCreationException(String message) : super(message);
}

class AccountImportException extends AccountException {
  AccountImportException(String message) : super(message);
}

class AccountSwitchException extends AccountException {
  AccountSwitchException(String message) : super(message);
}

class AccountDeletionException extends AccountException {
  AccountDeletionException(String message) : super(message);
}

class AccountNotFoundException extends AccountException {
  AccountNotFoundException(String message) : super(message);
}
```

### Phase 3: Nostr Service Integration (Week 5-6)

#### 3.1 Modified NostrService

```dart
// lib/services/nostr_service_multi_account.dart

extension MultiAccountSupport on NostrService {
  // Set new identity for account switching
  Future<void> setIdentity({
    required String privateKey,
    required String publicKey,
  }) async {
    // Clear existing identity
    _currentPrivateKey = null;
    _currentPublicKey = null;
    
    // Set new identity
    _currentPrivateKey = privateKey;
    _currentPublicKey = publicKey;
    
    // Update SDK client
    await _client.setSigner(NostrSigner.fromPrivateKey(privateKey));
    
    // Notify listeners
    _identityChangedController.add(publicKey);
  }

  // Clear all subscriptions for account switch
  Future<void> clearAllSubscriptions() async {
    // Cancel all active subscriptions
    for (final sub in _activeSubscriptions.values) {
      await sub.cancel();
    }
    _activeSubscriptions.clear();
    
    // Clear subscription state
    _subscriptionStates.clear();
    
    // Clear event caches that are account-specific
    _clearAccountSpecificCaches();
  }

  // Rebuild subscriptions for new account
  Future<void> rebuildSubscriptions() async {
    if (_currentPublicKey == null) {
      throw StateError('No identity set');
    }

    // Rebuild core subscriptions
    await _subscribeToProfile(_currentPublicKey);
    await _subscribeToContacts();
    await _subscribeToHomeFeed();
    await _subscribeToNotifications();
    
    // Restore any saved subscription preferences
    final prefs = await _getAccountSubscriptionPrefs(_currentPublicKey);
    await _restoreSubscriptionPrefs(prefs);
  }

  // Clear account-specific cached data
  void _clearAccountSpecificCaches() {
    // Clear follow lists
    _followList.clear();
    _followerList.clear();
    
    // Clear notification cache
    _notificationCache.clear();
    
    // Clear draft content
    _draftVideos.clear();
    _draftComments.clear();
    
    // Keep shared caches (videos, profiles) intact
  }

  // Get account-specific subscription preferences
  Future<SubscriptionPreferences> _getAccountSubscriptionPrefs(String pubkey) async {
    // Load from database or preferences
    return SubscriptionPreferences.load(pubkey);
  }

  // Restore subscription preferences
  Future<void> _restoreSubscriptionPrefs(SubscriptionPreferences prefs) async {
    // Restore hashtag subscriptions
    for (final hashtag in prefs.followedHashtags) {
      await subscribeToHashtag(hashtag);
    }
    
    // Restore custom feeds
    for (final feed in prefs.customFeeds) {
      await subscribeToCustomFeed(feed);
    }
  }
}
```

### Phase 4: Provider Integration (Week 7)

#### 4.1 Account Providers

```dart
// lib/providers/account_providers.dart

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'account_providers.g.dart';

// Account manager provider
@Riverpod(keepAlive: true)
AccountManager accountManager(AccountManagerRef ref) {
  final manager = AccountManager();
  manager.initialize();
  return manager;
}

// Current account provider
@riverpod
UserAccount? currentAccount(CurrentAccountRef ref) {
  final manager = ref.watch(accountManagerProvider);
  return manager.currentAccount;
}

// All accounts provider
@riverpod
List<UserAccount> allAccounts(AllAccountsRef ref) {
  final manager = ref.watch(accountManagerProvider);
  return manager.allAccounts;
}

// Account switching state
@riverpod
bool isAccountSwitching(IsAccountSwitchingRef ref) {
  final manager = ref.watch(accountManagerProvider);
  return manager.isSwitching;
}

// Account-specific settings provider
@riverpod
Map<String, dynamic> accountSettings(AccountSettingsRef ref) {
  final account = ref.watch(currentAccountProvider);
  return account?.settings ?? {};
}

// Account-specific relay configuration
@riverpod
List<String> accountRelays(AccountRelaysRef ref) {
  final account = ref.watch(currentAccountProvider);
  return account?.relayUrls ?? [];
}

// Account switch event stream
@riverpod
Stream<AccountSwitchEvent> accountSwitchStream(AccountSwitchStreamRef ref) {
  final manager = ref.watch(accountManagerProvider);
  return manager.accountSwitchStream;
}
```

#### 4.2 Modified Video Providers

```dart
// lib/providers/video_providers_multi_account.dart

// Modified home feed provider to be account-aware
@riverpod
List<VideoEvent> homeFeed(HomeFeedRef ref) {
  final account = ref.watch(currentAccountProvider);
  if (account == null) return [];
  
  final videoService = ref.watch(videoEventServiceProvider);
  
  // Get videos only from accounts this user follows
  final followList = ref.watch(followListProvider(account.pubkey));
  
  return videoService.getVideosFromAuthors(followList);
}

// Account-specific liked videos
@riverpod
List<VideoEvent> likedVideos(LikedVideosRef ref) {
  final account = ref.watch(currentAccountProvider);
  if (account == null) return [];
  
  final videoService = ref.watch(videoEventServiceProvider);
  return videoService.getLikedVideosByUser(account.pubkey);
}

// Account-specific uploaded videos
@riverpod
List<VideoEvent> myVideos(MyVideosRef ref) {
  final account = ref.watch(currentAccountProvider);
  if (account == null) return [];
  
  final videoService = ref.watch(videoEventServiceProvider);
  return videoService.getVideosByAuthor(account.pubkey);
}
```

### Phase 5: UI Implementation (Week 8)

#### 5.1 Account Switcher Widget

```dart
// lib/widgets/account_switcher.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AccountSwitcher extends ConsumerWidget {
  const AccountSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentAccount = ref.watch(currentAccountProvider);
    final allAccounts = ref.watch(allAccountsProvider);
    final isSwitching = ref.watch(isAccountSwitchingProvider);

    return PopupMenuButton<String>(
      enabled: !isSwitching,
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: _AccountAvatar(account: currentAccount),
      itemBuilder: (context) => [
        // Current account header
        if (currentAccount != null)
          PopupMenuItem<String>(
            enabled: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentAccount.displayName ?? currentAccount.name ?? 'Anonymous',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (currentAccount.nip05 != null)
                  Text(
                    currentAccount.nip05!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const Divider(),
              ],
            ),
          ),
        
        // Other accounts
        ...allAccounts
            .where((account) => account.id != currentAccount?.id)
            .map((account) => PopupMenuItem<String>(
                  value: account.id,
                  child: _AccountMenuItem(account: account),
                )),
        
        const PopupMenuDivider(),
        
        // Add account option
        PopupMenuItem<String>(
          value: 'add_account',
          child: ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('Add Account'),
            dense: true,
          ),
        ),
        
        // Manage accounts option
        PopupMenuItem<String>(
          value: 'manage_accounts',
          child: ListTile(
            leading: const Icon(Icons.manage_accounts),
            title: const Text('Manage Accounts'),
            dense: true,
          ),
        ),
      ],
      onSelected: (value) async {
        if (value == 'add_account') {
          _showAddAccountDialog(context, ref);
        } else if (value == 'manage_accounts') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AccountManagementScreen(),
            ),
          );
        } else {
          // Switch account
          try {
            await ref.read(accountManagerProvider).switchAccount(value);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to switch account: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      },
    );
  }

  void _showAddAccountDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const AddAccountDialog(),
    );
  }
}

class _AccountAvatar extends StatelessWidget {
  final UserAccount? account;
  
  const _AccountAvatar({required this.account});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).primaryColor,
          width: 2,
        ),
      ),
      child: ClipOval(
        child: account?.avatar != null
            ? Image.network(
                account!.avatar!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _defaultAvatar(context),
              )
            : _defaultAvatar(context),
      ),
    );
  }

  Widget _defaultAvatar(BuildContext context) {
    return Container(
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      child: Icon(
        Icons.person,
        size: 20,
        color: Theme.of(context).primaryColor,
      ),
    );
  }
}

class _AccountMenuItem extends StatelessWidget {
  final UserAccount account;
  
  const _AccountMenuItem({required this.account});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _AccountAvatar(account: account),
      title: Text(account.displayName ?? account.name ?? 'Anonymous'),
      subtitle: account.nip05 != null ? Text(account.nip05!) : null,
      dense: true,
    );
  }
}
```

#### 5.2 Account Management Screen

```dart
// lib/screens/account_management_screen.dart

class AccountManagementScreen extends ConsumerStatefulWidget {
  const AccountManagementScreen({super.key});

  @override
  ConsumerState<AccountManagementScreen> createState() => _AccountManagementScreenState();
}

class _AccountManagementScreenState extends ConsumerState<AccountManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(allAccountsProvider);
    final currentAccount = ref.watch(currentAccountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Accounts'),
      ),
      body: ListView.builder(
        itemCount: accounts.length,
        itemBuilder: (context, index) {
          final account = accounts[index];
          final isCurrent = account.id == currentAccount?.id;

          return Dismissible(
            key: Key(account.id),
            direction: accounts.length > 1
                ? DismissDirection.endToStart
                : DismissDirection.none,
            confirmDismiss: (direction) async {
              if (accounts.length == 1) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cannot delete the only account'),
                  ),
                );
                return false;
              }
              
              return await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Account'),
                  content: Text(
                    'Are you sure you want to delete ${account.displayName ?? account.name ?? "this account"}? This action cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
            },
            onDismissed: (direction) async {
              try {
                await ref.read(accountManagerProvider).deleteAccount(account.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Account deleted'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete account: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              color: Colors.red,
              child: const Icon(
                Icons.delete,
                color: Colors.white,
              ),
            ),
            child: ListTile(
              leading: _AccountAvatar(account: account),
              title: Text(
                account.displayName ?? account.name ?? 'Anonymous',
                style: isCurrent
                    ? TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      )
                    : null,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (account.nip05 != null)
                    Text(account.nip05!),
                  Text(
                    'Created: ${_formatDate(account.createdAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              trailing: isCurrent
                  ? Chip(
                      label: const Text('Current'),
                      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                    )
                  : IconButton(
                      icon: const Icon(Icons.swap_horiz),
                      onPressed: () async {
                        try {
                          await ref.read(accountManagerProvider).switchAccount(account.id);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Switched account'),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to switch: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                    ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AccountDetailsScreen(account: account),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => const AddAccountDialog(),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
```

## Security Architecture

### Key Management

```
┌─────────────────────────────────────────────────────┐
│                   User Action                        │
│                                                      │
│  1. Create/Import Account                           │
│  2. Request Private Key Access                      │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│               Biometric/PIN Check                    │
│                                                      │
│  - Touch ID / Face ID / Fingerprint                 │
│  - Device PIN as fallback                           │
└──────────────────────┬──────────────────────────────┘
                       │ Authenticated
                       ▼
┌─────────────────────────────────────────────────────┐
│              Secure Storage Layer                    │
│                                                      │
│  1. Derive unique key per account                   │
│  2. AES-256-GCM encryption                         │
│  3. Store in platform secure storage               │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│            Memory Management                         │
│                                                      │
│  1. Load key into secure memory                     │
│  2. Use for operations                             │
│  3. Secure wipe after use                          │
│  4. No logging or debug output                     │
└─────────────────────────────────────────────────────┘
```

### Security Best Practices

1. **Never store private keys in plain text**
2. **Always use platform-specific secure storage**
3. **Implement biometric authentication where available**
4. **Clear sensitive data from memory after use**
5. **Use secure random generation for new keys**
6. **Implement key derivation with unique salts**
7. **Add rate limiting for failed authentication attempts**
8. **Log security events without exposing sensitive data**

## API Reference

### AccountManager API

```dart
// Get singleton instance
final accountManager = AccountManager();

// Create new account
final account = await accountManager.createAccount(
  name: 'My Account',
  setAsDefault: true,
);

// Import existing account
final imported = await accountManager.importAccount(
  'nsec1...' // or hex private key
);

// Switch accounts
await accountManager.switchAccount(accountId);

// Delete account
await accountManager.deleteAccount(accountId);

// Update profile
await accountManager.updateAccountProfile(
  accountId,
  name: 'New Name',
  avatar: 'https://example.com/avatar.jpg',
);

// Get current account
final current = accountManager.currentAccount;

// Get all accounts
final all = accountManager.allAccounts;

// Listen to account switches
accountManager.accountSwitchStream.listen((event) {
  // Handle switch events
});
```

### Provider API

```dart
// In a ConsumerWidget
final currentAccount = ref.watch(currentAccountProvider);
final allAccounts = ref.watch(allAccountsProvider);
final isSwitching = ref.watch(isAccountSwitchingProvider);

// Account-specific data
final settings = ref.watch(accountSettingsProvider);
final relays = ref.watch(accountRelaysProvider);

// Account-aware feeds
final homeFeed = ref.watch(homeFeedProvider);
final myVideos = ref.watch(myVideosProvider);
```

## Migration Guide

### For Existing Users

When multi-account support is first launched, existing users need to be migrated:

```dart
class AccountMigration {
  static Future<void> migrateExistingUser() async {
    // Check if migration is needed
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('multi_account_migrated') == true) {
      return;
    }

    try {
      // Get existing private key
      final existingKey = await _getExistingPrivateKey();
      if (existingKey == null) {
        // No existing account, skip migration
        return;
      }

      // Get existing profile data
      final profile = await _getExistingProfile();

      // Create account using existing data
      final accountManager = AccountManager();
      await accountManager.createAccount(
        privateKey: existingKey,
        name: profile?.name,
        setAsDefault: true,
      );

      // Clean up old storage
      await _cleanupOldStorage();

      // Mark migration complete
      await prefs.setBool('multi_account_migrated', true);
    } catch (e) {
      print('Migration failed: $e');
      // Handle migration failure
    }
  }
}
```

### Database Migration

```sql
-- Migration script for existing database
BEGIN TRANSACTION;

-- Create new tables if they don't exist
CREATE TABLE IF NOT EXISTS accounts ...;
CREATE TABLE IF NOT EXISTS account_relays ...;
CREATE TABLE IF NOT EXISTS account_states ...;
CREATE TABLE IF NOT EXISTS account_settings ...;

-- Migrate existing user data to accounts table
INSERT INTO accounts (
  id,
  pubkey,
  name,
  avatar,
  created_at,
  last_used_at,
  is_default
)
SELECT
  lower(hex(randomblob(16))), -- Generate UUID
  pubkey,
  name,
  avatar_url,
  created_at,
  updated_at,
  1 -- Set as default account
FROM user_profile
WHERE NOT EXISTS (
  SELECT 1 FROM accounts WHERE pubkey = user_profile.pubkey
);

-- Migrate relay settings
INSERT INTO account_relays (account_id, relay_url)
SELECT 
  a.id,
  r.url
FROM accounts a
CROSS JOIN user_relays r
WHERE a.is_default = 1;

COMMIT;
```

## Testing Strategy

### Unit Tests

```dart
// test/services/account_manager_test.dart

void main() {
  group('AccountManager', () {
    late AccountManager accountManager;

    setUp(() {
      accountManager = AccountManager();
    });

    test('creates new account with generated keys', () async {
      final account = await accountManager.createAccount(
        name: 'Test Account',
      );

      expect(account.id, isNotEmpty);
      expect(account.pubkey, isNotEmpty);
      expect(account.name, equals('Test Account'));
    });

    test('imports account from nsec', () async {
      const nsec = 'nsec1...'; // Valid test nsec
      
      final account = await accountManager.importAccount(nsec);
      
      expect(account.pubkey, isNotEmpty);
    });

    test('switches between accounts', () async {
      final account1 = await accountManager.createAccount(name: 'Account 1');
      final account2 = await accountManager.createAccount(name: 'Account 2');

      await accountManager.switchAccount(account2.id);
      expect(accountManager.currentAccount?.id, equals(account2.id));

      await accountManager.switchAccount(account1.id);
      expect(accountManager.currentAccount?.id, equals(account1.id));
    });

    test('prevents deletion of only account', () async {
      final account = await accountManager.createAccount();

      expect(
        () => accountManager.deleteAccount(account.id),
        throwsA(isA<AccountDeletionException>()),
      );
    });

    test('preserves state during account switch', () async {
      final account1 = await accountManager.createAccount();
      
      // Set some state
      await setTestState('key', 'value1');
      
      final account2 = await accountManager.createAccount();
      await accountManager.switchAccount(account2.id);
      
      // Different state for account2
      await setTestState('key', 'value2');
      
      // Switch back
      await accountManager.switchAccount(account1.id);
      
      // Verify state preserved
      final state = await getTestState('key');
      expect(state, equals('value1'));
    });
  });

  group('SecureAccountStorage', () {
    test('stores and retrieves private keys securely', () async {
      const accountId = 'test-account';
      const privateKey = 'test-private-key';

      await SecureAccountStorage.storePrivateKey(
        accountId: accountId,
        privateKey: privateKey,
      );

      final retrieved = await SecureAccountStorage.getPrivateKey(accountId);
      expect(retrieved, equals(privateKey));
    });

    test('isolates keys between accounts', () async {
      await SecureAccountStorage.storePrivateKey(
        accountId: 'account1',
        privateKey: 'key1',
      );

      await SecureAccountStorage.storePrivateKey(
        accountId: 'account2',
        privateKey: 'key2',
      );

      final key1 = await SecureAccountStorage.getPrivateKey('account1');
      final key2 = await SecureAccountStorage.getPrivateKey('account2');

      expect(key1, equals('key1'));
      expect(key2, equals('key2'));
      expect(key1, isNot(equals(key2)));
    });

    test('deletes keys securely', () async {
      const accountId = 'test-account';
      
      await SecureAccountStorage.storePrivateKey(
        accountId: accountId,
        privateKey: 'test-key',
      );

      await SecureAccountStorage.deleteAccountKeys(accountId);

      final retrieved = await SecureAccountStorage.getPrivateKey(accountId);
      expect(retrieved, isNull);
    });
  });
}
```

### Integration Tests

```dart
// test/integration/account_switching_test.dart

void main() {
  testWidgets('account switching flow', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: TestScreen(),
        ),
      ),
    );

    // Create two accounts
    final accountManager = AccountManager();
    final account1 = await accountManager.createAccount(name: 'Account 1');
    final account2 = await accountManager.createAccount(name: 'Account 2');

    // Verify current account
    expect(find.text('Account 2'), findsOneWidget);

    // Open account switcher
    await tester.tap(find.byType(AccountSwitcher));
    await tester.pumpAndSettle();

    // Switch to account 1
    await tester.tap(find.text('Account 1'));
    await tester.pumpAndSettle();

    // Verify switched
    expect(find.text('Account 1'), findsOneWidget);
  });
}
```

## Performance Considerations

### Optimization Strategies

1. **Lazy Loading**: Load account data only when needed
2. **Caching**: Cache frequently accessed account data
3. **Batch Operations**: Group database operations
4. **Memory Management**: Limit accounts kept in memory
5. **Background Processing**: Perform heavy operations off main thread

### Performance Benchmarks

| Operation | Target | Actual | Status |
|-----------|--------|--------|--------|
| Account Switch | < 500ms | - | Pending |
| Key Retrieval | < 100ms | - | Pending |
| State Save | < 200ms | - | Pending |
| State Restore | < 200ms | - | Pending |
| Memory per Account | < 10MB | - | Pending |

## Troubleshooting

### Common Issues

#### Issue: Account switch takes too long
**Solution**: 
- Check subscription count
- Optimize state save/restore
- Use lazy loading for non-critical data

#### Issue: Private key not found
**Solution**:
- Verify secure storage permissions
- Check biometric authentication
- Ensure key was properly stored

#### Issue: State not preserved
**Solution**:
- Verify state save is called before switch
- Check database write permissions
- Ensure state restore is awaited

#### Issue: Memory leak during switching
**Solution**:
- Properly dispose controllers
- Clear caches on switch
- Limit accounts in memory

### Debug Helpers

```dart
// Enable debug logging
AccountManager.enableDebugLogging = true;

// Check account state
final debugInfo = await accountManager.getDebugInfo();
print(debugInfo);

// Verify secure storage
final canUseBiometric = await SecureAccountStorage.canUseBiometric();
print('Biometric available: $canUseBiometric');

// Test account switching performance
final stopwatch = Stopwatch()..start();
await accountManager.switchAccount(accountId);
print('Switch took: ${stopwatch.elapsedMilliseconds}ms');
```

## Future Enhancements

### Planned Features

1. **Account Groups**: Organize accounts into groups
2. **Quick Switch Gesture**: Swipe to switch accounts
3. **Account Templates**: Pre-configured account settings
4. **Cloud Backup**: Encrypted backup to cloud services
5. **Account Sharing**: Share account between devices
6. **Guest Mode**: Temporary anonymous accounts
7. **Business Accounts**: Special features for business users
8. **Family Accounts**: Parental controls and monitoring

### API Extensions

```dart
// Future API additions
class AccountManager {
  // Account groups
  Future<AccountGroup> createGroup(String name);
  Future<void> addAccountToGroup(String accountId, String groupId);
  
  // Quick actions
  Future<void> quickSwitch(); // Switch to next account
  Future<void> switchToPrevious(); // Go back to previous account
  
  // Templates
  Future<UserAccount> createFromTemplate(AccountTemplate template);
  
  // Backup
  Future<String> exportAllAccounts({required String password});
  Future<void> importAccounts(String data, {required String password});
}
```

## Conclusion

This implementation guide provides a complete roadmap for adding multi-account support to OpenVine. The architecture prioritizes security, performance, and user experience while maintaining backward compatibility and data efficiency.

### Key Takeaways

1. **Security is paramount** - Private keys must be protected at all times
2. **Performance matters** - Account switching must be seamless
3. **User experience** - Make multi-account management intuitive
4. **Data efficiency** - Share common data across accounts
5. **Extensibility** - Design for future enhancements

### Next Steps

1. Review and approve the implementation plan
2. Set up development environment
3. Begin Phase 1 implementation
4. Establish testing protocols
5. Plan beta testing program

For questions or clarifications, please refer to the relevant sections above or consult the development team.