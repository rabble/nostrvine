// ABOUTME: Resolves the watermark text shown on downloaded videos.
// ABOUTME: Prefers displayed NIP-05 identities and falls back to a simple @name.

import 'package:models/models.dart';

/// Returns the watermark text to render for a video's creator.
///
/// Prefers the creator's displayed NIP-05 so verified identities render
/// correctly, such as `@jackandjackofficial.divine.video`. If no NIP-05 is
/// available, falls back to a human-readable `@name`.
String resolveWatermarkText({
  UserProfile? profile,
  String? fallbackAuthorName,
}) {
  final displayNip05 = profile?.displayNip05?.trim();
  if (displayNip05 != null && displayNip05.isNotEmpty) {
    return displayNip05;
  }

  final fallbackName =
      profile?.displayName?.trim() ??
      profile?.name?.trim() ??
      fallbackAuthorName?.trim();

  if (fallbackName != null && fallbackName.isNotEmpty) {
    return fallbackName.startsWith('@') ? fallbackName : '@$fallbackName';
  }

  return '@Divine';
}
