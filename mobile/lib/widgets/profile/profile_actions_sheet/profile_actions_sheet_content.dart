// ABOUTME: Multi-state bottom sheet content for pending profile actions.
// ABOUTME: Animates between "Secure Your Account" and "Complete Your Profile"
// ABOUTME: prompts using the same fade pattern as MoreSheetContent.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:openvine/screens/auth/secure_account_screen.dart';
import 'package:openvine/screens/profile_setup_screen.dart';
import 'package:openvine/widgets/profile/profile_actions_sheet/profile_action_type.dart';

/// Content widget for the profile-actions bottom sheet.
///
/// Displays a prompt for each pending [ProfileActionType] in order.
/// When the user taps "Maybe Later", the sheet transitions to the next
/// action (if any) or dismisses. Tapping the primary button navigates
/// to the corresponding screen and closes the sheet.
class ProfileActionsSheetContent extends StatefulWidget {
  /// Creates a [ProfileActionsSheetContent].
  ///
  /// [actions] must contain at least one element.
  const ProfileActionsSheetContent({
    required this.actions,
    super.key,
  }) : assert(actions.length > 0, 'actions must not be empty');

  /// Ordered list of actions to present. The first action is shown
  /// immediately; subsequent ones appear after "Maybe Later".
  final List<ProfileActionType> actions;

  @override
  State<ProfileActionsSheetContent> createState() =>
      _ProfileActionsSheetContentState();
}

class _ProfileActionsSheetContentState extends State<ProfileActionsSheetContent>
    with SingleTickerProviderStateMixin {
  /// Index into [widget.actions] that we are transitioning **to**.
  late int _targetIndex;

  /// Index currently rendered on screen (swapped mid-animation).
  late int _displayedIndex;

  late AnimationController _controller;
  late Animation<double> _fadeOutAnimation;
  late Animation<double> _fadeInAnimation;

  @override
  void initState() {
    super.initState();
    _targetIndex = 0;
    _displayedIndex = 0;

    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Fade out current content: 0–250 ms.
    _fadeOutAnimation = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.333, curve: Curves.easeOut),
      ),
    );

    // Fade in next content: 500–750 ms.
    _fadeInAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.667, 1, curve: Curves.easeIn),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _transitionToNext() {
    final nextIndex = _targetIndex + 1;
    if (nextIndex >= widget.actions.length) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _targetIndex = nextIndex);
    _controller.forward(from: 0);

    // Swap displayed content after fade-out completes.
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() => _displayedIndex = nextIndex);
      }
    });
  }

  Future<void> _onPrimaryTap(ProfileActionType action) async {
    final route = switch (action) {
      ProfileActionType.secureAccount => SecureAccountScreen.path,
      ProfileActionType.completeProfile => ProfileSetupScreen.setupPath,
    };

    Navigator.of(context).pop();
    if (context.mounted) {
      context.push(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTransitioning = _targetIndex != _displayedIndex;

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final opacity = isTransitioning
              ? (_displayedIndex == _targetIndex ? _fadeInAnimation.value : 0.0)
              : (_targetIndex > 0 && _controller.isAnimating
                    ? _fadeOutAnimation.value
                    : 1.0);

          return Opacity(
            opacity: isTransitioning
                ? opacity
                : _fadeOutAnimation.value.clamp(
                    0.0,
                    1.0,
                  ),
            child: _buildPrompt(widget.actions[_displayedIndex]),
          );
        },
      ),
    );
  }

  Widget _buildPrompt(ProfileActionType action) {
    final (sticker, title, subtitle, primaryLabel) = switch (action) {
      ProfileActionType.secureAccount => (
        DivineStickerName.skeletonKey,
        'Secure Your Account',
        'Add email & password to recover your account on any device.',
        'Add Email & Password',
      ),
      ProfileActionType.completeProfile => (
        DivineStickerName.profile,
        'Complete Your Profile',
        'Add your name, bio, and picture to get started.',
        'Update Your Profile',
      ),
    };

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DivineSticker(sticker: sticker),
          const SizedBox(height: 32),
          Text(
            title,
            style: VineTheme.headlineSmallFont(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: VineTheme.bodyLargeFont(
              color: VineTheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          DivineButton(
            label: primaryLabel,
            onPressed: () => _onPrimaryTap(action),
            expanded: true,
          ),
          const SizedBox(height: 16),
          DivineButton(
            label: 'Maybe Later',
            onPressed: _transitionToNext,
            type: DivineButtonType.secondary,
            expanded: true,
          ),
        ],
      ),
    );
  }
}
