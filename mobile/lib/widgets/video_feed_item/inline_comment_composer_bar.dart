// ABOUTME: Inline comment composer bar shown at the bottom of the fullscreen
// ABOUTME: video player on Explore / Search / Profile entry points.

import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/fullscreen_feed/fullscreen_feed_bloc.dart';
import 'package:openvine/blocs/inline_comment_composer/inline_comment_composer_cubit.dart';
import 'package:openvine/l10n/l10n.dart';

/// Comment composer pinned to the bottom of [PooledFullscreenVideoFeedScreen].
///
/// Tapping the field opens the keyboard so the user can type and post a
/// comment without ever opening the full comments sheet — the goal is "drop
/// a comment without reading the others". On send, the keyboard dismisses
/// and a snackbar confirms the outcome.
///
/// Designed to be used as [Scaffold.bottomNavigationBar]; total visible
/// height above the home indicator matches the home-feed [VineBottomNav]
/// (72 px content + safe-area bottom). Visibility is owned by the parent
/// screen, which gates on "active video present" and "user signed in".
class InlineCommentComposerBar extends StatefulWidget {
  const InlineCommentComposerBar({super.key});

  /// Content height above the safe-area bottom inset. Matches
  /// `VineBottomNav._kTabSlotHeight` so the comment-bar variant of the
  /// fullscreen feed lines up with the home-feed nav vertically.
  static const double contentHeight = 72.0;

  @override
  State<InlineCommentComposerBar> createState() =>
      _InlineCommentComposerBarState();
}

class _InlineCommentComposerBarState extends State<InlineCommentComposerBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleTextChanged)
      ..dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  void _handleSubmit() {
    final video = context.read<FullscreenFeedBloc>().state.currentVideo;
    if (video == null) return;
    final text = _controller.text;
    if (text.trim().isEmpty) return;

    // Optimistic UX: clear the field and drop the keyboard immediately so
    // the user moves on while the publish lands in the background. The
    // cubit owns the snackbar via the BlocListener wired below.
    context.read<InlineCommentComposerCubit>().submit(
      video: video,
      content: text,
    );
    _controller.clear();
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<InlineCommentComposerCubit, InlineCommentComposerState>(
      listenWhen: (prev, curr) =>
          prev.status != curr.status &&
          (curr.status == InlineCommentComposerStatus.submitted ||
              curr.status == InlineCommentComposerStatus.failure),
      listener: (context, state) {
        final message = state.status == InlineCommentComposerStatus.submitted
            ? context.l10n.videoOverlayCommentPostedSnackbar
            : context.l10n.videoOverlayCommentPostFailedSnackbar;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(message),
              behavior: SnackBarBehavior.floating,
            ),
          );
        context.read<InlineCommentComposerCubit>().acknowledge();
      },
      child: ColoredBox(
        color: VineTheme.surfaceBackground,
        // Manually compute the bottom inset instead of using SafeArea
        // because the bar lives inside the Scaffold body (so it can ride
        // above the keyboard). When the keyboard is up, viewInsets.bottom
        // grows by the keyboard height while viewPadding.bottom stays at
        // the device's home-indicator size — leaving a SafeArea-driven
        // gap of empty surface color above the keyboard. Clamping to
        // `max(0, viewPadding - viewInsets)` collapses the inset to 0 in
        // that case so the input pill sits flush against the keyboard.
        child: Padding(
          padding: EdgeInsets.only(
            bottom: math.max(
              0,
              MediaQuery.viewPaddingOf(context).bottom -
                  MediaQuery.viewInsetsOf(context).bottom,
            ),
          ),
          child: SizedBox(
            height: InlineCommentComposerBar.contentHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              child: _ComposerField(
                controller: _controller,
                focusNode: _focusNode,
                hasText: _hasText,
                onSubmit: _handleSubmit,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill-shaped text field that fills the bar content area.
///
/// The send button appears only when [hasText] is true so an empty bar
/// shows just the "Add comment…" hint — matching the Figma spec
/// (node 15222:192143).
class _ComposerField extends StatelessWidget {
  const _ComposerField({
    required this.controller,
    required this.focusNode,
    required this.hasText,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasText;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: VineTheme.iconButtonBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 16, end: 8),
              child: Semantics(
                identifier: 'inline_comment_composer_field',
                textField: true,
                label: context.l10n.videoOverlayCommentBarSemanticLabel,
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSubmit(),
                  // Tap anywhere outside the field (the video, the action
                  // column, the app bar) dismisses the keyboard — matches
                  // the DM ConversationView convention.
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  cursorColor: VineTheme.tabIndicatorGreen,
                  style: VineTheme.bodyLargeFont(),
                  decoration: InputDecoration(
                    hintText: context.l10n.videoOverlayCommentBarHint,
                    hintStyle: VineTheme.bodyLargeFont(
                      color: VineTheme.onSurfaceMuted55,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                ),
              ),
            ),
          ),
          if (hasText) _SendButton(onPressed: onSubmit),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 4),
      child: Semantics(
        identifier: 'inline_comment_composer_send_button',
        button: true,
        label: context.l10n.videoOverlayCommentBarSendLabel,
        child: SizedBox.square(
          dimension: 40,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: VineTheme.tabIndicatorGreen,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: onPressed,
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.arrow_upward,
                color: VineTheme.whiteText,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
