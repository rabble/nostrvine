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
    emit(
      MyProfileLoading(
        profile: cachedProfile,
        extractedUsername: cachedProfile?.divineUsername,
        externalNip05: cachedProfile?.externalNip05,
      ),
    );

    // 2. Fetch fresh profile from relay
    try {
      final freshProfile = await _profileRepository.fetchFreshProfile(
        pubkey: pubkey,
      );

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
    emit(const MyProfileLoading());

    await emit.forEach<UserProfile?>(
      _profileRepository.watchProfile(pubkey: pubkey),
      onData: (profile) {
        if (profile != null) {
          add(const VerifiedClaimsRequested());
          return MyProfileUpdated(
            profile: profile,
            extractedUsername: profile.divineUsername,
            externalNip05: profile.externalNip05,
          );
        }
        return const MyProfileLoading();
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
}
