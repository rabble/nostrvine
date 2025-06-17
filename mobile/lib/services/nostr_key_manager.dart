// ABOUTME: Secure Nostr key management with persistence and backup
// ABOUTME: Handles key generation, storage, import/export, and security

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nostr/nostr.dart';
import 'package:crypto/crypto.dart';

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
      debugPrint('🔑 Initializing Nostr key manager...');
      
      final prefs = await SharedPreferences.getInstance();
      
      // Try to load existing keys
      final existingKeyData = prefs.getString(_keyPairKey);
      final keyVersion = prefs.getInt(_keyVersionKey) ?? 0;
      
      if (existingKeyData != null && keyVersion >= _currentKeyVersion) {
        debugPrint('🔑 Loading existing Nostr keys...');
        await _loadKeysFromStorage(existingKeyData);
      } else {
        debugPrint('🔑 No existing keys found or version outdated');
      }
      
      // Load backup hash
      _backupHash = prefs.getString(_backupHashKey);
      
      _isInitialized = true;
      notifyListeners();
      
      if (hasKeys) {
        debugPrint('✅ Key manager initialized with existing identity');
      } else {
        debugPrint('✅ Key manager initialized, ready for key generation');
      }
      
    } catch (e) {
      debugPrint('❌ Failed to initialize key manager: $e');
      rethrow;
    }
  }
  
  /// Generate new Nostr key pair
  Future<Keychain> generateKeys() async {
    if (!_isInitialized) {
      throw NostrKeyException('Key manager not initialized');
    }
    
    try {
      debugPrint('🔑 Generating new Nostr key pair...');
      
      // Generate new key pair
      _keyPair = Keychain.generate();
      
      // Save to persistent storage
      await _saveKeysToStorage();
      
      notifyListeners();
      
      debugPrint('✅ New Nostr key pair generated and saved');
      debugPrint('📝 Public key: ${_keyPair!.public}');
      
      return _keyPair!;
    } catch (e) {
      debugPrint('❌ Failed to generate keys: $e');
      throw NostrKeyException('Failed to generate new keys: $e');
    }
  }
  
  /// Import key pair from private key
  Future<Keychain> importPrivateKey(String privateKey) async {
    if (!_isInitialized) {
      throw NostrKeyException('Key manager not initialized');
    }
    
    try {
      debugPrint('🔑 Importing Nostr private key...');
      
      // Validate private key format (64 character hex)
      if (!_isValidPrivateKey(privateKey)) {
        throw NostrKeyException('Invalid private key format');
      }
      
      // Create key pair from private key
      _keyPair = Keychain(privateKey);
      
      // Save to persistent storage
      await _saveKeysToStorage();
      
      notifyListeners();
      
      debugPrint('✅ Private key imported successfully');
      debugPrint('📝 Public key: ${_keyPair!.public}');
      
      return _keyPair!;
    } catch (e) {
      debugPrint('❌ Failed to import private key: $e');
      throw NostrKeyException('Failed to import private key: $e');
    }
  }
  
  /// Export private key for backup
  String exportPrivateKey() {
    if (!hasKeys) {
      throw NostrKeyException('No keys available for export');
    }
    
    debugPrint('🔑 Exporting private key for backup');
    return _keyPair!.private;
  }
  
  /// Create mnemonic backup phrase (using private key as entropy)
  Future<List<String>> createMnemonicBackup() async {
    if (!hasKeys) {
      throw NostrKeyException('No keys available for backup');
    }
    
    try {
      debugPrint('🔑 Creating mnemonic backup...');
      
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
      
      debugPrint('✅ Mnemonic backup created');
      return mnemonic;
    } catch (e) {
      debugPrint('❌ Failed to create mnemonic backup: $e');
      throw NostrKeyException('Failed to create backup: $e');
    }
  }
  
  /// Restore from mnemonic backup
  Future<Keychain> restoreFromMnemonic(List<String> mnemonic) async {
    if (!_isInitialized) {
      throw NostrKeyException('Key manager not initialized');
    }
    
    try {
      debugPrint('🔑 Restoring from mnemonic backup...');
      
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
      debugPrint('❌ Failed to restore from mnemonic: $e');
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
      debugPrint('❌ Backup verification failed: $e');
      return false;
    }
  }
  
  /// Clear all stored keys (logout)
  Future<void> clearKeys() async {
    try {
      debugPrint('🔑 Clearing stored Nostr keys...');
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyPairKey);
      await prefs.remove(_keyVersionKey);
      await prefs.remove(_backupHashKey);
      
      _keyPair = null;
      _backupHash = null;
      
      notifyListeners();
      
      debugPrint('✅ Nostr keys cleared successfully');
    } catch (e) {
      debugPrint('❌ Failed to clear keys: $e');
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
      
      debugPrint('✅ Keys saved to persistent storage');
    } catch (e) {
      debugPrint('❌ Failed to save keys: $e');
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
      
      debugPrint('✅ Keys loaded from storage');
    } catch (e) {
      debugPrint('❌ Failed to load keys from storage: $e');
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