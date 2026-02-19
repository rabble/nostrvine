// ABOUTME: BLoC for loading the current user's own profile for editing
// ABOUTME: Implements cache+fresh pattern and extracts divine.video username

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:profile_repository/profile_repository.dart';

part 'my_profile_event.dart';
part 'my_profile_state.dart';

/// BLoC for loading the current user's own profile for editing.
///
/// Implements the cache+fresh pattern:
/// 1. On [MyProfileLoadRequested], emit cached profile immediately
/// 2. Fetch fresh profile from relay
/// 3. Extract divine.video username from NIP-05 if present
/// 4. Emit loaded state with profile and extracted username
///
/// The [pubkey] is provided at construction time since this BLoC is scoped
/// to a single profile editor screen instance.
class MyProfileBloc extends Bloc<MyProfileEvent, MyProfileState> {
  MyProfileBloc({
    required ProfileRepository profileRepository,
    required this.pubkey,
  }) : _profileRepository = profileRepository,
       super(const MyProfileInitial()) {
    on<MyProfileLoadRequested>(_onLoadRequested);
  }

  final ProfileRepository _profileRepository;

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
          ),
        );
      } else if (cachedProfile != null) {
        emit(
          MyProfileLoaded(
            profile: cachedProfile,
            isFresh: false,
            extractedUsername: cachedProfile.divineUsername,
          ),
        );
      } else {
        emit(const MyProfileError(errorType: MyProfileErrorType.notFound));
      }
    } catch (e) {
      if (cachedProfile != null) {
        emit(
          MyProfileLoaded(
            profile: cachedProfile,
            isFresh: false,
            extractedUsername: cachedProfile.divineUsername,
          ),
        );
      } else {
        emit(const MyProfileError(errorType: MyProfileErrorType.networkError));
      }
    }
  }
}
