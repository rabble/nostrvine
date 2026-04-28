import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/widgets/special_profile_checkmark.dart';

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
    Key? key,
    TextStyle? style,
    int? maxLines,
    bool? selectable,
    String? anonymousName,
    TextOverflow? overflow,
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
    Key? key,
    TextStyle? style,
    int? maxLines,
    bool? selectable,
    String? anonymousName,
    TextOverflow? overflow,
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
    UserProfile? resolvedProfile;
    if (userProfile case final userProfile?) {
      resolvedProfile = userProfile;
      displayName = userProfile.betterDisplayName(anonymousName);
    } else {
      final profileAsync = ref.watch(userProfileReactiveProvider(pubkey!));
      resolvedProfile = profileAsync.value;

      // Use embedded name from REST API as fallback, then generated name.
      final fallbackName =
          embeddedName ?? UserProfile.defaultDisplayNameFor(pubkey!);

      displayName = switch (profileAsync) {
        AsyncData(:final value) when value != null => value.betterDisplayName(
          anonymousName,
        ),
        AsyncLoading() || AsyncData() => fallbackName,
        AsyncError() => fallbackName,
      };
    }

    // Note: Strikethrough for failed NIP-05 verification is now shown on the
    // NIP-05 identifier itself (in _UniqueIdentifier), not on the display name.
    // The display name is the user's chosen name and should not be crossed out.

    final textStyle =
        style ??
        const TextStyle(
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
        if (shouldShowSpecialProfileCheckmark(resolvedProfile))
          const SpecialProfileCheckmark(),
      ],
    );
  }
}
