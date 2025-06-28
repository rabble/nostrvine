# OpenVine Logging System

## Overview

OpenVine uses a unified logging system with configurable log levels to control verbosity and reduce log spam in production environments.

## Log Levels

The following log levels are available (from most to least verbose):

1. **VERBOSE** - Very detailed trace information, including parameters and internal state
2. **DEBUG** - Detailed debugging information useful during development
3. **INFO** - Important state changes and high-level operations
4. **WARNING** - Warnings about potential issues or deprecated features
5. **ERROR** - Errors and exceptions that need attention

## Mobile App (Flutter)

### Basic Usage

```dart
import 'package:openvine/utils/unified_logger.dart';

// Use the Log alias for brevity
Log.verbose('Detailed trace info', name: 'ServiceName');
Log.debug('Debug information', name: 'ServiceName');
Log.info('Important state change', name: 'ServiceName');
Log.warning('Potential issue', name: 'ServiceName');
Log.error('Error occurred', name: 'ServiceName', error: exception);
```

### Configuration

#### Set log level in code:
```dart
// At app startup
UnifiedLogger.setLogLevel(LogLevel.info); // Only INFO and above will be logged
```

#### Set via environment variable:
```bash
flutter run --dart-define=LOG_LEVEL=debug
```

#### Default behavior:
- Debug builds: `LogLevel.debug`
- Release builds: `LogLevel.info`

### Migration from debugPrint

Replace `debugPrint` statements based on their content:

```dart
// Before
debugPrint('❌ Error loading data: $error');
debugPrint('⚠️ Connection unstable');
debugPrint('✅ Profile loaded successfully');
debugPrint('🔍 Searching for videos...');
debugPrint('  - Filter: $filter');

// After
Log.error('Error loading data', name: 'DataLoader', error: error);
Log.warning('Connection unstable', name: 'Network');
Log.info('Profile loaded successfully', name: 'Profile');
Log.debug('Searching for videos...', name: 'Search');
Log.verbose('Filter: $filter', name: 'Search');
```

## Backend (Cloudflare Workers)

### Basic Usage

```typescript
import logger from './utils/logger';

// Log at different levels
logger.verbose('Detailed trace info', { data: 'value' });
logger.debug('Debug information');
logger.info('Important operation completed');
logger.warn('Potential issue detected');
logger.error('Error occurred', error);

// Create child logger for specific module
const uploadLogger = logger.child('Upload');
uploadLogger.info('File uploaded', { fileId: '123' });
```

### Configuration

Set log level via environment variable in `wrangler.toml`:

```toml
[vars]
LOG_LEVEL = "INFO"  # VERBOSE, DEBUG, INFO, WARN, ERROR
```

## Analytics Worker

Same as backend, but with 'Analytics' prefix by default:

```typescript
import logger from './utils/logger';

logger.info('Trending calculation started');
logger.debug('Processing view event', { videoId, timestamp });
```

## Best Practices

1. **Use appropriate log levels:**
   - VERBOSE: Loop iterations, detailed parameters, trace info
   - DEBUG: Function entry/exit, state changes, processing steps
   - INFO: Successful operations, important milestones
   - WARNING: Recoverable errors, deprecations, retries
   - ERROR: Exceptions, failures, unrecoverable errors

2. **Always include context:**
   ```dart
   // Good
   Log.error('Failed to upload video', name: 'Upload', error: e);
   
   // Less helpful
   Log.error('Upload failed');
   ```

3. **Avoid logging sensitive data:**
   - Never log private keys, passwords, or auth tokens
   - Be careful with user data in logs

4. **Production configuration:**
   - Set log level to INFO or WARNING in production
   - Use VERBOSE/DEBUG only when debugging specific issues

5. **Performance considerations:**
   - Verbose logging is automatically skipped when disabled
   - No need to wrap in `if (kDebugMode)` checks

## Debugging Production Issues

To temporarily enable verbose logging in production:

```dart
// Mobile app - add a debug menu option
LoggingConfigService.instance.enableVerboseLogging();

// Backend - update environment variable
LOG_LEVEL=VERBOSE
```

Remember to disable verbose logging after debugging to avoid performance impact and log spam.