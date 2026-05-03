// ABOUTME: BLoC for orchestrating profile save and username claiming
// ABOUTME: Claims the username on the registry before publishing kind 0,
// ABOUTME: so kind 0 with a divine.video nip05 is never broadcast unless the
// ABOUTME: corresponding registry entry is in place.

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:stream_transform/stream_transform.dart';
import 'package:unified_logger/unified_logger.dart';

part 'profile_editor_event.dart';
part 'profile_editor_state.dart';

/// Minimum username length.
const _minUsernameLength = 3;

/// Maximum username length.
const _maxUsernameLength = 20;

/// Username format: lowercase letters, numbers, hyphens, underscores, periods.
/// NIP-05 local parts are lowercase-only (a-z0-9-_.) per spec.
final _usernamePattern = RegExp(r'^[a-z0-9._-]+$');

/// External NIP-05 format: `local-part@domain` per NIP-05 spec.
/// Local part: a-z0-9-_. (lowercase only).
/// Domain: standard DNS format with at least one dot and 2+ char TLD.
final _externalNip05Pattern = RegExp(
  r'^[a-z0-9._-]+@([a-z0-9-]+\.)+[a-z]{2,}$',
);

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
    required bool hasExistingProfile,
    String? currentUserPubkey,
  }) : _profileRepository = profileRepository,
       _hasExistingProfile = hasExistingProfile,
       _currentUserPubkey = currentUserPubkey,
       super(const ProfileEditorState()) {
    on<InitialUsernameSet>(_onInitialUsernameSet);
    on<ProfileSaved>(_onProfileSaved);
    on<ProfileSaveConfirmed>(_onProfileSaveConfirmed);
    on<UsernameChanged>(
      _onUsernameChanged,
      transformer: _debounceRestartable(),
    );
    on<Nip05ModeChanged>(_onNip05ModeChanged);
    on<ExternalNip05Changed>(_onExternalNip05Changed);
    on<InitialExternalNip05Set>(_onInitialExternalNip05Set);
    on<UsernameRechecked>(_onUsernameRechecked);
  }

  final ProfileRepository _profileRepository;
  final bool _hasExistingProfile;
  final String? _currentUserPubkey;

  void _onInitialUsernameSet(
    InitialUsernameSet event,
    Emitter<ProfileEditorState> emit,
  ) {
    emit(state.copyWith(initialUsername: event.username));
  }

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
        state.copyWith(username: username, usernameStatus: UsernameStatus.idle),
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
        ),
      );
      return;
    }

    // Skip API check if username matches the user's own claimed username
    final initial = state.initialUsername;
    if (initial != null && username == initial.toLowerCase()) {
      emit(
        state.copyWith(username: username, usernameStatus: UsernameStatus.idle),
      );
      return;
    }

    emit(
      state.copyWith(
        username: username,
        usernameStatus: UsernameStatus.checking,
      ),
    );

    final result = await _profileRepository.checkUsernameAvailability(
      username: username,
      currentUserPubkey: _currentUserPubkey,
    );

    switch (result) {
      case UsernameAvailable():
        emit(state.copyWith(usernameStatus: UsernameStatus.available));
      case UsernameTaken():
        emit(state.copyWith(usernameStatus: UsernameStatus.taken));
      case UsernameReserved():
        emit(
          state.copyWith(
            usernameStatus: UsernameStatus.reserved,
            reservedUsernames: {...state.reservedUsernames, username},
          ),
        );
      case UsernameBurned():
        emit(state.copyWith(usernameStatus: UsernameStatus.burned));
      case UsernameInvalidFormat(:final reason):
        emit(
          state.copyWith(
            usernameStatus: UsernameStatus.invalidFormat,
            usernameError: UsernameValidationError.invalidFormat,
            usernameFormatMessage: reason,
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

  void _onNip05ModeChanged(
    Nip05ModeChanged event,
    Emitter<ProfileEditorState> emit,
  ) {
    if (event.mode == Nip05Mode.divine) {
      // Switching back to divine mode — clear external NIP-05 state
      emit(state.copyWith(nip05Mode: Nip05Mode.divine, externalNip05: ''));
    } else {
      // Switching to external mode — reset divine username status to idle
      emit(
        state.copyWith(
          nip05Mode: Nip05Mode.external_,
          usernameStatus: UsernameStatus.idle,
        ),
      );
    }
  }

  void _onExternalNip05Changed(
    ExternalNip05Changed event,
    Emitter<ProfileEditorState> emit,
  ) {
    final nip05 = event.nip05.trim().toLowerCase();

    if (nip05.isEmpty) {
      emit(state.copyWith(externalNip05: nip05));
      return;
    }

    // Validate format: must match local-part@domain per NIP-05 spec
    if (!_externalNip05Pattern.hasMatch(nip05)) {
      emit(
        state.copyWith(
          externalNip05: nip05,
          externalNip05Error: ExternalNip05ValidationError.invalidFormat,
        ),
      );
      return;
    }

    // Reject divine.video / openvine.co domains — use divine mode instead
    final domain = nip05.split('@').last;
    if (domain == 'divine.video' ||
        domain.endsWith('.divine.video') ||
        domain == 'openvine.co' ||
        domain.endsWith('.openvine.co')) {
      emit(
        state.copyWith(
          externalNip05: nip05,
          externalNip05Error: ExternalNip05ValidationError.divineDomain,
        ),
      );
      return;
    }

    // Valid format — no API check needed for external NIP-05
    emit(state.copyWith(externalNip05: nip05));
  }

  void _onInitialExternalNip05Set(
    InitialExternalNip05Set event,
    Emitter<ProfileEditorState> emit,
  ) {
    emit(state.copyWith(initialExternalNip05: event.nip05));
  }

  /// Re-checks a previously reserved username against the nameserver.
  ///
  /// Removes the username from the local reserved cache and performs a fresh
  /// availability check. If support has released the name to this user, the
  /// nameserver will return it as available (owner matches current pubkey).
  Future<void> _onUsernameRechecked(
    UsernameRechecked event,
    Emitter<ProfileEditorState> emit,
  ) async {
    final username = state.username;
    if (username.isEmpty) return;

    // Remove from local reserved cache so the check runs against the server
    final updatedReserved = {...state.reservedUsernames}..remove(username);

    emit(
      state.copyWith(
        usernameStatus: UsernameStatus.checking,
        reservedUsernames: updatedReserved,
      ),
    );

    final result = await _profileRepository.checkUsernameAvailability(
      username: username,
      currentUserPubkey: _currentUserPubkey,
    );

    switch (result) {
      case UsernameAvailable():
        emit(state.copyWith(usernameStatus: UsernameStatus.available));
      case UsernameTaken():
        emit(state.copyWith(usernameStatus: UsernameStatus.taken));
      case UsernameReserved():
        emit(
          state.copyWith(
            usernameStatus: UsernameStatus.reserved,
            reservedUsernames: {...state.reservedUsernames, username},
          ),
        );
      case UsernameBurned():
        emit(state.copyWith(usernameStatus: UsernameStatus.burned));
      case UsernameInvalidFormat(:final reason):
        emit(
          state.copyWith(
            usernameStatus: UsernameStatus.invalidFormat,
            usernameError: UsernameValidationError.invalidFormat,
            usernameFormatMessage: reason,
          ),
        );
      case UsernameCheckError(:final message):
        Log.error(
          'Username re-check failed: $message',
          name: 'ProfileEditorBloc',
        );
        emit(
          state.copyWith(
            usernameStatus: UsernameStatus.reserved,
            reservedUsernames: {...state.reservedUsernames, username},
          ),
        );
    }
  }

  /// Core profile save logic (extracted for reuse).
  ///
  /// Order of operations is **claim first, publish second**: when a divine.video
  /// username is requested, the registry claim runs before the kind 0 metadata
  /// event is broadcast. Kind 0 is gossiped to relays and effectively immutable
  /// once sent, so publishing it before confirming the claim could leave the
  /// user advertising a `_@<name>.divine.video` identifier that the registry
  /// has no record of — irrecoverable without manual intervention.
  Future<void> _saveProfile(
    ProfileSaved event,
    Emitter<ProfileEditorState> emit,
  ) async {
    emit(state.copyWith(status: ProfileEditorStatus.loading));

    final displayName = event.displayName.trim();
    final about = (event.about?.trim().isEmpty ?? true) ? null : event.about;

    // Bloc decides which NIP-05 value to use based on current mode
    final isExternal = state.nip05Mode == Nip05Mode.external_;
    final username = isExternal || (event.username?.trim().isEmpty ?? true)
        ? null
        : event.username;
    final externalNip05 =
        !isExternal || (event.externalNip05?.trim().isEmpty ?? true)
        ? null
        : event.externalNip05?.trim().toLowerCase();

    // Explicitly clear NIP-05 when in divine mode with no username. Without
    // this flag, saveProfileEvent would silently preserve the existing NIP-05
    // from currentProfile.rawData even though the user opted out of both modes.
    final clearNip05 = !isExternal && username == null;
    final picture = (event.picture?.trim().isEmpty ?? true)
        ? null
        : event.picture;
    final banner = (event.banner?.trim().isEmpty ?? true) ? null : event.banner;

    final currentProfile = await _profileRepository.getCachedProfile(
      pubkey: event.pubkey,
    );

    Log.info(
      '📝 saveProfile: displayName=$displayName, '
      'username=$username, externalNip05=$externalNip05, '
      'currentNip05=${currentProfile?.nip05}',
      name: 'ProfileEditorBloc',
    );

    // 1. Claim the divine.video username FIRST when one is requested.
    //
    // If the claim fails for any reason — taken, reserved, network error,
    // server unreachable — we abort *before* publishing kind 0. This keeps
    // the user's metadata in sync with the registry by construction.
    if (username != null) {
      Log.info(
        '📝 Attempting to claim username: $username',
        name: 'ProfileEditorBloc',
      );

      final result = await _profileRepository.claimUsername(username: username);

      Log.info('📝 Username claim result: $result', name: 'ProfileEditorBloc');

      final claimError = switch (result) {
        UsernameClaimSuccess() => null,
        UsernameClaimTaken() => ProfileEditorError.usernameTaken,
        UsernameClaimReserved() => ProfileEditorError.usernameReserved,
        UsernameClaimError() => ProfileEditorError.claimFailed,
      };

      if (claimError != null) {
        final usernameStatus = switch (claimError) {
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
            error: claimError,
            usernameStatus: usernameStatus,
            reservedUsernames: reservedUsernames,
          ),
        );
        return;
      }
    }

    // 2. Publish kind 0 metadata. By this point either no divine.video
    // username was requested, or the claim has been confirmed.
    try {
      final savedProfile = await _profileRepository.saveProfileEvent(
        displayName: displayName,
        about: about,
        username: username,
        nip05: externalNip05,
        clearNip05: clearNip05,
        picture: picture,
        banner: banner,
        currentProfile: currentProfile,
      );
      Log.info(
        '📝 Profile published: nip05=${savedProfile.nip05}',
        name: 'ProfileEditorBloc',
      );
      await _profileRepository.cacheProfile(savedProfile);
      emit(state.copyWith(status: ProfileEditorStatus.success));
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      Log.error('Failed to publish profile: $error', name: 'ProfileEditorBloc');
      final profileError = error is NoRelaysConnectedException
          ? ProfileEditorError.noRelaysConnected
          : ProfileEditorError.publishFailed;
      emit(
        state.copyWith(
          status: ProfileEditorStatus.failure,
          error: profileError,
        ),
      );
    }
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
