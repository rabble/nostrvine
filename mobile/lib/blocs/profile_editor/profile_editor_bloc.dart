// ABOUTME: BLoC for orchestrating profile save and username claiming
// ABOUTME: Handles rollback when username claim fails

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/models/user_profile.dart' as app_models;
import 'package:openvine/repositories/username_repository.dart';
import 'package:openvine/services/user_profile_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:profile_repository/profile_repository.dart';

part 'profile_editor_event.dart';
part 'profile_editor_state.dart';

/// BLoC for orchestrating profile publishing and username claiming.
class ProfileEditorBloc extends Bloc<ProfileEditorEvent, ProfileEditorState> {
  ProfileEditorBloc({
    required ProfileRepository profileRepository,
    required UsernameRepository usernameRepository,
    required UserProfileService userProfileService,
  }) : _profileRepository = profileRepository,
       _usernameRepository = usernameRepository,
       _userProfileService = userProfileService,
       super(const ProfileEditorState()) {
    on<ProfileSaved>(_onProfileSaved);
  }

  final ProfileRepository _profileRepository;
  final UsernameRepository _usernameRepository;
  final UserProfileService _userProfileService;

  Future<void> _onProfileSaved(
    ProfileSaved event,
    Emitter<ProfileEditorState> emit,
  ) async {
    emit(state.copyWith(status: ProfileEditorStatus.loading));

    final currentProfile = await _profileRepository.getProfile(
      pubkey: event.pubkey,
    );
    final nip05 = (event.username != null && event.username!.isNotEmpty)
        ? '${event.username}@divine.video'
        : null;

    Log.info(
      '📝 saveProfile: displayName=${event.displayName}, '
      'username=${event.username}, currentNip05=${currentProfile?.nip05}',
      name: 'ProfileEditorBloc',
    );

    // 1. Publish profile
    UserProfile savedProfile;
    try {
      savedProfile = await _profileRepository.saveProfileEvent(
        displayName: event.displayName,
        about: event.about,
        nip05: nip05,
        picture: event.picture,
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
    if (event.username == null || event.username!.isEmpty) {
      Log.info('📝 No username to claim, SUCCESS', name: 'ProfileEditorBloc');
      emit(state.copyWith(status: ProfileEditorStatus.success));
      return;
    }

    // 3. Claim username
    Log.info(
      '📝 Attempting to claim username: ${event.username}',
      name: 'ProfileEditorBloc',
    );

    final result = await _usernameRepository.register(
      username: event.username!,
      pubkey: event.pubkey,
    );

    final error = switch (result) {
      UsernameClaimSuccess() => null,
      UsernameClaimTaken() => ProfileEditorError.usernameTaken,
      UsernameClaimReserved() => ProfileEditorError.usernameReserved,
      UsernameClaimError() => ProfileEditorError.publishFailed,
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
        displayName: event.displayName,
        about: event.about,
        nip05: currentProfile?.nip05,
        picture: event.picture,
        currentProfile: currentProfile,
      );
      final appProfile = app_models.UserProfile.fromJson(rolledBack.toJson());
      await _userProfileService.updateCachedProfile(appProfile);
      Log.info('📝 Rollback complete', name: 'ProfileEditorBloc');
    } catch (e) {
      Log.error('Rollback failed: $e', name: 'ProfileEditorBloc');
    }

    emit(state.copyWith(status: ProfileEditorStatus.failure, error: error));
  }
}
