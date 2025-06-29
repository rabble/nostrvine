// ABOUTME: Unified web authentication service supporting NIP-07 and nsec bunker
// ABOUTME: Provides seamless authentication for web users with multiple Nostr login methods

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'nip07_service.dart';
import '../utils/unified_logger.dart';
// import 'nsec_bunker_service.dart'; // Temporarily disabled due to nostr library compatibility

/// Available authentication methods for web
enum WebAuthMethod {
  nip07,      // Browser extension
  bunker,     // nsec bunker
  none,       // No authentication
}

/// Web authentication result
class WebAuthResult {
  final bool success;
  final WebAuthMethod? method;
  final String? publicKey;
  final String? errorMessage;
  final String? errorCode;
  
  const WebAuthResult({
    required this.success,
    this.method,
    this.publicKey,
    this.errorMessage,
    this.errorCode,
  });
  
  factory WebAuthResult.success(WebAuthMethod method, String publicKey) {
    return WebAuthResult(
      success: true,
      method: method,
      publicKey: publicKey,
    );
  }
  
  factory WebAuthResult.failure(String message, {String? code}) {
    return WebAuthResult(
      success: false,
      errorMessage: message,
      errorCode: code,
    );
  }
}

/// Event signing interface for web authentication
abstract class WebSigner {
  Future<Map<String, dynamic>?> signEvent(Map<String, dynamic> event);
  void dispose();
}

/// NIP-07 signer implementation
class Nip07Signer implements WebSigner {
  final Nip07Service _service;
  
  Nip07Signer(this._service);
  
  @override
  Future<Map<String, dynamic>?> signEvent(Map<String, dynamic> event) async {
    final result = await _service.signEvent(event);
    return result.success ? result.signedEvent : null;
  }
  
  @override
  void dispose() {
    _service.disconnect();
  }
}

/// Bunker signer implementation (temporarily disabled)
class BunkerSigner implements WebSigner {
  BunkerSigner(dynamic service);
  
  @override
  Future<Map<String, dynamic>?> signEvent(Map<String, dynamic> event) async {
    // Temporarily return null - bunker not implemented yet
    Log.warning('Bunker signing temporarily unavailable', name: 'WebAuthService', category: LogCategory.system);
    return null;
  }
  
  @override
  void dispose() {
    // No-op for now
  }
}

/// Unified web authentication service
class WebAuthService extends ChangeNotifier {
  static final WebAuthService _instance = WebAuthService._internal();
  factory WebAuthService() => _instance;
  WebAuthService._internal();

  // Service instances
  final Nip07Service _nip07Service = Nip07Service();
  // final NsecBunkerService _bunkerService = NsecBunkerService(); // Temporarily disabled

  // Current authentication state
  WebAuthMethod _currentMethod = WebAuthMethod.none;
  String? _currentPublicKey;
  WebSigner? _currentSigner;
  bool _isAuthenticated = false;

  /// Check if user is authenticated
  bool get isAuthenticated => _isAuthenticated && _currentPublicKey != null;

  /// Get current authentication method
  WebAuthMethod get currentMethod => _currentMethod;

  /// Get current user's public key
  String? get publicKey => _currentPublicKey;

  /// Get current signer for event signing
  WebSigner? get signer => _currentSigner;

  /// Check if NIP-07 is available
  bool get isNip07Available => _nip07Service.isAvailable;

  /// Get available authentication methods
  List<WebAuthMethod> get availableMethods {
    final methods = <WebAuthMethod>[];
    
    if (_nip07Service.isAvailable) {
      methods.add(WebAuthMethod.nip07);
    }
    
    // Bunker temporarily disabled
    // if (kIsWeb) {
    //   methods.add(WebAuthMethod.bunker);
    // }
    
    return methods;
  }

  /// Get user-friendly method names
  String getMethodDisplayName(WebAuthMethod method) {
    switch (method) {
      case WebAuthMethod.nip07:
        return _nip07Service.extensionName;
      case WebAuthMethod.bunker:
        return 'nsec bunker';
      case WebAuthMethod.none:
        return 'None';
    }
  }

  /// Authenticate using NIP-07 browser extension
  Future<WebAuthResult> authenticateWithNip07() async {
    if (!_nip07Service.isAvailable) {
      return WebAuthResult.failure(
        'No NIP-07 extension found',
        code: 'EXTENSION_NOT_FOUND',
      );
    }

    try {
      Log.debug('� Starting NIP-07 authentication...', name: 'WebAuthService', category: LogCategory.system);
      
      final result = await _nip07Service.connect();
      if (!result.success) {
        return WebAuthResult.failure(
          result.errorMessage ?? 'NIP-07 authentication failed',
          code: result.errorCode,
        );
      }

      // Set up authentication state
      _currentMethod = WebAuthMethod.nip07;
      _currentPublicKey = result.publicKey;
      _currentSigner = Nip07Signer(_nip07Service);
      _isAuthenticated = true;

      Log.info('NIP-07 authentication successful', name: 'WebAuthService', category: LogCategory.system);
      notifyListeners();
      
      return WebAuthResult.success(WebAuthMethod.nip07, result.publicKey!);
    } catch (e) {
      Log.error('NIP-07 authentication error: $e', name: 'WebAuthService', category: LogCategory.system);
      return WebAuthResult.failure(
        'Unexpected NIP-07 error: ${e.toString()}',
        code: 'UNEXPECTED_ERROR',
      );
    }
  }

  /// Authenticate using nsec bunker (temporarily disabled)
  Future<WebAuthResult> authenticateWithBunker(String bunkerUri) async {
    Log.warning('Bunker authentication temporarily unavailable', name: 'WebAuthService', category: LogCategory.system);
    return WebAuthResult.failure(
      'Bunker authentication is temporarily unavailable',
      code: 'TEMPORARILY_UNAVAILABLE',
    );
  }

  /// Sign an event using the current authentication method
  Future<Map<String, dynamic>?> signEvent(Map<String, dynamic> event) async {
    if (!isAuthenticated || _currentSigner == null) {
      Log.error('Cannot sign event: not authenticated', name: 'WebAuthService', category: LogCategory.system);
      return null;
    }

    try {
      return await _currentSigner!.signEvent(event);
    } catch (e) {
      Log.error('Event signing failed: $e', name: 'WebAuthService', category: LogCategory.system);
      return null;
    }
  }

  /// Disconnect and clear authentication
  Future<void> disconnect() async {
    Log.debug('� Disconnecting web authentication...', name: 'WebAuthService', category: LogCategory.system);
    
    _currentSigner?.dispose();
    _currentSigner = null;
    _currentPublicKey = null;
    _currentMethod = WebAuthMethod.none;
    _isAuthenticated = false;

    // Disconnect services
    _nip07Service.disconnect();
    // await _bunkerService.disconnect(); // Temporarily disabled

    notifyListeners();
    Log.info('Web authentication disconnected', name: 'WebAuthService', category: LogCategory.system);
  }

  /// Check for existing session on startup
  Future<void> checkExistingSession() async {
    // For NIP-07, we can try to connect silently if extension remembers the permission
    if (_nip07Service.isAvailable) {
      try {
        // Some extensions remember permissions, so we can try a quick connect
        final result = await _nip07Service.connect();
        if (result.success) {
          _currentMethod = WebAuthMethod.nip07;
          _currentPublicKey = result.publicKey;
          _currentSigner = Nip07Signer(_nip07Service);
          _isAuthenticated = true;
          
          Log.info('Restored NIP-07 session', name: 'WebAuthService', category: LogCategory.system);
          notifyListeners();
          return;
        }
      } catch (e) {
        // Silent failure, user will need to authenticate manually
        Log.info('No existing NIP-07 session found', name: 'WebAuthService', category: LogCategory.system);
      }
    }

    // For bunker, we would need to store the URI securely and reconnect
    // This is more complex and should be implemented based on security requirements
    Log.info('No existing web session found', name: 'WebAuthService', category: LogCategory.system);
  }

  /// Get debug information
  Map<String, dynamic> getDebugInfo() {
    return {
      'isAuthenticated': isAuthenticated,
      'currentMethod': _currentMethod.name,
      'publicKey': _currentPublicKey,
      'isNip07Available': isNip07Available,
      'availableMethods': availableMethods.map((m) => m.name).toList(),
      'nip07Info': _nip07Service.getDebugInfo(),
      'bunkerInfo': {'status': 'temporarily_disabled'},
    };
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}