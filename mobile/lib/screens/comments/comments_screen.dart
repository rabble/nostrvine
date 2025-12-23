// ABOUTME: Screen for displaying and posting comments on videos with threaded reply support
// ABOUTME: Uses Nostr Kind 1 events for comments with proper e/p tags for threading

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/comments/comments.dart';
import 'package:openvine/screens/comments/widgets/comments.dart';

class CommentsScreen extends ConsumerWidget {
  const CommentsScreen({
    required this.videoEvent,
    required this.sheetScrollController,
    super.key,
  });

  final VideoEvent videoEvent;
  final ScrollController sheetScrollController;

  /// Shows comments as a modal bottom sheet overlay
  static Future<void> show(BuildContext context, VideoEvent video) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (context, scrollController) => DecoratedBox(
            decoration: const BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: CommentsScreen(
              videoEvent: video,
              sheetScrollController: scrollController,
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = (eventId: videoEvent.id, pubkey: videoEvent.pubkey);

    // Wrap children in ProviderScope with comment context override
    return ProviderScope(
      overrides: [commentContextProvider.overrideWithValue(ctx)],
      child: _CommentsScreenContent(
        videoEvent: videoEvent,
        sheetScrollController: sheetScrollController,
      ),
    );
  }
}

/// Content widget that lives inside the ProviderScope
class _CommentsScreenContent extends ConsumerWidget {
  const _CommentsScreenContent({
    required this.videoEvent,
    required this.sheetScrollController,
  });

  final VideoEvent videoEvent;
  final ScrollController sheetScrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(commentContextProvider);

    // Listen for errors and show snackbar
    ref.listen(commentInputProvider(ctx.eventId, ctx.pubkey), (prev, next) {
      final error = next.error;
      if (error != null && prev?.error != error) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
        ref
            .read(commentInputProvider(ctx.eventId, ctx.pubkey).notifier)
            .clearError();
      }
    });

    return Column(
      children: [
        const CommentsDragHandle(),
        CommentsHeader(onClose: () => Navigator.pop(context)),
        const Divider(color: Colors.white24, height: 1),
        Expanded(
          child: CommentsList(
            isOriginalVine: videoEvent.isOriginalVine,
            scrollController: sheetScrollController,
          ),
        ),
        const _MainCommentInput(),
      ],
    );
  }
}

/// Main comment input widget that reads from provider
class _MainCommentInput extends ConsumerStatefulWidget {
  const _MainCommentInput();

  @override
  ConsumerState<_MainCommentInput> createState() => _MainCommentInputState();
}

class _MainCommentInputState extends ConsumerState<_MainCommentInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final ctx = ref.read(commentContextProvider);
    final inputState = ref.read(
      commentInputProvider(ctx.eventId, ctx.pubkey),
    );
    _controller = TextEditingController(text: inputState.mainInputText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctx = ref.watch(commentContextProvider);
    final inputState = ref.watch(
      commentInputProvider(ctx.eventId, ctx.pubkey),
    );

    // Sync controller with state (for when state changes externally,
    // e.g., after post clears the text)
    if (_controller.text != inputState.mainInputText) {
      _controller.text = inputState.mainInputText;
      _controller.selection = TextSelection.collapsed(
        offset: inputState.mainInputText.length,
      );
    }

    return CommentInput(
      controller: _controller,
      isPosting: inputState.isMainPosting,
      onChanged: (text) {
        ref
            .read(commentInputProvider(ctx.eventId, ctx.pubkey).notifier)
            .updateMainText(text);
      },
      onSubmit: () {
        ref
            .read(commentInputProvider(ctx.eventId, ctx.pubkey).notifier)
            .postMainComment();
      },
    );
  }
}
