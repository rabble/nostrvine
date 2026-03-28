// ABOUTME: BLoC for the unified share sheet
// ABOUTME: Manages contact loading, recipient selection, video sharing,
// ABOUTME: and one-shot actions (save, copy, share via)

import 'dart:convert';
import 'dart:io';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:nostr_sdk/nip19/nip19_tlv.dart';
import 'package:openvine/repositories/follow_repository.dart';
import 'package:openvine/services/bookmark_service.dart';
import 'package:openvine/services/video_sharing_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:profile_repository/profile_repository.dart';

part 'share_sheet_event.dart';
part 'share_sheet_state.dart';

/// BLoC for the unified share bottom sheet.
///
/// Manages:
/// - Contact loading (recent + followed users)
/// - Recipient selection
/// - Quick-send and send-with-message flows
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
  }) : _video = video,
       _relayUrl = relayUrl,
       _videoSharingService = videoSharingService,
       _profileRepository = profileRepository,
       _followRepository = followRepository,
       _bookmarkServiceFuture = bookmarkServiceFuture,
       _cacheManager = cacheManager,
       super(const ShareSheetState()) {
    on<ShareSheetContactsLoadRequested>(_onContactsLoadRequested);
    on<ShareSheetQuickSendRequested>(
      _onQuickSendRequested,
      transformer: droppable(),
    );
    on<ShareSheetRecipientSelected>(_onRecipientSelected);
    on<ShareSheetRecipientCleared>(_onRecipientCleared);
    on<ShareSheetSendRequested>(_onSendRequested, transformer: droppable());
    on<ShareSheetSaveRequested>(_onSaveRequested, transformer: droppable());
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

      // Batch-fetch uncached profiles
      final allPubkeys = [...recentPubkeys, ...remainingFollows];
      final cachedChecks = await Future.wait(
        allPubkeys.map((pk) => _profileRepository.getCachedProfile(pubkey: pk)),
      );
      final uncached = <String>[];
      for (var i = 0; i < allPubkeys.length; i++) {
        if (cachedChecks[i] == null) uncached.add(allPubkeys[i]);
      }
      if (uncached.isNotEmpty) {
        await Future.wait(
          uncached.map(
            (pk) => _profileRepository.fetchFreshProfile(pubkey: pk),
          ),
        );
      }

      final contacts = <ShareableUser>[...recentUsers];

      for (final pubkey in remainingFollows) {
        final profile = await _profileRepository.getCachedProfile(
          pubkey: pubkey,
        );
        contacts.add(
          ShareableUser(
            pubkey: pubkey,
            displayName: profile?.bestDisplayName,
            picture: profile?.picture,
          ),
        );
      }

      emit(
        state.copyWith(
          status: ShareSheetStatus.ready,
          contacts: contacts,
          clearActionResult: true,
        ),
      );
    } catch (e) {
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

  void _onRecipientSelected(
    ShareSheetRecipientSelected event,
    Emitter<ShareSheetState> emit,
  ) {
    final updatedContacts = List<ShareableUser>.from(state.contacts)
      ..removeWhere((c) => c.pubkey == event.recipient.pubkey)
      ..insert(0, event.recipient);

    emit(
      state.copyWith(
        selectedRecipient: event.recipient,
        contacts: updatedContacts,
        clearActionResult: true,
      ),
    );
  }

  void _onRecipientCleared(
    ShareSheetRecipientCleared event,
    Emitter<ShareSheetState> emit,
  ) {
    emit(state.copyWith(clearRecipient: true, clearActionResult: true));
  }

  // --------------------------------------------------------------------------
  // Quick-send (tap contact → send immediately, no message)
  // --------------------------------------------------------------------------

  Future<void> _onQuickSendRequested(
    ShareSheetQuickSendRequested event,
    Emitter<ShareSheetState> emit,
  ) async {
    final user = event.recipient;
    if (state.isSending || state.sentPubkeys.contains(user.pubkey)) return;

    // Clear any selected recipient so More Actions stays visible
    emit(
      state.copyWith(
        isSending: true,
        clearRecipient: true,
        clearActionResult: true,
      ),
    );

    try {
      final result = await _videoSharingService.shareVideoWithUser(
        video: _video,
        recipientPubkey: user.pubkey,
      );

      final recipientName = user.displayName ?? 'user';
      if (result.success) {
        emit(
          state.copyWith(
            isSending: false,
            sentPubkeys: {...state.sentPubkeys, user.pubkey},
            actionResult: ShareSheetSendSuccess(recipientName),
          ),
        );
      } else {
        emit(
          state.copyWith(
            isSending: false,
            actionResult: ShareSheetSendFailure(),
          ),
        );
      }
    } catch (e) {
      Log.error(
        'Failed to quick-send video: $e',
        name: 'ShareSheetBloc',
        category: LogCategory.ui,
      );
      emit(
        state.copyWith(
          isSending: false,
          actionResult: ShareSheetSendFailure(),
        ),
      );
    }
  }

  // --------------------------------------------------------------------------
  // Send with optional message
  // --------------------------------------------------------------------------

  Future<void> _onSendRequested(
    ShareSheetSendRequested event,
    Emitter<ShareSheetState> emit,
  ) async {
    if (state.selectedRecipient == null || state.isSending) return;

    emit(state.copyWith(isSending: true, clearActionResult: true));

    try {
      final recipient = state.selectedRecipient!;
      final message = event.message?.trim();

      final result = await _videoSharingService.shareVideoWithUser(
        video: _video,
        recipientPubkey: recipient.pubkey,
        personalMessage: message?.isEmpty == true ? null : message,
      );

      final recipientName = recipient.displayName ?? 'user';
      if (result.success) {
        emit(
          state.copyWith(
            isSending: false,
            actionResult: ShareSheetSendSuccess(
              recipientName,
              shouldDismiss: true,
            ),
          ),
        );
      } else {
        emit(
          state.copyWith(
            isSending: false,
            actionResult: ShareSheetSendFailure(),
          ),
        );
      }
    } catch (e) {
      Log.error(
        'Failed to send video: $e',
        name: 'ShareSheetBloc',
        category: LogCategory.ui,
      );
      emit(
        state.copyWith(
          isSending: false,
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
        state.copyWith(
          actionResult: ShareSheetSaveResult(succeeded: false),
        ),
      );
      return;
    }

    try {
      final succeeded = await bookmarkService.addVideoToGlobalBookmarks(
        _video.id,
      );
      emit(
        state.copyWith(
          actionResult: ShareSheetSaveResult(succeeded: succeeded),
        ),
      );
    } catch (e) {
      Log.error(
        'Failed to add bookmark: $e',
        name: 'ShareSheetBloc',
        category: LogCategory.ui,
      );
      emit(
        state.copyWith(
          actionResult: ShareSheetSaveResult(succeeded: false),
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
            label: 'Link to post copied to clipboard',
            text: url,
          ),
        ),
      );
    } catch (e) {
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
          final tmpFile = File(
            '${tmpDir.path}/divine_share_thumb.jpg',
          );
          await file.copy(tmpFile.path);
          thumbnailPath = tmpFile.path;
        } catch (e) {
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
    } catch (e) {
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
            label: 'Nostr event JSON copied to clipboard',
            text: json,
          ),
        ),
      );
    } catch (e) {
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
            label: 'Nostr event ID copied to clipboard',
            text: nevent,
          ),
        ),
      );
    } catch (e) {
      Log.error(
        'Failed to generate event ID: $e',
        name: 'ShareSheetBloc',
        category: LogCategory.ui,
      );
      emit(state.copyWith(actionResult: ShareSheetActionFailure()));
    }
  }
}
