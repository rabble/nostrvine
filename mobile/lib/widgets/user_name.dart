import 'package:openvine/models/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:divine_ui/divine_ui.dart';

class UserName extends ConsumerWidget {
  const UserName._({
    super.key,
    this.pubkey,
    this.userProfile,
    this.embeddedName,
    this.style,
    this.maxLines,
    this.overflow,
    this.selectable = false,
    this.anonymousName,
  });

  /// Create a UserName widget from a pubkey.
  ///
  /// If [embeddedName] is provided (e.g., from REST API response with
  /// author_name), it will be used as a fallback when the profile isn't
  /// cached yet. This avoids unnecessary WebSocket profile fetches for
  /// videos that already have author data embedded.
  factory UserName.fromPubKey(
    String pubkey, {
    String? embeddedName,
    key,
    style,
    maxLines,
    overflow,
    selectable,
    anonymousName,
  }) => UserName._(
    pubkey: pubkey,
    embeddedName: embeddedName,
    key: key,
    style: style,
    maxLines: maxLines,
    overflow: overflow,
    selectable: selectable,
    anonymousName: anonymousName,
  );

  factory UserName.fromUserProfile(
    UserProfile userProfile, {
    key,
    style,
    maxLines,
    overflow,
    selectable,
    anonymousName,
  }) => UserName._(
    userProfile: userProfile,
    key: key,
    style: style,
    maxLines: maxLines,
    overflow: overflow,
    selectable: selectable,
    anonymousName: anonymousName,
  );

  final String? pubkey;
  final UserProfile? userProfile;

  /// Optional embedded author name from REST API (e.g., video.authorName).
  /// Used as fallback when profile isn't cached, avoiding WebSocket fetches.
  final String? embeddedName;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? selectable;
  final String? anonymousName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    late String displayName;
    late bool showCheckmark;
    if (userProfile case final userProfile?) {
      displayName = userProfile.betterDisplayName(anonymousName);
      showCheckmark = _isReserved(userProfile);
    } else {
      final profileAsync = ref.watch(userProfileReactiveProvider(pubkey!));

      // Use embedded name from REST API as fallback before truncated npub.
      // This avoids unnecessary WebSocket profile fetches for videos with
      // author_name already embedded.
      final fallbackName = embeddedName ?? NostrKeyUtils.truncateNpub(pubkey!);

      (displayName, showCheckmark) = switch (profileAsync) {
        AsyncData(:final value) when value != null => (
          value.betterDisplayName(anonymousName),
          _isReserved(value),
        ),
        AsyncLoading() || AsyncData() => (fallbackName, false),
        AsyncError() => (fallbackName, false),
      };
    }

    final textStyle =
        style ??
        TextStyle(
          color: VineTheme.secondaryText,
          fontSize: 10,
          fontWeight: FontWeight.w400,
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        Flexible(
          child: selectable ?? false
              ? SelectableText(
                  displayName,
                  style: textStyle,
                  maxLines: maxLines ?? 1,
                )
              : Text(
                  displayName,
                  style: textStyle,
                  maxLines: maxLines ?? 1,
                  overflow: overflow ?? TextOverflow.ellipsis,
                ),
        ),

        if (showCheckmark)
          Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 10),
          ),
      ],
    );
  }

  bool _isReserved(UserProfile? userProfile) {
    if (userProfile == null) return false;
    // NIP-05 verification requires an async HTTP call to the domain's
    // .well-known/nostr.json endpoint. Having a NIP-05 field set does NOT
    // mean it's verified - anyone can claim any NIP-05 in their profile.
    // Until we have a cached verification provider, don't show the badge.
    // See: https://github.com/nostr-protocol/nips/blob/master/05.md
    return false;
  }
}
