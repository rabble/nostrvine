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

  /// Recursively disposes gesture recognizers owned by inline spans.
  static void disposeSpans(List<InlineSpan> spans) {
    for (final span in spans) {
      if (span is! TextSpan) continue;
      span.recognizer?.dispose();
      final children = span.children;
      if (children != null) disposeSpans(children);
    }
  }
}
