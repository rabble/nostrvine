// ABOUTME: Content widget for the More sheet with animated transitions
// ABOUTME: Manages menu and block/unblock confirmation states

import 'package:flutter/material.dart';

import 'package:openvine/widgets/profile/more_sheet/block_confirmation_view.dart';
import 'package:openvine/widgets/profile/more_sheet/more_sheet_menu.dart';
import 'package:openvine/widgets/profile/more_sheet/more_sheet_result.dart';
import 'package:openvine/widgets/profile/more_sheet/unblock_confirmation_view.dart';

/// The current mode of the More sheet.
enum MoreSheetMode {
  /// Shows the main menu with copy, unfollow, block options.
  menu,

  /// Shows the block confirmation view.
  blockConfirmation,

  /// Shows the unblock confirmation view.
  unblockConfirmation,
}

/// Content widget for the More sheet that manages menu and confirmation states.
///
/// Provides smooth animated transitions between menu and confirmation views.
class MoreSheetContent extends StatefulWidget {
  /// Creates a More sheet content widget.
  const MoreSheetContent({
    required this.userIdHex,
    required this.displayName,
    required this.isFollowing,
    required this.isBlocked,
    this.initialMode = MoreSheetMode.menu,
    super.key,
  });

  /// The hex public key of the user.
  final String userIdHex;

  /// The display name of the user.
  final String displayName;

  /// Whether the current user is following this user.
  final bool isFollowing;

  /// Whether this user is blocked.
  final bool isBlocked;

  /// The initial mode to display.
  final MoreSheetMode initialMode;

  @override
  State<MoreSheetContent> createState() => _MoreSheetContentState();
}

class _MoreSheetContentState extends State<MoreSheetContent>
    with SingleTickerProviderStateMixin {
  late MoreSheetMode _targetMode;
  late MoreSheetMode _displayedMode;
  late AnimationController _controller;
  late Animation<double> _fadeOutAnimation;
  late Animation<double> _fadeInAnimation;

  @override
  void initState() {
    super.initState();
    _targetMode = widget.initialMode;
    _displayedMode = widget.initialMode;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Fade out menu: 0-250ms (0.0-0.333 of total)
    _fadeOutAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.333, curve: Curves.easeOut),
      ),
    );

    // Fade in confirmation: 500-750ms (0.667-1.0 of total)
    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.667, 1.0, curve: Curves.easeIn),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _transitionTo(MoreSheetMode mode) {
    setState(() => _targetMode = mode);
    _controller.forward();

    // Switch displayed content at 200ms (after fade out, before resize)
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() => _displayedMode = mode);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // If we started directly in a non-menu mode, show content at full opacity
    final startedInConfirmation = widget.initialMode != MoreSheetMode.menu;
    if (startedInConfirmation) {
      return _buildContent();
    }

    final isTransitioning = _targetMode != MoreSheetMode.menu;

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final opacity = isTransitioning
              ? (_displayedMode != MoreSheetMode.menu
                    ? _fadeInAnimation.value
                    : 0.0)
              : _fadeOutAnimation.value;

          return Opacity(
            opacity: isTransitioning ? opacity : _fadeOutAnimation.value,
            child: _buildContent(),
          );
        },
      ),
    );
  }

  Widget _buildContent() {
    switch (_displayedMode) {
      case MoreSheetMode.menu:
        return _buildMenu();
      case MoreSheetMode.blockConfirmation:
        return _buildBlockConfirmation();
      case MoreSheetMode.unblockConfirmation:
        return _buildUnblockConfirmation();
    }
  }

  Widget _buildMenu() {
    return MoreSheetMenu(
      displayName: widget.displayName,
      isFollowing: widget.isFollowing,
      isBlocked: widget.isBlocked,
      onCopy: () => Navigator.of(context).pop(MoreSheetResult.copy),
      onUnfollow: () => Navigator.of(context).pop(MoreSheetResult.unfollow),
      onBlockTap: () {
        if (widget.isBlocked) {
          _transitionTo(MoreSheetMode.unblockConfirmation);
        } else {
          _transitionTo(MoreSheetMode.blockConfirmation);
        }
      },
    );
  }

  Widget _buildBlockConfirmation() {
    return BlockConfirmationView(
      displayName: widget.displayName,
      onCancel: () => Navigator.of(context).pop(),
      onConfirm: () =>
          Navigator.of(context).pop(MoreSheetResult.blockConfirmed),
    );
  }

  Widget _buildUnblockConfirmation() {
    return UnblockConfirmationView(
      displayName: widget.displayName,
      onCancel: () => Navigator.of(context).pop(),
      onConfirm: () =>
          Navigator.of(context).pop(MoreSheetResult.unblockConfirmed),
    );
  }
}
