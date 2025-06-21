// ABOUTME: Service for NIP-07 browser extension authentication (Alby, nos2x, Nostore)
// ABOUTME: Provides clean Dart interface for one-click Nostr login via browser extensions

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'nip07_interop.dart' as nip07;

/// Authentication result from NIP-07 extension
class Nip07AuthResult {
  final bool success;
  final String? publicKey;
  final String? errorMessage;
  final String? errorCode;
  
  const Nip07AuthResult({
    required this.success,
    this.publicKey,
    this.errorMessage,
    this.errorCode,
  });
  
  factory Nip07AuthResult.success(String publicKey) {
    return Nip07AuthResult(success: true, publicKey: publicKey);
  }
  
  factory Nip07AuthResult.failure(String message, {String? code}) {
    return Nip07AuthResult(
      success: false,
      errorMessage: message,
      errorCode: code,
    );
  }
}

/// Event signing result from NIP-07 extension
class Nip07SignResult {
  final bool success;
  final Map<String, dynamic>? signedEvent;
  final String? errorMessage;
  final String? errorCode;
  
  const Nip07SignResult({
    required this.success,
    this.signedEvent,
    this.errorMessage,
    this.errorCode,
  });
  
  factory Nip07SignResult.success(Map<String, dynamic> event) {
    return Nip07SignResult(success: true, signedEvent: event);
  }
  
  factory Nip07SignResult.failure(String message, {String? code}) {
    return Nip07SignResult(
      success: false,
      errorMessage: message,
      errorCode: code,
    );
  }
}

/// Service for managing NIP-07 browser extension interactions
class Nip07Service extends ChangeNotifier {
  static final Nip07Service _instance = Nip07Service._internal();
  factory Nip07Service() => _instance;
  Nip07Service._internal();

  String? _currentPublicKey;
  bool _isConnected = false;
  Map<String, dynamic>? _userRelays;

  /// Check if NIP-07 extension is available
  bool get isAvailable {
    // Only available on web platform
    if (!kIsWeb) return false;
    return nip07.isNip07Available;
  }

  /// Check if user is currently connected via NIP-07
  bool get isConnected => _isConnected && _currentPublicKey != null;

  /// Get current user's public key
  String? get publicKey => _currentPublicKey;

  /// Get user's relay configuration (if available)
  Map<String, dynamic>? get userRelays => _userRelays;

  /// Detect available extension name for UI display
  String get extensionName {
    if (!isAvailable) return 'None';
    
    // Try to detect specific extensions based on available features
    try {
      final ext = nip07.nostr!;
      
      // Check for Alby-specific features
      if (ext.nip04 != null) {
        return 'Alby or compatible extension';
      }
      
      return 'Nostr extension';
    } catch (e) {
      return 'Unknown extension';
    }
  }

  /// Attempt to connect and authenticate with NIP-07 extension
  Future<Nip07AuthResult> connect() async {
    if (!isAvailable) {
      return Nip07AuthResult.failure(
        'No NIP-07 extension found. Please install Alby, nos2x, or another compatible extension.',
        code: 'EXTENSION_NOT_FOUND',
      );
    }

    try {
      debugPrint('🔐 Attempting NIP-07 authentication...');
      
      // Request public key from extension
      final pubkey = await nip07.safeNip07Call(
        () => nip07.nostr!.getPublicKey(),
        'get public key',
      );

      // Validate the public key format
      if (pubkey.isEmpty || pubkey.length != 64) {
        return Nip07AuthResult.failure(
          'Invalid public key received from extension',
          code: 'INVALID_PUBKEY',
        );
      }

      _currentPublicKey = pubkey;
      _isConnected = true;

      // Try to get user's relays (optional feature)
      try {
        final relaysMethod = nip07.nostr!.getRelays;
        if (relaysMethod != null) {
          _userRelays = await relaysMethod();
          debugPrint('📡 Retrieved ${_userRelays?.length ?? 0} relays from extension');
        }
      } catch (e) {
        debugPrint('⚠️ Extension does not support getRelays: $e');
        // Not a critical error, continue without relays
      }

      debugPrint('✅ NIP-07 authentication successful');
      debugPrint('👤 Public key: ${pubkey.substring(0, 16)}...');
      
      notifyListeners();
      return Nip07AuthResult.success(pubkey);

    } on nip07.Nip07Exception catch (e) {
      debugPrint('❌ NIP-07 authentication failed: ${e.message}');
      return Nip07AuthResult.failure(e.message, code: e.code);
    } catch (e) {
      debugPrint('❌ Unexpected NIP-07 error: $e');
      return Nip07AuthResult.failure(
        'Unexpected error during authentication: ${e.toString()}',
        code: 'UNEXPECTED_ERROR',
      );
    }
  }

  /// Sign a Nostr event using the browser extension
  Future<Nip07SignResult> signEvent(Map<String, dynamic> unsignedEvent) async {
    if (!isConnected) {
      return Nip07SignResult.failure(
        'Not connected to NIP-07 extension',
        code: 'NOT_CONNECTED',
      );
    }

    try {
      debugPrint('📝 Signing event with NIP-07 extension...');
      
      // Convert Dart event to JavaScript format
      final jsEvent = nip07.dartEventToJs(unsignedEvent);
      
      // Sign the event
      final signedJsEvent = await nip07.safeNip07Call(
        () => nip07.nostr!.signEvent(jsEvent),
        'sign event',
      );

      // Convert back to Dart format
      final signedEvent = nip07.jsEventToDart(signedJsEvent);

      // Validate the signed event
      if (signedEvent['sig'] == null || signedEvent['id'] == null) {
        return Nip07SignResult.failure(
          'Extension returned incomplete signed event',
          code: 'INCOMPLETE_SIGNATURE',
        );
      }

      debugPrint('✅ Event signed successfully');
      debugPrint('📋 Event ID: ${signedEvent['id']}');
      
      return Nip07SignResult.success(signedEvent);

    } on nip07.Nip07Exception catch (e) {
      debugPrint('❌ Event signing failed: ${e.message}');
      return Nip07SignResult.failure(e.message, code: e.code);
    } catch (e) {
      debugPrint('❌ Unexpected signing error: $e');
      return Nip07SignResult.failure(
        'Unexpected error during event signing: ${e.toString()}',
        code: 'UNEXPECTED_ERROR',
      );
    }
  }

  /// Encrypt a message using NIP-04 (if extension supports it)
  Future<String?> encryptMessage(String recipientPubkey, String message) async {
    if (!isConnected || nip07.nostr?.nip04 == null) {
      return null;
    }

    try {
      return await nip07.nostr!.nip04!.encrypt(recipientPubkey, message);
    } catch (e) {
      debugPrint('⚠️ NIP-04 encryption failed: $e');
      return null;
    }
  }

  /// Decrypt a message using NIP-04 (if extension supports it)
  Future<String?> decryptMessage(String senderPubkey, String encryptedMessage) async {
    if (!isConnected || nip07.nostr?.nip04 == null) {
      return null;
    }

    try {
      return await nip07.nostr!.nip04!.decrypt(senderPubkey, encryptedMessage);
    } catch (e) {
      debugPrint('⚠️ NIP-04 decryption failed: $e');
      return null;
    }
  }

  /// Disconnect from the extension
  void disconnect() {
    _currentPublicKey = null;
    _isConnected = false;
    _userRelays = null;
    
    debugPrint('🔓 Disconnected from NIP-07 extension');
    notifyListeners();
  }

  /// Get connection status for debugging
  Map<String, dynamic> getDebugInfo() {
    return {
      'isAvailable': isAvailable,
      'isConnected': isConnected,
      'publicKey': _currentPublicKey,
      'extensionName': extensionName,
      'hasRelays': _userRelays != null,
      'relayCount': _userRelays?.length ?? 0,
      'hasNip04': nip07.nostr?.nip04 != null,
    };
  }
}