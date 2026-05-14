// ABOUTME: Service that orchestrates the video-metadata-edit republish flow.
// ABOUTME: Extracts all business logic from the presentation layer into the service layer.

import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:models/models.dart' show VideoEvent;
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/collaborator_invite_service.dart';
import 'package:openvine/services/personal_event_cache_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/utils/collaborator_tags.dart';
import 'package:unified_logger/unified_logger.dart';

/// Result returned by [VideoMetadataUpdateService.updateVideo].
sealed class VideoUpdateResult {
  const VideoUpdateResult();
}

/// The re-publish succeeded.
class VideoUpdateSuccess extends VideoUpdateResult {
  const VideoUpdateSuccess({
    required this.updatedEvent,
    required this.inviteFailureCount,
  });

  final VideoEvent updatedEvent;

  /// Number of collaborator invites that failed to send (may be 0).
  final int inviteFailureCount;
}

/// The re-publish failed with an unrecoverable error.
class VideoUpdateFailure extends VideoUpdateResult {
  const VideoUpdateFailure(this.error);
  final Object error;
}

/// Tag names that carry engagement counts on Vine-imported video events.
///
/// These must survive a metadata edit so that `originalLoops` /
/// `originalLikes` / `originalComments` are not zeroed on the replacement
/// event.
const _engagementCountTagNames = {
  'loops',
  'likes',
  'reposts',
  'views',
  'comments',
};

/// Returns the subset of [tags] that carry engagement counts.
List<List<String>> extractEngagementCountTags(List<List<String>> tags) {
  return tags
      .where(
        (tag) => tag.length >= 2 && _engagementCountTagNames.contains(tag[0]),
      )
      .toList();
}

/// Sends collaborator invites to any pubkeys added since the last publish.
///
/// Returns a map of pubkey → [CollaboratorInviteResult] for each *new*
/// collaborator. Collaborators already present in [previousCollaboratorPubkeys]
/// are skipped.
Future<Map<String, CollaboratorInviteResult>>
sendPostPublishCollaboratorInvites({
  required CollaboratorInviteService inviteService,
  required VideoEvent video,
  required Iterable<String> previousCollaboratorPubkeys,
  required Iterable<String> updatedCollaboratorPubkeys,
  String relayHint = collaboratorInviteRelayHint,
}) async {
  final previous = previousCollaboratorPubkeys.toSet();
  final newCollaborators = updatedCollaboratorPubkeys
      .where((pubkey) => !previous.contains(pubkey))
      .toSet();
  if (newCollaborators.isEmpty) return const {};

  final videoAddress =
      '${NIP71VideoKinds.addressableShortVideo}:${video.pubkey}:${video.stableId}';
  final results = <String, CollaboratorInviteResult>{};
  for (final pubkey in newCollaborators) {
    try {
      results[pubkey] = await inviteService.sendInvite(
        collaboratorPubkey: pubkey,
        creatorPubkey: video.pubkey,
        videoAddress: videoAddress,
        title: video.title,
        thumbnailUrl: video.thumbnailUrl,
        relayHint: relayHint,
      );
    } on Object catch (e, stackTrace) {
      Log.warning(
        'Failed to send post-publish collaborator invite: $e\n$stackTrace',
        name: 'VideoMetadataUpdateService',
        category: LogCategory.video,
      );
      results[pubkey] = CollaboratorInviteResult(
        success: false,
        error: e.toString(),
      );
    }
  }
  return results;
}

/// Orchestrates the video-metadata-edit republish flow.
///
/// Responsibilities:
/// - Extracts video URLs from the original event's imeta tags.
/// - Optionally uploads a new thumbnail to Blossom.
/// - Assembles the replacement NIP-71 Nostr event.
/// - Signs and publishes the event.
/// - Updates the in-process event caches.
/// - Sends post-publish collaborator invites.
///
/// All dependencies are constructor-injected for testability.
class VideoMetadataUpdateService {
  const VideoMetadataUpdateService({
    required AuthService authService,
    required BlossomUploadService blossomService,
    required NostrClient nostrService,
    required PersonalEventCacheService personalEventCache,
    required VideoEventService videoEventService,
    required CollaboratorInviteService collaboratorInviteService,
  }) : _authService = authService,
       _blossomService = blossomService,
       _nostrService = nostrService,
       _personalEventCache = personalEventCache,
       _videoEventService = videoEventService,
       _collaboratorInviteService = collaboratorInviteService;

  final AuthService _authService;
  final BlossomUploadService _blossomService;
  final NostrClient _nostrService;
  final PersonalEventCacheService _personalEventCache;
  final VideoEventService _videoEventService;
  final CollaboratorInviteService _collaboratorInviteService;

  /// Re-publishes [originalVideo] with the metadata from [editorState].
  ///
  /// If [newThumbnailFile] is non-null, it is uploaded to Blossom before
  /// the event is signed; on upload failure the original thumbnail URL is
  /// kept and the republish continues.
  ///
  /// [initialCollaboratorPubkeys] is used to determine which collaborators
  /// are new (and therefore need an invite DM).
  Future<VideoUpdateResult> updateVideo({
    required VideoEvent originalVideo,
    required VideoEditorProviderState editorState,
    required Set<String> initialCollaboratorPubkeys,
    File? newThumbnailFile,
  }) async {
    try {
      if (!_authService.isAuthenticated) {
        throw Exception('User not authenticated');
      }

      final tags = <List<String>>[];

      // Required 'd' tag — must match the original to replace the event.
      tags.add(['d', originalVideo.stableId]);

      final videoUrls = _extractVideoUrls(originalVideo);
      if (videoUrls.isEmpty) {
        throw Exception('Cannot update video: no valid HTTP video URLs found');
      }

      final imetaComponents = <String>[];
      for (final url in videoUrls) {
        imetaComponents.add('url $url');
      }
      imetaComponents.add('m video/mp4');

      if (newThumbnailFile != null) {
        final uploadResult = await _blossomService.uploadImage(
          imageFile: newThumbnailFile,
          nostrPubkey: _authService.currentPublicKeyHex ?? '',
        );
        if (uploadResult.success && uploadResult.cdnUrl != null) {
          imetaComponents.add('image ${uploadResult.cdnUrl!}');
        } else {
          Log.error(
            'Thumbnail upload failed during video update; keeping original',
            name: 'VideoMetadataUpdateService',
            category: LogCategory.video,
          );
          if (originalVideo.thumbnailUrl != null) {
            imetaComponents.add('image ${originalVideo.thumbnailUrl!}');
          }
        }
      } else if (originalVideo.thumbnailUrl != null) {
        imetaComponents.add('image ${originalVideo.thumbnailUrl!}');
      }

      if (originalVideo.blurhash != null) {
        imetaComponents.add('blurhash ${originalVideo.blurhash!}');
      }
      if (originalVideo.dimensions != null) {
        imetaComponents.add('dim ${originalVideo.dimensions!}');
      }
      if (originalVideo.sha256 != null) {
        imetaComponents.add('x ${originalVideo.sha256!}');
      }
      if (originalVideo.fileSize != null) {
        imetaComponents.add('size ${originalVideo.fileSize!}');
      }

      if (imetaComponents.isNotEmpty) {
        tags.add(['imeta', ...imetaComponents]);
      }

      final title = editorState.title.trim();
      if (title.isNotEmpty) {
        tags.add(['title', title]);
      }

      for (final hashtag in editorState.tags) {
        tags.add(['t', hashtag]);
      }

      for (final label in editorState.contentWarnings) {
        tags.add(['l', label.value, 'content-warning']);
      }

      // Preserve engagement count tags so Vine-imported metrics survive
      // the metadata edit.
      tags.addAll(extractEngagementCountTags(originalVideo.nostrEventTags));

      if (originalVideo.publishedAt != null) {
        tags.add(['published_at', originalVideo.publishedAt!]);
      }
      if (originalVideo.duration != null) {
        tags.add(['duration', originalVideo.duration.toString()]);
      }
      if (originalVideo.altText != null) {
        tags.add(['alt', originalVideo.altText!]);
      }

      for (final pubkey in editorState.collaboratorPubkeys) {
        tags.add(buildCollaboratorPTag(pubkey));
      }

      if (editorState.inspiredByVideo != null) {
        tags.add([
          'a',
          editorState.inspiredByVideo!.addressableId,
          editorState.inspiredByVideo!.relayUrl ?? '',
          'inspired-by',
        ]);
      }

      tags.add(['client', 'diVine']);

      if (editorState.allowAudioReuse) {
        tags.add(['allow_audio_reuse', 'true']);
      }

      var content = editorState.description.trim();
      final inspiredByNpub = editorState.inspiredByNpub;
      if (inspiredByNpub != null && inspiredByNpub.isNotEmpty) {
        final ibText = '\n\nInspired by nostr:$inspiredByNpub';
        content = content.isEmpty ? ibText.trim() : '$content$ibText';
      }

      // Use original created_at + 1 so relays treat this as a replacement
      // while preserving the video's chronological position in feeds.
      final event = await _authService.createAndSignEvent(
        kind: NIP71VideoKinds.addressableShortVideo,
        content: content,
        tags: tags,
        createdAt: originalVideo.createdAt + 1,
      );

      if (event == null) {
        throw Exception('Failed to create updated event');
      }

      final publishResult = await _nostrService.publishEvent(event);
      if (publishResult is! PublishSuccess) {
        throw Exception('Failed to publish updated event');
      }
      final publishedEvent = publishResult.event;

      _personalEventCache.cacheUserEvent(publishedEvent);

      final updatedVideoEvent = VideoEvent.fromNostrEvent(publishedEvent);
      _videoEventService.updateVideoEvent(updatedVideoEvent);

      final inviteFailureCount = await _sendCollaboratorInvites(
        video: updatedVideoEvent,
        initialCollaboratorPubkeys: initialCollaboratorPubkeys,
        updatedCollaboratorPubkeys: editorState.collaboratorPubkeys,
      );

      return VideoUpdateSuccess(
        updatedEvent: updatedVideoEvent,
        inviteFailureCount: inviteFailureCount,
      );
    } on Object catch (e) {
      Log.error(
        'Failed to update video: $e',
        name: 'VideoMetadataUpdateService',
        category: LogCategory.video,
      );
      return VideoUpdateFailure(e);
    }
  }

  /// Extracts all valid HTTP video URLs from the event's imeta tags.
  ///
  /// Handles both the legacy space-separated format
  /// (`['imeta', 'url https://...', ...]`) and the current key-value pair
  /// format (`['imeta', 'url', 'https://...', ...]`).
  ///
  /// Falls back to [VideoEvent.videoUrl] when the raw tags array is empty
  /// (e.g. events loaded from a JSON cache that omits raw tags).
  List<String> _extractVideoUrls(VideoEvent video) {
    final urls = <String>[];
    for (final tag in video.nostrEventTags) {
      if (tag.isEmpty || tag[0] != 'imeta') continue;
      if (tag.length > 1 && tag[1].contains(' ')) {
        // Legacy space-separated format.
        for (var i = 1; i < tag.length; i++) {
          final spaceIdx = tag[i].indexOf(' ');
          if (spaceIdx > 0) {
            final key = tag[i].substring(0, spaceIdx);
            final value = tag[i].substring(spaceIdx + 1);
            if (key == 'url' && _isHttpUrl(value) && !urls.contains(value)) {
              urls.add(value);
            }
          }
        }
      } else {
        // Current key-value pair format.
        for (var i = 1; i < tag.length - 1; i += 2) {
          if (tag[i] == 'url' &&
              _isHttpUrl(tag[i + 1]) &&
              !urls.contains(tag[i + 1])) {
            urls.add(tag[i + 1]);
          }
        }
      }
    }
    if (urls.isEmpty && _isHttpUrl(video.videoUrl)) {
      urls.add(video.videoUrl!);
    }
    return urls;
  }

  static bool _isHttpUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }

  /// Sends DM invites to newly added collaborators and returns the failure
  /// count (0 means all invites succeeded or there were no new collaborators).
  Future<int> _sendCollaboratorInvites({
    required VideoEvent video,
    required Set<String> initialCollaboratorPubkeys,
    required Set<String> updatedCollaboratorPubkeys,
  }) async {
    final results = await sendPostPublishCollaboratorInvites(
      inviteService: _collaboratorInviteService,
      video: video,
      previousCollaboratorPubkeys: initialCollaboratorPubkeys,
      updatedCollaboratorPubkeys: updatedCollaboratorPubkeys,
    );
    return results.values.where((r) => !r.success).length;
  }
}
