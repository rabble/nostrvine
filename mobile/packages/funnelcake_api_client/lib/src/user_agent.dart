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
/// Cache note: `/api/videos` responses are edge-cached with
/// `Vary: Accept-Encoding, X-Pubkey, Authorization, X-Divine-Platform` —
/// User-Agent is NOT varied on. That is only safe while either every native
/// client sends the same platform signal via `X-Divine-Platform` (this
/// header) or no server behavior branches on the User-Agent. If a future
/// change makes the User-Agent alone decide per-platform responses, the Vary
/// list or cache key must gain `User-Agent` before that ships, or iOS and
/// Android clients will be served each other's cached objects.
String buildDivineUserAgent({String? appVersion, String? platform}) =>
    'Divine-Mobile/${appVersion ?? 'unknown'} (${platform ?? divinePlatformLabel})';

/// Builds the identity headers every Divine mobile HTTP client sends:
/// the shared [buildDivineUserAgent] User-Agent plus the machine-readable
/// `X-Divine-Platform` token Funnelcake prefers for platform branching
/// (divine-mobile#7744; `ios` applies, anything else skips — Funnelcake
/// compares case-insensitively).
Map<String, String> buildDivineClientHeaders({String? appVersion}) => {
  'User-Agent': buildDivineUserAgent(appVersion: appVersion),
  'X-Divine-Platform': divinePlatformToken,
};
