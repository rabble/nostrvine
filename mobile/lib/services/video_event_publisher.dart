// ABOUTME: Service for publishing videos directly to Nostr without backend processing
// ABOUTME: Handles event creation, signing, and relay broadcasting for direct uploads

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'package:nostr_sdk/event.dart';
import 'package:openvine/models/audio_event.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:models/models.dart'
    hide LogCategory, NIP71VideoKinds, PendingUpload, UploadStatus;
import 'package:openvine/services/audio_extraction_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/blossom_upload_service.dart';
import 'package:openvine/services/blurhash_service.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/user_profile_service.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:openvine/services/personal_event_cache_service.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/profile_stats_cache_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/utils/proofmode_publishing_helpers.dart';
import 'package:openvine/constants/nip71_migration.dart';

/// Service for publishing processed videos to Nostr relays
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class VideoEventPublisher {
  VideoEventPublisher({
    required UploadManager uploadManager,
    required NostrClient nostrService,
    AuthService? authService,
    PersonalEventCacheService? personalEventCache,
    VideoEventService? videoEventService,
    BlossomUploadService? blossomUploadService,
    UserProfileService? userProfileService,
    AudioExtractionService? audioExtractionService,
  }) : _uploadManager = uploadManager,
       _nostrService = nostrService,
       _authService = authService,
       _personalEventCache = personalEventCache,
       _videoEventService = videoEventService,
       _blossomUploadService = blossomUploadService,
       _userProfileService = userProfileService,
       _audioExtractionService = audioExtractionService;
  final UploadManager _uploadManager;
  final NostrClient _nostrService;
  final AuthService? _authService;
  final PersonalEventCacheService? _personalEventCache;
  final VideoEventService? _videoEventService;
  final BlossomUploadService? _blossomUploadService;
  final UserProfileService? _userProfileService;
  final AudioExtractionService? _audioExtractionService;

  // Statistics
  int _totalEventsPublished = 0;
  int _totalEventsFailed = 0;
  DateTime? _lastPublishTime;

  /// Initialize the publisher
  Future<void> initialize() async {
    Log.debug(
      'Initializing VideoEventPublisher',
      name: 'VideoEventPublisher',
      category: LogCategory.video,
    );

    Log.info(
      'VideoEventPublisher initialized',
      name: 'VideoEventPublisher',
      category: LogCategory.video,
    );
  }

  /// Publish event to Nostr relays
  Future<bool> _publishEventToNostr(Event event) async {
    try {
      Log.debug(
        'Publishing event to Nostr relays: ${event.id}',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );

      // Log relay diagnostics
      Log.info(
        '🔍 Relay diagnostics: isInitialized=${_nostrService.isInitialized}, '
        'configured=${_nostrService.configuredRelayCount}, '
        'connected=${_nostrService.connectedRelayCount}',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      Log.info(
        '🔍 Configured relays: ${_nostrService.configuredRelays}',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      Log.info(
        '🔍 Connected relays: ${_nostrService.connectedRelays}',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );

      // Ensure NostrClient is initialized before attempting broadcast
      if (!_nostrService.isInitialized) {
        Log.warning(
          '⚠️ NostrClient not initialized, initializing now...',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
        await _nostrService.initialize();
      }

      Log.info(
        '📡 ${_nostrService.connectedRelayCount} relay(s) connected',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );

      // Log the complete event details
      Log.info(
        '📤 FULL EVENT TO PUBLISH:',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      Log.info(
        '  ID: ${event.id}',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      Log.info(
        '  Pubkey: ${event.pubkey}',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      Log.info(
        '  Created At: ${event.createdAt}',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      Log.info(
        '  Kind: ${event.kind}',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      Log.info(
        '  Content: "${event.content}"',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      Log.info(
        '  Tags (${event.tags.length} total):',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      for (final tag in event.tags) {
        Log.info(
          '    - ${tag.join(", ")}',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
      }
      Log.info(
        '  Signature: ${event.sig}',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      Log.info(
        '  Is Valid: ${event.isValid}',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      Log.info(
        '  Is Signed: ${event.isSigned}',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );

      // Log the raw JSON representation
      try {
        final eventMap = event.toJson();
        final jsonStr = jsonEncode(eventMap);
        Log.info(
          '📋 FULL EVENT JSON:',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
        Log.info(
          jsonStr,
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
      } catch (e) {
        Log.warning(
          'Could not serialize event to JSON: $e',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
      }

      // Use the existing Nostr service to publish
      final sentEvent = await _nostrService.publishEvent(event);

      // Check if publish was successful
      if (sentEvent != null) {
        Log.info(
          '✅ Event successfully published to relays: ${event.id}',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );

        return true;
      } else {
        Log.error(
          '❌ Event publish failed to all relays',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
        return false;
      }
    } catch (e) {
      Log.error(
        'Failed to publish event to relays: $e',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      return false;
    }
  }

  /// Get publishing statistics
  Map<String, dynamic> get publishingStats => {
    'total_published': _totalEventsPublished,
    'total_failed': _totalEventsFailed,
    'last_publish_time': _lastPublishTime?.toIso8601String(),
  };

  /// Publish a video event with custom metadata
  Future<bool> publishVideoEvent({
    required PendingUpload upload,
    String? title,
    String? description,
    List<String>? hashtags,
    int? expirationTimestamp,
    bool allowAudioReuse = false,
  }) async {
    // Create a temporary upload with updated metadata
    final updatedUpload = upload.copyWith(
      title: title ?? upload.title,
      description: description ?? upload.description,
      hashtags: hashtags ?? upload.hashtags,
    );

    return publishDirectUpload(
      updatedUpload,
      expirationTimestamp: expirationTimestamp,
      allowAudioReuse: allowAudioReuse,
    );
  }

  /// Publish a video directly without polling (for direct upload)
  Future<bool> publishDirectUpload(
    PendingUpload upload, {
    int? expirationTimestamp,
    bool allowAudioReuse = false,
  }) async {
    if (upload.videoId == null || upload.cdnUrl == null) {
      Log.error(
        'Cannot publish upload - missing videoId or cdnUrl',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      return false;
    }

    try {
      Log.debug(
        'Publishing direct upload: ${upload.videoId}',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );

      // Create NIP-71 compliant tags for the video
      final tags = <List<String>>[];

      // Generate unique identifier for the addressable event
      // Use videoId if available, otherwise generate from timestamp and upload ID
      final dTag =
          upload.videoId ??
          '${DateTime.now().millisecondsSinceEpoch}_${upload.id}';
      tags.add(['d', dTag]);

      // Build imeta tag components
      final imetaComponents = <String>[];

      // Add all video URLs from Blossom upload stored in PendingUpload
      // Priority order (based on _scoreVideoUrl in video_event.dart):
      // 1. streamingMp4Url (BunnyStream MP4 - scores 110) - ONLY if valid
      // 2. fallbackUrl (R2 MP4 - scores 100)
      // 3. streamingHlsUrl (HLS - scores 90)

      final urlsAdded = <String>[];

      // Validate BunnyStream MP4 URL - must have quality suffix (e.g., play_360p.mp4)
      // Invalid: .../play.mp4 (returns 404)
      // Valid: .../play_360p.mp4, .../play_480p.mp4, etc.
      if (upload.streamingMp4Url != null &&
          upload.streamingMp4Url!.isNotEmpty) {
        final isValidBunnyMp4 =
            upload.streamingMp4Url!.contains('stream.divine.video')
            ? upload.streamingMp4Url!.contains(RegExp(r'play_\d+p\.mp4'))
            : true; // Non-BunnyStream URLs are assumed valid

        if (isValidBunnyMp4) {
          imetaComponents.add('url ${upload.streamingMp4Url}');
          urlsAdded.add('MP4(streaming): ${upload.streamingMp4Url}');
        } else {
          Log.warning(
            '⚠️ Skipping invalid BunnyStream MP4 URL (missing quality suffix): ${upload.streamingMp4Url}',
            name: 'VideoEventPublisher',
            category: LogCategory.video,
          );
        }
      }

      if (upload.fallbackUrl != null && upload.fallbackUrl!.isNotEmpty) {
        imetaComponents.add('url ${upload.fallbackUrl}');
        urlsAdded.add('MP4(R2 fallback): ${upload.fallbackUrl}');
      }

      if (upload.streamingHlsUrl != null &&
          upload.streamingHlsUrl!.isNotEmpty) {
        imetaComponents.add('url ${upload.streamingHlsUrl}');
        urlsAdded.add('HLS: ${upload.streamingHlsUrl}');
      }

      // Fallback to legacy cdnUrl if no Blossom-specific URLs
      if (urlsAdded.isEmpty &&
          upload.cdnUrl != null &&
          upload.cdnUrl!.isNotEmpty) {
        imetaComponents.add('url ${upload.cdnUrl}');
        urlsAdded.add('Legacy CDN: ${upload.cdnUrl}');
      }

      if (urlsAdded.isNotEmpty) {
        Log.info(
          '✅ Added video URLs to imeta:\n  ${urlsAdded.join("\n  ")}',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
      } else {
        Log.error(
          '❌ No video URLs available from upload',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
      }

      imetaComponents.add('m video/mp4');

      // Use uploaded thumbnail CDN URL from Blossom upload
      if (upload.thumbnailPath != null && upload.thumbnailPath!.isNotEmpty) {
        final thumbnailPath = upload.thumbnailPath!;
        // Only include HTTP/HTTPS CDN URLs
        if (thumbnailPath.startsWith('http://') ||
            thumbnailPath.startsWith('https://')) {
          imetaComponents.add('image $thumbnailPath');
          Log.info(
            '✅ Using uploaded thumbnail CDN URL: $thumbnailPath',
            name: 'VideoEventPublisher',
            category: LogCategory.video,
          );
        }
      }

      // Add dimensions to imeta if available
      if (upload.videoWidth != null && upload.videoHeight != null) {
        imetaComponents.add('dim ${upload.videoWidth}x${upload.videoHeight}');
      }

      // Add file size and SHA256 if available from local video file
      if (upload.localVideoPath.isNotEmpty) {
        try {
          final videoFile = File(upload.localVideoPath);
          if (videoFile.existsSync()) {
            // Add file size
            final fileSize = videoFile.lengthSync();
            imetaComponents.add('size $fileSize');

            // Calculate SHA256 hash
            final bytes = await videoFile.readAsBytes();
            final hash = sha256.convert(bytes);
            imetaComponents.add('x $hash');

            Log.verbose(
              'Added file metadata - size: $fileSize bytes, hash: $hash',
              name: 'VideoEventPublisher',
              category: LogCategory.video,
            );
          }
        } catch (e) {
          Log.warning(
            'Failed to calculate file metadata: $e',
            name: 'VideoEventPublisher',
            category: LogCategory.video,
          );
        }
      }

      // Generate blurhash for progressive image loading
      if (upload.localVideoPath.isNotEmpty) {
        try {
          Log.debug(
            '🎨 Generating blurhash from video thumbnail',
            name: 'VideoEventPublisher',
            category: LogCategory.video,
          );

          // Extract thumbnail bytes with 10-second timeout
          final thumbnailBytes =
              await VideoThumbnailService.extractThumbnailBytes(
                videoPath: upload.localVideoPath,
                timeMs: 500,
                quality: 75,
              ).timeout(
                const Duration(seconds: 10),
                onTimeout: () {
                  Log.warning(
                    '⏱️ Thumbnail extraction timed out after 10 seconds',
                    name: 'VideoEventPublisher',
                    category: LogCategory.video,
                  );
                  return null;
                },
              );

          if (thumbnailBytes != null) {
            // Generate blurhash with 3-second timeout
            final blurhash =
                await BlurhashService.generateBlurhash(thumbnailBytes).timeout(
                  const Duration(seconds: 3),
                  onTimeout: () {
                    Log.warning(
                      '⏱️ Blurhash generation timed out after 3 seconds',
                      name: 'VideoEventPublisher',
                      category: LogCategory.video,
                    );
                    return null;
                  },
                );

            if (blurhash != null && blurhash.isNotEmpty) {
              imetaComponents.add('blurhash $blurhash');
              Log.info(
                '✅ Generated blurhash: $blurhash',
                name: 'VideoEventPublisher',
                category: LogCategory.video,
              );
            } else {
              Log.warning(
                'Blurhash generation returned null or empty',
                name: 'VideoEventPublisher',
                category: LogCategory.video,
              );
            }
          } else {
            Log.warning(
              'Thumbnail extraction returned null',
              name: 'VideoEventPublisher',
              category: LogCategory.video,
            );
          }
        } catch (e) {
          Log.warning(
            'Failed to generate blurhash: $e',
            name: 'VideoEventPublisher',
            category: LogCategory.video,
          );
          // Continue publishing without blurhash - it's optional metadata
        }
      }

      // Add the complete imeta tag
      tags.add(['imeta', ...imetaComponents]);

      // Optional tags
      if (upload.title != null) tags.add(['title', upload.title!]);
      if (upload.description != null) {
        tags.add(['summary', upload.description!]);
      }

      // Add hashtags
      if (upload.hashtags != null) {
        for (final hashtag in upload.hashtags!) {
          tags.add(['t', hashtag]);
        }
      }

      // Add client tag
      tags.add(['client', 'diVine']);

      // Add published_at tag (current timestamp)
      tags.add([
        'published_at',
        (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString(),
      ]);

      // Add duration tag if available
      if (upload.videoDuration != null) {
        tags.add(['duration', upload.videoDuration!.inSeconds.toString()]);
      }

      // Add alt tag for accessibility (use title or description as alt text)
      final altText = upload.title ?? upload.description ?? 'Short video';
      tags.add(['alt', altText]);

      // Add expiration tag if specified
      if (expirationTimestamp != null) {
        tags.add(['expiration', expirationTimestamp.toString()]);
      }

      // Handle audio reuse: extract audio, upload, publish Kind 1063 event
      // Then add e tag linking video to audio event
      String? audioEventId;
      if (allowAudioReuse && upload.localVideoPath.isNotEmpty) {
        tags.add(['allow_audio_reuse', 'true']);
        Log.info(
          'Audio reuse enabled - starting audio publishing flow',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );

        // Get the user's pubkey for the audio event
        final userPubkey = _authService?.currentPublicKeyHex;
        if (userPubkey != null) {
          // Get a relay hint from connected relays
          String relayHint = 'wss://relay.divine.video';
          if (_nostrService.connectedRelays.isNotEmpty) {
            relayHint = _nostrService.connectedRelays.first;
          }

          // Publish audio event first (we need its ID for the video event)
          audioEventId = await _publishAudioEvent(
            videoPath: upload.localVideoPath,
            videoDTag: dTag,
            pubkey: userPubkey,
            relayHint: relayHint,
            videoTitle: upload.title,
          );

          if (audioEventId != null) {
            // Add e tag referencing the audio event
            // Format: ["e", <audio-event-id>, <relay-hint>, "audio"]
            tags.add(['e', audioEventId, relayHint, 'audio']);
            Log.info(
              'Added audio reference e tag: $audioEventId',
              name: 'VideoEventPublisher',
              category: LogCategory.video,
            );
          } else {
            Log.warning(
              'Audio publishing failed - continuing with video-only publish',
              name: 'VideoEventPublisher',
              category: LogCategory.video,
            );
          }
        } else {
          Log.warning(
            'No user pubkey available - skipping audio publishing',
            name: 'VideoEventPublisher',
            category: LogCategory.video,
          );
        }
      }

      // Add ProofMode tags if native proof exists
      if (upload.hasProofMode) {
        try {
          final nativeProof = upload.nativeProof;
          if (nativeProof != null) {
            Log.info(
              '📜 Adding ProofMode verification tags to Nostr event',
              name: 'VideoEventPublisher',
              category: LogCategory.video,
            );

            // Add verification level tag (NIP-145)
            final verificationLevel = getVerificationLevel(nativeProof);
            tags.add(['verification', verificationLevel]);
            Log.verbose(
              'Added verification tag: $verificationLevel',
              name: 'VideoEventPublisher',
              category: LogCategory.video,
            );

            // Add ProofMode native proof tag (complete JSON proof data)
            final proofTag = createProofManifestTag(nativeProof);
            tags.add(['proofmode', proofTag]);
            Log.verbose(
              'Added proofmode proof tag (${proofTag.length} chars)',
              name: 'VideoEventPublisher',
              category: LogCategory.video,
            );

            // Add device attestation tag if available (NIP-145)
            final deviceTag = createDeviceAttestationTag(nativeProof);
            if (deviceTag != null) {
              tags.add(['device_attestation', deviceTag]);
              Log.verbose(
                'Added device_attestation tag',
                name: 'VideoEventPublisher',
                category: LogCategory.video,
              );
            }

            // Add PGP fingerprint tag if available (NIP-145)
            final pgpTag = createPgpFingerprintTag(nativeProof);
            if (pgpTag != null) {
              tags.add(['pgp_fingerprint', pgpTag]);
              Log.verbose(
                'Added pgp_fingerprint tag: $pgpTag',
                name: 'VideoEventPublisher',
                category: LogCategory.video,
              );
            }

            Log.info(
              '✅ ProofMode verification tags added successfully',
              name: 'VideoEventPublisher',
              category: LogCategory.video,
            );
          }
        } catch (e) {
          Log.error(
            'Failed to add ProofMode tags: $e',
            name: 'VideoEventPublisher',
            category: LogCategory.video,
          );
          // Continue publishing even if ProofMode tag generation fails
        }
      }

      // Create the event content
      final content = upload.description ?? upload.title ?? '';

      // Create and sign the event
      if (_authService == null) {
        Log.error(
          'Auth service is null - cannot create video event',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
        return false;
      }

      if (!_authService.isAuthenticated) {
        Log.error(
          'User not authenticated - cannot create video event',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
        return false;
      }

      Log.debug(
        '📱 Creating and signing video event...',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      Log.verbose(
        'Content: "$content"',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      Log.verbose(
        'Tags: ${tags.length} tags',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );

      final event = await _authService.createAndSignEvent(
        kind:
            NIP71VideoKinds.getPreferredAddressableKind(), // NIP-71 addressable short video
        content: content,
        tags: tags,
      );

      if (event == null) {
        Log.error(
          'Failed to create and sign video event - createAndSignEvent returned null',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
        return false;
      }

      // Cache the video event immediately after creation
      _personalEventCache?.cacheUserEvent(event);

      Log.info(
        'Created video event: ${event.id}',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );

      // Publish to Nostr relays with retry logic
      Log.info(
        '🚀 Starting relay publication for event ${event.id}',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );

      // Retry up to 3 times with exponential backoff
      const maxRetries = 3;
      var publishResult = false;

      for (var attempt = 1; attempt <= maxRetries; attempt++) {
        publishResult = await _publishEventToNostr(event);

        if (publishResult) {
          if (attempt > 1) {
            Log.info(
              '✅ Publish succeeded on attempt $attempt',
              name: 'VideoEventPublisher',
              category: LogCategory.video,
            );
          }
          break;
        }

        if (attempt < maxRetries) {
          final delaySeconds = attempt * 2; // 2s, 4s backoff
          Log.warning(
            '⚠️ Publish attempt $attempt failed, retrying in ${delaySeconds}s...',
            name: 'VideoEventPublisher',
            category: LogCategory.video,
          );
          await Future<void>.delayed(Duration(seconds: delaySeconds));
        } else {
          Log.error(
            '❌ All $maxRetries publish attempts failed',
            name: 'VideoEventPublisher',
            category: LogCategory.video,
          );
        }
      }

      if (publishResult) {
        // Update upload status
        await _uploadManager.updateUploadStatus(
          upload.id,
          UploadStatus.published,
          nostrEventId: event.id,
        );

        _totalEventsPublished++;
        _lastPublishTime = DateTime.now();

        // Add the published video to local cache immediately for instant UI updates
        if (_videoEventService != null) {
          try {
            final videoEvent = VideoEvent.fromNostrEvent(event);
            _videoEventService.addVideoEvent(videoEvent);
            Log.info(
              'Added published video to discovery cache: ${event.id}',
              name: 'VideoEventPublisher',
              category: LogCategory.video,
            );
          } catch (e) {
            Log.warning(
              'Failed to add published video to cache: $e',
              name: 'VideoEventPublisher',
              category: LogCategory.video,
            );
          }
        }

        // Invalidate profile stats cache so video count updates immediately
        final currentPubkey = _nostrService.publicKey;
        if (currentPubkey.isNotEmpty) {
          ProfileStatsCacheService().clearStats(currentPubkey);
          Log.debug(
            'Invalidated profile stats cache for new video',
            name: 'VideoEventPublisher',
            category: LogCategory.video,
          );
        }

        Log.info(
          'Successfully published direct upload: ${event.id}',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
        Log.debug(
          'Video URL: ${upload.cdnUrl}',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );

        return true;
      } else {
        Log.error(
          'Failed to publish to Nostr relays',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
        return false;
      }
    } catch (e, stackTrace) {
      Log.error(
        'Error publishing direct upload: $e',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      Log.verbose(
        '📱 Stack trace: $stackTrace',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      _totalEventsFailed++;
      return false;
    }
  }

  /// Extracts audio from video, uploads to Blossom, and publishes Kind 1063 event
  ///
  /// Returns the event ID of the published audio event, or null if any step fails.
  /// Failures in audio publishing are handled gracefully - video still publishes.
  ///
  /// The audio title uses the video title if provided, falling back to
  /// "Original sound - @username" format.
  Future<String?> _publishAudioEvent({
    required String videoPath,
    required String videoDTag,
    required String pubkey,
    required String relayHint,
    String? videoTitle,
  }) async {
    Log.info(
      'Starting audio extraction and publishing flow',
      name: 'VideoEventPublisher',
      category: LogCategory.video,
    );

    // Check required services
    if (_blossomUploadService == null) {
      Log.warning(
        'BlossomUploadService not available - skipping audio publishing',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      return null;
    }

    final audioExtractionService =
        _audioExtractionService ?? AudioExtractionService();

    AudioExtractionResult? extractionResult;
    try {
      // Step 1: Extract audio from video
      Log.info(
        'Step 1: Extracting audio from video: $videoPath',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );

      extractionResult = await audioExtractionService.extractAudio(videoPath);

      Log.info(
        'Audio extraction successful: ${extractionResult.audioFilePath}',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      Log.debug(
        'Audio details: duration=${extractionResult.duration}s, '
        'size=${extractionResult.fileSize}B, '
        'mimeType=${extractionResult.mimeType}',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );

      // Step 2: Upload audio to Blossom
      Log.info(
        'Step 2: Uploading audio to Blossom',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );

      final audioFile = File(extractionResult.audioFilePath);
      // _blossomUploadService is guaranteed non-null here (checked at method start)
      final blossomService = _blossomUploadService;
      final uploadResult = await blossomService.uploadAudio(
        audioFile: audioFile,
        mimeType: extractionResult.mimeType,
      );

      if (!uploadResult.success) {
        Log.error(
          'Audio upload failed: ${uploadResult.errorMessage}',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
        return null;
      }

      final audioUrl = uploadResult.fallbackUrl ?? uploadResult.url;
      if (audioUrl == null) {
        Log.error(
          'Audio upload succeeded but no URL returned',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
        return null;
      }

      Log.info(
        'Audio upload successful: $audioUrl',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );

      // Step 3: Create audio title from video title or fallback to username
      String audioTitle;
      if (videoTitle != null && videoTitle.isNotEmpty) {
        // Use the video title as the audio title
        audioTitle = videoTitle;
        Log.debug(
          'Audio title set from video title: $audioTitle',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
      } else {
        // Fallback to "Original sound - @username" format
        audioTitle = 'Original sound';
        if (_userProfileService != null) {
          try {
            final profile = await _userProfileService.fetchProfile(pubkey);
            if (profile != null) {
              // Use bestDisplayName which has proper fallback logic:
              // displayName -> name -> truncated npub
              final displayName = profile.bestDisplayName;
              audioTitle = 'Original sound - @$displayName';
              Log.debug(
                'Audio title set from profile: $audioTitle',
                name: 'VideoEventPublisher',
                category: LogCategory.video,
              );
            } else {
              Log.warning(
                'Profile not found for pubkey, using default audio title',
                name: 'VideoEventPublisher',
                category: LogCategory.video,
              );
            }
          } catch (e) {
            Log.warning(
              'Failed to fetch profile for audio title: $e',
              name: 'VideoEventPublisher',
              category: LogCategory.video,
            );
          }
        }
      }

      Log.debug(
        'Audio title: $audioTitle',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );

      // Step 4: Create Kind 1063 audio event
      Log.info(
        'Step 3: Creating Kind 1063 audio event',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );

      // Build the source video reference: "kind:pubkey:d-tag"
      final sourceVideoReference =
          '${NIP71VideoKinds.getPreferredAddressableKind()}:$pubkey:$videoDTag';

      // Create AudioEvent for tag generation
      final audioEvent = AudioEvent(
        id: '', // Will be set by signing
        pubkey: pubkey,
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        url: audioUrl,
        mimeType: extractionResult.mimeType,
        sha256: extractionResult.sha256Hash,
        fileSize: extractionResult.fileSize,
        duration: extractionResult.duration,
        title: audioTitle,
        sourceVideoReference: sourceVideoReference,
        sourceVideoRelay: relayHint,
      );

      // Generate tags from the AudioEvent model
      final audioTags = audioEvent.toTags();

      // Create and sign the audio event
      if (_authService == null || !_authService.isAuthenticated) {
        Log.error(
          'Auth service not available or not authenticated',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
        return null;
      }

      final signedAudioEvent = await _authService.createAndSignEvent(
        kind: audioEventKind, // Kind 1063
        content: '', // Empty content per NIP-94
        tags: audioTags,
      );

      if (signedAudioEvent == null) {
        Log.error(
          'Failed to create and sign audio event',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
        return null;
      }

      Log.info(
        'Created audio event: ${signedAudioEvent.id}',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );

      // Step 5: Publish audio event to relays
      Log.info(
        'Step 4: Publishing audio event to relays',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );

      final publishResult = await _publishEventToNostr(signedAudioEvent);

      if (!publishResult) {
        Log.error(
          'Failed to publish audio event to relays',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
        return null;
      }

      Log.info(
        'Audio event published successfully: ${signedAudioEvent.id}',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );

      return signedAudioEvent.id;
    } on AudioExtractionException catch (e) {
      Log.warning(
        'Audio extraction failed: ${e.message}',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      return null;
    } catch (e, stackTrace) {
      Log.error(
        'Audio publishing failed: $e',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      Log.verbose(
        'Stack trace: $stackTrace',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      return null;
    } finally {
      // Clean up temporary audio file
      if (extractionResult != null) {
        try {
          await audioExtractionService.cleanupAudioFile(
            extractionResult.audioFilePath,
          );
          Log.debug(
            'Cleaned up temporary audio file',
            name: 'VideoEventPublisher',
            category: LogCategory.video,
          );
        } catch (e) {
          Log.warning(
            'Failed to cleanup temporary audio file: $e',
            name: 'VideoEventPublisher',
            category: LogCategory.video,
          );
        }
      }
    }
  }

  void dispose() {
    Log.debug(
      'Disposing VideoEventPublisher',
      name: 'VideoEventPublisher',
      category: LogCategory.video,
    );
  }
}
