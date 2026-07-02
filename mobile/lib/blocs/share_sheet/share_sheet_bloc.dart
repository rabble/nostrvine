// ABOUTME: BLoC for the unified share sheet
// ABOUTME: Manages contact loading, recipient selection, video sharing,
// ABOUTME: and one-shot actions (save, copy, share via)

import 'dart:convert';
import 'dart:io';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:nostr_sdk/nip19/nip19_tlv.dart';
import 'package:openvine/blocs/share_sheet/reportable_sites.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/bookmark_service.dart';
import 'package:openvine/services/video_clip_import_service.dart';
import 'package:openvine/services/video_sharing_service.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:unified_logger/unified_logger.dart';

part 'share_sheet_event.dart';
part 'share_sheet_state.dart';

/// BLoC for the unified share bottom sheet.
///
/// Manages:
/// - Contact loading (recent + followed users)
/// - Recipient selection (select-then-send: tapping a contact only selects;
///   the DM goes out on an explicit [ShareSheetSendRequested])
/// - One-shot actions (save, copy link, copy JSON, copy event ID, share via)
///
/// Emits [ShareSheetActionResult] as one-shot side effects for the UI
/// to handle (snackbars, clipboard, sheet dismissal).
class ShareSheetBloc extends Bloc<ShareSheetEvent, ShareSheetState> {
  ShareSheetBloc({
    required VideoEvent video,
    required String relayUrl,
    required VideoSharingService videoSharingService,
    required ProfileRepository profileRepository,
    required FollowRepository followRepository,
    Future<BookmarkService?>? bookmarkServiceFuture,
    BaseCacheManager? cacheManager,
    VideoClipImportService? videoClipImportService,
  }) : _video = video,
       _relayUrl = relayUrl,
       _videoSharingService = videoSharingService,
       _profileRepository = profileRepository,
       _followRepository = followRepository,
       _bookmarkServiceFuture = bookmarkServiceFuture,
       _cacheManager = cacheManager,
       _videoClipImportService = videoClipImportService,
       super(const ShareSheetState()) {
    on<ShareSheetContactsLoadRequested>(_onContactsLoadRequested);
    on<ShareSheetRecipientToggled>(_onRecipientToggled);
    on<ShareSheetSendRequested>(_onSendRequested, transformer: droppable());
    on<ShareSheetSaveRequested>(_onSaveRequested, transformer: droppable());
    on<ShareSheetAddVideoToClipsRequested>(
      _onAddVideoToClipsRequested,
      transformer: droppable(),
    );
    on<ShareSheetCopyLinkRequested>(_onCopyLinkRequested);
    on<ShareSheetShareViaRequested>(_onShareViaRequested);
    on<ShareSheetCopyEventJsonRequested>(_onCopyEventJsonRequested);
    on<ShareSheetCopyEventIdRequested>(_onCopyEventIdRequested);
  }

  final VideoEvent _video;
  final String _relayUrl;
  final VideoSharingService _videoSharingService;
  final ProfileRepository _profileRepository;
  final FollowRepository _followRepository;
  final Future<BookmarkService?>? _bookmarkServiceFuture;
  final BaseCacheManager? _cacheManager;
  final VideoClipImportService? _videoClipImportService;

  void _addUnexpectedError(
    Object error,
    StackTrace stackTrace,
    String context,
  ) {
    addError(Reportable(error, context: context), stackTrace);
  }

  // --------------------------------------------------------------------------
  // Contact loading
  // --------------------------------------------------------------------------

  Future<void> _onContactsLoadRequested(
    ShareSheetContactsLoadRequested event,
    Emitter<ShareSheetState> emit,
  ) async {
    emit(
      state.copyWith(status: ShareSheetStatus.loading, clearActionResult: true),
    );

    try {
      final recentUsers = _videoSharingService.recentlySharedWith;
      final followList = _followRepository.followingPubkeys;
      final recentPubkeys = recentUsers.map((u) => u.pubkey).toSet();

      final remainingFollows = followList
          .where((pk) => !recentPubkeys.contains(pk))
          .toList();

      // One batched read (cache + bulk REST + relays, in the repository)
      // instead of a per-pubkey DB/network storm fired on sheet open. The
      // repository owns the source-selection strategy. Recents already carry
      // their display data snapshotted at last-send time, so only the
      // remaining follows need profiles. Staleness is session-bounded:
      // VideoSharingService._recentlySharedWith is in-memory only and resets
      // to empty on app restart, so a stale avatar or name is visible at most
      // within the same session until the user shares with that contact again.
      // Skip the call entirely when there are no follows to fetch. See #5391.
      final profiles = remainingFollows.isEmpty
          ? const <String, UserProfile>{}
          : await _profileRepository.fetchBatchProfiles(
              pubkeys: remainingFollows,
            );

      final contacts = <ShareableUser>[
        ...recentUsers,
        for (final pubkey in remainingFollows)
          ShareableUser(
            pubkey: pubkey,
            displayName: profiles[pubkey]?.bestDisplayName,
            picture: profiles[pubkey]?.picture,
          ),
      ];

      emit(
        state.copyWith(
          status: ShareSheetStatus.ready,
          contacts: contacts,
          clearActionResult: true,
        ),
      );
    } catch (e, stackTrace) {
      _addUnexpectedError(
        e,
        stackTrace,
        ShareSheetBlocReportableSites.onContactsLoadRequested,
      );
      Log.error(
        'Error loading contacts: $e',
        name: 'ShareSheetBloc',
        category: LogCategory.ui,
      );
      emit(
        state.copyWith(
          status: ShareSheetStatus.ready,
          contacts: [],
          clearActionResult: true,
        ),
      );
    }
  }

  // --------------------------------------------------------------------------
  // Recipient selection
  // --------------------------------------------------------------------------

  void _onRecipientToggled(
    ShareSheetRecipientToggled event,
    Emitter<ShareSheetState> emit,
  ) {
    final recipient = event.recipient;
    final updatedSelection = state.isSelected(recipient)
        ? [
            for (final r in state.selectedRecipients)
              if (r.pubkey != recipient.pubkey) r,
          ]
        : [...state.selectedRecipients, recipient];

    // Find People can pick someone who isn't in the contacts row yet —
    // surface them at the front so their selection tick is visible.
    // Existing contacts stay in place: reordering under the user's
    // finger while multi-selecting is disorienting.
    final inContacts = state.contacts.any(
      (c) => c.pubkey == recipient.pubkey,
    );
    final updatedContacts = inContacts
        ? state.contacts
        : [recipient, ...state.contacts];

    emit(
      state.copyWith(
        selectedRecipients: updatedSelection,
        contacts: updatedContacts,
        clearActionResult: true,
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Send with optional message
  // --------------------------------------------------------------------------

  Future<void> _onSendRequested(
    ShareSheetSendRequested event,
    Emitter<ShareSheetState> emit,
  ) async {
    if (state.selectedRecipients.isEmpty || state.isSending) return;

    // Deliberate compose-then-send: the awaited flow keeps a visible
    // "sending" spinner (isSending) and reports the outcome in-sheet.
    emit(state.copyWith(isSending: true, clearActionResult: true));

    try {
      final recipients = state.selectedRecipients;
      final message = event.message?.trim();

      // Fans out one DM per recipient (each gets its own gift wrap).
      final results = await _videoSharingService.shareVideoWithMultipleUsers(
        video: _video,
        recipientPubkeys: [for (final r in recipients) r.pubkey],
        personalMessage: message?.isEmpty == true ? null : message,
      );

      if (isClosed) return;

      final delivered = [
        for (final r in recipients)
          if (results[r.pubkey]?.success ?? false) r,
      ];
      final failedCount = recipients.length - delivered.length;

      // The send is dismiss-and-forget: a recipient publish that fails is
      // already durably enqueued (VideoSharingService -> DmRepository.
      // sendMessage enqueues before publish) and OutgoingDmRetryService
      // replays the SAME rumor id on the next app-foreground. Re-sending from
      // the sheet would mint a NEW rumor id the receiver can't dedup against
      // that replay, double-delivering — so we never keep recipients selected
      // for a manual retry. We report what was delivered and let the queue
      // finish the rest.
      if (delivered.isNotEmpty) {
        if (failedCount > 0) {
          Log.warning(
            'Partial share: ${delivered.length} delivered, $failedCount '
            'queued for background retry',
            name: 'ShareSheetBloc',
            category: LogCategory.ui,
          );
        }
        final single = delivered.length == 1 && recipients.length == 1
            ? delivered.single
            : null;
        emit(
          state.copyWith(
            isSending: false,
            selectedRecipients: const [],
            actionResult: ShareSheetSendSuccess(
              recipientNames: [
                for (final r in delivered) r.displayName ?? 'user',
              ],
              recipientPubkey: single?.pubkey,
              conversationId: single == null
                  ? null
                  : results[single.pubkey]?.conversationId,
            ),
          ),
        );
      } else {
        emit(
          state.copyWith(
            isSending: false,
            selectedRecipients: const [],
            actionResult: ShareSheetSendFailure(),
          ),
        );
      }
    } catch (e, stackTrace) {
      _addUnexpectedError(
        e,
        stackTrace,
        ShareSheetBlocReportableSites.onSendRequested,
      );
      Log.error(
        'Failed to send video: $e',
        name: 'ShareSheetBloc',
        category: LogCategory.ui,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          isSending: false,
          selectedRecipients: const [],
          actionResult: ShareSheetSendFailure(),
        ),
      );
    }
  }

  // --------------------------------------------------------------------------
  // Save to bookmarks
  // --------------------------------------------------------------------------

  Future<void> _onSaveRequested(
    ShareSheetSaveRequested event,
    Emitter<ShareSheetState> emit,
  ) async {
    final bookmarkService = await _bookmarkServiceFuture;
    if (bookmarkService == null) {
      Log.warning(
        'Bookmark service unavailable — cannot save',
        name: 'ShareSheetBloc',
        category: LogCategory.ui,
      );
      emit(
        state.copyWith(actionResult: ShareSheetSaveResult(succeeded: false)),
      );
      return;
    }

    var wasBookmarked = false;
    try {
      wasBookmarked = bookmarkService.isVideoBookmarkedGlobally(_video.id);
      final succeeded = await bookmarkService.toggleVideoInGlobalBookmarks(
        _video.id,
      );
      emit(
        state.copyWith(
          actionResult: ShareSheetSaveResult(
            succeeded: succeeded,
            removed: succeeded && wasBookmarked,
            wasBookmarkedBeforeToggle: wasBookmarked,
          ),
        ),
      );
    } catch (e, stackTrace) {
      _addUnexpectedError(
        e,
        stackTrace,
        ShareSheetBlocReportableSites.onSaveRequested,
      );
      Log.error(
        'Failed to toggle bookmark: $e',
        name: 'ShareSheetBloc',
        category: LogCategory.ui,
      );
      emit(
        state.copyWith(
          actionResult: ShareSheetSaveResult(
            succeeded: false,
            wasBookmarkedBeforeToggle: wasBookmarked,
          ),
        ),
      );
    }
  }

  // --------------------------------------------------------------------------
  // Add video to clips
  // --------------------------------------------------------------------------

  Future<void> _onAddVideoToClipsRequested(
    ShareSheetAddVideoToClipsRequested event,
    Emitter<ShareSheetState> emit,
  ) async {
    final importer = _videoClipImportService;
    if (importer == null) {
      Log.warning(
        'Video clip importer unavailable',
        name: 'ShareSheetBloc',
        category: LogCategory.ui,
      );
      emit(
        state.copyWith(
          actionResult: ShareSheetVideoClipImportResult(succeeded: false),
        ),
      );
      return;
    }

    try {
      final result = await importer.importToLibrary(
        _video,
        libraryTitle: event.libraryTitle,
      );
      emit(
        state.copyWith(
          actionResult: ShareSheetVideoClipImportResult(
            succeeded: result is VideoClipImportSuccess,
            libraryTitle: result is VideoClipImportSuccess
                ? result.clip.libraryTitle
                : null,
          ),
        ),
      );
    } catch (e, stackTrace) {
      _addUnexpectedError(
        e,
        stackTrace,
        ShareSheetBlocReportableSites.onAddVideoToClipsRequested,
      );
      Log.error(
        'Failed to import video clip: $e',
        name: 'ShareSheetBloc',
        category: LogCategory.ui,
      );
      emit(
        state.copyWith(
          actionResult: ShareSheetVideoClipImportResult(succeeded: false),
        ),
      );
    }
  }

  // --------------------------------------------------------------------------
  // Copy / Share actions (BLoC generates data, UI handles platform calls)
  // --------------------------------------------------------------------------

  void _onCopyLinkRequested(
    ShareSheetCopyLinkRequested event,
    Emitter<ShareSheetState> emit,
  ) {
    try {
      final url = _videoSharingService.generateShareUrl(_video);
      emit(
        state.copyWith(
          actionResult: ShareSheetCopiedToClipboard(
            kind: ShareSheetCopiedKind.postLink,
            text: url,
          ),
        ),
      );
    } catch (e, stackTrace) {
      _addUnexpectedError(
        e,
        stackTrace,
        ShareSheetBlocReportableSites.onCopyLinkRequested,
      );
      Log.error(
        'Failed to generate share link: $e',
        name: 'ShareSheetBloc',
        category: LogCategory.ui,
      );
      emit(state.copyWith(actionResult: ShareSheetActionFailure()));
    }
  }

  Future<void> _onShareViaRequested(
    ShareSheetShareViaRequested event,
    Emitter<ShareSheetState> emit,
  ) async {
    try {
      final shareData = _videoSharingService.generateShareData(_video);

      // Download thumbnail if available and a cache manager was provided.
      // Copy to a temp file with a .jpg extension so iOS recognises it as
      // an image rather than a generic document.
      String? thumbnailPath;
      final thumbUrl = shareData.thumbnailUrl;
      if (thumbUrl != null && _cacheManager != null) {
        try {
          final file = await _cacheManager
              .getSingleFile(thumbUrl)
              .timeout(const Duration(seconds: 5));
          final tmpDir = Directory.systemTemp;
          final tmpFile = File('${tmpDir.path}/divine_share_thumb.jpg');
          await file.copy(tmpFile.path);
          thumbnailPath = tmpFile.path;
        } catch (e) {
          // Intentional silent fallback (no addError): sharing proceeds
          // without a thumbnail attachment. No caller-visible failure —
          // the share sheet still opens with the URL + title.
          Log.warning(
            'Thumbnail download failed, sharing without image: $e',
            name: 'ShareSheetBloc',
            category: LogCategory.ui,
          );
        }
      }

      final title = shareData.title;
      emit(
        state.copyWith(
          actionResult: ShareSheetShareViaTriggered(
            shareUrl: shareData.shareUrl,
            thumbnailPath: thumbnailPath,
            title: title,
            subject: title,
          ),
        ),
      );
    } catch (e, stackTrace) {
      _addUnexpectedError(
        e,
        stackTrace,
        ShareSheetBlocReportableSites.onShareViaRequested,
      );
      Log.error(
        'Failed to generate share data: $e',
        name: 'ShareSheetBloc',
        category: LogCategory.ui,
      );
      emit(state.copyWith(actionResult: ShareSheetActionFailure()));
    }
  }

  void _onCopyEventJsonRequested(
    ShareSheetCopyEventJsonRequested event,
    Emitter<ShareSheetState> emit,
  ) {
    try {
      final json = const JsonEncoder.withIndent('  ').convert(_video.toJson());
      emit(
        state.copyWith(
          actionResult: ShareSheetCopiedToClipboard(
            kind: ShareSheetCopiedKind.eventJson,
            text: json,
          ),
        ),
      );
    } catch (e, stackTrace) {
      _addUnexpectedError(
        e,
        stackTrace,
        ShareSheetBlocReportableSites.onCopyEventJsonRequested,
      );
      Log.error(
        'Failed to generate event JSON: $e',
        name: 'ShareSheetBloc',
        category: LogCategory.ui,
      );
      emit(state.copyWith(actionResult: ShareSheetActionFailure()));
    }
  }

  void _onCopyEventIdRequested(
    ShareSheetCopyEventIdRequested event,
    Emitter<ShareSheetState> emit,
  ) {
    try {
      final nevent = NIP19Tlv.encodeNevent(
        Nevent(id: _video.id, author: _video.pubkey, relays: [_relayUrl]),
      );
      emit(
        state.copyWith(
          actionResult: ShareSheetCopiedToClipboard(
            kind: ShareSheetCopiedKind.eventId,
            text: nevent,
          ),
        ),
      );
    } catch (e, stackTrace) {
      _addUnexpectedError(
        e,
        stackTrace,
        ShareSheetBlocReportableSites.onCopyEventIdRequested,
      );
      Log.error(
        'Failed to generate event ID: $e',
        name: 'ShareSheetBloc',
        category: LogCategory.ui,
      );
      emit(state.copyWith(actionResult: ShareSheetActionFailure()));
    }
  }
}
