// ABOUTME: BLoC for the current user's own profile
// ABOUTME: Supports one-shot load (editor) and stream subscription (profile screen)

import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:profile_repository/profile_repository.dart';

part 'my_profile_event.dart';
part 'my_profile_state.dart';

/// BLoC for the current user's own profile.
class MyProfileBloc extends Bloc<MyProfileEvent, MyProfileState> {
  MyProfileBloc({
    required ProfileRepository profileRepository,
    required this.pubkey,
    IdentityClaimsRepository? identityClaimsRepository,
  }) : _profileRepository = profileRepository,
       _identityClaimsRepository = identityClaimsRepository,
       super(const MyProfileInitial()) {
    on<MyProfileLoadRequested>(_onLoadRequested);
    on<MyProfileSubscriptionRequested>(
      _onSubscriptionRequested,
      transformer: restartable(),
    );
    on<MyProfileFetchRequested>(_onFetchRequested);
    on<MyProfileRefreshRequested>(
      _onRefreshRequested,
      transformer: sequential(),
    );
    on<VerifiedClaimsRequested>(_onVerifiedClaimsRequested);
  }

  final ProfileRepository _profileRepository;
  final IdentityClaimsRepository? _identityClaimsRepository;

  /// The pubkey of the current user.
  final String pubkey;

  Future<void> _onLoadRequested(
    MyProfileLoadRequested event,
    Emitter<MyProfileState> emit,
  ) async {
    // 1. Get cached profile and emit immediately
    final cachedProfile = await _profileRepository.getCachedProfile(
      pubkey: pubkey,
    );
    if (isClosed) return;
    emit(
      MyProfileLoading(
        profile: cachedProfile,
        extractedUsername: cachedProfile?.divineUsername,
        externalNip05: cachedProfile?.externalNip05,
        verifiedClaims: _claimsFromState(state),
      ),
    );

    // 2. Fetch fresh profile from relay
    try {
      final freshProfile = await _profileRepository.fetchFreshProfile(
        pubkey: pubkey,
      );
      if (isClosed) return;

      if (freshProfile != null) {
        emit(
          MyProfileLoaded(
            profile: freshProfile,
            isFresh: true,
            extractedUsername: freshProfile.divineUsername,
            externalNip05: freshProfile.externalNip05,
          ),
        );
        add(const VerifiedClaimsRequested());
      } else if (cachedProfile != null) {
        emit(
          MyProfileLoaded(
            profile: cachedProfile,
            isFresh: false,
            extractedUsername: cachedProfile.divineUsername,
            externalNip05: cachedProfile.externalNip05,
          ),
        );
        add(const VerifiedClaimsRequested());
      } else {
        emit(const MyProfileError(errorType: MyProfileErrorType.notFound));
      }
    } on Exception {
      if (isClosed) return;
      if (cachedProfile != null) {
        emit(
          MyProfileLoaded(
            profile: cachedProfile,
            isFresh: false,
            extractedUsername: cachedProfile.divineUsername,
            externalNip05: cachedProfile.externalNip05,
          ),
        );
        add(const VerifiedClaimsRequested());
      } else {
        emit(const MyProfileError(errorType: MyProfileErrorType.networkError));
      }
    }
  }

  Future<void> _onSubscriptionRequested(
    MyProfileSubscriptionRequested event,
    Emitter<MyProfileState> emit,
  ) async {
    // Pre-seed with cached profile so the real display name is shown
    // immediately rather than a generated fallback while the Drift watch
    // stream fires its first event. Mirrors the same pattern used in
    // _onLoadRequested.
    final cachedProfile = await _profileRepository.getCachedProfile(
      pubkey: pubkey,
    );
    if (isClosed) return;
    emit(
      MyProfileLoading(
        profile: cachedProfile,
        extractedUsername: cachedProfile?.divineUsername,
        externalNip05: cachedProfile?.externalNip05,
      ),
    );

    await emit.forEach<UserProfile?>(
      _profileRepository.watchProfile(pubkey: pubkey),
      onData: (profile) {
        if (isClosed) return state;
        if (profile != null) {
          add(const VerifiedClaimsRequested());
          return MyProfileUpdated(
            profile: profile,
            extractedUsername: profile.divineUsername,
            externalNip05: profile.externalNip05,
          );
        }
        final currentProfile = _profileFromState(state);
        if (currentProfile == null) return const MyProfileLoading();
        return MyProfileLoading(
          profile: currentProfile,
          extractedUsername: currentProfile.divineUsername,
          externalNip05: currentProfile.externalNip05,
          verifiedClaims: _claimsFromState(state),
        );
      },
      onError: (error, stackTrace) {
        addError(error, stackTrace);
        return state;
      },
    );
  }

  Future<void> _onFetchRequested(
    MyProfileFetchRequested event,
    Emitter<MyProfileState> emit,
  ) async {
    try {
      await _profileRepository.fetchFreshProfile(pubkey: pubkey);
    } on Exception catch (e, stackTrace) {
      addError(e, stackTrace);
    }
  }

  Future<void> _onRefreshRequested(
    MyProfileRefreshRequested event,
    Emitter<MyProfileState> emit,
  ) async {
    final currentProfile = _profileFromState(state);
    emit(
      _loadingStateFor(currentProfile, verifiedClaims: _claimsFromState(state)),
    );

    try {
      final freshProfile = await _profileRepository.fetchFreshProfile(
        pubkey: pubkey,
      );
      if (isClosed) return;

      final latestClaims = _claimsFromState(state);
      if (freshProfile != null) {
        emit(
          _loadedStateFor(
            freshProfile,
            isFresh: true,
            verifiedClaims: latestClaims,
          ),
        );
        add(const VerifiedClaimsRequested());
      } else if (_profileFromState(state) case final latestProfile?) {
        emit(
          _loadedStateFor(
            latestProfile,
            isFresh: false,
            verifiedClaims: latestClaims,
          ),
        );
        add(const VerifiedClaimsRequested());
      } else {
        emit(const MyProfileError(errorType: MyProfileErrorType.notFound));
      }
    } on Exception catch (e, stackTrace) {
      addError(e, stackTrace);
      if (isClosed) return;
      final latestClaims = _claimsFromState(state);
      if (_profileFromState(state) case final latestProfile?) {
        emit(
          _loadedStateFor(
            latestProfile,
            isFresh: false,
            verifiedClaims: latestClaims,
          ),
        );
        add(const VerifiedClaimsRequested());
      } else {
        emit(const MyProfileError(errorType: MyProfileErrorType.networkError));
      }
    } finally {
      final completer = event.completer;
      if (completer != null && !completer.isCompleted) {
        completer.complete();
      }
    }
  }

  Future<void> _onVerifiedClaimsRequested(
    VerifiedClaimsRequested event,
    Emitter<MyProfileState> emit,
  ) async {
    final repo = _identityClaimsRepository;
    if (repo == null) return;

    final current = state;
    final UserProfile profile;
    if (current is MyProfileLoaded) {
      profile = current.profile;
    } else if (current is MyProfileUpdated) {
      profile = current.profile;
    } else {
      return;
    }

    try {
      final claims = await repo.verifiedClaims(
        pubkey: profile.pubkey,
        tags: profile.rawTags,
      );
      if (isClosed) return;
      // State may have changed mid-await; re-check before emitting.
      final latest = state;
      if (latest is MyProfileLoaded &&
          latest.profile.pubkey == profile.pubkey) {
        emit(latest.copyWith(verifiedClaims: claims));
      } else if (latest is MyProfileUpdated &&
          latest.profile.pubkey == profile.pubkey) {
        emit(latest.copyWith(verifiedClaims: claims));
      }
    } on Exception catch (e, stackTrace) {
      // Verifier failures are expected (network/4xx/5xx/timeout). Per
      // .claude/rules/error_handling.md they are NOT Reportable. Surface as
      // empty list rather than blocking the UI.
      addError(e, stackTrace);
      if (isClosed) return;
      final latest = state;
      if (latest is MyProfileLoaded &&
          latest.profile.pubkey == profile.pubkey) {
        emit(latest.copyWith(verifiedClaims: const []));
      } else if (latest is MyProfileUpdated &&
          latest.profile.pubkey == profile.pubkey) {
        emit(latest.copyWith(verifiedClaims: const []));
      }
    }
  }

  UserProfile? _profileFromState(MyProfileState state) {
    final profile = switch (state) {
      MyProfileLoaded(:final profile) => profile,
      MyProfileUpdated(:final profile) => profile,
      MyProfileLoading(:final profile) => profile,
      _ => null,
    };
    return profile?.pubkey == pubkey ? profile : null;
  }

  List<IdentityClaim> _claimsFromState(MyProfileState state) {
    final claims = switch (state) {
      MyProfileLoaded(:final profile, :final verifiedClaims) =>
        profile.pubkey == pubkey ? verifiedClaims : const <IdentityClaim>[],
      MyProfileUpdated(:final profile, :final verifiedClaims) =>
        profile.pubkey == pubkey ? verifiedClaims : const <IdentityClaim>[],
      MyProfileLoading(:final profile, :final verifiedClaims) =>
        profile?.pubkey == pubkey ? verifiedClaims : const <IdentityClaim>[],
      _ => const <IdentityClaim>[],
    };
    return claims;
  }

  MyProfileLoading _loadingStateFor(
    UserProfile? profile, {
    List<IdentityClaim> verifiedClaims = const [],
  }) => MyProfileLoading(
    profile: profile,
    extractedUsername: profile?.divineUsername,
    externalNip05: profile?.externalNip05,
    verifiedClaims: verifiedClaims,
  );

  MyProfileLoaded _loadedStateFor(
    UserProfile profile, {
    required bool isFresh,
    List<IdentityClaim> verifiedClaims = const [],
  }) => MyProfileLoaded(
    profile: profile,
    isFresh: isFresh,
    extractedUsername: profile.divineUsername,
    externalNip05: profile.externalNip05,
    verifiedClaims: verifiedClaims,
  );
}
