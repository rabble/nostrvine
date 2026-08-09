// ABOUTME: BLoC for fetching the list of users who liked or reposted a video.
// ABOUTME: Backs the engagement list screens shown when the video owner taps
// ABOUTME: the like or repost button on their own video.

import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:models/models.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:reposts_repository/reposts_repository.dart';
import 'package:unified_logger/unified_logger.dart';

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
///
/// The likers list is emitted twice for an addressable video whose superseded
/// revisions are not yet known: once from the ids the fetch had, and again
/// when the backend lookup that supplies those revisions lands (#6021). The
/// repository never holds the first list back for that lookup, so this bloc
/// subscribes to it instead — see
/// [LikesRepository.watchRevisionEnrichedLikers].
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
    on<_VideoEngagementLikersEnriched>(_onLikersEnriched);

    // Subscribed here rather than from the load handler because the stream
    // buffers nothing: the update can land before a droppable load has been
    // processed, and only an addressable video can have revisions to widen.
    if (type == VideoEngagementType.likers && addressableId != null) {
      _enrichedLikers = _likesRepository
          .watchRevisionEnrichedLikers()
          .where((update) => update.eventId == eventId)
          .listen(
            (update) =>
                add(_VideoEngagementLikersEnriched(update.likerPubkeys)),
          );
    }
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

  StreamSubscription<RevisionEnrichedLikers>? _enrichedLikers;

  Future<void> _onLoadRequested(
    VideoEngagementLoadRequested event,
    Emitter<VideoEngagementState> emit,
  ) async {
    final preFetchPubkeys = state.pubkeys;
    emit(state.copyWith(status: VideoEngagementStatus.loading));
    try {
      Log.info(
        'Loading video engagement list: type=${type.name}, '
        'eventId=$eventId, addressableId=${addressableId ?? '(none)'}',
        name: 'VideoEngagementBloc',
        category: LogCategory.video,
      );
      final pubkeys = await _fetch();
      await _prewarmProfiles(pubkeys);

      emit(
        state.copyWith(
          status: VideoEngagementStatus.success,
          // Revision enrichment can land while this fetch is running — the
          // profile pre-warm alone holds it for up to 2s. It re-resolves the
          // same list one revision wider, so overwriting it with the fetched
          // one here would put #6021 back for as long as the sheet is open.
          pubkeys: identical(state.pubkeys, preFetchPubkeys) ? pubkeys : null,
        ),
      );
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(state.copyWith(status: VideoEngagementStatus.failure));
    }
  }

  /// Replaces the list with the one resolved once the video's revision lookup
  /// landed (#6021).
  ///
  /// Emitted regardless of the current status: the wider list is a complete
  /// re-resolve, so it is the right answer whether the initial load is still
  /// running, already succeeded, or failed.
  Future<void> _onLikersEnriched(
    _VideoEngagementLikersEnriched event,
    Emitter<VideoEngagementState> emit,
  ) async {
    await _prewarmProfiles(event.pubkeys);
    if (emit.isDone) return;
    emit(
      state.copyWith(
        status: VideoEngagementStatus.success,
        pubkeys: event.pubkeys,
      ),
    );
  }

  /// Pre-warms the profile cache so [UserProfileTile] widgets render real
  /// names on first paint.
  ///
  /// Awaits the batch fetch (bounded to [_profilePrefetchTimeout]), so the
  /// caller's state is held for up to that duration. On timeout or error the
  /// list still appears — the per-tile `userProfileReactiveProvider` fetch
  /// acts as fallback.
  Future<void> _prewarmProfiles(List<String> pubkeys) async {
    if (pubkeys.isEmpty) return;
    await _profileRepository
        ?.fetchBatchProfiles(pubkeys: pubkeys)
        .timeout(_profilePrefetchTimeout)
        .catchError((_) => <String, UserProfile>{});
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

  @override
  Future<void> close() async {
    await _enrichedLikers?.cancel();
    return super.close();
  }
}
