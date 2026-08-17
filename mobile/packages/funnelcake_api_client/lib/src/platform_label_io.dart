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
