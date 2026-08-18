// ABOUTME: Shared User-Agent builder for Divine mobile HTTP clients.
// ABOUTME: Carries version and platform on Funnelcake and ApiService requests.

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
/// Cache note: funnelcake#1047 varies only plain-recent `/api/videos`
/// responses on the bounded, edge-computed `X-Divine-News-Hack-Client` class.
/// Raw `User-Agent` and `X-Divine-Platform` are deliberately not `Vary` values.
/// Before that origin behavior deploys, divine-router must overwrite the class
/// from these client signals before cache lookup. Shipping these headers first
/// is inert; deploying the origin branch before the router classifier is live
/// could let differently classified clients share one cached response.
String buildDivineUserAgent({String? appVersion, String? platform}) {
  final trimmedVersion = appVersion?.trim();
  final effectiveVersion = trimmedVersion == null || trimmedVersion.isEmpty
      ? 'unknown'
      : trimmedVersion;
  return 'Divine-Mobile/$effectiveVersion (${platform ?? divinePlatformLabel})';
}

/// Builds the identity headers used by `FunnelcakeApiClient` and `ApiService`:
/// the shared [buildDivineUserAgent] User-Agent plus, on io platforms, the
/// machine-readable `X-Divine-Platform` token used by the paired rollout
/// (divine-mobile#7744; `ios` applies, anything else skips).
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
