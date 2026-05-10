// ABOUTME: BLoC for fetching the list of users who liked or reposted a video.
// ABOUTME: Backs the engagement list screens shown when the video owner taps
// ABOUTME: the like or repost button on their own video.

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:reposts_repository/reposts_repository.dart';

part 'video_engagement_event.dart';
part 'video_engagement_state.dart';

/// BLoC for the "who liked / reposted this video" engagement list.
///
/// Reads the relevant fetch method on [LikesRepository] /
/// [RepostsRepository] based on [type], and emits the resulting pubkey
/// list to the UI.
class VideoEngagementBloc
    extends Bloc<VideoEngagementEvent, VideoEngagementState> {
  VideoEngagementBloc({
    required this.eventId,
    required this.type,
    required LikesRepository likesRepository,
    required RepostsRepository repostsRepository,
    this.addressableId,
  }) : _likesRepository = likesRepository,
       _repostsRepository = repostsRepository,
       super(VideoEngagementState(type: type)) {
    on<VideoEngagementLoadRequested>(
      _onLoadRequested,
      transformer: droppable(),
    );
  }

  /// Hex id of the target video event.
  final String eventId;

  /// Optional `kind:pubkey:d-tag` for addressable video events (Kind 30000+).
  final String? addressableId;

  /// Whether to load likers or reposters.
  final VideoEngagementType type;

  final LikesRepository _likesRepository;
  final RepostsRepository _repostsRepository;

  Future<void> _onLoadRequested(
    VideoEngagementLoadRequested event,
    Emitter<VideoEngagementState> emit,
  ) async {
    emit(state.copyWith(status: VideoEngagementStatus.loading));
    try {
      final pubkeys = await _fetch();
      emit(
        state.copyWith(
          status: VideoEngagementStatus.success,
          pubkeys: pubkeys,
        ),
      );
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(state.copyWith(status: VideoEngagementStatus.failure));
    }
  }

  Future<List<String>> _fetch() => switch (type) {
    VideoEngagementType.likers => _likesRepository.fetchEventLikers(
      eventId: eventId,
      addressableId: addressableId,
    ),
    VideoEngagementType.reposters => _repostsRepository.fetchEventReposters(
      eventId: eventId,
      addressableId: addressableId,
    ),
  };
}
