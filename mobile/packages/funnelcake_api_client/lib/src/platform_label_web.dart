// ABOUTME: Platform label for the shared User-Agent on web builds.

/// Platform label sent by web builds of the app.
String get divinePlatformLabel => 'Web';

/// Platform token for the `X-Divine-Platform` header; always null on web.
///
/// Do not "fix" this to return a token: web cannot send one. `User-Agent`
/// is a forbidden header the browser drops, and a custom header like
/// `X-Divine-Platform` is not on the CORS safelist, so adding it turns every
/// request into a preflight that backend CORS policy (funnelcake, relay
/// manager) currently rejects. Web builds therefore omit the header entirely
/// and Funnelcake's fallback classifies them by the browser's own real
/// User-Agent — no store-client literal matches, so browsers keep the
/// default (non-iOS) treatment.
String? get divinePlatformToken => null;
