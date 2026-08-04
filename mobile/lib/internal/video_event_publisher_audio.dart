part of '../services/video_event_publisher.dart';

extension _VideoEventPublisherAudio on VideoEventPublisher {
  /// Extracts audio from video, uploads to Blossom, and publishes Kind 1063 event
  ///
  /// Returns the event ID of the published audio event, or null if any step fails.
  /// Failures in audio publishing are handled gracefully - video still publishes.
  ///
  /// The audio title uses the video title if provided, falling back to
  /// "Original sound - @username" format.
  String _audioRelayHint() {
    if (_nostrService.connectedRelays.isNotEmpty) {
      return _nostrService.connectedRelays.first;
    }
    return 'wss://relay.divine.video';
  }

  String _audioCreditContent({
    required String title,
    required String creatorName,
    String? sourceUrl,
    String? licenseName,
  }) {
    final lines = <String>[
      title.trim(),
      'Created by ${creatorName.trim()}',
      if (sourceUrl?.trim().isNotEmpty ?? false) 'Source: ${sourceUrl!.trim()}',
      if (licenseName?.trim().isNotEmpty ?? false)
        'License: ${licenseName!.trim()}',
    ];
    return lines.join('\n');
  }

  Future<String?> _publishImportedAudioEvent({
    required AudioEvent audio,
    required AudioShareAttribution attribution,
    required bool allowAudioReuse,
    required String videoDTag,
    required String pubkey,
    required String relayHint,
  }) async {
    final filePath = audio.localFilePath;
    final blossomService = _blossomUploadService;
    if (filePath == null || blossomService == null) {
      return null;
    }

    final audioFile = File(filePath);
    if (!audioFile.existsSync()) {
      Log.error(
        'Imported audio file does not exist: $filePath',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      return null;
    }

    final uploadResult = await blossomService.uploadAudio(
      audioFile: audioFile,
      mimeType: audio.mimeType ?? 'audio/mpeg',
    );
    final audioUrl = uploadResult.fallbackUrl ?? uploadResult.url;
    if (!uploadResult.success ||
        audioUrl == null ||
        uploadResult.videoId == null) {
      Log.error(
        'Imported audio upload failed: ${uploadResult.errorMessage}',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      return null;
    }

    final sourceVideoReference =
        '${NIP71VideoKinds.getPreferredAddressableKind()}:$pubkey:$videoDTag';
    final publishedAudio = AudioEvent(
      id: '',
      pubkey: pubkey,
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      url: audioUrl,
      mimeType: audio.mimeType ?? 'audio/mpeg',
      sha256: uploadResult.videoId,
      fileSize: await audioFile.length(),
      duration: audio.duration,
      title: attribution.title.trim(),
      source: attribution.sourceUrl?.trim(),
      sourceVideoReference: sourceVideoReference,
      sourceVideoRelay: relayHint,
      creatorName: attribution.creatorName.trim(),
      creatorPubkey: attribution.creatorPubkey,
      creatorUrl: attribution.creatorUrl,
      licenseName: attribution.licenseName,
      licenseUrl: attribution.licenseUrl,
      publicTags: attribution.publicTags,
      allowsReuse: allowAudioReuse,
    );

    if (_authService == null || !_authService.isAuthenticated) {
      Log.error(
        'Auth service not available or not authenticated',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      return null;
    }

    final signedAudioEvent = await _authService.createAndSignEvent(
      kind: audioEventKind,
      content: _audioCreditContent(
        title: attribution.title,
        creatorName: attribution.creatorName,
        sourceUrl: attribution.sourceUrl,
        licenseName: attribution.licenseName,
      ),
      tags: publishedAudio.toTags(),
    );
    if (signedAudioEvent == null) {
      Log.error(
        'Failed to create and sign imported audio event',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      return null;
    }

    final published = await _publishEventToNostr(signedAudioEvent);
    if (!published) {
      Log.error(
        'Failed to publish imported audio event to relays',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      return null;
    }

    try {
      await _savedSoundsService?.saveSound(
        AudioEvent.fromNostrEvent(signedAudioEvent),
      );
    } catch (e) {
      Log.warning(
        'Failed to save imported audio event to My Sounds: $e',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
    }

    return signedAudioEvent.id;
  }

  Future<String?> _publishProviderAudioBridge({
    required AudioEvent audio,
    required bool allowAudioReuse,
    required String videoDTag,
    required String pubkey,
    required String relayHint,
  }) async {
    final external = audio.externalSource;
    final url = audio.url;
    if (external == null ||
        url == null ||
        url.isEmpty ||
        external.sourceUrl?.trim().isEmpty != false) {
      Log.error(
        'Provider audio is missing durable public credit',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      return null;
    }

    // `creator` is nullable all the way down from the sound-proxy schema, so a
    // thin catalog row credits the provider rather than losing the publish.
    final creatorName = external.creatorName?.trim().isNotEmpty ?? false
        ? external.creatorName!.trim()
        : external.providerName;

    final title = audio.title?.trim().isNotEmpty ?? false
        ? audio.title!.trim()
        : '${external.providerName} sound';
    final bridge = AudioEvent(
      id: '',
      pubkey: pubkey,
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      url: url,
      mimeType: audio.mimeType,
      duration: audio.duration,
      title: title,
      source: external.sourceUrl!.trim(),
      sourceVideoReference:
          '${NIP71VideoKinds.getPreferredAddressableKind()}:$pubkey:$videoDTag',
      sourceVideoRelay: relayHint,
      creatorName: creatorName,
      creatorUrl: external.creatorUrl,
      licenseName: external.license.name,
      licenseUrl: external.license.url,
      publicTags: external.catalogTags,
      proxyId: external.providerSoundId,
      proxyProtocol: external.provider,
      allowsReuse: allowAudioReuse && external.license.allowsDerivatives,
    );

    final authService = _authService;
    if (authService == null || !authService.isAuthenticated) return null;
    final event = await authService.createAndSignEvent(
      kind: audioEventKind,
      content: _audioCreditContent(
        title: title,
        creatorName: creatorName,
        sourceUrl: external.sourceUrl,
        licenseName: external.license.name,
      ),
      tags: bridge.toTags(),
    );
    if (event == null || !await _publishEventToNostr(event)) return null;
    return event.id;
  }

  Future<String?> _publishAudioEvent({
    required String videoPath,
    required String videoDTag,
    required String pubkey,
    required String relayHint,
    String? videoTitle,
    AudioShareAttribution? attribution,
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

      extractionResult = await audioExtractionService.extractAudio(
        videoPath: videoPath,
      );

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

      // Step 3: Create public title and creator credit.
      var creatorName = UserProfile.defaultDisplayNameFor(pubkey);
      if (_profileRepository != null) {
        try {
          final profile = await _profileRepository.fetchFreshProfile(
            pubkey: pubkey,
          );
          if (profile != null) creatorName = profile.bestDisplayName;
        } catch (e) {
          Log.warning(
            'Failed to fetch profile for audio credit: $e',
            name: 'VideoEventPublisher',
            category: LogCategory.video,
          );
        }
      }
      final audioTitle = attribution?.title.trim().isNotEmpty ?? false
          ? attribution!.title.trim()
          : (videoTitle?.trim().isNotEmpty ?? false)
          ? videoTitle!.trim()
          : 'Original sound - @$creatorName';
      final creditedCreator =
          attribution?.creatorName.trim().isNotEmpty ?? false
          ? attribution!.creatorName.trim()
          : creatorName;

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
        source: attribution?.sourceUrl,
        sourceVideoReference: sourceVideoReference,
        sourceVideoRelay: relayHint,
        creatorName: creditedCreator,
        creatorPubkey: attribution?.creatorPubkey ?? pubkey,
        creatorUrl: attribution?.creatorUrl,
        licenseName: attribution?.licenseName,
        licenseUrl: attribution?.licenseUrl,
        publicTags: attribution?.publicTags ?? const [],
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
        content: _audioCreditContent(
          title: audioTitle,
          creatorName: creditedCreator,
          sourceUrl: attribution?.sourceUrl,
          licenseName: attribution?.licenseName,
        ),
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

      if (_savedSoundsService != null) {
        try {
          await _savedSoundsService.saveSound(
            AudioEvent.fromNostrEvent(signedAudioEvent),
          );
          Log.info(
            'Saved published audio event to My Sounds: ${signedAudioEvent.id}',
            name: 'VideoEventPublisher',
            category: LogCategory.video,
          );
        } catch (e) {
          Log.warning(
            'Failed to save published audio event to My Sounds: $e',
            name: 'VideoEventPublisher',
            category: LogCategory.video,
          );
        }
      }

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
}
