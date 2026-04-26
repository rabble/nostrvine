// ABOUTME: App bar for conversation detail screen.
// ABOUTME: Wraps DiVineAppBar with back button, user name/handle, and options.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

/// Top app bar for the conversation detail screen.
///
/// Wraps [DiVineAppBar] with a back button, the other user's display name
/// and handle, and a trailing options button.
class ConversationAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const ConversationAppBar({
    required this.displayName,
    required this.handle,
    required this.onBack,
    required this.onOptions,
    this.onTitleTap,
    super.key,
  });

  final String displayName;
  final String handle;
  final VoidCallback onBack;
  final VoidCallback onOptions;

  /// Called when the user taps the name/handle in the app bar.
  final VoidCallback? onTitleTap;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    return DiVineAppBar(
      title: displayName,
      subtitle: handle.isNotEmpty ? handle : null,
      titleMode: onTitleTap != null
          ? DiVineAppBarTitleMode.tappable
          : DiVineAppBarTitleMode.simple,
      onTitleTap: onTitleTap,
      showBackButton: true,
      onBackPressed: onBack,
      backgroundColor: VineTheme.surfaceBackground,
      style: DiVineAppBarStyle(titleStyle: VineTheme.titleMediumFont()),
      actions: [
        DiVineAppBarAction(
          icon: SvgIconSource(DivineIconName.dotsThree.assetPath),
          onPressed: onOptions,
          semanticLabel: 'Options',
        ),
      ],
    );
  }
}
