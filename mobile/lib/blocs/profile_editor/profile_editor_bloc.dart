// ABOUTME: BLoC for orchestrating profile save and username claiming
// ABOUTME: Claims the username on the registry before publishing kind 0,
// ABOUTME: so kind 0 with a divine.video nip05 is never broadcast unless the
// ABOUTME: corresponding registry entry is in place. Owns the staged
// ABOUTME: avatar upload for the current edit session; Save remains the
// ABOUTME: only publish point.

import 'dart:io' show File;
import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/profile_editor/reportable_sites.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/mention_resolution_service.dart';
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
    MentionResolutionService? mentionResolutionService,
    String? currentUserPubkey,
  }) : _profileRepository = profileRepository,
       _blossomUploadService = blossomUploadService,
       _hasExistingProfile = hasExistingProfile,
       _mentionResolutionService =
           mentionResolutionService ??
           MentionResolutionService(profileRepository: profileRepository),
       _currentUserPubkey = currentUserPubkey,
       super(const ProfileEditorState()) {
    on<InitialUsernameSet>(_onInitialUsernameSet);
    on<InitialPersistedPictureSet>(_onInitialPersistedPictureSet);
    on<ProfileSaved>(_onProfileSaved);
    on<ProfileNip05Saved>(_onProfileNip05Saved);
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
    on<InitialPersistedBannerSet>(_onInitialPersistedBannerSet);
    on<ProfileBannerUploadRequested>(
      _onProfileBannerUploadRequested,
      transformer: droppable(),
    );
    on<ProfileBannerColorSelected>(_onProfileBannerColorSelected);
    on<ProfileBannerCleared>(_onProfileBannerCleared);
    on<VerifierLaunchRequested>(_onVerifierLaunchRequested);
    on<VerifierWebViewDismissed>(_onVerifierWebViewDismissed);
  }

  final ProfileRepository _profileRepository;
  final BlossomUploadService _blossomUploadService;
  final bool _hasExistingProfile;
  final MentionResolutionService _mentionResolutionService;
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
      // Classification: Network/IO — matrix-NO. Catch sees `DioException` /
      // `BlossomResumableUploadException` rethrown by `BlossomUploadService`.
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
    // Classification: API/domain — matrix-NO. `Exception(...)` is synthesized
    // from a documented `success: false` result with a typed `failureReason`.
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

  void _onInitialPersistedBannerSet(
    InitialPersistedBannerSet event,
    Emitter<ProfileEditorState> emit,
  ) {
    final banner = event.banner;
    final parsedColor = _parseBannerHexColor(banner);
    emit(
      state.copyWith(
        persistedBanner: banner,
        pendingBannerColor: parsedColor,
      ),
    );
  }

  /// Parses a banner string into a [Color] when it looks like a hex color.
  ///
  /// Accepts `0xRRGGBB`, `#RRGGBB`, or bare `RRGGBB`. Returns `null` for
  /// URLs, empty strings, and malformed input. Mirrors the parser in
  /// `UserProfileUtils.profileBackgroundColor` to keep the seeding behavior
  /// in lockstep with how the rest of the app reads `banner` as a color.
  Color? _parseBannerHexColor(String? banner) {
    if (banner == null || banner.isEmpty) return null;
    var hex = banner;
    if (hex.startsWith('0x')) {
      hex = hex.substring(2);
    } else if (hex.startsWith('#')) {
      hex = hex.substring(1);
    } else if (hex.startsWith('http')) {
      return null;
    }
    if (hex.length != 6) return null;
    final value = int.tryParse(hex, radix: 16);
    if (value == null) return null;
    return Color(0xFF000000 | value);
  }

  Future<void> _onProfileBannerUploadRequested(
    ProfileBannerUploadRequested event,
    Emitter<ProfileEditorState> emit,
  ) async {
    emit(state.copyWith(pendingBannerStatus: PendingBannerStatus.uploading));

    BlossomUploadResult result;
    try {
      if (event.bytes != null) {
        result = await _blossomUploadService.uploadImageBytes(
          bytes: event.bytes!,
          filename: event.filename ?? 'banner.jpg',
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
        'Banner upload threw: $error',
        name: 'ProfileEditorBloc',
        category: LogCategory.ui,
      );
      // Classification: Network/IO — matrix-NO. Catch sees `DioException` /
      // `BlossomResumableUploadException` rethrown by `BlossomUploadService`.
      addError(error, stackTrace);
      emit(
        state.copyWith(
          pendingBannerStatus: PendingBannerStatus.failed,
          bannerUploadError: BannerUploadError.generic,
        ),
      );
      return;
    }

    if (result.success && (result.cdnUrl?.isNotEmpty ?? false)) {
      Log.info(
        '✅ Banner staged: ${result.cdnUrl}',
        name: 'ProfileEditorBloc',
        category: LogCategory.ui,
      );
      emit(
        state.copyWith(
          pendingBannerStatus: PendingBannerStatus.staged,
          pendingBannerUrl: result.cdnUrl,
          // Image and color are mutually exclusive — clear any staged color.
          pendingBannerColor: null,
        ),
      );
      return;
    }

    final errorMessage = result.errorMessage ?? 'Upload failed';
    Log.error(
      'Banner upload failed: $errorMessage',
      name: 'ProfileEditorBloc',
      category: LogCategory.ui,
    );
    // Classification: API/domain — matrix-NO. `Exception(...)` is synthesized
    // from a documented `success: false` result with a typed `failureReason`.
    addError(Exception(errorMessage), StackTrace.current);
    emit(
      state.copyWith(
        pendingBannerStatus: PendingBannerStatus.failed,
        bannerUploadError: _mapBannerUploadFailureReason(result.failureReason),
      ),
    );
  }

  BannerUploadError _mapBannerUploadFailureReason(
    BlossomUploadFailureReason? failureReason,
  ) {
    return switch (failureReason ?? BlossomUploadFailureReason.unknown) {
      BlossomUploadFailureReason.network => BannerUploadError.network,
      BlossomUploadFailureReason.auth => BannerUploadError.auth,
      BlossomUploadFailureReason.fileTooLarge => BannerUploadError.fileTooLarge,
      BlossomUploadFailureReason.server => BannerUploadError.server,
      BlossomUploadFailureReason.unknown => BannerUploadError.generic,
    };
  }

  void _onProfileBannerColorSelected(
    ProfileBannerColorSelected event,
    Emitter<ProfileEditorState> emit,
  ) {
    emit(
      state.copyWith(
        pendingBannerColor: event.color,
        // Image and color are mutually exclusive — clear any staged URL.
        pendingBannerUrl: null,
        pendingBannerStatus: PendingBannerStatus.idle,
      ),
    );
  }

  void _onProfileBannerCleared(
    ProfileBannerCleared event,
    Emitter<ProfileEditorState> emit,
  ) {
    emit(
      state.copyWith(
        pendingBannerUrl: null,
        pendingBannerColor: null,
        pendingBannerStatus: PendingBannerStatus.idle,
      ),
    );
  }

  bool _shouldDropSaveBecauseUploadInFlight(String saveSource) {
    if (state.pendingAvatarStatus == PendingAvatarStatus.uploading) {
      Log.info(
        'Ignoring $saveSource while avatar upload is in flight',
        name: 'ProfileEditorBloc',
      );
      return true;
    }

    if (state.pendingBannerStatus == PendingBannerStatus.uploading) {
      Log.info(
        'Ignoring $saveSource while banner upload is in flight',
        name: 'ProfileEditorBloc',
      );
      return true;
    }

    return false;
  }

  Future<void> _onProfileSaved(
    ProfileSaved event,
    Emitter<ProfileEditorState> emit,
  ) async {
    try {
      // Save remains the only publish point, so every save entry point must
      // refuse to publish while a staged upload is still in flight.
      if (_shouldDropSaveBecauseUploadInFlight('ProfileSaved')) return;

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
    } on Object catch (error, stackTrace) {
      // Classification: Invariant — matrix-YES. Defensive handler-level
      // catch for `Error` types that escape `_saveProfile`'s typed publish
      // branches and the `claimUsername` `on Exception` swallow (StateError
      // from a signer invariant, TypeError from cast mismatches, etc.).
      Log.error(
        'Profile save handler threw: $error',
        name: 'ProfileEditorBloc',
      );
      addError(
        Reportable(
          error,
          context: ProfileEditorReportableSites.onProfileSaved,
        ),
        stackTrace,
      );
      emit(
        state.copyWith(
          status: ProfileEditorStatus.failure,
          error: ProfileEditorError.publishFailed,
        ),
      );
    }
  }

  /// Banner string the next save should write into kind 0.
  ///
  /// Priority: staged value derived from bloc state ([effectiveBanner]) >
  /// caller-supplied `event.banner` (legacy fallback). Empty / whitespace
  /// is treated as "no banner".
  String? _resolveEffectiveBanner(ProfileSaved event) {
    final fromState = state.effectiveBanner?.trim();
    if (fromState != null && fromState.isNotEmpty) return fromState;
    final fromEvent = event.banner?.trim();
    if (fromEvent != null && fromEvent.isNotEmpty) return fromEvent;
    return null;
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

  Future<void> _onProfileNip05Saved(
    ProfileNip05Saved event,
    Emitter<ProfileEditorState> emit,
  ) async {
    try {
      if (_shouldDropSaveBecauseUploadInFlight('ProfileNip05Saved')) return;

      final displayName =
          event.currentProfile.displayName ?? event.currentProfile.name ?? '';
      if (displayName.trim().isEmpty) {
        Log.error(
          'NIP-05 save ignored because the loaded profile has no display name',
          name: 'ProfileEditorBloc',
        );
        return;
      }

      final saveEvent = ProfileSaved(
        pubkey: event.currentProfile.pubkey,
        displayName: displayName,
        about: event.currentProfile.about,
        username: state.nip05Mode == Nip05Mode.divine ? state.username : null,
        externalNip05: state.nip05Mode == Nip05Mode.external_
            ? state.externalNip05
            : null,
        picture: event.currentProfile.picture,
        banner: event.currentProfile.banner,
      );

      await _saveProfile(saveEvent, _resolveEffectivePicture(saveEvent), emit);
    } on Object catch (error, stackTrace) {
      // Classification: Invariant — matrix-YES. Same coverage as
      // [_onProfileSaved] — `Error` types that escape `_saveProfile`'s typed
      // branches.
      Log.error(
        'Profile NIP-05 save handler threw: $error',
        name: 'ProfileEditorBloc',
      );
      addError(
        Reportable(
          error,
          context: ProfileEditorReportableSites.onProfileNip05Saved,
        ),
        stackTrace,
      );
      emit(
        state.copyWith(
          status: ProfileEditorStatus.failure,
          error: ProfileEditorError.publishFailed,
        ),
      );
    }
  }

  Future<void> _onProfileSaveConfirmed(
    ProfileSaveConfirmed event,
    Emitter<ProfileEditorState> emit,
  ) async {
    try {
      if (_shouldDropSaveBecauseUploadInFlight('ProfileSaveConfirmed')) return;

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
    } on Object catch (error, stackTrace) {
      // Classification: Invariant — matrix-YES. Same coverage as
      // [_onProfileSaved] — `Error` types that escape `_saveProfile`'s typed
      // branches.
      Log.error(
        'Profile save-confirmed handler threw: $error',
        name: 'ProfileEditorBloc',
      );
      addError(
        Reportable(
          error,
          context: ProfileEditorReportableSites.onProfileSaveConfirmed,
        ),
        stackTrace,
      );
      emit(
        state.copyWith(
          status: ProfileEditorStatus.failure,
          error: ProfileEditorError.publishFailed,
        ),
      );
    }
  }

  Future<void> _onUsernameChanged(
    UsernameChanged event,
    Emitter<ProfileEditorState> emit,
  ) async {
    try {
      final rawUsername = event.username;
      final username = rawUsername.trim();

      if (username.isEmpty) {
        emit(
          state.copyWith(
            username: username,
            usernameStatus: UsernameStatus.idle,
          ),
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
          state.copyWith(
            username: username,
            usernameStatus: UsernameStatus.idle,
          ),
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

      // Restartable transformer may have cancelled this run while the API
      // call was in flight; guard before emitting to a closed emitter.
      if (emit.isDone) return;

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
    } on Object catch (error, stackTrace) {
      // Classification: Invariant — matrix-YES. `checkUsernameAvailability`
      // catches `on Exception` and returns `UsernameCheckError`, but `Error`
      // subclasses (a JSON decode `TypeError`, an unexpected `StateError`)
      // escape past that filter.
      if (emit.isDone) return;
      Log.error(
        'Username availability check threw: $error',
        name: 'ProfileEditorBloc',
      );
      addError(
        Reportable(
          error,
          context: ProfileEditorReportableSites.onUsernameChanged,
        ),
        stackTrace,
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
    try {
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
    } on Object catch (error, stackTrace) {
      // Classification: Invariant — matrix-YES. Same `Error`-escape contract
      // as [_onUsernameChanged] — `checkUsernameAvailability` swallows
      // Exception, only Error subclasses reach here.
      final username = state.username;
      final validation = username.isEmpty
          ? null
          : validateDivineUsername(username);
      final normalized = validation is DivineUsernameValid
          ? validation.normalized
          : null;
      Log.error(
        'Username re-check threw: $error',
        name: 'ProfileEditorBloc',
      );
      addError(
        Reportable(
          error,
          context: ProfileEditorReportableSites.onUsernameRechecked,
        ),
        stackTrace,
      );
      emit(
        state.copyWith(
          usernameStatus: UsernameStatus.reserved,
          reservedUsernames: normalized == null
              ? state.reservedUsernames
              : {...state.reservedUsernames, normalized},
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
    final about = await _canonicalizeProfileAbout(event);
    final website = event.website?.trim();

    // Bloc decides which NIP-05 value to use based on current mode
    final isExternal = state.nip05Mode == Nip05Mode.external_;
    final trimmedUsername = event.username?.trim();
    final username = isExternal || (trimmedUsername?.isEmpty ?? true)
        ? null
        : switch (validateDivineUsername(trimmedUsername!)) {
            DivineUsernameValid(:final normalized) => normalized,
            DivineUsernameInvalid() => trimmedUsername,
          };
    final externalSource = (event.externalNip05?.trim().isEmpty ?? true)
        ? state.externalNip05
        : event.externalNip05!;
    final externalNip05 = !isExternal || externalSource.trim().isEmpty
        ? null
        : externalSource.trim().toLowerCase();

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
    // Banner is owned by bloc state (staged URL > staged color > persisted),
    // with `event.banner` as a legacy fallback for callers that haven't
    // migrated to the staged-state model yet. Empty string treated as null.
    final banner = _resolveEffectiveBanner(event);

    final currentProfile = await _profileRepository.getCachedProfile(
      pubkey: event.pubkey,
    );

    Log.info(
      '📝 saveProfile: displayName=$displayName, '
      'username=$username, externalNip05=$externalNip05, '
      'currentNip05=${currentProfile?.nip05}',
      name: 'ProfileEditorBloc',
    );

    // 1. Claim the divine.video username FIRST when a new one is requested.
    //
    // If the claim fails for any reason — taken, reserved, network error,
    // server unreachable — we abort *before* publishing kind 0. This keeps
    // the user's metadata in sync with the registry by construction.
    final shouldClaimUsername =
        username != null &&
        (state.initialUsername == null ||
            username.toLowerCase() != state.initialUsername!.toLowerCase());
    if (shouldClaimUsername) {
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
        website: website,
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
    } on NoRelaysConnectedException catch (error, stackTrace) {
      // Classification: Network/IO — matrix-NO. The device has no active
      // relay connections; user-actionable retry path.
      Log.error(
        'Failed to publish profile (no relays): $error',
        name: 'ProfileEditorBloc',
      );
      addError(error, stackTrace);
      emit(
        state.copyWith(
          status: ProfileEditorStatus.failure,
          error: ProfileEditorError.noRelaysConnected,
        ),
      );
    } on ProfilePublishFailedException catch (error, stackTrace) {
      // Classification: API/domain — matrix-NO. Typed publish failure
      // (relay rejected event or send error).
      Log.error(
        'Failed to publish profile: $error',
        name: 'ProfileEditorBloc',
      );
      addError(error, stackTrace);
      emit(
        state.copyWith(
          status: ProfileEditorStatus.failure,
          error: ProfileEditorError.publishFailed,
        ),
      );
    } on Object catch (error, stackTrace) {
      // Classification: Invariant — matrix-YES. Anything that escapes the
      // typed `ProfileRepositoryException` branches above is unexpected:
      // a drift `TypeError` from a schema mismatch, a `StateError` from a
      // sync transform between `saveProfileEvent` and `cacheProfile`, etc.
      Log.error(
        'Failed to publish profile (unexpected): $error',
        name: 'ProfileEditorBloc',
      );
      addError(
        Reportable(
          error,
          context: ProfileEditorReportableSites.saveProfilePublish,
        ),
        stackTrace,
      );
      emit(
        state.copyWith(
          status: ProfileEditorStatus.failure,
          error: ProfileEditorError.publishFailed,
        ),
      );
    }
  }

  Future<String?> _canonicalizeProfileAbout(ProfileSaved event) async {
    final rawAbout = event.about;
    if (rawAbout?.trim().isEmpty ?? true) return null;

    try {
      final result = await _mentionResolutionService.resolveTextMentions(
        rawText: rawAbout!,
        currentUserPubkey: event.pubkey,
      );
      return result.canonicalText;
    } on Object catch (error, stackTrace) {
      // Classification: Invariant — matrix-YES. `MentionResolutionService`
      // catches `on Exception` internally; only `Error` subtypes (StateError
      // from `_applyReplacements`, RangeError on substring edges, TypeError
      // from API-shape casts) reach here. The save continues with the
      // unresolved `rawAbout`.
      Log.error(
        'Profile bio mention resolution failed: $error',
        name: 'ProfileEditorBloc',
      );
      addError(
        Reportable(
          error,
          context: ProfileEditorReportableSites.canonicalizeProfileAbout,
        ),
        stackTrace,
      );
      return rawAbout;
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
