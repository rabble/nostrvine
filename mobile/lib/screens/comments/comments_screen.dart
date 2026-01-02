// ABOUTME: Screen for displaying and posting comments on videos with threaded reply support
// ABOUTME: Uses BLoC pattern with Nostr Kind 1111 (NIP-22) events for comments

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/comments/comments_bloc.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';
import 'package:openvine/router/route_transitions.dart';
import 'package:openvine/screens/comments/widgets/widgets.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Maps [CommentsError] to user-facing strings.
/// TODO(l10n): Replace with context.l10n when localization is added.
String _errorToString(CommentsError error) {
  return switch (error) {
    CommentsError.loadFailed => 'Failed to load comments',
    CommentsError.notAuthenticated => 'Please sign in to comment',
    CommentsError.postCommentFailed => 'Failed to post comment',
    CommentsError.postReplyFailed => 'Failed to post reply',
    CommentsError.deleteCommentFailed => 'Failed to delete comment',
  };
}

class CommentsScreen extends ConsumerWidget {
  /// Route name for this screen.
  static const routeName = 'comments';

  /// Path for this route with video ID.
  static const path = '/video/:id/comments';

  /// Page builder for GoRouter (modal overlay).
  static Page<void> pageBuilder(BuildContext context, GoRouterState state) {
    final videoId = state.pathParameters['id'];
    if (videoId == null || videoId.isEmpty) {
      return StandardPage(
        key: state.pageKey,
        child: Scaffold(
          appBar: AppBar(title: const Text('Error')),
          body: const Center(child: Text('Invalid video ID')),
        ),
      );
    }
    return ModalPage(
      key: state.pageKey,
      child: CommentsPage(videoId: videoId),
    );
  }

  const CommentsScreen({
    required this.videoEvent,
    required this.sheetScrollController,
    super.key,
  });

  final VideoEvent videoEvent;
  final ScrollController sheetScrollController;

  /// Opens comments for a video using URL-based routing.
  ///
  /// This pushes the `/video/:id/comments` route which is deep-linkable.
  static void show(BuildContext context, VideoEvent video) {
    context.push('/video/${video.id}/comments');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commentsRepository = ref.watch(commentsRepositoryProvider);
    final authService = ref.watch(authServiceProvider);

    return BlocProvider<CommentsBloc>(
      create: (_) => CommentsBloc(
        commentsRepository: commentsRepository,
        authService: authService,
        rootEventId: videoEvent.id,
        rootEventKind: NIP71VideoKinds.addressableShortVideo,
        rootAuthorPubkey: videoEvent.pubkey,
      )..add(const CommentsLoadRequested()),
      child: _CommentsScreenBody(
        videoEvent: videoEvent,
        sheetScrollController: sheetScrollController,
      ),
    );
  }
}

/// Body widget with error listener
class _CommentsScreenBody extends StatelessWidget {
  const _CommentsScreenBody({
    required this.videoEvent,
    required this.sheetScrollController,
  });

  final VideoEvent videoEvent;
  final ScrollController sheetScrollController;

  @override
  Widget build(BuildContext context) {
    return BlocListener<CommentsBloc, CommentsState>(
      listenWhen: (prev, next) =>
          prev.error != next.error && next.error != null,
      listener: (context, state) {
        if (state.error != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(_errorToString(state.error!))));
          context.read<CommentsBloc>().add(const CommentErrorCleared());
        }
      },
      child: Column(
        children: [
          const CommentsDragHandle(),
          CommentsHeader(onClose: () => context.pop()),
          const Divider(color: Colors.white24, height: 1),
          Expanded(
            child: CommentsList(
              isOriginalVine: videoEvent.isOriginalVine,
              scrollController: sheetScrollController,
            ),
          ),
          const _MainCommentInput(),
        ],
      ),
    );
  }
}

/// Main comment input widget that reads from CommentsBloc state
class _MainCommentInput extends StatefulWidget {
  const _MainCommentInput();

  @override
  State<_MainCommentInput> createState() => _MainCommentInputState();
}

class _MainCommentInputState extends State<_MainCommentInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final state = context.read<CommentsBloc>().state;
    _controller = TextEditingController(text: state.mainInputText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CommentsBloc, CommentsState>(
      buildWhen: (prev, next) =>
          prev.mainInputText != next.mainInputText ||
          prev.isPosting != next.isPosting,
      builder: (context, state) {
        // Sync controller with state (for when state changes externally,
        // e.g., after post clears the text)
        if (_controller.text != state.mainInputText) {
          _controller.text = state.mainInputText;
          _controller.selection = TextSelection.collapsed(
            offset: state.mainInputText.length,
          );
        }

        return CommentInput(
          controller: _controller,
          isPosting: state.isPosting && state.activeReplyCommentId == null,
          onChanged: (text) {
            context.read<CommentsBloc>().add(CommentTextChanged(text));
          },
          onSubmit: () {
            context.read<CommentsBloc>().add(const CommentSubmitted());
          },
        );
      },
    );
  }
}

/// Route page wrapper that loads video by ID and displays comments.
///
/// Used for URL-based navigation to `/video/:id/comments`.
class CommentsPage extends ConsumerStatefulWidget {
  const CommentsPage({required this.videoId, super.key});

  final String videoId;

  @override
  ConsumerState<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends ConsumerState<CommentsPage> {
  VideoEvent? _video;
  bool _isLoading = true;
  String? _error;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadVideo();
    // Set overlay visibility for modal state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(overlayVisibilityProvider.notifier).setModalOpen(true);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadVideo() async {
    try {
      Log.info(
        'Loading video for comments: ${widget.videoId}',
        name: 'CommentsPage',
        category: LogCategory.ui,
      );

      final videoEventService = ref.read(videoEventServiceProvider);

      // Try to find video in existing loaded events first
      var video = videoEventService.getVideoById(widget.videoId);

      if (video != null) {
        Log.info(
          'Found video in cache: ${video.title}',
          name: 'CommentsPage',
          category: LogCategory.ui,
        );
        if (mounted) {
          setState(() {
            _video = video;
            _isLoading = false;
          });
        }
        return;
      }

      // Video not in cache, fetch from Nostr
      Log.info(
        'Video not in cache, fetching from Nostr...',
        name: 'CommentsPage',
        category: LogCategory.ui,
      );

      final nostrService = ref.read(nostrServiceProvider);
      final event = await nostrService.fetchEventById(widget.videoId);

      if (event != null) {
        final fetchedVideo = VideoEvent.fromNostrEvent(event);
        Log.info(
          'Fetched video from Nostr: ${fetchedVideo.title}',
          name: 'CommentsPage',
          category: LogCategory.ui,
        );
        if (mounted) {
          setState(() {
            _video = fetchedVideo;
            _isLoading = false;
          });
        }
      } else {
        Log.warning(
          'Video not found: ${widget.videoId}',
          name: 'CommentsPage',
          category: LogCategory.ui,
        );
        if (mounted) {
          setState(() {
            _error = 'Video not found';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      Log.error(
        'Error loading video: $e',
        name: 'CommentsPage',
        category: LogCategory.ui,
      );
      if (mounted) {
        setState(() {
          _error = 'Failed to load video';
          _isLoading = false;
        });
      }
    }
  }

  void _handleClose() {
    ref.read(overlayVisibilityProvider.notifier).setModalOpen(false);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          ref.read(overlayVisibilityProvider.notifier).setModalOpen(false);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: GestureDetector(
          onTap: _handleClose,
          child: Container(
            color: Colors.black54,
            child: GestureDetector(
              onTap: () {}, // Prevent tap-through to dismiss
              child: DraggableScrollableSheet(
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
                  child: _buildContent(scrollController),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ScrollController scrollController) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: VineTheme.vineGreen),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: _handleClose, child: const Text('Close')),
          ],
        ),
      );
    }

    if (_video == null) {
      return const Center(
        child: Text('Video not found', style: TextStyle(color: Colors.white)),
      );
    }

    return CommentsScreen(
      videoEvent: _video!,
      sheetScrollController: scrollController,
    );
  }
}
