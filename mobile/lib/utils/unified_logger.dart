// ABOUTME: Unified logging utility that outputs to both Flutter console and browser DevTools
// ABOUTME: Provides structured logging with levels while maintaining single command simplicity

import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Log levels for filtering and categorization
enum LogLevel {
  verbose(500),
  debug(700),
  info(800),
  warning(900),
  error(1000);
  
  final int value;
  const LogLevel(this.value);
  
  static LogLevel fromString(String level) {
    switch (level.toLowerCase()) {
      case 'verbose':
        return LogLevel.verbose;
      case 'debug':
        return LogLevel.debug;
      case 'info':
        return LogLevel.info;
      case 'warning':
      case 'warn':
        return LogLevel.warning;
      case 'error':
        return LogLevel.error;
      default:
        return LogLevel.info;
    }
  }
}

/// Unified logger that outputs to both Flutter tool console and browser DevTools
/// 
/// This logger combines the best of both worlds:
/// - debugPrint: Shows in Flutter tool console (terminal)
/// - developer.log: Shows in browser DevTools with structured logging
/// 
/// Configure log level via:
/// - Code: UnifiedLogger.setLogLevel(LogLevel.info)
/// - Environment: LOG_LEVEL=info (or verbose, debug, warning, error)
/// - Default: debug in debug mode, info in release mode
class UnifiedLogger {
  /// Current log level - only messages at or above this level will be logged
  static LogLevel _currentLevel = _getDefaultLogLevel();
  
  /// Get default log level from environment or mode
  static LogLevel _getDefaultLogLevel() {
    // Check environment variable first
    const envLevel = String.fromEnvironment('LOG_LEVEL');
    if (envLevel.isNotEmpty) {
      return LogLevel.fromString(envLevel);
    }
    // Default based on build mode
    return kDebugMode ? LogLevel.debug : LogLevel.info;
  }
  
  /// Set the minimum log level
  static void setLogLevel(LogLevel level) {
    _currentLevel = level;
    if (kDebugMode) {
      debugPrint('🔧 Log level set to: ${level.name}');
    }
  }
  
  /// Get the current log level
  static LogLevel get currentLevel => _currentLevel;
  
  /// Check if a specific level is enabled
  static bool isLevelEnabled(LogLevel level) => level.value >= _currentLevel.value;

  /// Internal logging method that outputs to both destinations
  static void _log(
    String message, {
    String? name,
    required LogLevel level,
    Object? error,
    StackTrace? stackTrace,
  }) {
    // Check if this level should be logged
    if (!isLevelEnabled(level)) {
      return;
    }
    
    // Create timestamp
    final now = DateTime.now();
    final timestamp = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.millisecond.toString().padLeft(3, '0')}';
    
    // Format message with timestamp
    final timestampedMessage = '[$timestamp] $message';
    
    // Always output to Flutter tool console via debugPrint
    debugPrint(timestampedMessage);
    
    // Also output to browser DevTools via developer.log (web only)
    if (kIsWeb) {
      developer.log(
        timestampedMessage,
        name: name ?? 'OpenVines',
        level: level.value,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Verbose logging - detailed debug information
  static void verbose(String message, {String? name}) {
    _log(message, name: name, level: LogLevel.verbose);
  }

  /// Debug logging - development debugging
  static void debug(String message, {String? name}) {
    _log(message, name: name, level: LogLevel.debug);
  }

  /// Info logging - general information
  static void info(String message, {String? name}) {
    _log(message, name: name, level: LogLevel.info);
  }

  /// Warning logging - potential issues
  static void warning(String message, {String? name}) {
    _log(message, name: name, level: LogLevel.warning);
  }

  /// Error logging - actual errors with optional error object
  static void error(String message, {String? name, Object? error, StackTrace? stackTrace}) {
    _log(message, name: name, level: LogLevel.error, error: error, stackTrace: stackTrace);
  }

  /// Convenience method that matches developer.log signature  
  static void log(
    String message, {
    String? name,
    LogLevel level = LogLevel.info,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(message, name: name, level: level, error: error, stackTrace: stackTrace);
  }
  
  /// Migration helper - replaces debugPrint calls
  /// In debug mode: logs at debug level
  /// In release mode: logs at info level
  static void print(String message, {String? name}) {
    _log(message, name: name, level: kDebugMode ? LogLevel.debug : LogLevel.info);
  }
}

/// Convenience alias for shorter syntax
typedef Log = UnifiedLogger;