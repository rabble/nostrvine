// ABOUTME: BLoC for viewing another user's profile
// ABOUTME: Implements cache+fresh pattern and block/unblock actions

import 'package:bloc_concurrency/bloc_concurrency.dart';
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
    on<VerifiedClaimsRequested>(
      _onVerifiedClaimsRequested,
      transformer: restartable(),
    );
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
    // Carry claims through the reload so chips do not vanish and re-pop
    // while the verifier revalidates (#3936). Read AFTER the await so an
    // authoritative claims resolve landing during the cache read is not
    // clobbered by a stale capture.
    final currentClaims = _claimsFromState(state);
    emit(
      OtherProfileLoading(
        profile: cachedProfile,
        verifiedClaims: currentClaims,
      ),
    );

    try {
      final freshProfile = await _profileRepository.fetchFreshProfile(
        pubkey: pubkey,
        requireRawKind0: _requireRawKind0,
      );
      if (isClosed) return;
      final latestClaims = _claimsFromState(state);
      if (freshProfile != null) {
        emit(
          OtherProfileLoaded(
            profile: freshProfile,
            isFresh: true,
            verifiedClaims: latestClaims,
          ),
        );
        add(const VerifiedClaimsRequested());
      } else if (cachedProfile != null) {
        emit(
          OtherProfileLoaded(
            profile: cachedProfile,
            isFresh: false,
            verifiedClaims: latestClaims,
          ),
        );
        add(const VerifiedClaimsRequested());
      } else {
        emit(
          const OtherProfileError(errorType: OtherProfileErrorType.notFound),
        );
      }
    } catch (e) {
      if (isClosed) return;
      if (cachedProfile != null) {
        emit(
          OtherProfileLoaded(
            profile: cachedProfile,
            isFresh: false,
            verifiedClaims: _claimsFromState(state),
          ),
        );
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
    // Carry claims through the refresh so chips do not vanish and re-pop
    // after the round-trip (#3936).
    final currentClaims = _claimsFromState(state);
    emit(
      OtherProfileLoading(
        profile: currentProfile,
        verifiedClaims: currentClaims,
      ),
    );

    try {
      final freshProfile = await _profileRepository.fetchFreshProfile(
        pubkey: pubkey,
        requireRawKind0: _requireRawKind0,
      );
      if (isClosed) return;
      if (freshProfile != null) {
        emit(
          OtherProfileLoaded(
            profile: freshProfile,
            isFresh: true,
            verifiedClaims: currentClaims,
          ),
        );
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
        emit(
          OtherProfileLoaded(
            profile: currentProfile,
            isFresh: false,
            verifiedClaims: currentClaims,
          ),
        );
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

    // Instant path (#3936): cached claims source ∩ persisted verdict
    // snapshot renders chips without any network round-trip.
    CachedVerifiedClaims? cached;
    try {
      final cachedTags = await _profileRepository.cachedIdentityTags(
        profile.pubkey,
      );
      if (isClosed) return;
      cached = await repo.cachedVerifiedClaims(
        pubkey: profile.pubkey,
        tags: cachedTags ?? profile.rawTags,
      );
      if (isClosed) return;
      if (cached != null) {
        _emitClaims(emit, profile.pubkey, cached.claims, authoritative: false);
      }
    } on Exception catch (e, stackTrace) {
      // Cache read failure — degrade straight to the network path.
      addError(e, stackTrace);
    }

    // Refresh the claims source: kind 10011 wins, kind-0 tags fall back.
    List<List<String>> freshTags;
    try {
      freshTags = await _profileRepository.freshIdentityTags(
        pubkey: profile.pubkey,
        kind0Tags: profile.rawTags,
      );
    } on Exception catch (e, stackTrace) {
      // Degraded claims source (cache I/O failure). Resolving against the
      // kind-0 fallback could authoritatively clear chips for a profile
      // whose claims live in kind 10011, so keep last-known-good and let
      // the next revalidation tick retry.
      addError(e, stackTrace);
      return;
    }
    if (isClosed) return;

    // The repository owns the skip-or-verify (stale-while-revalidate)
    // decision; the bloc just renders whatever it resolves to (#3936). The
    // currently-rendered claims ride along so a rate-limited (inconclusive)
    // outcome cannot clear visible chips.
    try {
      final claims = await repo.resolveClaims(
        pubkey: profile.pubkey,
        freshTags: freshTags,
        cached: cached,
        renderedClaims: _claimsFromState(state),
      );
      if (isClosed) return;
      _emitClaims(emit, profile.pubkey, claims, authoritative: true);
    } on Exception catch (e, stackTrace) {
      // Verifier failures are expected (network/4xx/5xx/timeout). Per
      // .claude/rules/error_handling.md they are NOT Reportable. Keep the
      // last-known-good claims instead of erasing rendered chips.
      addError(e, stackTrace);
    }
  }

  /// Emits [claims] onto the latest state when it still shows
  /// [profilePubkey]'s profile. State may have changed mid-await, so the
  /// check runs at emit time.
  ///
  /// A non-[authoritative] emit (the instant cache path) may only add
  /// chips: it is unioned with the rendered set, so a reduced or empty
  /// snapshot intersection never clears claims the verifier has not
  /// negatively confirmed. Only the authoritative resolve path replaces
  /// the rendered set outright.
  void _emitClaims(
    Emitter<OtherProfileState> emit,
    String profilePubkey,
    List<IdentityClaim> claims, {
    required bool authoritative,
  }) {
    final latest = state;
    if (latest is OtherProfileLoaded &&
        latest.profile.pubkey == profilePubkey) {
      final next = authoritative
          ? claims
          : _withRenderedPreserved(claims, latest.verifiedClaims);
      emit(latest.copyWith(verifiedClaims: next));
    }
  }

  /// Rendered-first union keyed on case-insensitive `platform:identity`:
  /// order-stable (no chip reorder churn across revalidation ticks, and
  /// the steady-state result is deep-equal to [rendered] so the emit is
  /// Equatable-suppressed) and dedup-safe across casing or proof drift.
  List<IdentityClaim> _withRenderedPreserved(
    List<IdentityClaim> incoming,
    List<IdentityClaim> rendered,
  ) {
    if (rendered.isEmpty) return incoming;
    final renderedKeys = {for (final claim in rendered) _identityKeyOf(claim)};
    return [
      ...rendered,
      ...incoming.where(
        (claim) => !renderedKeys.contains(_identityKeyOf(claim)),
      ),
    ];
  }

  String _identityKeyOf(IdentityClaim claim) =>
      '${claim.platform.toLowerCase()}:${claim.identity.toLowerCase()}';

  List<IdentityClaim> _claimsFromState(OtherProfileState state) {
    return switch (state) {
      OtherProfileLoaded(:final verifiedClaims) => verifiedClaims,
      OtherProfileLoading(:final verifiedClaims) => verifiedClaims,
      _ => const [],
    };
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
