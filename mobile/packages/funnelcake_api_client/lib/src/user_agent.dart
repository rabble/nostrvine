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
/// Cache note: the corresponding server behavior is implemented by
/// funnelcake#1047. `/api/videos` responses are edge-cached
/// (`public, max-age=10`) and vary on `Accept-Encoding, X-Pubkey,
/// Authorization, X-Divine-Platform`; default and `sort=recent` responses also
/// vary on `User-Agent` there, so a legacy `OpenVine-Mobile/1.0` binary can never
/// share a cached object with a browser or a platform-tokened client. The
/// funnelcake branch and its `Vary` edits are one change and must land
/// together, and before store binaries ship this header — otherwise the
/// origin would serve per-platform responses while the edge stores one
/// shared object, and iOS and Android clients would be served each other's
/// cached videos.
String buildDivineUserAgent({String? appVersion, String? platform}) {
  final trimmedVersion = appVersion?.trim();
  final effectiveVersion = trimmedVersion == null || trimmedVersion.isEmpty
      ? 'unknown'
      : trimmedVersion;
  return 'Divine-Mobile/$effectiveVersion (${platform ?? divinePlatformLabel})';
}

/// Builds the identity headers every Divine mobile HTTP client sends:
/// the shared [buildDivineUserAgent] User-Agent plus, on io platforms, the
/// machine-readable `X-Divine-Platform` token Funnelcake prefers for
/// platform branching (divine-mobile#7744; `ios` applies, anything else
/// skips — Funnelcake compares case-insensitively).
///
/// Web builds send no `X-Divine-Platform`: it is not on the CORS safelist,
/// so it would fail preflight against current backend CORS policy (see
/// `divinePlatformToken` in the platform label implementations).
Map<String, String> buildDivineClientHeaders({String? appVersion}) {
  final headers = <String, String>{
    'User-Agent': buildDivineUserAgent(appVersion: appVersion),
  };
  final token = divinePlatformToken;
  if (token != null) {
    headers['X-Divine-Platform'] = token;
  }
  return headers;
}
