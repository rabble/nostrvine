// ABOUTME: BLoC for orchestrating profile save and username claiming
// ABOUTME: Handles rollback when username claim fails

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/models/user_profile.dart' as app_models;
import 'package:openvine/services/user_profile_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:stream_transform/stream_transform.dart';

part 'profile_editor_event.dart';
part 'profile_editor_state.dart';

/// Minimum username length.
const _minUsernameLength = 3;

/// Maximum username length.
const _maxUsernameLength = 20;

/// Username format: letters, numbers, hyphens, underscores, periods.
final _usernamePattern = RegExp(r'^[a-zA-Z0-9._-]+$');

/// Debounce duration for username validation
const _debounceDuration = Duration(milliseconds: 500);

/// Event transformer that debounces and restarts on new events
EventTransformer<E> _debounceRestartable<E>() {
  return (events, mapper) {
    return restartable<E>().call(events.debounce(_debounceDuration), mapper);
  };
}

/// BLoC for orchestrating profile publishing and username claiming.
class ProfileEditorBloc extends Bloc<ProfileEditorEvent, ProfileEditorState> {
  ProfileEditorBloc({
    required ProfileRepository profileRepository,
    required UserProfileService userProfileService,
    required bool hasExistingProfile,
  }) : _profileRepository = profileRepository,
       _userProfileService = userProfileService,
       _hasExistingProfile = hasExistingProfile,
       super(const ProfileEditorState()) {
    on<ProfileSaved>(_onProfileSaved);
    on<ProfileSaveConfirmed>(_onProfileSaveConfirmed);
    on<UsernameChanged>(
      _onUsernameChanged,
      transformer: _debounceRestartable(),
    );
  }

  final ProfileRepository _profileRepository;
  final UserProfileService _userProfileService;
  final bool _hasExistingProfile;

  Future<void> _onProfileSaved(
    ProfileSaved event,
    Emitter<ProfileEditorState> emit,
  ) async {
    // Guard: Check if we're about to overwrite existing profile with minimal data
    if (!_hasExistingProfile && event.isMinimal) {
      Log.info(
        '⚠️ Blank profile warning: no existing profile found, requesting confirmation',
        name: 'ProfileEditorBloc',
      );
      emit(
        state.copyWith(
          status: ProfileEditorStatus.confirmationRequired,
          pendingEvent: event,
        ),
      );
      return;
    }

    await _saveProfile(event, emit);
  }

  Future<void> _onProfileSaveConfirmed(
    ProfileSaveConfirmed event,
    Emitter<ProfileEditorState> emit,
  ) async {
    if (state.pendingEvent == null) {
      Log.error(
        'ProfileSaveConfirmed called without pending event',
        name: 'ProfileEditorBloc',
      );
      return;
    }

    Log.info(
      '✅ User confirmed blank profile publish',
      name: 'ProfileEditorBloc',
    );

    await _saveProfile(state.pendingEvent!, emit);
  }

  Future<void> _onUsernameChanged(
    UsernameChanged event,
    Emitter<ProfileEditorState> emit,
  ) async {
    final rawUsername = event.username;
    final username = rawUsername.trim();

    if (username.isEmpty) {
      emit(
        state.copyWith(
          username: username,
          usernameStatus: UsernameStatus.idle,
          usernameError: null,
        ),
      );
      return;
    }

    if (!_usernamePattern.hasMatch(rawUsername)) {
      emit(
        state.copyWith(
          username: username,
          usernameStatus: UsernameStatus.error,
          usernameError: UsernameValidationError.invalidFormat,
        ),
      );
      return;
    }

    // Then check length
    if (username.length < _minUsernameLength ||
        username.length > _maxUsernameLength) {
      emit(
        state.copyWith(
          username: username,
          usernameStatus: UsernameStatus.error,
          usernameError: UsernameValidationError.invalidLength,
        ),
      );
      return;
    }

    if (state.reservedUsernames.contains(username)) {
      emit(
        state.copyWith(
          username: username,
          usernameStatus: UsernameStatus.reserved,
          usernameError: null,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        username: username,
        usernameStatus: UsernameStatus.checking,
        usernameError: null,
      ),
    );

    final result = await _profileRepository.checkUsernameAvailability(
      username: username,
    );

    switch (result) {
      case UsernameAvailable():
        emit(
          state.copyWith(
            usernameStatus: UsernameStatus.available,
            usernameError: null,
          ),
        );
      case UsernameTaken():
        emit(
          state.copyWith(
            usernameStatus: UsernameStatus.taken,
            usernameError: null,
          ),
        );
      case UsernameCheckError(:final message):
        Log.error(
          'Username availability check failed: $message',
          name: 'ProfileEditorBloc',
        );
        emit(
          state.copyWith(
            usernameStatus: UsernameStatus.error,
            usernameError: UsernameValidationError.networkError,
          ),
        );
    }
  }

  /// Core profile save logic (extracted for reuse)
  Future<void> _saveProfile(
    ProfileSaved event,
    Emitter<ProfileEditorState> emit,
  ) async {
    emit(state.copyWith(status: ProfileEditorStatus.loading));

    final displayName = event.displayName.trim();
    final about = (event.about?.trim().isEmpty ?? true) ? null : event.about;
    final username = (event.username?.trim().isEmpty ?? true)
        ? null
        : event.username;
    final picture = (event.picture?.trim().isEmpty ?? true)
        ? null
        : event.picture;
    final banner = (event.banner?.trim().isEmpty ?? true) ? null : event.banner;

    final currentProfile = await _profileRepository.getCachedProfile(
      pubkey: event.pubkey,
    );
    final nip05 = username != null ? '_@$username.divine.video' : null;

    Log.info(
      '📝 saveProfile: displayName=$displayName, '
      'username=$username, currentNip05=${currentProfile?.nip05}',
      name: 'ProfileEditorBloc',
    );

    // 1. Publish profile
    UserProfile savedProfile;
    try {
      savedProfile = await _profileRepository.saveProfileEvent(
        displayName: displayName,
        about: about,
        nip05: nip05,
        picture: picture,
        banner: banner,
        currentProfile: currentProfile,
      );
      Log.info(
        '📝 Profile published: nip05=${savedProfile.nip05}',
        name: 'ProfileEditorBloc',
      );
      // TODO(Josh-Sanford): Move cache into ProfileRepository and remove
      // UserProfileService dependency
      final appProfile = app_models.UserProfile.fromJson(savedProfile.toJson());
      await _userProfileService.updateCachedProfile(appProfile);
    } catch (error) {
      Log.error('Failed to publish profile: $error', name: 'ProfileEditorBloc');
      emit(
        state.copyWith(
          status: ProfileEditorStatus.failure,
          error: ProfileEditorError.publishFailed,
        ),
      );
      return;
    }

    // 2. No username to claim - done
    if (username == null) {
      Log.info('📝 No username to claim, SUCCESS', name: 'ProfileEditorBloc');
      emit(state.copyWith(status: ProfileEditorStatus.success));
      return;
    }

    // 3. Claim username
    Log.info(
      '📝 Attempting to claim username: $username',
      name: 'ProfileEditorBloc',
    );

    final result = await _profileRepository.claimUsername(username: username);

    Log.info('📝 Username claim result: $result', name: 'ProfileEditorBloc');

    final error = switch (result) {
      UsernameClaimSuccess() => null,
      UsernameClaimTaken() => ProfileEditorError.usernameTaken,
      UsernameClaimReserved() => ProfileEditorError.usernameReserved,
      UsernameClaimError() => ProfileEditorError.claimFailed,
    };

    if (error == null) {
      Log.info('📝 Username claim SUCCESS', name: 'ProfileEditorBloc');
      emit(state.copyWith(status: ProfileEditorStatus.success));
      return;
    }

    // 4. Rollback on failure
    Log.info(
      '📝 Rolling back to nip05=${currentProfile?.nip05}',
      name: 'ProfileEditorBloc',
    );
    try {
      final rolledBack = await _profileRepository.saveProfileEvent(
        displayName: displayName,
        about: about,
        nip05: currentProfile?.nip05,
        picture: picture,
        banner: banner,
        currentProfile: currentProfile,
      );
      final appProfile = app_models.UserProfile.fromJson(rolledBack.toJson());
      await _userProfileService.updateCachedProfile(appProfile);
      Log.info('📝 Rollback complete', name: 'ProfileEditorBloc');
    } catch (e) {
      Log.error('Rollback failed: $e', name: 'ProfileEditorBloc');
    }

    final usernameStatus = switch (error) {
      ProfileEditorError.usernameReserved => UsernameStatus.reserved,
      ProfileEditorError.usernameTaken => UsernameStatus.taken,
      _ => null,
    };

    final reservedUsernames = usernameStatus == UsernameStatus.reserved
        ? {...state.reservedUsernames, username}
        : null;

    emit(
      state.copyWith(
        status: ProfileEditorStatus.failure,
        error: error,
        usernameStatus: usernameStatus,
        reservedUsernames: reservedUsernames,
      ),
    );
  }
}

/// Extension for checking if profile data is minimal/blank.
extension _ProfileDataMinimal on ProfileSaved {
  /// Whether this profile data is minimal.
  ///
  /// A profile is considered minimal if:
  /// - Display name is very short (< 3 chars)
  /// - No bio
  /// - No picture
  bool get isMinimal {
    final trimmedDisplayName = displayName.trim();
    final trimmedAbout = about?.trim();
    final trimmedPicture = picture?.trim();

    final hasMinimalDisplayName = trimmedDisplayName.length < 3;
    final hasNoBio = trimmedAbout == null || trimmedAbout.isEmpty;
    final hasNoPicture = trimmedPicture == null || trimmedPicture.isEmpty;

    return hasMinimalDisplayName && hasNoBio && hasNoPicture;
  }
}
