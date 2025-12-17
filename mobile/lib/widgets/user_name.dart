import 'package:openvine/models/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/theme/vine_theme.dart';

class UserName extends ConsumerWidget {
  const UserName._({
    super.key,
    this.pubkey,
    this.userProfile,
    this.style,
    this.maxLines,
    this.overflow,
    this.selectable = false,
    this.anonymousName,
  });

  factory UserName.fromPubKey(
    String pubkey, {
    key,
    style,
    maxLines,
    overflow,
    selectable,
    anonymousName,
  }) => UserName._(
    pubkey: pubkey,
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

      (displayName, showCheckmark) = switch (profileAsync) {
        AsyncData(:final value) when value != null => (
          value.betterDisplayName(anonymousName),
          _isReserved(value),
        ),
        AsyncData() || AsyncError() => ('Unknown', false),
        AsyncLoading() => ('Loading...', false),
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
      spacing: 4,
      children: [
        selectable ?? false
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
    // TODO(any): We need to determine how we tell if a user's name is
    // reserved or not. Existing code was adding a check mark if the
    // user profile hasNip05.
    // see https://github.com/nostr-protocol/nips/blob/master/05.md
    return userProfile.hasNip05;
  }
}
