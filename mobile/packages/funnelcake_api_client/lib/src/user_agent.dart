// ABOUTME: Shared User-Agent builder for Divine mobile HTTP clients.
// ABOUTME: Carries app version and platform on every backend request.

import 'package:funnelcake_api_client/src/platform_label_stub.dart'
    if (dart.library.io) 'package:funnelcake_api_client/src/platform_label_io.dart'
    if (dart.library.js_interop) 'package:funnelcake_api_client/src/platform_label_web.dart';

/// Builds the Divine mobile User-Agent string, for example
/// `Divine-Mobile/1.0.20 (iOS)`.
///
/// Used by `FunnelcakeApiClient` and `ApiService` so the header cannot drift
/// between call sites. Funnelcake logs `user_agent.original` and branches on
/// it, so the string must change with the shipped version and name the OS.
///
/// Cache note: once the User-Agent stops being a single identical value, the
/// Fastly cache policy for `/api/videos` must include User-Agent in `Vary` or
/// the cache key, or iOS and Android clients will share one cached object.
String buildDivineUserAgent({String? appVersion, String? platform}) =>
    'Divine-Mobile/${appVersion ?? 'unknown'} (${platform ?? divinePlatformLabel})';
