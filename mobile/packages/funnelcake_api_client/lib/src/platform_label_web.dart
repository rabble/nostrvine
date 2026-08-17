// ABOUTME: Platform label for the shared User-Agent on web builds.

/// Platform label sent by web builds of the app.
String get divinePlatformLabel => 'Web';

/// Platform token for the `X-Divine-Platform` header sent by web builds.
/// Browsers may strip the header under CORS; Funnelcake then falls back to
/// the browser's own User-Agent and keeps the default (non-iOS) treatment.
String get divinePlatformToken => 'web';
