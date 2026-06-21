import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' show UserProfile;
import 'package:openvine/providers/user_profile_providers.dart';

/// Shared helpers for linkified-text renderers.
final class LinkifiedTextSupport {
  const LinkifiedTextSupport._();

  /// Resolves the display label used for profile references.
  static String profileDisplayText(WidgetRef ref, String hexPubkey) {
    final profile = ref.watch(userProfileReactiveProvider(hexPubkey)).value;
    final profileText = switch (profile) {
      UserProfile(:final displayName?) when displayName.isNotEmpty =>
        displayName,
      UserProfile(:final name?) when name.isNotEmpty => name,
      UserProfile(:final shortDisplayNip05?)
          when shortDisplayNip05.isNotEmpty =>
        shortDisplayNip05,
      _ => UserProfile.defaultDisplayNameFor(hexPubkey),
    };
    return profileText.startsWith('@') ? profileText : '@$profileText';
  }

  /// Matches a plain typed mention against known mentioned profile pubkeys.
  ///
  /// Nostr `p` tags identify mentioned users but do not carry the visible
  /// username. The renderer can still resolve common cases once profiles are
  /// cached by comparing the typed token with the profile's known names.
  static String? profilePubkeyForMention(
    WidgetRef ref,
    String username,
    Iterable<String> profilePubkeys,
  ) {
    final normalizedUsername = _normalizeMentionValue(username);
    if (normalizedUsername.isEmpty) return null;

    for (final pubkey in profilePubkeys) {
      final profile = ref.watch(userProfileReactiveProvider(pubkey)).value;
      if (profile == null) continue;

      final values = <String?>[
        profile.name,
        profile.displayName,
        profile.divineUsername,
        profile.shortDisplayNip05,
        profile.displayNip05,
        profile.nip05,
        pubkey,
      ];

      final matches = values
          .whereType<String>()
          .map(_normalizeMentionValue)
          .any((value) => value == normalizedUsername);
      if (matches) return pubkey;
    }

    return null;
  }

  /// Recursively disposes gesture recognizers owned by inline spans.
  static void disposeSpans(List<InlineSpan> spans) {
    for (final span in spans) {
      if (span is! TextSpan) continue;
      span.recognizer?.dispose();
      final children = span.children;
      if (children != null) disposeSpans(children);
    }
  }

  static String _normalizeMentionValue(String value) {
    final trimmed = value.trim().toLowerCase();
    final withoutPrefix = trimmed.startsWith('@')
        ? trimmed.substring(1)
        : trimmed;
    return withoutPrefix.replaceAll(RegExp('[^a-z0-9]'), '');
  }
}
