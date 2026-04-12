// ABOUTME: Script to help migrate debugPrint calls to UnifiedLogger with appropriate levels
// ABOUTME: Run this to see migration suggestions for updating logging statements

import 'package:unified_logger/unified_logger.dart';

void main() {
  Log.info(
    'Logging Migration Helper',
    name: 'MigrateLogging',
    category: LogCategory.system,
  );
  Log.info(
    'This script analyzes debugPrint patterns and suggests appropriate log levels.',
    name: 'MigrateLogging',
    category: LogCategory.system,
  );

  // Common patterns and their suggested log levels (for reference)
  // Error patterns: ❌|Error|Failed|Exception|Crash → Log.error
  // Warning patterns: ⚠️|Warning|Warn|Deprecated|Retry → Log.warning
  // Info patterns: ✅|Success|Completed|Connected|Initialized|Started|Stopped → Log.info
  // Debug patterns: 🔍|🔄|📡|Creating|Loading|Processing|Handling → Log.debug
  // Verbose patterns: - Authors:|- Hashtags:|- Since:|- Until:|- Limit:|Detailed|Trace → Log.verbose

  Log.info(
    'Pattern Analysis:',
    name: 'MigrateLogging',
    category: LogCategory.system,
  );
  Log.info(
    'ERROR level for: Errors, failures, exceptions',
    name: 'MigrateLogging',
    category: LogCategory.system,
  );
  Log.info(
    'WARNING level for: Warnings, retries, connection issues',
    name: 'MigrateLogging',
    category: LogCategory.system,
  );
  Log.info(
    'INFO level for: Important state changes, completions',
    name: 'MigrateLogging',
    category: LogCategory.system,
  );
  Log.info(
    'DEBUG level for: Operational details, processing steps',
    name: 'MigrateLogging',
    category: LogCategory.system,
  );
  Log.info(
    'VERBOSE level for: Detailed parameters, trace information',
    name: 'MigrateLogging',
    category: LogCategory.system,
  );

  Log.info(
    'Migration steps:',
    name: 'MigrateLogging',
    category: LogCategory.system,
  );
  Log.info(
    "1. Add import: import '../utils/unified_logger.dart';",
    name: 'MigrateLogging',
    category: LogCategory.system,
  );
  Log.info(
    '2. Replace debugPrint based on content:',
    name: 'MigrateLogging',
    category: LogCategory.system,
  );
  Log.info(
    "   - debugPrint('❌ Error...') → Log.error('Error...', name: 'ServiceName')",
    name: 'MigrateLogging',
    category: LogCategory.system,
  );
  Log.info(
    "   - debugPrint('⚠️ Warning...') → Log.warning('Warning...', name: 'ServiceName')",
    name: 'MigrateLogging',
    category: LogCategory.system,
  );
  Log.info(
    "   - debugPrint('✅ Success...') → Log.info('Success...', name: 'ServiceName')",
    name: 'MigrateLogging',
    category: LogCategory.system,
  );
  Log.info(
    "   - debugPrint('🔍 Loading...') → Log.debug('Loading...', name: 'ServiceName')",
    name: 'MigrateLogging',
    category: LogCategory.system,
  );
  Log.info(
    "   - debugPrint('  - Details...') → Log.verbose('Details...', name: 'ServiceName')",
    name: 'MigrateLogging',
    category: LogCategory.system,
  );
  Log.info('', name: 'MigrateLogging', category: LogCategory.system);
  Log.info(
    '3. For simple migrations without changing level:',
    name: 'MigrateLogging',
    category: LogCategory.system,
  );
  Log.info(
    '   - debugPrint(message) → Log.print(message)',
    name: 'MigrateLogging',
    category: LogCategory.system,
  );
  Log.info('', name: 'MigrateLogging', category: LogCategory.system);
  Log.info(
    '4. Configure log level at app startup:',
    name: 'MigrateLogging',
    category: LogCategory.system,
  );
  Log.info(
    '   - Development: UnifiedLogger.setLogLevel(LogLevel.debug)',
    name: 'MigrateLogging',
    category: LogCategory.system,
  );
  Log.info(
    '   - Production: UnifiedLogger.setLogLevel(LogLevel.info)',
    name: 'MigrateLogging',
    category: LogCategory.system,
  );
  Log.info(
    '   - Debugging issues: UnifiedLogger.setLogLevel(LogLevel.verbose)',
    name: 'MigrateLogging',
    category: LogCategory.system,
  );
}
