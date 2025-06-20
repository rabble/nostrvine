// ABOUTME: Unified logging utility that outputs to both Flutter console and browser DevTools
// ABOUTME: Provides structured logging with levels while maintaining single command simplicity

import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Unified logger that outputs to both Flutter tool console and browser DevTools
/// 
/// This logger combines the best of both worlds:
/// - debugPrint: Shows in Flutter tool console (terminal)
/// - developer.log: Shows in browser DevTools with structured logging
class UnifiedLogger {
  /// Log levels for filtering and categorization
  static const int _levelVerbose = 500;
  static const int _levelDebug = 700;
  static const int _levelInfo = 800;
  static const int _levelWarning = 900;
  static const int _levelError = 1000;

  /// Internal logging method that outputs to both destinations
  static void _log(
    String message, {
    String? name,
    int level = _levelInfo,
    Object? error,
    StackTrace? stackTrace,
  }) {
    // Always output to Flutter tool console via debugPrint
    debugPrint(message);
    
    // Also output to browser DevTools via developer.log (web only)
    if (kIsWeb) {
      developer.log(
        message,
        name: name ?? 'NostrVine',
        level: level,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Verbose logging - detailed debug information
  static void verbose(String message, {String? name}) {
    _log(message, name: name, level: _levelVerbose);
  }

  /// Debug logging - development debugging
  static void debug(String message, {String? name}) {
    _log(message, name: name, level: _levelDebug);
  }

  /// Info logging - general information
  static void info(String message, {String? name}) {
    _log(message, name: name, level: _levelInfo);
  }

  /// Warning logging - potential issues
  static void warning(String message, {String? name}) {
    _log(message, name: name, level: _levelWarning);
  }

  /// Error logging - actual errors with optional error object
  static void error(String message, {String? name, Object? error, StackTrace? stackTrace}) {
    _log(message, name: name, level: _levelError, error: error, stackTrace: stackTrace);
  }

  /// Convenience method that matches developer.log signature
  static void log(
    String message, {
    String? name,
    int level = _levelInfo,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(message, name: name, level: level, error: error, stackTrace: stackTrace);
  }
}

/// Convenience alias for shorter syntax
typedef Log = UnifiedLogger;