// ABOUTME: Cubit that resolves a video from a divine.video stableId.
// ABOUTME: Checks the VideoEventService cache first, then fetches from relay.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// State for [VideoLinkPreviewCubit].
sealed class VideoLinkPreviewState extends Equatable {
  const VideoLinkPreviewState();

  @override
  List<Object?> get props => [];
}

class VideoLinkPreviewLoading extends VideoLinkPreviewState {
  const VideoLinkPreviewLoading();
}

class VideoLinkPreviewResolved extends VideoLinkPreviewState {
  const VideoLinkPreviewResolved(this.video);

  final VideoEvent video;

  @override
  List<Object?> get props => [video.id];
}

class VideoLinkPreviewNotFound extends VideoLinkPreviewState {
  const VideoLinkPreviewNotFound();
}

/// Resolves a [VideoEvent] from a `divine.video/video/{stableId}` URL.
///
/// Resolution strategy:
/// 1. Check [VideoEventService] cache by event ID.
/// 2. Check cache by vine ID (d-tag).
/// 3. Fetch from relay by event ID.
/// 4. Query relay by d-tag for addressable video events (kind 34236).
/// 5. Emit [VideoLinkPreviewNotFound] if all lookups fail.
class VideoLinkPreviewCubit extends Cubit<VideoLinkPreviewState> {
  VideoLinkPreviewCubit({
    required String videoStableId,
    required VideoEventService videoEventService,
    required NostrClient nostrClient,
  }) : _videoStableId = videoStableId,
       _videoEventService = videoEventService,
       _nostrClient = nostrClient,
       super(const VideoLinkPreviewLoading()) {
    // Schedule as microtask so the first emit happens after callers
    // (BlocProvider, blocTest) have subscribed to the stream.
    Future.microtask(_resolve);
  }

  final String _videoStableId;
  final VideoEventService _videoEventService;
  final NostrClient _nostrClient;

  Future<void> _resolve() async {
    // Try cache: first by event ID, then by vine ID (d-tag).
    final cached =
        _videoEventService.getVideoById(_videoStableId) ??
        _videoEventService.getVideoEventByVineId(_videoStableId);
    if (cached != null) {
      emit(VideoLinkPreviewResolved(cached));
      return;
    }

    // Fetch from relay when not in cache.
    try {
      // Try by event ID first.
      var event = await _nostrClient.fetchEventById(_videoStableId);

      // If not found, query by d-tag for addressable video events.
      if (event == null) {
        final results = await _nostrClient.queryEvents([
          Filter(
            kinds: const [NIP71VideoKinds.addressableShortVideo],
            d: [_videoStableId],
            limit: 1,
          ),
        ]);
        if (results.isNotEmpty) {
          event = results.first;
        }
      }

      if (event != null) {
        emit(VideoLinkPreviewResolved(VideoEvent.fromNostrEvent(event)));
        return;
      }
    } catch (e) {
      Log.warning(
        'Video link preview relay fetch failed for $_videoStableId: $e',
        name: 'VideoLinkPreviewCubit',
        category: LogCategory.ui,
      );
    }

    emit(const VideoLinkPreviewNotFound());
  }
}
