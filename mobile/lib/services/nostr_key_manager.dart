// ABOUTME: Secure Nostr key management with persistence and backup
// ABOUTME: Handles key generation, storage, import/export, and security

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:crypto/crypto.dart';
import '../utils/unified_logger.dart';

// Simple KeyPair class to replace Keychain
class Keychain {
  final String private;
  final String public;
  
  Keychain(this.private) : public = getPublicKey(private);
  
  static Keychain generate() {
    final privateKey = generatePrivateKey();
    return Keychain(privateKey);
  }
}

/// Secure management of Nostr private keys with persistence
class NostrKeyManager extends ChangeNotifier {
  static const String _keyPairKey = 'nostr_keypair';
  static const String _keyVersionKey = 'nostr_key_version';
  static const String _backupHashKey = 'nostr_backup_hash';
  static const int _currentKeyVersion = 1;
  
  Keychain? _keyPair;
  bool _isInitialized = false;
  String? _backupHash;
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get hasKeys => _keyPair != null;
  String? get publicKey => _keyPair?.public;
  String? get privateKey => _keyPair?.private;
  Keychain? get keyPair => _keyPair;
  bool get hasBackup => _backupHash != null;
  
  /// Initialize key manager and load existing keys
  Future<void> initialize() async {
    try {
      Log.debug('� Initializing Nostr key manager...', name: 'NostrKeyManager', category: LogCategory.relay);
      
      final prefs = await SharedPreferences.getInstance();
      
      // Try to load existing keys
      final existingKeyData = prefs.getString(_keyPairKey);
      final keyVersion = prefs.getInt(_keyVersionKey) ?? 0;
      
      if (existingKeyData != null && keyVersion >= _currentKeyVersion) {
        Log.debug('� Loading existing Nostr keys...', name: 'NostrKeyManager', category: LogCategory.relay);
        await _loadKeysFromStorage(existingKeyData);
      } else {
        Log.info('� No existing keys found or version outdated', name: 'NostrKeyManager', category: LogCategory.relay);
      }
      
      // Load backup hash
      _backupHash = prefs.getString(_backupHashKey);
      
      _isInitialized = true;
      notifyListeners();
      
      if (hasKeys) {
        Log.info('Key manager initialized with existing identity', name: 'NostrKeyManager', category: LogCategory.relay);
      } else {
        Log.info('Key manager initialized, ready for key generation', name: 'NostrKeyManager', category: LogCategory.relay);
      }
      
    } catch (e) {
      Log.error('Failed to initialize key manager: $e', name: 'NostrKeyManager', category: LogCategory.relay);
      rethrow;
    }
  }
  
  /// Generate new Nostr key pair
  Future<Keychain> generateKeys() async {
    if (!_isInitialized) {
      throw NostrKeyException('Key manager not initialized');
    }
    
    try {
      Log.debug('� Generating new Nostr key pair...', name: 'NostrKeyManager', category: LogCategory.relay);
      
      // Generate new key pair
      _keyPair = Keychain.generate();
      
      // Save to persistent storage
      await _saveKeysToStorage();
      
      notifyListeners();
      
      Log.info('New Nostr key pair generated and saved', name: 'NostrKeyManager', category: LogCategory.relay);
      Log.verbose('Public key: ${_keyPair!.public}', name: 'NostrKeyManager', category: LogCategory.relay);
      
      return _keyPair!;
    } catch (e) {
      Log.error('Failed to generate keys: $e', name: 'NostrKeyManager', category: LogCategory.relay);
      throw NostrKeyException('Failed to generate new keys: $e');
    }
  }
  
  /// Import key pair from private key
  Future<Keychain> importPrivateKey(String privateKey) async {
    if (!_isInitialized) {
      throw NostrKeyException('Key manager not initialized');
    }
    
    try {
      Log.debug('� Importing Nostr private key...', name: 'NostrKeyManager', category: LogCategory.relay);
      
      // Validate private key format (64 character hex)
      if (!_isValidPrivateKey(privateKey)) {
        throw NostrKeyException('Invalid private key format');
      }
      
      // Create key pair from private key
      _keyPair = Keychain(privateKey);
      
      // Save to persistent storage
      await _saveKeysToStorage();
      
      notifyListeners();
      
      Log.info('Private key imported successfully', name: 'NostrKeyManager', category: LogCategory.relay);
      Log.verbose('Public key: ${_keyPair!.public}', name: 'NostrKeyManager', category: LogCategory.relay);
      
      return _keyPair!;
    } catch (e) {
      Log.error('Failed to import private key: $e', name: 'NostrKeyManager', category: LogCategory.relay);
      throw NostrKeyException('Failed to import private key: $e');
    }
  }
  
  /// Export private key for backup
  String exportPrivateKey() {
    if (!hasKeys) {
      throw NostrKeyException('No keys available for export');
    }
    
    Log.debug('� Exporting private key for backup', name: 'NostrKeyManager', category: LogCategory.relay);
    return _keyPair!.private;
  }
  
  /// Create mnemonic backup phrase (using private key as entropy)
  Future<List<String>> createMnemonicBackup() async {
    if (!hasKeys) {
      throw NostrKeyException('No keys available for backup');
    }
    
    try {
      Log.debug('� Creating mnemonic backup...', name: 'NostrKeyManager', category: LogCategory.relay);
      
      // Use private key as entropy source for mnemonic generation
      final privateKeyBytes = _hexToBytes(_keyPair!.private);
      
      // Simple word mapping (for prototype - use proper BIP39 in production)
      final wordList = _getSimpleWordList();
      final mnemonic = <String>[];
      
      // Convert private key bytes to mnemonic words (12 words)
      for (int i = 0; i < 12; i++) {
        final byteIndex = i % privateKeyBytes.length;
        final wordIndex = privateKeyBytes[byteIndex] % wordList.length;
        mnemonic.add(wordList[wordIndex]);
      }
      
      // Create backup hash for verification
      final mnemonicString = mnemonic.join(' ');
      final backupBytes = utf8.encode(mnemonicString + _keyPair!.private);
      _backupHash = sha256.convert(backupBytes).toString();
      
      // Save backup hash
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_backupHashKey, _backupHash!);
      
      notifyListeners();
      
      Log.info('Mnemonic backup created', name: 'NostrKeyManager', category: LogCategory.relay);
      return mnemonic;
    } catch (e) {
      Log.error('Failed to create mnemonic backup: $e', name: 'NostrKeyManager', category: LogCategory.relay);
      throw NostrKeyException('Failed to create backup: $e');
    }
  }
  
  /// Restore from mnemonic backup
  Future<Keychain> restoreFromMnemonic(List<String> mnemonic) async {
    if (!_isInitialized) {
      throw NostrKeyException('Key manager not initialized');
    }
    
    try {
      Log.debug('� Restoring from mnemonic backup...', name: 'NostrKeyManager', category: LogCategory.relay);
      
      if (mnemonic.length != 12) {
        throw NostrKeyException('Invalid mnemonic length (expected 12 words)');
      }
      
      // Validate mnemonic words
      final wordList = _getSimpleWordList();
      for (final word in mnemonic) {
        if (!wordList.contains(word)) {
          throw NostrKeyException('Invalid mnemonic word: $word');
        }
      }
      
      // In a real implementation, this would derive the private key from mnemonic
      // For prototype, we'll ask user to provide the private key for verification
      throw NostrKeyException('Mnemonic restoration requires private key for verification in prototype');
      
    } catch (e) {
      Log.error('Failed to restore from mnemonic: $e', name: 'NostrKeyManager', category: LogCategory.relay);
      rethrow;
    }
  }
  
  /// Verify backup integrity
  Future<bool> verifyBackup(List<String> mnemonic, String privateKey) async {
    try {
      final mnemonicString = mnemonic.join(' ');
      final backupBytes = utf8.encode(mnemonicString + privateKey);
      final calculatedHash = sha256.convert(backupBytes).toString();
      
      return calculatedHash == _backupHash;
    } catch (e) {
      Log.error('Backup verification failed: $e', name: 'NostrKeyManager', category: LogCategory.relay);
      return false;
    }
  }
  
  /// Clear all stored keys (logout)
  Future<void> clearKeys() async {
    try {
      Log.debug('� Clearing stored Nostr keys...', name: 'NostrKeyManager', category: LogCategory.relay);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyPairKey);
      await prefs.remove(_keyVersionKey);
      await prefs.remove(_backupHashKey);
      
      _keyPair = null;
      _backupHash = null;
      
      notifyListeners();
      
      Log.info('Nostr keys cleared successfully', name: 'NostrKeyManager', category: LogCategory.relay);
    } catch (e) {
      Log.error('Failed to clear keys: $e', name: 'NostrKeyManager', category: LogCategory.relay);
      throw NostrKeyException('Failed to clear keys: $e');
    }
  }
  
  /// Save keys to persistent storage
  Future<void> _saveKeysToStorage() async {
    if (_keyPair == null) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Create secure key data structure
      final keyData = {
        'private': _keyPair!.private,
        'public': _keyPair!.public,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'version': _currentKeyVersion,
      };
      
      // Save encrypted in production, plain for prototype
      final keyDataString = jsonEncode(keyData);
      
      await prefs.setString(_keyPairKey, keyDataString);
      await prefs.setInt(_keyVersionKey, _currentKeyVersion);
      
      Log.info('Keys saved to persistent storage', name: 'NostrKeyManager', category: LogCategory.relay);
    } catch (e) {
      Log.error('Failed to save keys: $e', name: 'NostrKeyManager', category: LogCategory.relay);
      throw NostrKeyException('Failed to save keys: $e');
    }
  }
  
  /// Load keys from persistent storage
  Future<void> _loadKeysFromStorage(String keyDataString) async {
    try {
      final keyData = jsonDecode(keyDataString) as Map<String, dynamic>;
      
      final privateKey = keyData['private'] as String?;
      final publicKey = keyData['public'] as String?;
      
      if (privateKey == null || publicKey == null) {
        throw NostrKeyException('Invalid key data structure');
      }
      
      // Validate key format
      if (!_isValidPrivateKey(privateKey) || !_isValidPublicKey(publicKey)) {
        throw NostrKeyException('Invalid key format in storage');
      }
      
      _keyPair = Keychain(privateKey);
      
      // Verify public key matches
      if (_keyPair!.public != publicKey) {
        throw NostrKeyException('Public key mismatch - possible corruption');
      }
      
      Log.info('Keys loaded from storage', name: 'NostrKeyManager', category: LogCategory.relay);
    } catch (e) {
      Log.error('Failed to load keys from storage: $e', name: 'NostrKeyManager', category: LogCategory.relay);
      throw NostrKeyException('Failed to load stored keys: $e');
    }
  }
  
  /// Validate private key format
  bool _isValidPrivateKey(String privateKey) {
    return RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(privateKey);
  }
  
  /// Validate public key format  
  bool _isValidPublicKey(String publicKey) {
    return RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(publicKey);
  }
  
  /// Convert hex string to bytes
  List<int> _hexToBytes(String hex) {
    final result = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      result.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return result;
  }
  
  /// Get simple word list for mnemonic (prototype implementation)
  List<String> _getSimpleWordList() {
    return [
      'abandon', 'ability', 'able', 'about', 'above', 'absent', 'absorb', 'abstract',
      'absurd', 'abuse', 'access', 'accident', 'account', 'accuse', 'achieve', 'acid',
      'acoustic', 'acquire', 'across', 'action', 'actor', 'actress', 'actual', 'adapt',
      'add', 'addict', 'address', 'adjust', 'admit', 'adult', 'advance', 'advice',
      'aerobic', 'affair', 'afford', 'afraid', 'again', 'agent', 'agree', 'ahead',
      'aim', 'air', 'airport', 'aisle', 'alarm', 'album', 'alcohol', 'alert',
      'alien', 'all', 'alley', 'allow', 'almost', 'alone', 'alpha', 'already',
      'also', 'alter', 'always', 'amateur', 'amazing', 'among', 'amount', 'amused',
      'analyst', 'anchor', 'ancient', 'anger', 'angle', 'angry', 'animal', 'ankle',
      'announce', 'annual', 'another', 'answer', 'antenna', 'antique', 'anxiety', 'any',
      'apart', 'apology', 'appear', 'apple', 'approve', 'april', 'area', 'arena',
      'argue', 'arm', 'armed', 'armor', 'army', 'around', 'arrange', 'arrest',
      'arrive', 'arrow', 'art', 'artist', 'artwork', 'ask', 'aspect', 'assault',
      'asset', 'assist', 'assume', 'asthma', 'athlete', 'atom', 'attack', 'attend',
      'attitude', 'attract', 'auction', 'audit', 'august', 'aunt', 'author', 'auto',
      'autumn', 'average', 'avocado', 'avoid', 'awake', 'aware', 'away', 'awesome',
      'awful', 'awkward', 'axis', 'baby', 'bachelor', 'bacon', 'badge', 'bag',
      'balance', 'balcony', 'ball', 'bamboo', 'banana', 'banner', 'bar', 'barely',
      'bargain', 'barrel', 'base', 'basic', 'basket', 'battle', 'beach', 'bean',
      'beauty', 'because', 'become', 'beef', 'before', 'begin', 'behave', 'behind',
      'believe', 'below', 'belt', 'bench', 'benefit', 'best', 'betray', 'better',
      'between', 'beyond', 'bicycle', 'bid', 'bike', 'bind', 'biology', 'bird',
      'birth', 'bitter', 'black', 'blade', 'blame', 'blanket', 'blast', 'bleak',
      'bless', 'blind', 'blood', 'blossom', 'blow', 'blue', 'blur', 'blush',
      'board', 'boat', 'body', 'boil', 'bomb', 'bone', 'bonus', 'book',
      'boost', 'border', 'boring', 'borrow', 'boss', 'bottom', 'bounce', 'box',
      'boy', 'bracket', 'brain', 'brand', 'brass', 'brave', 'bread', 'breeze',
      'brick', 'bridge', 'brief', 'bright', 'bring', 'brisk', 'broccoli', 'broken',
      'bronze', 'broom', 'brother', 'brown', 'brush', 'bubble', 'buddy', 'budget',
      'buffalo', 'build', 'bulb', 'bulk', 'bullet', 'bundle', 'bunker', 'burden',
      'burger', 'burst', 'bus', 'business', 'busy', 'butter', 'buyer', 'buzz'
    ];
  }
  
  /// Get user identity summary
  Map<String, dynamic> getIdentitySummary() {
    if (!hasKeys) {
      return {'hasIdentity': false};
    }
    
    return {
      'hasIdentity': true,
      'publicKey': publicKey,
      'publicKeyShort': '${publicKey!.substring(0, 8)}...${publicKey!.substring(publicKey!.length - 8)}',
      'hasBackup': hasBackup,
      'isInitialized': isInitialized,
    };
  }
}

/// Exception thrown by key manager operations
class NostrKeyException implements Exception {
  final String message;
  
  const NostrKeyException(this.message);
  
  @override
  String toString() => 'NostrKeyException: $message';
}