// ABOUTME: BLoC for viewing another user's profile
// ABOUTME: Implements cache+fresh pattern and block/unblock actions

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:models/models.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:unified_logger/unified_logger.dart';

part 'other_profile_event.dart';
part 'other_profile_state.dart';

/// BLoC for managing the state of viewing another user's profile.
///
/// Implements the cache+fresh pattern:
/// 1. On [OtherProfileLoadRequested], emit cached profile immediately (if available)
/// 2. Fetch fresh profile from relay
/// 3. Emit fresh profile when received
///
/// Also handles block/unblock actions via [OtherProfileBlockRequested]
/// and [OtherProfileUnblockRequested].
///
/// The [pubkey] is provided at construction time since this BLoC is scoped
/// to a single profile screen instance.
class OtherProfileBloc extends Bloc<OtherProfileEvent, OtherProfileState> {
  OtherProfileBloc({
    required ProfileRepository profileRepository,
    required this.pubkey,
    required ContentBlocklistRepository contentBlocklistRepository,
    required String currentUserPubkey,
    required FollowRepository followRepository,
    bool requireRawKind0 = false,
    IdentityClaimsRepository? identityClaimsRepository,
  }) : _profileRepository = profileRepository,
       _blocklistRepository = contentBlocklistRepository,
       _currentUserPubkey = currentUserPubkey,
       _followRepository = followRepository,
       _requireRawKind0 = requireRawKind0,
       _identityClaimsRepository = identityClaimsRepository,
       super(const OtherProfileInitial()) {
    on<OtherProfileLoadRequested>(_onLoadRequested);
    on<OtherProfileRefreshRequested>(_onRefreshRequested);
    on<OtherProfileBlockRequested>(_onBlockRequested);
    on<OtherProfileUnblockRequested>(_onUnblockRequested);
    on<VerifiedClaimsRequested>(_onVerifiedClaimsRequested);
  }

  final ProfileRepository _profileRepository;
  final ContentBlocklistRepository _blocklistRepository;
  final String _currentUserPubkey;
  final FollowRepository _followRepository;
  final bool _requireRawKind0;
  final IdentityClaimsRepository? _identityClaimsRepository;

  /// The pubkey of the profile being viewed.
  final String pubkey;

  /// Current block status for the viewed profile.
  bool get isBlocked => _blocklistRepository.isBlocked(pubkey);

  /// Whether the current user is following the viewed profile.
  bool get isFollowing => _followRepository.isFollowing(pubkey);

  Future<void> _onLoadRequested(
    OtherProfileLoadRequested event,
    Emitter<OtherProfileState> emit,
  ) async {
    // 1. Get cached profile from repository
    final cachedProfile = await _profileRepository.getCachedProfile(
      pubkey: pubkey,
    );
    if (isClosed) return;
    emit(OtherProfileLoading(profile: cachedProfile));

    try {
      final freshProfile = await _profileRepository.fetchFreshProfile(
        pubkey: pubkey,
        requireRawKind0: _requireRawKind0,
      );
      if (isClosed) return;
      if (freshProfile != null) {
        emit(OtherProfileLoaded(profile: freshProfile, isFresh: true));
        add(const VerifiedClaimsRequested());
      } else if (cachedProfile != null) {
        emit(OtherProfileLoaded(profile: cachedProfile, isFresh: false));
        add(const VerifiedClaimsRequested());
      } else {
        emit(
          const OtherProfileError(errorType: OtherProfileErrorType.notFound),
        );
      }
    } catch (e) {
      if (isClosed) return;
      if (cachedProfile != null) {
        emit(OtherProfileLoaded(profile: cachedProfile, isFresh: false));
        add(const VerifiedClaimsRequested());
      } else {
        emit(
          const OtherProfileError(
            errorType: OtherProfileErrorType.networkError,
          ),
        );
      }
    }
  }

  Future<void> _onRefreshRequested(
    OtherProfileRefreshRequested event,
    Emitter<OtherProfileState> emit,
  ) async {
    final currentProfile = switch (state) {
      OtherProfileInitial() => null,
      OtherProfileLoading(:final profile) => profile,
      OtherProfileLoaded(:final profile) => profile,
      OtherProfileError(:final profile) => profile,
    };
    emit(OtherProfileLoading(profile: currentProfile));

    try {
      final freshProfile = await _profileRepository.fetchFreshProfile(
        pubkey: pubkey,
        requireRawKind0: _requireRawKind0,
      );
      if (isClosed) return;
      if (freshProfile != null) {
        emit(OtherProfileLoaded(profile: freshProfile, isFresh: true));
        add(const VerifiedClaimsRequested());
      } else {
        emit(
          OtherProfileError(
            errorType: OtherProfileErrorType.notFound,
            profile: currentProfile,
          ),
        );
      }
    } catch (e) {
      if (isClosed) return;
      if (currentProfile != null) {
        emit(OtherProfileLoaded(profile: currentProfile, isFresh: false));
        add(const VerifiedClaimsRequested());
      } else {
        emit(
          const OtherProfileError(
            errorType: OtherProfileErrorType.networkError,
          ),
        );
      }
    }
  }

  Future<void> _onVerifiedClaimsRequested(
    VerifiedClaimsRequested event,
    Emitter<OtherProfileState> emit,
  ) async {
    final repo = _identityClaimsRepository;
    if (repo == null) return;

    final current = state;
    if (current is! OtherProfileLoaded) return;
    final profile = current.profile;

    try {
      final claims = await repo.verifiedClaims(
        pubkey: profile.pubkey,
        tags: profile.rawTags,
      );
      if (isClosed) return;
      final latest = state;
      if (latest is OtherProfileLoaded &&
          latest.profile.pubkey == profile.pubkey) {
        emit(latest.copyWith(verifiedClaims: claims));
      }
    } on Exception catch (e, stackTrace) {
      // Verifier failures are expected (network/4xx/5xx/timeout). Per
      // .claude/rules/error_handling.md they are NOT Reportable.
      addError(e, stackTrace);
      if (isClosed) return;
      final latest = state;
      if (latest is OtherProfileLoaded &&
          latest.profile.pubkey == profile.pubkey) {
        emit(latest.copyWith(verifiedClaims: const []));
      }
    }
  }

  Future<void> _onBlockRequested(
    OtherProfileBlockRequested event,
    Emitter<OtherProfileState> emit,
  ) async {
    await _blocklistRepository.blockUser(pubkey, ourPubkey: _currentUserPubkey);

    // Unfollow the user if we're currently following them
    if (_followRepository.isFollowing(pubkey)) {
      try {
        await _followRepository.toggleFollow(pubkey);
      } catch (e, s) {
        Log.error(
          'Failed to unfollow blocked user $pubkey',
          name: 'OtherProfileBloc',
          error: e,
          stackTrace: s,
        );
      }
    }
  }

  Future<void> _onUnblockRequested(
    OtherProfileUnblockRequested event,
    Emitter<OtherProfileState> emit,
  ) async {
    await _blocklistRepository.unblockUser(pubkey);
  }
}
