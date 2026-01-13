import 'dart:async';

import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/repositories/username_repository.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'profile_editor_notifier.g.dart';

/// Outcome of a profile save operation.
///
/// Used as the data type for [ProfileEditorNotifier] state.
/// Expected business outcomes are returned as [AsyncData], while
/// unexpected failures are returned as [AsyncError].
enum ProfileSaveResult {
  /// Profile and username (if provided) were saved successfully.
  success,

  /// Username is reserved; user should contact support.
  usernameReserved,

  /// Username is already taken by another user.
  usernameTaken,

  /// Failed to publish profile to Nostr relays.
  profilePublishFailed,
}

/// Provides the Profile Repository
@riverpod
ProfileRepository profileRepository(Ref ref) {
  final nostrClient = ref.watch(nostrServiceProvider);
  return ProfileRepository(nostrClient: nostrClient);
}

/// Notifier for orchestrating profile publishing and username claiming.
@riverpod
class ProfileEditorNotifier extends _$ProfileEditorNotifier {
  @override
  FutureOr<ProfileSaveResult?> build() {
    return null;
  }

  /// Saves profile metadata and optionally claims a username.
  ///
  /// The operation follows this sequence:
  /// 1. Publish profile to Nostr with the new nip05 (if username provided)
  /// 2. Claim the username via the name server
  /// 3. If claim fails, rollback by publishing profile without the nip05
  ///
  /// [pubkey] is the user's public key in hex format.
  /// [displayName] is required and will be shown as the user's name.
  /// [username] if provided, will be claimed as `username@divine.video`.
  Future<void> saveProfile({
    required String pubkey,
    required String displayName,
    String? about,
    String? username,
    String? picture,
  }) async {
    state = const AsyncLoading();
    final usernameRepository = ref.read(usernameRepositoryProvider);
    final profileRepository = ref.read(profileRepositoryProvider);
    final currentProfile = await profileRepository.getProfile(pubkey: pubkey);
    final nip05 = (username != null && username.isNotEmpty)
        ? '$username@divine.video'
        : null;

    try {
      await profileRepository.saveProfileEvent(
        displayName: displayName,
        about: about,
        nip05: nip05,
        picture: picture,
        currentProfile: currentProfile,
      );
    } catch (error, stackTrace) {
      Log.error(
        'Failed to publish profile: $error',
        name: 'ProfileEditorNotifier',
        error: error,
      );
      state = AsyncError(ProfileSaveResult.profilePublishFailed, stackTrace);
      return;
    }

    if (username == null) {
      state = const AsyncData(ProfileSaveResult.success);
      return;
    }

    final result = await usernameRepository.register(
      username: username,
      pubkey: pubkey,
    );
    state = switch (result) {
      UsernameClaimSuccess() => const AsyncData(ProfileSaveResult.success),
      UsernameClaimTaken() => const AsyncData(ProfileSaveResult.usernameTaken),
      UsernameClaimReserved() => const AsyncData(
        ProfileSaveResult.usernameReserved,
      ),
      UsernameClaimError() => AsyncError(result.message, StackTrace.current),
    };

    if (result is! UsernameClaimSuccess) {
      // Restores the user's previous nip05 after a failed username claim.
      try {
        await profileRepository.saveProfileEvent(
          displayName: displayName,
          about: about,
          nip05: currentProfile?.nip05,
          picture: picture,
          currentProfile: currentProfile,
        );
      } catch (error) {
        Log.error('Rollback failed: $error', name: 'ProfileEditorNotifier');
      }
    }
  }
}
