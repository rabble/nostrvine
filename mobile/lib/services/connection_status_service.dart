// ABOUTME: Service for monitoring internet connectivity and relay connection status
// ABOUTME: Provides real-time connection status updates and retry mechanisms

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../utils/unified_logger.dart';

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
      Log.debug('� Initializing connection status service...', name: 'ConnectionStatusService', category: LogCategory.system);
      
      // Check initial connectivity
      await _checkConnectivity();
      
      // Listen for connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        _onConnectivityChanged,
        onError: _onConnectivityError,
      );
      
      // Start periodic internet access checks
      _startPeriodicChecks();
      
      Log.info('Connection status service initialized', name: 'ConnectionStatusService', category: LogCategory.system);
    } catch (e) {
      Log.error('Failed to initialize connection status service: $e', name: 'ConnectionStatusService', category: LogCategory.system);
      _lastError = e.toString();
    }
  }
  
  /// Handle connectivity changes
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    Log.debug('Connectivity changed: $results', name: 'ConnectionStatusService', category: LogCategory.system);
    _connectionTypes = results;
    
    final wasOnline = _isOnline;
    _isOnline = !results.contains(ConnectivityResult.none);
    
    if (_isOnline && !wasOnline) {
      Log.debug('� Connection restored', name: 'ConnectionStatusService', category: LogCategory.system);
      _checkInternetAccess(); // Verify actual internet access
    } else if (!_isOnline && wasOnline) {
      Log.debug('� Connection lost', name: 'ConnectionStatusService', category: LogCategory.system);
      _hasInternetAccess = false;
    }
    
    notifyListeners();
  }
  
  /// Handle connectivity stream errors
  void _onConnectivityError(dynamic error) {
    Log.error('Connectivity stream error: $error', name: 'ConnectionStatusService', category: LogCategory.system);
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
      
      Log.debug('� Initial connectivity: $_connectionTypes, online: $_isOnline, internet: $_hasInternetAccess', name: 'ConnectionStatusService', category: LogCategory.system);
    } catch (e) {
      Log.error('Error checking connectivity: $e', name: 'ConnectionStatusService', category: LogCategory.system);
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
      bool hasAccess = false;
      
      if (kIsWeb) {
        // Web platform: Use connectivity check assumption
        // On web, if connectivity_plus reports we're online, we assume internet access
        // since we can't use InternetAddress.lookup on web
        hasAccess = _isOnline;
        Log.debug('� Web platform: Using connectivity assumption for internet access', name: 'ConnectionStatusService', category: LogCategory.system);
      } else {
        // Native platform: Use DNS lookup to test actual internet access
        final hosts = [
          'relay.damus.io',
          'nos.lol', 
          'google.com',
          'cloudflare.com',
        ];
        
        for (final host in hosts) {
          try {
            final result = await InternetAddress.lookup(host)
                .timeout(const Duration(seconds: 3));
            
            if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
              hasAccess = true;
              break;
            }
          } catch (e) {
            Log.error('Failed to reach $host: $e', name: 'ConnectionStatusService', category: LogCategory.system);
          }
        }
      }
      
      final hadAccess = _hasInternetAccess;
      _hasInternetAccess = hasAccess;
      
      if (hasAccess && !hadAccess) {
        Log.debug('� Internet access restored', name: 'ConnectionStatusService', category: LogCategory.system);
      } else if (!hasAccess && hadAccess) {
        Log.warning('Internet access lost', name: 'ConnectionStatusService', category: LogCategory.system);
      }
      
      debugPrint('🌐 Internet access check: $hasAccess (platform: ${kIsWeb ? 'web' : 'native'})');
    } catch (e) {
      Log.error('Error checking internet access: $e', name: 'ConnectionStatusService', category: LogCategory.system);
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
    Log.debug('Force checking connection status...', name: 'ConnectionStatusService', category: LogCategory.system);
    await _checkConnectivity();
  }
  
  /// Wait for connection to be restored
  Future<bool> waitForConnection({Duration timeout = const Duration(seconds: 30)}) async {
    if (_isOnline && _hasInternetAccess) return true;
    
    Log.debug('⏳ Waiting for connection to be restored...', name: 'ConnectionStatusService', category: LogCategory.system);
    
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