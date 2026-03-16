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
    super.key,
  });

  final String displayName;
  final String handle;
  final VoidCallback onBack;
  final VoidCallback onOptions;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    return DiVineAppBar(
      title: displayName,
      subtitle: handle.isNotEmpty ? handle : null,
      showBackButton: true,
      onBackPressed: onBack,
      backgroundColor: VineTheme.surfaceBackground,
      style: DiVineAppBarStyle(
        titleStyle: VineTheme.titleMediumFont(),
      ),
      /* TODO(meylis1998): Uncomment the button below once it has a function.
      actions: [
        DiVineAppBarAction(
          icon: const SvgIconSource(
            'assets/icon/dots_three_vertical.svg',
          ),
          onPressed: onOptions,
          semanticLabel: 'Options',
        ),
      ],*/
    );
  }
}
