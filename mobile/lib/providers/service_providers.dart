// ABOUTME: Riverpod providers for infrastructure services migrated off the
// ABOUTME: lazy-static singleton pattern to constructor injection (#4743).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/services/logging_config_service.dart';
import 'package:openvine/services/top_hashtags_service.dart';

/// Provides the app's [LoggingConfigService].
///
/// Replaces the former `LoggingConfigService.instance` singleton so the
/// service can be overridden with a fake in tests instead of reaching into
/// static state. Kept alive for the app's lifetime (logging config is global).
final loggingConfigServiceProvider = Provider<LoggingConfigService>(
  (ref) => LoggingConfigService(),
);

/// Provides the app's shared [TopHashtagsService].
///
/// Replaces the former `TopHashtagsService.instance` singleton. A single
/// shared instance is kept alive so the in-memory hashtag list loaded by one
/// consumer (e.g. the explore cubit warming the cache) is visible to the
/// others (the hashtag repository and the popular-videos tab).
final topHashtagsServiceProvider = Provider<TopHashtagsService>(
  (ref) => TopHashtagsService(),
);
