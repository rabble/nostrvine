import 'package:openvine/models/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/theme/vine_theme.dart';

class UserName extends ConsumerWidget {
  const UserName({
    super.key,
    required this.pubkey,
    this.style,
    this.maxLines,
    this.overflow,
    this.selectable = false,
  });

  final String pubkey;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool selectable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileReactiveProvider(pubkey));

    final (displayName, isReserved) = switch (profileAsync) {
      AsyncData(:final value) when value != null => (
        value.bestDisplayName,
        _isReserved(value),
      ),
      AsyncData() || AsyncError() => ('Unknown', false),
      AsyncLoading() => ('Loading...', false),
    };

    final textStyle =
        style ??
        TextStyle(
          color: VineTheme.secondaryText,
          fontSize: 10,
          fontWeight: FontWeight.w400,
        );

    return Row(
      children: [
        selectable
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
        // TODO( any ): replace with real design for reserved user names
        if (isReserved) Text('✓', style: TextStyle(color: Colors.blue)),
      ],
    );
  }
}

bool _isReserved(UserProfile? userProfile) {
  // TODO( any ): replace with real code once available
  return userProfile?.bestDisplayName == 'Taylor Swift' ||
      userProfile?.bestDisplayName == 'rabble' ||
      userProfile?.bestDisplayName == ' Lele';
}
