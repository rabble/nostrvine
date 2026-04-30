// ABOUTME: Cubit for fetching pubkeys of users who reposted a video.
// ABOUTME: Queries relay for Kind 16 repost events referencing the video ID.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/services/video_event_service.dart';

/// State for [VideoRepostersCubit].
class VideoRepostersState extends Equatable {
  const VideoRepostersState({this.pubkeys = const [], this.isLoading = true});

  /// Pubkeys of users who reposted this video.
  final List<String> pubkeys;

  /// Whether the relay query is still in progress.
  final bool isLoading;

  @override
  List<Object?> get props => [pubkeys, isLoading];
}

/// Fetches the pubkeys of users who reposted a video.
///
/// Queries the relay for Kind 16 (NIP-18 generic repost) events that
/// reference the video ID. Uses [VideoEventService.getRepostersForVideo]
/// which has a 5-second timeout.
class VideoRepostersCubit extends Cubit<VideoRepostersState> {
  VideoRepostersCubit({
    required VideoEventService videoEventService,
    required String videoId,
  }) : _videoEventService = videoEventService,
       _videoId = videoId,
       super(const VideoRepostersState()) {
    _fetch();
  }

  final VideoEventService _videoEventService;
  final String _videoId;

  Future<void> _fetch() async {
    if (_videoId.isEmpty) {
      if (isClosed) return;
      emit(const VideoRepostersState(isLoading: false));
      return;
    }
    try {
      final pubkeys = await _videoEventService.getRepostersForVideo(_videoId);
      if (isClosed) return;
      emit(VideoRepostersState(pubkeys: pubkeys, isLoading: false));
    } catch (e, stackTrace) {
      if (isClosed) return;
      addError(e, stackTrace);
      emit(const VideoRepostersState(isLoading: false));
    }
  }
}
