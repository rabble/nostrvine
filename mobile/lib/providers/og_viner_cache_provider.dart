// ABOUTME: Riverpod provider for the local OG Viner positive cache.
// ABOUTME: Keeps badge reads local-only and avoids per-user server lookups.

import 'package:flutter_riverpod/legacy.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/og_viner_cache_service.dart';
import 'package:riverpod/misc.dart';

final ogVinerCacheServiceProvider = ChangeNotifierProvider<OgVinerCacheService>(
  (ref) {
    try {
      final prefs = ref.watch(sharedPreferencesProvider);
      return OgVinerCacheService(prefs: prefs);
    } on ProviderException catch (e) {
      if (e.exception is UnimplementedError) {
        return OgVinerCacheService();
      }
      rethrow;
    }
  },
);
