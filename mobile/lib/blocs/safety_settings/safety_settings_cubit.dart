// ABOUTME: Screen-scoped Cubit for the SafetySettingsScreen moderation hub.
// ABOUTME: Owns the three toggle prefs (age-verified, people-I-follow,
// ABOUTME: divine-hosted-only) plus reactive labeler and blocklist lists.

import 'dart:async';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:content_policy/content_policy.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:openvine/blocs/safety_settings/safety_settings_state.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/services/content_filter_service.dart';
import 'package:openvine/services/divine_host_filter_service.dart';
import 'package:openvine/services/moderation_label_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/utils/npub_hex.dart';

/// Cubit backing `SafetySettingsScreen`.
///
/// Subscribing cubit: subscribes to `ContentBlocklistRepository.stateStream`
/// so the blocked-users section stays up-to-date when external block/unblock
/// events arrive (replacing the pre-migration
/// `ref.watch(blocklistVersionProvider)` rebuild trick). Labeler changes do
/// not have a service-level stream, so the cubit re-reads
/// `customLabelers` after each `addLabeler` / `removeLabeler` action.
///
/// The age-verification toggle cascades through three services
/// (`AgeVerificationService`, `ContentFilterService`, `VideoEventService`)
/// to mirror the pre-migration `_setAgeVerified` behavior — unlocking adult
/// categories on confirm, locking them and filtering the existing feed on
/// unconfirm.
class SafetySettingsCubit extends Cubit<SafetySettingsState> {
  SafetySettingsCubit({
    required AgeVerificationService ageVerificationService,
    required ContentFilterService contentFilterService,
    required VideoEventService videoEventService,
    required DivineHostFilterService divineHostFilterService,
    required ModerationLabelService moderationLabelService,
    required FollowRepository followRepository,
    required ContentBlocklistRepository contentBlocklistRepository,
    bool isAdultContentLocked = false,
  }) : _isAdultContentLocked = isAdultContentLocked,
       _ageVerificationService = ageVerificationService,
       _contentFilterService = contentFilterService,
       _videoEventService = videoEventService,
       _divineHostFilterService = divineHostFilterService,
       _moderationLabelService = moderationLabelService,
       _followRepository = followRepository,
       _contentBlocklistRepository = contentBlocklistRepository,
       super(const SafetySettingsState());

  final AgeVerificationService _ageVerificationService;
  final ContentFilterService _contentFilterService;
  final VideoEventService _videoEventService;
  final DivineHostFilterService _divineHostFilterService;
  final ModerationLabelService _moderationLabelService;
  final FollowRepository _followRepository;
  final ContentBlocklistRepository _contentBlocklistRepository;
  final bool _isAdultContentLocked;

  StreamSubscription<ContentPolicyState>? _blocklistSub;

  /// Snapshots the three settings + the labeler / blocklist lists, and
  /// starts subscribing to the blocklist stream for live refreshes.
  Future<void> load() async {
    emit(state.copyWith(status: SafetySettingsStatus.loading));
    await _ageVerificationService.initialize();
    await _moderationLabelService.ensureLoaded();
    emit(
      state.copyWith(
        status: SafetySettingsStatus.ready,
        isAgeVerified: _ageVerificationService.isAdultContentVerified,
        isAdultContentLocked: _isAdultContentLocked,
        isPeopleIFollowEnabled:
            _moderationLabelService.isFollowingModerationEnabled,
        showDivineHostedOnly: _divineHostFilterService.showDivineHostedOnly,
        customLabelers: _moderationLabelService.customLabelers,
        blockedUsers: _contentBlocklistRepository.runtimeBlockedUsers,
      ),
    );
    _blocklistSub ??= _contentBlocklistRepository.stateStream.listen((_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          blockedUsers: _contentBlocklistRepository.runtimeBlockedUsers,
        ),
      );
    });
  }

  /// Confirm/un-confirm adult-content age verification.
  ///
  /// On confirm: persist + unlock adult categories.
  /// On un-confirm: persist + lock adult categories + filter the existing
  /// feed (kept to mirror `_setAgeVerified` pre-migration behavior).
  ///
  /// Emits optimistically so the row moves on the tap frame; see
  /// [setPeopleIFollowEnabled] for why.
  Future<void> setAgeVerified(bool value) async {
    if (_isAdultContentLocked) return; // protected minors cannot toggle
    final previous = state.isAgeVerified;
    emit(state.copyWith(isAgeVerified: value));
    try {
      await _ageVerificationService.setAdultContentVerified(value);
      if (value) {
        await _contentFilterService.unlockAdultCategories();
      } else {
        await _contentFilterService.lockAdultCategories();
        _videoEventService.filterAdultContentFromExistingVideos();
      }
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(state.copyWith(isAgeVerified: previous));
    }
  }

  /// Toggle the "show only Divine-hosted content" filter.
  ///
  /// Emits optimistically so the row moves on the tap frame; see
  /// [setPeopleIFollowEnabled] for why.
  Future<void> setShowDivineHostedOnly(bool value) async {
    final previous = state.showDivineHostedOnly;
    emit(state.copyWith(showDivineHostedOnly: value));
    try {
      await _divineHostFilterService.setShowDivineHostedOnly(value);
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(state.copyWith(showDivineHostedOnly: previous));
    }
  }

  /// Toggle "use people I follow as trusted labelers".
  ///
  /// Passes the current following set as an enable-time *seed* so the service
  /// wires those pubkeys' label streams immediately, matching the
  /// pre-migration call shape. This snapshot is not the source of truth while
  /// enabled: `moderationLabelServiceProvider` subscribes to
  /// `FollowRepository.followingStream` and re-runs `syncFollowedLabelers` on
  /// every follow-graph change (a no-op while disabled), so the feature stays
  /// live without the cubit owning that subscription.
  ///
  /// The emit is optimistic: enabling this fans out one relay query per
  /// followed pubkey, awaited one after another, so emitting after the
  /// service call left the switch pinned to its old position for seconds —
  /// long enough that the only way to see the new value was to leave the
  /// screen and come back (which re-reads the persisted flag in [load]).
  /// On failure the toggle snaps back.
  Future<void> setPeopleIFollowEnabled(bool value) async {
    final previous = state.isPeopleIFollowEnabled;
    emit(state.copyWith(isPeopleIFollowEnabled: value));
    try {
      await _moderationLabelService.setFollowingModerationEnabled(
        value,
        followedPubkeys: _followRepository.followingPubkeys,
      );
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(state.copyWith(isPeopleIFollowEnabled: previous));
    }
  }

  /// Subscribe to a custom labeler.
  ///
  /// Accepts either an `npub1…` (converted via `npubToHexOrNull`) or a raw
  /// hex pubkey. After the service mutation, re-reads `customLabelers` so
  /// the emitted state reflects the canonical (post-mutation) set.
  Future<void> addLabeler(String input) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return;
    final hexPubkey = npubToHexOrNull(trimmed) ?? trimmed;
    await _moderationLabelService.addLabeler(hexPubkey);
    emit(
      state.copyWith(customLabelers: _moderationLabelService.customLabelers),
    );
  }

  /// Unsubscribe from a custom labeler.
  Future<void> removeLabeler(String pubkey) async {
    await _moderationLabelService.removeLabeler(pubkey);
    emit(
      state.copyWith(customLabelers: _moderationLabelService.customLabelers),
    );
  }

  /// Unblock a previously-blocked author.
  ///
  /// The `stateStream` subscription will also emit a refresh, but we re-read
  /// the runtime list eagerly so the optimistic UI update lands on the same
  /// frame as the mutation.
  Future<void> unblockUser(String pubkey) async {
    await _contentBlocklistRepository.unblockUser(pubkey);
    emit(
      state.copyWith(
        blockedUsers: _contentBlocklistRepository.runtimeBlockedUsers,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _blocklistSub?.cancel();
    return super.close();
  }
}
