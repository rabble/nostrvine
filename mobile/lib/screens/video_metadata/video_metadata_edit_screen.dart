// ABOUTME: Screen wrapper for the full-screen video metadata edit flow.
// ABOUTME: Resolves the VideoEvent by id (with optional prefetched fast-path).

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' show VideoEvent;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/router/route_error_screen.dart';
import 'package:openvine/widgets/video_metadata/modes/edit/video_metadata_edit_stack.dart';

/// Screen entry-point for editing an already-published [VideoEvent].
///
/// The screen is keyed on a [videoId] so the route is deep-linkable. When a
/// [prefetched] [VideoEvent] is available (e.g. from a feed-side tap), it is
/// used immediately as a fast path; otherwise the screen resolves the id via
/// the [videoEventResolverProvider] (in-memory → personal cache → relay).
///
/// Navigate to this screen with [pathFor]:
/// ```dart
/// context.push(
///   VideoMetadataEditScreen.pathFor(video.id),
///   extra: video, // optional fast-path
/// );
/// ```
class VideoMetadataEditScreen extends ConsumerStatefulWidget {
  static const routeName = 'video-edit';
  static const path = '/video-edit';

  /// Build a concrete `/video-edit/:videoId` path for [videoId].
  static String pathFor(String videoId) =>
      '$path/${Uri.encodeComponent(videoId)}';

  const VideoMetadataEditScreen({
    required this.videoId,
    this.prefetched,
    super.key,
  });

  final String videoId;
  final VideoEvent? prefetched;

  @override
  ConsumerState<VideoMetadataEditScreen> createState() =>
      _VideoMetadataEditScreenState();
}

class _VideoMetadataEditScreenState
    extends ConsumerState<VideoMetadataEditScreen> {
  VideoEvent? _resolved;
  bool _resolveFailed = false;

  @override
  void initState() {
    super.initState();
    if (widget.prefetched != null && widget.prefetched!.id == widget.videoId) {
      _resolved = widget.prefetched;
    } else {
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final resolver = ref.read(videoEventResolverProvider);
    final video = await resolver.resolveById(
      widget.videoId,
      allowOwnContentBypass: true,
    );
    if (!mounted) return;
    setState(() {
      _resolved = video;
      _resolveFailed = video == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final resolved = _resolved;
    if (resolved != null) {
      return VideoMetadataEditStack(video: resolved);
    }
    if (_resolveFailed) {
      return RouteErrorScreen(message: context.l10n.routeInvalidVideoId);
    }
    return const Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      body: Center(
        child: CircularProgressIndicator(color: VineTheme.vineGreen),
      ),
    );
  }
}
