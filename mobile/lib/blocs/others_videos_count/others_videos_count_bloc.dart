// ABOUTME: BLoC for displaying another user's video count
// ABOUTME: One-time fetch operation, no subscription

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:videos_repository/videos_repository.dart';
import 'package:openvine/utils/unified_logger.dart';

part 'others_videos_count_event.dart';
part 'others_videos_count_state.dart';

/// BLoC for displaying another user's video count.
///
/// Performs a one-time fetch of the video count for the target user.
/// Queries Nostr relays for NIP-71 video events.
class OthersVideosCountBloc
    extends Bloc<OthersVideosCountEvent, OthersVideosCountState> {
  OthersVideosCountBloc({required VideosRepository videosRepository})
    : _videosRepository = videosRepository,
      super(const OthersVideosCountState()) {
    on<OthersVideosCountLoadRequested>(_onLoadRequested);
  }

  final VideosRepository _videosRepository;

  /// Handle request to load another user's video count
  Future<void> _onLoadRequested(
    OthersVideosCountLoadRequested event,
    Emitter<OthersVideosCountState> emit,
  ) async {
    emit(
      state.copyWith(
        status: OthersVideosCountStatus.loading,
        targetPubkey: event.targetPubkey,
      ),
    );

    try {
      final count = await _videosRepository.getVideoCount(event.targetPubkey);

      Log.info(
        'OthersVideosCountBloc: Loaded video count for ${event.targetPubkey}: $count',
        name: 'OthersVideosCountBloc',
        category: LogCategory.video,
      );

      emit(
        state.copyWith(
          status: OthersVideosCountStatus.success,
          count: count,
        ),
      );
    } catch (e) {
      Log.error(
        'Failed to load video count for ${event.targetPubkey}: $e',
        name: 'OthersVideosCountBloc',
        category: LogCategory.video,
      );
      emit(state.copyWith(status: OthersVideosCountStatus.failure));
    }
  }
}
