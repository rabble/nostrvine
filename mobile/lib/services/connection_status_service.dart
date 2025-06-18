// ABOUTME: Service for monitoring internet connectivity and relay connection status
// ABOUTME: Provides real-time connection status updates and retry mechanisms

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Service for monitoring connection status and handling offline scenarios
class ConnectionStatusService extends ChangeNotifier {
  static final ConnectionStatusService _instance = ConnectionStatusService._internal();
  factory ConnectionStatusService() => _instance;
  ConnectionStatusService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  
  bool _isOnline = true;
  bool _hasInternetAccess = true;
  List<ConnectivityResult> _connectionTypes = [];
  String? _lastError;
  
  /// Connection status getters
  bool get isOnline => _isOnline;
  bool get hasInternetAccess => _hasInternetAccess;
  bool get isOffline => !_isOnline;
  List<ConnectivityResult> get connectionTypes => List.unmodifiable(_connectionTypes);
  String? get lastError => _lastError;
  
  /// Get human-readable connection status
  String get connectionStatus {
    if (!_isOnline) return 'Offline';
    if (!_hasInternetAccess) return 'No Internet Access';
    if (_connectionTypes.contains(ConnectivityResult.wifi)) return 'WiFi';
    if (_connectionTypes.contains(ConnectivityResult.mobile)) return 'Mobile Data';
    if (_connectionTypes.contains(ConnectivityResult.ethernet)) return 'Ethernet';
    return 'Connected';
  }
  
  /// Initialize connection monitoring
  Future<void> initialize() async {
    try {
      debugPrint('🌐 Initializing connection status service...');
      
      // Check initial connectivity
      await _checkConnectivity();
      
      // Listen for connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        _onConnectivityChanged,
        onError: _onConnectivityError,
      );
      
      // Start periodic internet access checks
      _startPeriodicChecks();
      
      debugPrint('✅ Connection status service initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize connection status service: $e');
      _lastError = e.toString();
    }
  }
  
  /// Handle connectivity changes
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    debugPrint('🔄 Connectivity changed: $results');
    _connectionTypes = results;
    
    final wasOnline = _isOnline;
    _isOnline = !results.contains(ConnectivityResult.none);
    
    if (_isOnline && !wasOnline) {
      debugPrint('🟢 Connection restored');
      _checkInternetAccess(); // Verify actual internet access
    } else if (!_isOnline && wasOnline) {
      debugPrint('🔴 Connection lost');
      _hasInternetAccess = false;
    }
    
    notifyListeners();
  }
  
  /// Handle connectivity stream errors
  void _onConnectivityError(dynamic error) {
    debugPrint('❌ Connectivity stream error: $error');
    _lastError = error.toString();
    notifyListeners();
  }
  
  /// Check current connectivity status
  Future<void> _checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _connectionTypes = results;
      _isOnline = !results.contains(ConnectivityResult.none);
      
      if (_isOnline) {
        await _checkInternetAccess();
      } else {
        _hasInternetAccess = false;
      }
      
      debugPrint('📶 Initial connectivity: $_connectionTypes, online: $_isOnline, internet: $_hasInternetAccess');
    } catch (e) {
      debugPrint('❌ Error checking connectivity: $e');
      _lastError = e.toString();
      _isOnline = false;
      _hasInternetAccess = false;
    }
  }
  
  /// Test actual internet access by checking reachable hosts
  Future<void> _checkInternetAccess() async {
    if (!_isOnline) {
      _hasInternetAccess = false;
      return;
    }
    
    try {
      // Test multiple hosts for reliability
      final hosts = [
        'relay.damus.io',
        'nos.lol', 
        'google.com',
        'cloudflare.com',
      ];
      
      bool hasAccess = false;
      
      for (final host in hosts) {
        try {
          final result = await InternetAddress.lookup(host)
              .timeout(const Duration(seconds: 3));
          
          if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
            hasAccess = true;
            break;
          }
        } catch (e) {
          debugPrint('⚠️ Failed to reach $host: $e');
        }
      }
      
      final hadAccess = _hasInternetAccess;
      _hasInternetAccess = hasAccess;
      
      if (hasAccess && !hadAccess) {
        debugPrint('🌐 Internet access restored');
      } else if (!hasAccess && hadAccess) {
        debugPrint('⚠️ Internet access lost');
      }
      
      debugPrint('🌐 Internet access check: $hasAccess');
    } catch (e) {
      debugPrint('❌ Error checking internet access: $e');
      _lastError = e.toString();
      _hasInternetAccess = false;
    }
    
    notifyListeners();
  }
  
  /// Start periodic connectivity checks
  void _startPeriodicChecks() {
    Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isOnline) {
        _checkInternetAccess();
      }
    });
  }
  
  /// Force a connection check
  Future<void> forceCheck() async {
    debugPrint('🔄 Force checking connection status...');
    await _checkConnectivity();
  }
  
  /// Wait for connection to be restored
  Future<bool> waitForConnection({Duration timeout = const Duration(seconds: 30)}) async {
    if (_isOnline && _hasInternetAccess) return true;
    
    debugPrint('⏳ Waiting for connection to be restored...');
    
    final completer = Completer<bool>();
    late StreamSubscription subscription;
    
    subscription = Stream.periodic(const Duration(seconds: 1))
        .take(timeout.inSeconds)
        .listen((_) async {
      await _checkConnectivity();
      if (_isOnline && _hasInternetAccess) {
        subscription.cancel();
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      }
    });
    
    // Set timeout
    Timer(timeout, () {
      subscription.cancel();
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    });
    
    return completer.future;
  }
  
  /// Get detailed connection info for debugging
  Map<String, dynamic> getConnectionInfo() {
    return {
      'isOnline': _isOnline,
      'hasInternetAccess': _hasInternetAccess,
      'connectionTypes': _connectionTypes.map((e) => e.name).toList(),
      'connectionStatus': connectionStatus,
      'lastError': _lastError,
    };
  }
  
  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}

/// Exception thrown when connection operations fail
class ConnectionException implements Exception {
  final String message;
  final String? details;
  
  const ConnectionException(this.message, [this.details]);
  
  @override
  String toString() => 'ConnectionException: $message${details != null ? ' ($details)' : ''}';
}