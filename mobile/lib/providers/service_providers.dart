// ABOUTME: Riverpod providers for infrastructure services migrated off the
// ABOUTME: lazy-static singleton pattern to constructor injection (#4743).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/services/logging_config_service.dart';

/// Provides the app's [LoggingConfigService].
///
/// Replaces the former `LoggingConfigService.instance` singleton so the
/// service can be overridden with a fake in tests instead of reaching into
/// static state. Kept alive for the app's lifetime (logging config is global).
final loggingConfigServiceProvider = Provider<LoggingConfigService>(
  (ref) => LoggingConfigService(),
);
