// ABOUTME: Web platform cache config using default HTTP client
// ABOUTME: Avoids dart:io which is unavailable on web

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Creates a [Config] for web using default file service (no dart:io).
Config createCacheConfig(String key) {
  return Config(
    key,
    stalePeriod: const Duration(days: 7),
    maxNrOfCacheObjects: 200,
  );
}
