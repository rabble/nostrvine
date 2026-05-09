// ABOUTME: BLoC for orchestrating profile save and username claiming
// ABOUTME: Claims the username on the registry before publishing kind 0,
// ABOUTME: so kind 0 with a divine.video nip05 is never broadcast unless the
// ABOUTME: corresponding registry entry is in place. Owns the staged
// ABOUTME: avatar upload for the current edit session; Save remains the
// ABOUTME: only publish point.

import 'dart:io' show File;
import 'dart:typed_data';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:stream_transform/stream_transform.dart';
import 'package:unified_logger/unified_logger.dart';

part 'profile_editor_event.dart';
part 'profile_editor_state.dart';

/// Matches [DivineUsernameInvalid.reason] for length failures from
/// [validateDivineUsername].
String get _divineUsernameLengthFailureReason =>
    'Usernames must be $kDivineUsernameMinLength–$kDivineUsernameMaxLength characters';

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
    required BlossomUploadService blossomUploadService,
    required bool hasExistingProfile,
    String? currentUserPubkey,
  }) : _profileRepository = profileRepository,
       _blossomUploadService = blossomUploadService,
       _hasExistingProfile = hasExistingProfile,
       _currentUserPubkey = currentUserPubkey,
       super(const ProfileEditorState()) {
    on<InitialUsernameSet>(_onInitialUsernameSet);
    on<InitialPersistedPictureSet>(_onInitialPersistedPictureSet);
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
    // Drop concurrent upload requests while one is already in flight.
    // The UI disables avatar-source actions during upload; this prevents a
    // second file/bytes pick from interleaving if a caller dispatches anyway.
    on<ProfilePictureUploadRequested>(
      _onProfilePictureUploadRequested,
      transformer: droppable(),
    );
    on<ProfilePictureUploadCleared>(_onProfilePictureUploadCleared);
    on<ProfilePictureUrlSet>(_onProfilePictureUrlSet);
    on<VerifierLaunchRequested>(_onVerifierLaunchRequested);
    on<VerifierWebViewDismissed>(_onVerifierWebViewDismissed);
  }

  final ProfileRepository _profileRepository;
  final BlossomUploadService _blossomUploadService;
  final bool _hasExistingProfile;
  final String? _currentUserPubkey;

  void _onInitialUsernameSet(
    InitialUsernameSet event,
    Emitter<ProfileEditorState> emit,
  ) {
    emit(state.copyWith(initialUsername: event.username));
  }

  void _onInitialPersistedPictureSet(
    InitialPersistedPictureSet event,
    Emitter<ProfileEditorState> emit,
  ) {
    emit(state.copyWith(persistedPictureUrl: event.pictureUrl));
  }

  Future<void> _onProfilePictureUploadRequested(
    ProfilePictureUploadRequested event,
    Emitter<ProfileEditorState> emit,
  ) async {
    emit(state.copyWith(pendingAvatarStatus: PendingAvatarStatus.uploading));

    BlossomUploadResult result;
    try {
      if (event.bytes != null) {
        result = await _blossomUploadService.uploadImageBytes(
          bytes: event.bytes!,
          filename: event.filename ?? 'avatar.jpg',
          nostrPubkey: event.pubkey,
          mimeType: event.mimeType,
        );
      } else {
        result = await _blossomUploadService.uploadImage(
          imageFile: event.file!,
          nostrPubkey: event.pubkey,
          mimeType: event.mimeType,
        );
      }
    } on Object catch (error, stackTrace) {
      Log.error(
        'Avatar upload threw: $error',
        name: 'ProfileEditorBloc',
        category: LogCategory.ui,
      );
      addError(error, stackTrace);
      emit(
        state.copyWith(
          pendingAvatarStatus: PendingAvatarStatus.failed,
          avatarUploadError: AvatarUploadError.generic,
        ),
      );
      return;
    }

    if (result.success && (result.cdnUrl?.isNotEmpty ?? false)) {
      Log.info(
        '✅ Avatar staged: ${result.cdnUrl}',
        name: 'ProfileEditorBloc',
        category: LogCategory.ui,
      );
      emit(
        state.copyWith(
          pendingAvatarStatus: PendingAvatarStatus.staged,
          pendingPictureUrl: result.cdnUrl,
        ),
      );
      return;
    }

    // Failure surfaces via the bloc's error stream so the bloc observer logs
    // and Crashlytics flow keeps working. The classified `avatarUploadError`
    // on state lets the UI map to the right localized snackbar (per
    // `error_handling.md`: enums on state, not raw error strings).
    // `pendingPictureUrl` is intentionally left untouched: a failed retry
    // should not blank out a previously-staged picture.
    final errorMessage = result.errorMessage ?? 'Upload failed';
    Log.error(
      'Avatar upload failed: $errorMessage',
      name: 'ProfileEditorBloc',
      category: LogCategory.ui,
    );
    addError(Exception(errorMessage), StackTrace.current);
    emit(
      state.copyWith(
        pendingAvatarStatus: PendingAvatarStatus.failed,
        avatarUploadError: _mapUploadFailureReason(result.failureReason),
      ),
    );
  }

  /// Maps the upload-service failure classification into the bloc's UI-facing
  /// avatar error enum.
  AvatarUploadError _mapUploadFailureReason(
    BlossomUploadFailureReason? failureReason,
  ) {
    return switch (failureReason ?? BlossomUploadFailureReason.unknown) {
      BlossomUploadFailureReason.network => AvatarUploadError.network,
      BlossomUploadFailureReason.auth => AvatarUploadError.auth,
      BlossomUploadFailureReason.fileTooLarge => AvatarUploadError.fileTooLarge,
      BlossomUploadFailureReason.server => AvatarUploadError.server,
      BlossomUploadFailureReason.unknown => AvatarUploadError.generic,
    };
  }

  void _onProfilePictureUploadCleared(
    ProfilePictureUploadCleared event,
    Emitter<ProfileEditorState> emit,
  ) {
    emit(
      state.copyWith(
        pendingAvatarStatus: PendingAvatarStatus.idle,
        pendingPictureUrl: null,
      ),
    );
  }

  void _onProfilePictureUrlSet(
    ProfilePictureUrlSet event,
    Emitter<ProfileEditorState> emit,
  ) {
    if (state.pendingAvatarStatus == PendingAvatarStatus.uploading) {
      Log.info(
        'Ignoring ProfilePictureUrlSet received while avatar upload is in flight',
        name: 'ProfileEditorBloc',
      );
      return;
    }

    final trimmed = event.url.trim();
    if (trimmed.isEmpty) {
      emit(
        state.copyWith(
          pendingAvatarStatus: PendingAvatarStatus.idle,
          pendingPictureUrl: null,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        pendingAvatarStatus: PendingAvatarStatus.staged,
        pendingPictureUrl: trimmed,
      ),
    );
  }

  Future<void> _onProfileSaved(
    ProfileSaved event,
    Emitter<ProfileEditorState> emit,
  ) async {
    // Drop the save when an avatar upload is still in flight. Without this
    // guard, `_resolveEffectivePicture` would fall back to
    // `persistedPictureUrl` and publish kind 0 with the OLD picture, then
    // the staged URL would land and the user would have to Save again. The
    // UI also disables Save during upload (via `isSaveReady`); this is the
    // belt-and-braces so any other caller — retry CTAs, future events —
    // can't slip past.
    if (state.pendingAvatarStatus == PendingAvatarStatus.uploading) {
      Log.info(
        'Ignoring ProfileSaved received while avatar upload is in flight',
        name: 'ProfileEditorBloc',
      );
      return;
    }

    // The effective picture is owned by bloc state (staged > persisted),
    // with `event.picture` as a legacy fallback for callers that haven't
    // migrated to the staged-state model yet.
    final effectivePicture = _resolveEffectivePicture(event);

    // Guard: about to overwrite existing profile with minimal data?
    if (!_hasExistingProfile && _isMinimal(event, effectivePicture)) {
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

    await _saveProfile(event, effectivePicture, emit);
  }

  /// Picture URL the next save should write into kind 0.
  ///
  /// Priority: staged URL on bloc state > caller-supplied `event.picture`
  /// (legacy fallback) > persisted URL on bloc state. An empty string is
  /// treated as "no picture" at every level.
  String? _resolveEffectivePicture(ProfileSaved event) {
    final staged = state.pendingPictureUrl?.trim();
    if (staged != null && staged.isNotEmpty) return staged;
    final fromEvent = event.picture?.trim();
    if (fromEvent != null && fromEvent.isNotEmpty) return fromEvent;
    final persisted = state.persistedPictureUrl?.trim();
    if (persisted != null && persisted.isNotEmpty) return persisted;
    return null;
  }

  /// Whether the resolved profile data is minimal enough to require user
  /// confirmation before overwriting an existing profile (or creating one
  /// from scratch).
  bool _isMinimal(ProfileSaved event, String? effectivePicture) {
    final hasShortDisplayName = event.displayName.trim().length < 3;
    final hasNoBio = event.about?.trim().isEmpty ?? true;
    final hasNoPicture =
        effectivePicture == null || effectivePicture.trim().isEmpty;
    return hasShortDisplayName && hasNoBio && hasNoPicture;
  }

  Future<void> _onProfileSaveConfirmed(
    ProfileSaveConfirmed event,
    Emitter<ProfileEditorState> emit,
  ) async {
    final pending = state.pendingEvent;
    if (pending == null) {
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

    await _saveProfile(pending, _resolveEffectivePicture(pending), emit);
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

    final validation = validateDivineUsername(rawUsername);
    if (validation case DivineUsernameInvalid(:final reason)) {
      final isLength = reason == _divineUsernameLengthFailureReason;
      emit(
        state.copyWith(
          username: username,
          usernameStatus: isLength
              ? UsernameStatus.error
              : UsernameStatus.invalidFormat,
          usernameError: isLength
              ? UsernameValidationError.invalidLength
              : UsernameValidationError.invalidFormat,
          usernameFormatMessage: isLength ? null : reason,
        ),
      );
      return;
    }

    final normalized = (validation as DivineUsernameValid).normalized;

    if (state.reservedUsernames.contains(normalized)) {
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
    if (initial != null && normalized == initial.toLowerCase()) {
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
      username: normalized,
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
            reservedUsernames: {...state.reservedUsernames, normalized},
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

    final validation = validateDivineUsername(username);
    if (validation case DivineUsernameInvalid()) {
      return;
    }
    final normalized = (validation as DivineUsernameValid).normalized;

    // Remove from local reserved cache so the check runs against the server
    final updatedReserved = {...state.reservedUsernames}..remove(normalized);

    emit(
      state.copyWith(
        usernameStatus: UsernameStatus.checking,
        reservedUsernames: updatedReserved,
      ),
    );

    final result = await _profileRepository.checkUsernameAvailability(
      username: normalized,
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
            reservedUsernames: {...state.reservedUsernames, normalized},
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
            reservedUsernames: {...state.reservedUsernames, normalized},
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
    String? effectivePicture,
    Emitter<ProfileEditorState> emit,
  ) async {
    emit(state.copyWith(status: ProfileEditorStatus.loading));

    final displayName = event.displayName.trim();
    final about = (event.about?.trim().isEmpty ?? true) ? null : event.about;

    // Bloc decides which NIP-05 value to use based on current mode
    final isExternal = state.nip05Mode == Nip05Mode.external_;
    final trimmedUsername = event.username?.trim();
    final username = isExternal || (trimmedUsername?.isEmpty ?? true)
        ? null
        : switch (validateDivineUsername(trimmedUsername!)) {
            DivineUsernameValid(:final normalized) => normalized,
            DivineUsernameInvalid() => trimmedUsername,
          };
    final externalNip05 =
        !isExternal || (event.externalNip05?.trim().isEmpty ?? true)
        ? null
        : event.externalNip05?.trim().toLowerCase();

    // Only clear NIP-05 when the user explicitly removes a verified handle
    // they were known to have: their initialUsername or initialExternalNip05
    // was loaded by the editor and they are now opting out of it.
    //
    // When both are null the editor never loaded the user's existing NIP-05
    // (e.g. relay race returning an older Kind 0, stale cache). Treating that
    // as an opt-out would silently destroy a verified handle the user never
    // intended to remove — exactly the bug that caused #4012.
    final clearNip05 =
        !isExternal &&
        username == null &&
        (state.initialUsername != null || state.initialExternalNip05 != null);
    final picture = effectivePicture;
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

  void _onVerifierLaunchRequested(
    VerifierLaunchRequested event,
    Emitter<ProfileEditorState> emit,
  ) {
    emit(state.copyWith(verifierStatus: VerifierStatus.launchRequested));
  }

  void _onVerifierWebViewDismissed(
    VerifierWebViewDismissed event,
    Emitter<ProfileEditorState> emit,
  ) {
    emit(state.copyWith(verifierStatus: VerifierStatus.dismissed));
  }
}
