// ABOUTME: BLoC for fetching the list of users who liked or reposted a video.
// ABOUTME: Backs the engagement list screens shown when the video owner taps
// ABOUTME: the like or repost button on their own video.

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:models/models.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:reposts_repository/reposts_repository.dart';

part 'video_engagement_event.dart';
part 'video_engagement_state.dart';

/// BLoC for the "who liked / reposted this video" engagement list.
///
/// Reads the relevant fetch method on [LikesRepository] /
/// [RepostsRepository] based on [type], and emits the resulting pubkey
/// list to the UI.
///
/// After fetching pubkeys, calls [ProfileRepository.fetchBatchProfiles] with a
/// 2-second timeout to pre-warm the local Drift cache before the UI renders.
/// This holds the loading state for up to 2 seconds so [UserProfileTile]
/// widgets can display real names on first paint instead of the generated
/// fallback placeholder. On timeout or error the list is still emitted as
/// success — per-tile [userProfileReactiveProvider] fetches serve as fallback.
class VideoEngagementBloc
    extends Bloc<VideoEngagementEvent, VideoEngagementState> {
  VideoEngagementBloc({
    required this.eventId,
    required this.type,
    required LikesRepository likesRepository,
    required RepostsRepository repostsRepository,
    required ProfileRepository? profileRepository,
    this.addressableId,
  }) : _likesRepository = likesRepository,
       _repostsRepository = repostsRepository,
       _profileRepository = profileRepository,
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

  /// Nullable because [profileRepositoryProvider] legitimately returns `null`
  /// before authentication. When non-null, profiles for the returned pubkeys
  /// are batch-fetched into the local cache before the success state is emitted.
  final ProfileRepository? _profileRepository;

  static const _profilePrefetchTimeout = Duration(seconds: 2);

  Future<void> _onLoadRequested(
    VideoEngagementLoadRequested event,
    Emitter<VideoEngagementState> emit,
  ) async {
    emit(state.copyWith(status: VideoEngagementStatus.loading));
    try {
      final pubkeys = await _fetch();

      // Pre-warm the profile cache so UserProfileTile widgets render real
      // names on first paint. This awaits the batch fetch (bounded to
      // _profilePrefetchTimeout = 2 s), so the loading state is held for up
      // to that duration. On timeout or error the list still appears — the
      // per-tile userProfileReactiveProvider fetch acts as fallback.
      if (pubkeys.isNotEmpty) {
        await _profileRepository
            ?.fetchBatchProfiles(pubkeys: pubkeys)
            .timeout(_profilePrefetchTimeout)
            .catchError((_) => <String, UserProfile>{});
      }

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
