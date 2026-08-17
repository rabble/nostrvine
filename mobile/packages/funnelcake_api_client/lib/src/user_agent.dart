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
/// Cache note: `/api/videos` responses are edge-cached (`public, max-age=10`)
/// and, in funnelcake's committed code, vary on
/// `Accept-Encoding, X-Pubkey, Authorization`. The divine-mobile#7744
/// counterpart change in funnelcake adds `X-Divine-Platform` both to that
/// `Vary` list and to the server's platform branching; those two funnelcake
/// edits are one change and must land together, and before store binaries
/// ship this header. If the platform branch ever lands without the matching
/// `Vary`, the origin would serve per-platform responses while the edge
/// stores one shared object — iOS and Android clients would then be served
/// each other's cached videos.
String buildDivineUserAgent({String? appVersion, String? platform}) =>
    'Divine-Mobile/${appVersion ?? 'unknown'} (${platform ?? divinePlatformLabel})';

/// Sentinel for an unset `platformToken` argument of
/// `buildDivineClientHeaders`; distinct from an explicit `null`, which
/// forces the header off (the web behavior).
const Object _platformTokenUnset = Object();

/// Builds the identity headers every Divine mobile HTTP client sends:
/// the shared [buildDivineUserAgent] User-Agent plus, on io platforms, the
/// machine-readable `X-Divine-Platform` token Funnelcake prefers for
/// platform branching (divine-mobile#7744; `ios` applies, anything else
/// skips — Funnelcake compares case-insensitively).
///
/// Web builds send no `X-Divine-Platform`: it is not on the CORS safelist,
/// so it would fail preflight against current backend CORS policy (see
/// `divinePlatformToken` in the platform label implementations).
Map<String, String> buildDivineClientHeaders({
  String? appVersion,
  Object? platformToken = _platformTokenUnset,
}) {
  final headers = <String, String>{
    'User-Agent': buildDivineUserAgent(appVersion: appVersion),
  };
  final token = identical(platformToken, _platformTokenUnset)
      ? divinePlatformToken
      : platformToken as String?;
  if (token != null) {
    headers['X-Divine-Platform'] = token;
  }
  return headers;
}
