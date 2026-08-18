// ABOUTME: Platform label for the shared User-Agent on io platforms.

import 'dart:io';

/// Human-facing OS label for the shared Divine User-Agent on io platforms.
String get divinePlatformLabel => switch (Platform.operatingSystem) {
  'ios' => 'iOS',
  'android' => 'Android',
  'macos' => 'macOS',
  'windows' => 'Windows',
  'linux' => 'Linux',
  _ => Platform.operatingSystem,
};

/// Machine platform token for the `X-Divine-Platform` header on io platforms.
/// `dart:io` already reports lowercase tokens (`ios`, `android`, …), which is
/// the casing Funnelcake compares against (case-insensitively).
String? get divinePlatformToken => Platform.operatingSystem;
