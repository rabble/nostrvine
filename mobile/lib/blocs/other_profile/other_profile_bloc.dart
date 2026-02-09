// ABOUTME: BLoC for viewing another user's profile
// ABOUTME: Implements cache+fresh pattern - shows cached immediately, then fetches fresh

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:profile_repository/profile_repository.dart';

part 'other_profile_event.dart';
part 'other_profile_state.dart';

/// BLoC for managing the state of viewing another user's profile.
///
/// Implements the cache+fresh pattern:
/// 1. On [OtherProfileLoadRequested], emit cached profile immediately (if available)
/// 2. Fetch fresh profile from relay
/// 3. Emit fresh profile when received
///
/// The [pubkey] is provided at construction time since this BLoC is scoped
/// to a single profile screen instance.
class OtherProfileBloc extends Bloc<OtherProfileEvent, OtherProfileState> {
  OtherProfileBloc({
    required ProfileRepository profileRepository,
    required this.pubkey,
  }) : _profileRepository = profileRepository,
       super(const OtherProfileInitial()) {
    on<OtherProfileLoadRequested>(_onLoadRequested);
    on<OtherProfileRefreshRequested>(_onRefreshRequested);
  }

  final ProfileRepository _profileRepository;

  /// The pubkey of the profile being viewed.
  final String pubkey;

  Future<void> _onLoadRequested(
    OtherProfileLoadRequested event,
    Emitter<OtherProfileState> emit,
  ) async {
    // 1. Get cached profile from repository
    final cachedProfile = await _profileRepository.getCachedProfile(
      pubkey: pubkey,
    );
    emit(OtherProfileLoading(profile: cachedProfile));

    try {
      final freshProfile = await _profileRepository.fetchFreshProfile(
        pubkey: pubkey,
      );
      if (freshProfile != null) {
        emit(OtherProfileLoaded(profile: freshProfile, isFresh: true));
      } else if (cachedProfile != null) {
        emit(OtherProfileLoaded(profile: cachedProfile, isFresh: false));
      } else {
        emit(
          const OtherProfileError(errorType: OtherProfileErrorType.notFound),
        );
      }
    } catch (e) {
      if (cachedProfile != null) {
        emit(OtherProfileLoaded(profile: cachedProfile, isFresh: false));
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
      );
      if (freshProfile != null) {
        emit(OtherProfileLoaded(profile: freshProfile, isFresh: true));
      } else {
        emit(
          OtherProfileError(
            errorType: OtherProfileErrorType.notFound,
            profile: currentProfile,
          ),
        );
      }
    } catch (e) {
      if (currentProfile != null) {
        emit(OtherProfileLoaded(profile: currentProfile, isFresh: false));
      } else {
        emit(
          const OtherProfileError(
            errorType: OtherProfileErrorType.networkError,
          ),
        );
      }
    }
  }
}
