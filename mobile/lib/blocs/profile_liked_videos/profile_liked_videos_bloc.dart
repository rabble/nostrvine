// ABOUTME: BLoC for managing profile liked videos grid
// ABOUTME: Fetches video data from cache and relays for liked event IDs

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/utils/unified_logger.dart';

part 'profile_liked_videos_event.dart';
part 'profile_liked_videos_state.dart';

/// BLoC for managing profile liked videos.
///
/// Handles:
/// - Loading video data for a list of liked event IDs
/// - Caching: checks VideoEventService cache first
/// - Fetching: fetches missing videos from Nostr relays
/// - Filtering: excludes unsupported video formats
class ProfileLikedVideosBloc
    extends Bloc<ProfileLikedVideosEvent, ProfileLikedVideosState> {
  ProfileLikedVideosBloc({
    required VideoEventService videoEventService,
    required NostrClient nostrClient,
  }) : _videoEventService = videoEventService,
       _nostrClient = nostrClient,
       super(const ProfileLikedVideosState()) {
    on<ProfileLikedVideosLoadRequested>(_onLoadRequested);
    on<ProfileLikedVideosRefreshRequested>(_onRefreshRequested);
  }

  final VideoEventService _videoEventService;
  final NostrClient _nostrClient;

  /// Handle load request with liked event IDs.
  Future<void> _onLoadRequested(
    ProfileLikedVideosLoadRequested event,
    Emitter<ProfileLikedVideosState> emit,
  ) async {
    final likedEventIds = event.likedEventIds;

    Log.info(
      'ProfileLikedVideosBloc: Loading ${likedEventIds.length} liked videos',
      name: 'ProfileLikedVideosBloc',
      category: LogCategory.video,
    );

    if (likedEventIds.isEmpty) {
      emit(
        state.copyWith(
          status: ProfileLikedVideosStatus.success,
          videos: [],
          likedEventIds: [],
          clearError: true,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: ProfileLikedVideosStatus.loading,
        likedEventIds: likedEventIds,
        clearError: true,
      ),
    );

    try {
      final videos = await _fetchVideos(likedEventIds);

      Log.info(
        'ProfileLikedVideosBloc: Loaded ${videos.length} videos',
        name: 'ProfileLikedVideosBloc',
        category: LogCategory.video,
      );

      emit(
        state.copyWith(
          status: ProfileLikedVideosStatus.success,
          videos: videos,
        ),
      );
    } catch (e) {
      Log.error(
        'ProfileLikedVideosBloc: Failed to load videos - $e',
        name: 'ProfileLikedVideosBloc',
        category: LogCategory.video,
      );
      emit(
        state.copyWith(
          status: ProfileLikedVideosStatus.failure,
          error: ProfileLikedVideosError.loadFailed,
        ),
      );
    }
  }

  /// Handle refresh request - re-fetch using stored liked event IDs.
  Future<void> _onRefreshRequested(
    ProfileLikedVideosRefreshRequested event,
    Emitter<ProfileLikedVideosState> emit,
  ) async {
    if (state.likedEventIds.isEmpty) {
      return;
    }

    add(ProfileLikedVideosLoadRequested(likedEventIds: state.likedEventIds));
  }

  // TODO(any): Make logic easier, export part of logic in repository
  /// Fetch videos for the given event IDs.
  ///
  /// 1. Check cache first
  /// 2. Fetch missing videos from relays
  /// 3. Return ordered list matching the input order
  Future<List<VideoEvent>> _fetchVideos(List<String> likedEventIds) async {
    final cachedVideosMap = <String, VideoEvent>{};
    final missingIds = <String>[];

    // Check cache first
    for (final eventId in likedEventIds) {
      final cached = _videoEventService.getVideoById(eventId);
      if (cached != null) {
        cachedVideosMap[eventId] = cached;
      } else {
        missingIds.add(eventId);
      }
    }

    Log.info(
      'ProfileLikedVideosBloc: Found ${cachedVideosMap.length} in cache, '
      '${missingIds.length} need relay fetch',
      name: 'ProfileLikedVideosBloc',
      category: LogCategory.video,
    );

    // Fetch missing videos from relays
    if (missingIds.isNotEmpty) {
      final fetchedVideos = await _fetchVideosFromRelay(missingIds);
      for (final video in fetchedVideos) {
        cachedVideosMap[video.id] = video;
      }

      Log.info(
        'ProfileLikedVideosBloc: Fetched ${fetchedVideos.length} from relay',
        name: 'ProfileLikedVideosBloc',
        category: LogCategory.video,
      );
    }

    // Build ordered list using the recency-ordered IDs
    final orderedVideos = <VideoEvent>[];
    for (final eventId in likedEventIds) {
      final video = cachedVideosMap[eventId];
      if (video != null) {
        orderedVideos.add(video);
      }
    }

    // Filter out unsupported videos (WebM on iOS/macOS)
    return orderedVideos.where((v) => v.isSupportedOnCurrentPlatform).toList();
  }

  /// Fetch videos from relays by their event IDs.
  Future<List<VideoEvent>> _fetchVideosFromRelay(List<String> eventIds) async {
    if (eventIds.isEmpty) return [];

    final completer = Completer<List<VideoEvent>>();
    final videos = <VideoEvent>[];

    // Generate unique subscription ID for cleanup
    final subscriptionId =
        'liked_videos_bloc_${DateTime.now().millisecondsSinceEpoch}';

    /// Helper to clean up subscription resources
    Future<void> cleanup() async {
      await _nostrClient.unsubscribe(subscriptionId);
    }

    try {
      // Create filter for video events by ID
      // NIP-71 kinds: 34235 (horizontal), 34236 (vertical/short)
      final filter = Filter(ids: eventIds, kinds: [34235, 34236]);

      final eventStream = _nostrClient.subscribe([
        filter,
      ], subscriptionId: subscriptionId);

      eventStream.listen(
        (event) {
          try {
            final video = VideoEvent.fromNostrEvent(event);
            videos.add(video);
          } catch (e) {
            Log.warning(
              'ProfileLikedVideosBloc: Failed to parse event ${event.id}: $e',
              name: 'ProfileLikedVideosBloc',
              category: LogCategory.video,
            );
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            cleanup();
            completer.complete(videos);
          }
        },
        onError: (Object error) {
          Log.error(
            'ProfileLikedVideosBloc: Stream error: $error',
            name: 'ProfileLikedVideosBloc',
            category: LogCategory.video,
          );
          if (!completer.isCompleted) {
            cleanup();
            completer.complete(videos);
          }
        },
      );

      return completer.future;
    } catch (e) {
      Log.error(
        'ProfileLikedVideosBloc: Failed to fetch from relay: $e',
        name: 'ProfileLikedVideosBloc',
        category: LogCategory.video,
      );
      await cleanup();
      return videos;
    }
  }
}
