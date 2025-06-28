// ABOUTME: Script to help migrate debugPrint calls to UnifiedLogger with appropriate levels
// ABOUTME: Run this to see migration suggestions for updating logging statements

import 'dart:io';

void main() {
  print('Logging Migration Helper\n');
  print('This script analyzes debugPrint patterns and suggests appropriate log levels.\n');
  
  // Common patterns and their suggested log levels
  final patterns = {
    // Error patterns
    RegExp(r'❌|Error|Failed|Exception|Crash', caseSensitive: false): 'Log.error',
    
    // Warning patterns  
    RegExp(r'⚠️|Warning|Warn|Deprecated|Retry', caseSensitive: false): 'Log.warning',
    
    // Info patterns (important state changes)
    RegExp(r'✅|Success|Completed|Connected|Initialized|Started|Stopped', caseSensitive: false): 'Log.info',
    
    // Debug patterns (detailed operational info)
    RegExp(r'🔍|🔄|📡|Creating|Loading|Processing|Handling', caseSensitive: false): 'Log.debug',
    
    // Verbose patterns (very detailed tracing)
    RegExp(r'- Authors:|- Hashtags:|- Since:|- Until:|- Limit:|Detailed|Trace', caseSensitive: false): 'Log.verbose',
  };
  
  print('Pattern Analysis:\n');
  print('ERROR level for: Errors, failures, exceptions');
  print('WARNING level for: Warnings, retries, connection issues');
  print('INFO level for: Important state changes, completions');
  print('DEBUG level for: Operational details, processing steps');
  print('VERBOSE level for: Detailed parameters, trace information\n');
  
  print('Migration steps:');
  print('1. Add import: import \'../utils/unified_logger.dart\';');
  print('2. Replace debugPrint based on content:');
  print('   - debugPrint(\'❌ Error...\') → Log.error(\'Error...\', name: \'ServiceName\')');
  print('   - debugPrint(\'⚠️ Warning...\') → Log.warning(\'Warning...\', name: \'ServiceName\')');
  print('   - debugPrint(\'✅ Success...\') → Log.info(\'Success...\', name: \'ServiceName\')');
  print('   - debugPrint(\'🔍 Loading...\') → Log.debug(\'Loading...\', name: \'ServiceName\')');
  print('   - debugPrint(\'  - Details...\') → Log.verbose(\'Details...\', name: \'ServiceName\')');
  print('\n3. For simple migrations without changing level:');
  print('   - debugPrint(message) → Log.print(message)');
  print('\n4. Configure log level at app startup:');
  print('   - Development: UnifiedLogger.setLogLevel(LogLevel.debug)');
  print('   - Production: UnifiedLogger.setLogLevel(LogLevel.info)');
  print('   - Debugging issues: UnifiedLogger.setLogLevel(LogLevel.verbose)');
}