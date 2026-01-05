// ABOUTME: Pure video metadata screen using revolutionary Riverpod architecture
// ABOUTME: Adds metadata to recorded videos before publishing without VideoManager dependencies

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:openvine/models/text_overlay.dart';
import 'package:openvine/providers/sound_library_service_provider.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/services/text_overlay_renderer.dart';
import 'package:openvine/services/video_export_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/providers/vine_recording_provider.dart';
import 'package:openvine/models/pending_upload.dart'
    show UploadStatus, PendingUpload;
import 'package:openvine/models/vine_draft.dart';
import 'package:models/models.dart' as vine show AspectRatio;
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/widgets/upload_progress_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openvine/utils/video_duration_extractor.dart';

/// Parameters for background video processing (text overlays, audio mixing)
class VideoProcessingParams {
  const VideoProcessingParams({
    this.textOverlays = const [],
    this.selectedSoundId,
    this.externalAudioEventId,
    this.externalAudioUrl,
    this.externalAudioIsBundled = false,
    this.externalAudioAssetPath,
    this.previewSize,
  });

  final List<TextOverlay> textOverlays;
  final String? selectedSoundId;
  final String? externalAudioEventId;
  final String? externalAudioUrl;
  final bool externalAudioIsBundled;
  final String? externalAudioAssetPath;
  final Size? previewSize;

  bool get needsProcessing =>
      textOverlays.isNotEmpty ||
      selectedSoundId != null ||
      externalAudioUrl != null ||
      externalAudioAssetPath != null;
}

/// Pure video metadata screen using revolutionary single-controller Riverpod architecture
class VideoMetadataScreenPure extends ConsumerStatefulWidget {
  const VideoMetadataScreenPure({
    super.key,
    required this.draftId,
    this.processingParams,
  });

  final String draftId;

  /// Optional processing parameters for background video processing
  /// When provided, the screen will process the video before starting upload
  final VideoProcessingParams? processingParams;

  @override
  ConsumerState<VideoMetadataScreenPure> createState() =>
      _VideoMetadataScreenPureState();
}

class _VideoMetadataScreenPureState
    extends ConsumerState<VideoMetadataScreenPure> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _hashtagController = TextEditingController();
  final List<String> _hashtags = [];
  bool _isExpiringPost = false;
  bool _expirationConfirmed = false; // User must explicitly confirm expiration
  int _expirationHours = 24;
  bool _isPublishing = false;
  bool?
  _allowAudioReuse; // Per-video audio sharing override (null = not loaded)
  String _publishingStatus = '';
  double _uploadProgress = 0.0;
  String? _currentUploadId;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isVideoPlaying = false;
  VineDraft? _currentDraft;

  // Background upload state (managed by Task 3 - initState/dispose)
  String? _backgroundUploadId;
  StreamSubscription? _uploadProgressListener;

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftService = DraftStorageService(prefs);
      final drafts = await draftService.getAllDrafts();

      final draft = drafts.firstWhere(
        (d) => d.id == widget.draftId,
        orElse: () {
          Log.error(
            '📝 Draft not found: ${widget.draftId}',
            category: LogCategory.video,
          );
          if (mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Draft not found'),
                backgroundColor: Colors.red,
              ),
            );
          }
          throw StateError('Draft ${widget.draftId} not found');
        },
      );

      // Load the global audio sharing preference as default
      final audioSharingService = ref.read(
        audioSharingPreferenceServiceProvider,
      );
      final defaultAudioSharing = audioSharingService.isAudioSharingEnabled;

      if (mounted) {
        setState(() {
          _currentDraft = draft;
          _allowAudioReuse = defaultAudioSharing;
        });

        // Populate form with draft data
        _titleController.text = draft.title;
        _descriptionController.text = draft.description;

        // Convert hashtags list back to individual tags (not space-separated like VinePreviewScreenPure)
        _hashtags.clear();
        _hashtags.addAll(draft.hashtags);

        Log.info(
          '📝 VideoMetadataScreenPure: Loaded draft ${draft.id}, audio sharing default: $defaultAudioSharing',
          category: LogCategory.video,
        );

        // Initialize video preview
        _initializeVideoPreview();

        // Check if we need to process video first (text overlays, audio mixing)
        if (widget.processingParams?.needsProcessing == true) {
          Log.info(
            '📝 Starting background video processing',
            category: LogCategory.video,
          );
          // Start processing in background, then upload when done
          _processVideoInBackground();
        } else {
          // No processing needed - start background upload immediately (Task 3)
          _startBackgroundUpload();
        }
      }
    } catch (e) {
      Log.error('📝 Failed to load draft: $e', category: LogCategory.video);
    }
  }

  /// Process video in background (text overlays, audio mixing)
  /// Updates draft with processed video file when complete
  Future<void> _processVideoInBackground() async {
    if (_currentDraft == null || widget.processingParams == null) return;

    final params = widget.processingParams!;
    if (!params.needsProcessing) {
      _startBackgroundUpload();
      return;
    }

    try {
      String currentVideoPath = _currentDraft!.videoFile.path;
      final prefs = await SharedPreferences.getInstance();
      final draftService = DraftStorageService(prefs);

      // Step 1: Apply text overlays if any exist
      if (params.textOverlays.isNotEmpty) {
        Log.info(
          '📝 Burning ${params.textOverlays.length} text overlays into video',
          category: LogCategory.video,
        );

        // Get video size from the video controller or use a default
        Size videoSize;
        if (_videoController != null && _isVideoInitialized) {
          videoSize = _videoController!.value.size;
        } else {
          // Fallback to 1080p
          videoSize = const Size(1080, 1920);
        }

        final renderer = TextOverlayRenderer();
        final overlayImage = await renderer.renderOverlays(
          params.textOverlays,
          videoSize,
          previewSize: params.previewSize,
        );

        final exportService = VideoExportService();
        final newPath = await exportService.applyTextOverlay(
          currentVideoPath,
          overlayImage,
        );

        // Clean up previous temp file if different from original
        if (currentVideoPath != _currentDraft!.videoFile.path) {
          try {
            await File(currentVideoPath).delete();
          } catch (_) {}
        }

        currentVideoPath = newPath;

        Log.info(
          '📝 Text overlays burned into video: $currentVideoPath',
          category: LogCategory.video,
        );
      }

      // Step 2: Apply external audio from lip sync flow
      if (params.externalAudioUrl != null ||
          params.externalAudioAssetPath != null) {
        Log.info(
          '📝 Mixing external audio from lip sync: ${params.externalAudioEventId}',
          category: LogCategory.video,
        );

        final exportService = VideoExportService();
        final previousPath = currentVideoPath;

        if (params.externalAudioIsBundled &&
            params.externalAudioAssetPath != null) {
          // Bundled sound
          currentVideoPath = await exportService.mixAudio(
            currentVideoPath,
            params.externalAudioAssetPath!,
          );
        } else if (params.externalAudioUrl != null) {
          final audioUrl = params.externalAudioUrl!;
          if (audioUrl.startsWith('http://') ||
              audioUrl.startsWith('https://')) {
            // Download remote audio first
            final tempDir = await getTemporaryDirectory();
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final audioFilePath = '${tempDir.path}/audio_$timestamp.mp3';

            final response = await http.get(Uri.parse(audioUrl));
            if (response.statusCode == 200) {
              await File(audioFilePath).writeAsBytes(response.bodyBytes);
              currentVideoPath = await exportService.mixExternalAudio(
                currentVideoPath,
                audioFilePath,
              );
              // Clean up downloaded audio
              try {
                await File(audioFilePath).delete();
              } catch (_) {}
            }
          }
        }

        // Clean up previous temp file
        if (previousPath != _currentDraft!.videoFile.path &&
            previousPath != currentVideoPath) {
          try {
            await File(previousPath).delete();
          } catch (_) {}
        }

        Log.info(
          '📝 External audio mixed into video: $currentVideoPath',
          category: LogCategory.video,
        );
      }

      // Step 3: Apply sound from sound picker (if no external audio)
      if (params.selectedSoundId != null &&
          params.externalAudioUrl == null &&
          params.externalAudioAssetPath == null) {
        Log.info(
          '📝 Mixing sound: ${params.selectedSoundId}',
          category: LogCategory.video,
        );

        final soundService = await ref.read(soundLibraryServiceProvider.future);
        final sound = soundService.getSoundById(params.selectedSoundId!);

        if (sound != null) {
          final exportService = VideoExportService();
          final previousPath = currentVideoPath;

          currentVideoPath = await exportService.mixAudio(
            currentVideoPath,
            sound.assetPath,
          );

          // Clean up previous temp file
          if (previousPath != _currentDraft!.videoFile.path) {
            try {
              await File(previousPath).delete();
            } catch (_) {}
          }

          Log.info(
            '📝 Sound mixed into video: $currentVideoPath',
            category: LogCategory.video,
          );
        }
      }

      // Update draft with processed video file
      if (currentVideoPath != _currentDraft!.videoFile.path) {
        final updatedDraft = _currentDraft!.copyWith(
          videoFile: File(currentVideoPath),
        );

        // Save updated draft
        await draftService.saveDraft(updatedDraft);

        if (mounted) {
          setState(() {
            _currentDraft = updatedDraft;
          });
        }

        Log.info(
          '📝 Draft updated with processed video: $currentVideoPath',
          category: LogCategory.video,
        );
      }

      // Now start the background upload with processed video
      _startBackgroundUpload();
    } catch (e) {
      Log.error(
        '📝 Background video processing failed: $e',
        category: LogCategory.video,
      );

      if (mounted) {
        // Still try to upload the original video
        _startBackgroundUpload();
      }
    }
  }

  Future<void> _initializeVideoPreview() async {
    if (_currentDraft == null) return;

    try {
      // Verify file exists before attempting to play
      if (!await _currentDraft!.videoFile.exists()) {
        throw Exception(
          'Video file does not exist: ${_currentDraft!.videoFile.path}',
        );
      }

      final fileSize = await _currentDraft!.videoFile.length();
      Log.info(
        '📝 Initializing video preview for file: ${_currentDraft!.videoFile.path} (${fileSize} bytes)',
        category: LogCategory.video,
      );

      _videoController = VideoPlayerController.file(_currentDraft!.videoFile);

      // Add timeout to prevent hanging - video player should initialize quickly
      await _videoController!.initialize().timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          throw Exception(
            'Video player initialization timed out after 2 seconds',
          );
        },
      );

      await _videoController!.setLooping(true);

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
      }

      // Listen for play state changes
      _videoController!.addListener(_onVideoStateChanged);

      // Start playing after UI has rendered
      // Use addPostFrameCallback to ensure play() happens after frame is drawn
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (_videoController != null && mounted) {
          await _videoController!.play();
          Log.info(
            '📝 Video started playing (isPlaying: ${_videoController!.value.isPlaying})',
            category: LogCategory.video,
          );
        }
      });

      Log.info(
        '📝 Video preview initialized successfully',
        category: LogCategory.video,
      );
    } catch (e) {
      Log.error(
        '📝 Failed to initialize video preview: $e',
        category: LogCategory.video,
      );

      // Still allow the screen to be usable even if preview fails
      if (mounted) {
        setState(() {
          _isVideoInitialized = false;
        });
      }
    }
  }

  void _onVideoStateChanged() {
    if (_videoController != null && mounted) {
      final isPlaying = _videoController!.value.isPlaying;
      if (_isVideoPlaying != isPlaying) {
        setState(() {
          _isVideoPlaying = isPlaying;
        });
      }
    }
  }

  void _toggleVideoPlayPause() {
    if (_videoController == null) return;

    if (_videoController!.value.isPlaying) {
      _videoController!.pause();
    } else {
      _videoController!.play();
    }
  }

  /// Start background upload immediately when screen loads (Task 3)
  Future<void> _startBackgroundUpload() async {
    if (_currentDraft == null) {
      Log.warning(
        '📝 Cannot start background upload: draft not loaded',
        category: LogCategory.video,
      );
      return;
    }

    try {
      final uploadManager = ref.read(uploadManagerProvider);
      final authService = ref.read(authServiceProvider);

      if (!authService.isAuthenticated) {
        Log.error(
          '📝 Cannot start background upload: not authenticated (state: ${authService.authState.name})',
          category: LogCategory.video,
        );
        return;
      }

      final pubkey = authService.currentPublicKeyHex!;

      Log.info(
        '📝 Starting background upload for draft: ${_currentDraft!.id}',
        category: LogCategory.video,
      );

      // Get video duration with fallback
      final videoDuration = await _getVideoDuration();

      // Start upload in background - single source of truth from draft
      final pendingUpload = await uploadManager.startUploadFromDraft(
        draft: _currentDraft!,
        nostrPubkey: pubkey,
        videoDuration: videoDuration,
      );

      // Store upload ID in state
      if (mounted) {
        setState(() {
          _backgroundUploadId = pendingUpload.id;
        });
      }

      Log.info(
        '📝 Background upload started: ${pendingUpload.id}',
        category: LogCategory.video,
      );
    } catch (e) {
      Log.error(
        '📝 Failed to start background upload: $e',
        category: LogCategory.video,
      );
    }
  }

  /// Cancel background upload if still in progress (Task 3)
  /// Note: This is called from dispose(), so we can't await async operations.
  /// The cancel operation will run in the background.
  void _cancelBackgroundUpload() {
    if (_backgroundUploadId == null) {
      return;
    }

    try {
      final uploadManager = ref.read(uploadManagerProvider);
      final upload = uploadManager.getUpload(_backgroundUploadId!);

      if (upload == null) {
        Log.info(
          '📝 Upload already removed: $_backgroundUploadId',
          category: LogCategory.video,
        );
        return;
      }

      // Only cancel if upload is still in progress
      if (upload.status == UploadStatus.uploading ||
          upload.status == UploadStatus.processing ||
          upload.status == UploadStatus.pending ||
          upload.status == UploadStatus.retrying) {
        Log.info(
          '📝 Cancelling background upload: $_backgroundUploadId (status: ${upload.status})',
          category: LogCategory.video,
        );
        // Fire and forget - can't await in dispose()
        unawaited(uploadManager.cancelUpload(_backgroundUploadId!));
      } else {
        Log.info(
          '📝 Upload already complete, not cancelling: $_backgroundUploadId (status: ${upload.status})',
          category: LogCategory.video,
        );
      }

      // Cancel progress listener (also fire and forget)
      unawaited(_uploadProgressListener?.cancel());
      _uploadProgressListener = null;
    } catch (e) {
      Log.error(
        '📝 Failed to cancel background upload: $e',
        category: LogCategory.video,
      );
    }
  }

  /// Get video duration with fallback to file extraction
  ///
  /// First tries to get duration from the video player controller.
  /// If that returns zero/null, extracts duration directly from the video file.
  /// This prevents publishing videos with 0-second duration.
  Future<Duration> _getVideoDuration() async {
    // Try video player controller first (if initialized)
    if (_videoController != null && _isVideoInitialized) {
      final playerDuration = _videoController!.value.duration;
      if (playerDuration != Duration.zero) {
        Log.debug(
          'Got duration from video player: ${playerDuration.inMilliseconds}ms',
          name: 'VideoMetadataScreen',
          category: LogCategory.video,
        );
        return playerDuration;
      }
      Log.warning(
        'Video player initialized but duration is zero',
        name: 'VideoMetadataScreen',
        category: LogCategory.video,
      );
    }

    // Fallback: extract duration from video file
    if (_currentDraft != null) {
      Log.info(
        'Extracting duration from video file as fallback',
        name: 'VideoMetadataScreen',
        category: LogCategory.video,
      );
      final extractedDuration = await extractVideoDuration(
        _currentDraft!.videoFile,
      );
      if (extractedDuration != null && extractedDuration != Duration.zero) {
        Log.info(
          'Extracted duration from file: ${extractedDuration.inMilliseconds}ms',
          name: 'VideoMetadataScreen',
          category: LogCategory.video,
        );
        return extractedDuration;
      }
      Log.error(
        'Failed to extract duration from video file',
        name: 'VideoMetadataScreen',
        category: LogCategory.video,
      );
    }

    // Last resort: return zero and warn
    Log.error(
      'Could not determine video duration - using 0',
      name: 'VideoMetadataScreen',
      category: LogCategory.video,
    );
    return Duration.zero;
  }

  @override
  void dispose() {
    // Cancel background upload if still in progress (Task 3)
    _cancelBackgroundUpload();

    _titleController.dispose();
    _descriptionController.dispose();
    _hashtagController.dispose();
    _videoController?.removeListener(_onVideoStateChanged);
    _videoController?.dispose();
    super.dispose();

    Log.info(
      '📝 VideoMetadataScreenPure: Disposed',
      category: LogCategory.video,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: VineTheme.vineGreen,
            leading: IconButton(
              key: const Key('back-button'),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text(
              'Add Metadata',
              style: TextStyle(color: Colors.white),
            ),
            actions: [
              if (_currentDraft?.canRetry ?? false)
                // Show Retry button for failed drafts
                TextButton(
                  key: const Key('retry-button'),
                  onPressed: _isPublishing ? null : _publishVideo,
                  child: _isPublishing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Retry',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                )
              else
                // Show Publish button for draft status
                TextButton(
                  onPressed:
                      (_isPublishing || (_currentDraft?.isPublishing ?? false))
                      ? null
                      : _publishVideo,
                  child:
                      (_isPublishing || (_currentDraft?.isPublishing ?? false))
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Publish',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
            ],
          ),
          body: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.opaque,
            child: Stack(
              children: [
                Column(
                  children: [
                    // Error banner for failed publishes
                    if (_currentDraft?.publishStatus == PublishStatus.failed &&
                        _currentDraft?.publishError != null)
                      Container(
                        width: double.infinity,
                        color: Colors.red[900],
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _currentDraft!.publishError!,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            Text(
                              'Attempt ${_currentDraft!.publishAttempts}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Video preview with tap-to-pause
                            GestureDetector(
                              onTap: _toggleVideoPlayPause,
                              child: Container(
                                height: 200,
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Center(
                                    child:
                                        _isVideoInitialized &&
                                            _videoController != null
                                        ? Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              // Video with proper aspect ratio cropping
                                              AspectRatio(
                                                aspectRatio:
                                                    _currentDraft!
                                                            .aspectRatio ==
                                                        vine.AspectRatio.square
                                                    ? 1.0
                                                    : 9.0 / 16.0,
                                                child: ClipRect(
                                                  child: FittedBox(
                                                    fit: BoxFit.cover,
                                                    child: SizedBox(
                                                      width: _videoController!
                                                          .value
                                                          .size
                                                          .width,
                                                      height: _videoController!
                                                          .value
                                                          .size
                                                          .height,
                                                      child: VideoPlayer(
                                                        _videoController!,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              // Play/pause overlay icon
                                              AnimatedOpacity(
                                                opacity: _isVideoPlaying
                                                    ? 0.0
                                                    : 1.0,
                                                duration: const Duration(
                                                  milliseconds: 200,
                                                ),
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: Colors.black
                                                        .withValues(alpha: 0.5),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  padding: const EdgeInsets.all(
                                                    12,
                                                  ),
                                                  child: const Icon(
                                                    Icons.play_arrow,
                                                    color: Colors.white,
                                                    size: 40,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          )
                                        : Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const CircularProgressIndicator(
                                                color: VineTheme.vineGreen,
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Loading preview...',
                                                style: TextStyle(
                                                  color: Colors.grey[400],
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            Expanded(
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Title input
                                    const Text(
                                      'Title',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _titleController,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                      textInputAction: TextInputAction.next,
                                      decoration: InputDecoration(
                                        hintText: 'Enter video title...',
                                        hintStyle: TextStyle(
                                          color: Colors.grey[400],
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey[900],
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Description input
                                    const Text(
                                      'Description',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _descriptionController,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                      maxLines: 4,
                                      textInputAction: TextInputAction.next,
                                      decoration: InputDecoration(
                                        hintText: 'Describe your video...',
                                        hintStyle: TextStyle(
                                          color: Colors.grey[400],
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey[900],
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Hashtag input
                                    const Text(
                                      'Add Hashtag',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _hashtagController,
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                            textInputAction:
                                                TextInputAction.done,
                                            onEditingComplete: FocusScope.of(
                                              context,
                                            ).unfocus,
                                            decoration: InputDecoration(
                                              hintText: 'hashtag',
                                              hintStyle: TextStyle(
                                                color: Colors.grey[400],
                                              ),
                                              filled: true,
                                              fillColor: Colors.grey[900],
                                              prefixText: '#',
                                              prefixStyle: const TextStyle(
                                                color: VineTheme.vineGreen,
                                              ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                borderSide: BorderSide.none,
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                borderSide: BorderSide.none,
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                borderSide: BorderSide.none,
                                              ),
                                              errorBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                borderSide: BorderSide.none,
                                              ),
                                            ),
                                            onSubmitted: _addHashtag,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          onPressed: () => _addHashtag(
                                            _hashtagController.text,
                                          ),
                                          icon: const Icon(
                                            Icons.add,
                                            color: VineTheme.vineGreen,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),

                                    // Hashtags display
                                    if (_hashtags.isNotEmpty) ...[
                                      const Text(
                                        'Hashtags',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: _hashtags
                                            .map(
                                              (hashtag) => Chip(
                                                label: Text('#$hashtag'),
                                                labelStyle: const TextStyle(
                                                  color: Colors.white,
                                                ),
                                                backgroundColor:
                                                    VineTheme.vineGreen,
                                                deleteIcon: const Icon(
                                                  Icons.close,
                                                  color: Colors.white,
                                                  size: 18,
                                                ),
                                                onDeleted: () =>
                                                    _removeHashtag(hashtag),
                                              ),
                                            )
                                            .toList(),
                                      ),
                                      const SizedBox(height: 16),
                                    ],

                                    // Expiring post option
                                    SwitchListTile(
                                      title: const Text(
                                        'Expiring Post',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      subtitle: Text(
                                        _isExpiringPost
                                            ? 'Delete after ${_formatExpirationDuration()}'
                                            : 'Post will not expire',
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                        ),
                                      ),
                                      value: _isExpiringPost,
                                      onChanged: (value) async {
                                        if (value) {
                                          // Show confirmation dialog before enabling expiration
                                          final confirmed =
                                              await _showExpirationConfirmationDialog();
                                          if (confirmed) {
                                            setState(() {
                                              _isExpiringPost = true;
                                              _expirationConfirmed = true;
                                            });
                                          }
                                        } else {
                                          setState(() {
                                            _isExpiringPost = false;
                                            _expirationConfirmed = false;
                                          });
                                        }
                                      },
                                      activeThumbColor: VineTheme.vineGreen,
                                    ),

                                    if (_isExpiringPost) ...[
                                      const SizedBox(height: 16),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Delete after:',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                _buildDurationButton(
                                                  '1 Day',
                                                  24,
                                                ),
                                                _buildDurationButton(
                                                  '1 Week',
                                                  168,
                                                ),
                                                _buildDurationButton(
                                                  '1 Month',
                                                  720,
                                                ),
                                                _buildDurationButton(
                                                  '1 Year',
                                                  8760,
                                                ),
                                                _buildDurationButton(
                                                  '1 Decade',
                                                  87600,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                    ],

                                    // Audio sharing option - per-video override
                                    if (_allowAudioReuse != null)
                                      SwitchListTile(
                                        title: const Text(
                                          'Allow others to use this audio',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        subtitle: Text(
                                          _allowAudioReuse!
                                              ? 'Others can reuse audio from this video'
                                              : 'Audio is exclusive to this video',
                                          style: TextStyle(
                                            color: Colors.grey[400],
                                          ),
                                        ),
                                        value: _allowAudioReuse!,
                                        onChanged: (value) {
                                          setState(() {
                                            _allowAudioReuse = value;
                                          });
                                        },
                                        activeThumbColor: VineTheme.vineGreen,
                                        secondary: const Icon(
                                          Icons.music_note,
                                          color: VineTheme.vineGreen,
                                        ),
                                      ),

                                    // ProofMode info panel
                                    // TODO: Add proofManifest to VineDraft model if needed
                                    // if (_currentDraft?.proofManifest != null) ...[
                                    //   const SizedBox(height: 16),
                                    //   ProofModeInfoPanel(manifest: _currentDraft!.proofManifest!),
                                    // ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                // Publishing progress overlay
                if (_isPublishing)
                  Container(
                    color: Colors.black.withValues(alpha: 0.8),
                    child: Center(
                      child: Container(
                        margin: const EdgeInsets.all(32),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Progress indicator - show deterministic if we have upload progress
                            _currentUploadId != null && _uploadProgress > 0
                                ? Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      SizedBox(
                                        width: 80,
                                        height: 80,
                                        child: CircularProgressIndicator(
                                          value: _uploadProgress,
                                          color: VineTheme.vineGreen,
                                          strokeWidth: 4,
                                          backgroundColor: Colors.grey[700],
                                        ),
                                      ),
                                      Text(
                                        '${(_uploadProgress * 100).toInt()}%',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          decoration: TextDecoration.none,
                                        ),
                                      ),
                                    ],
                                  )
                                : const CircularProgressIndicator(
                                    color: VineTheme.vineGreen,
                                    strokeWidth: 3,
                                  ),
                            const SizedBox(height: 24),
                            Text(
                              _publishingStatus,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.none,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _addHashtag(String hashtag) {
    final trimmed = hashtag.trim().toLowerCase();
    if (trimmed.isNotEmpty && !_hashtags.contains(trimmed)) {
      setState(() {
        _hashtags.add(trimmed);
        _hashtagController.clear();
      });
    }
  }

  void _removeHashtag(String hashtag) {
    setState(() {
      _hashtags.remove(hashtag);
    });
  }

  Future<bool> _showExpirationConfirmationDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 12),
              Text(
                'Enable Expiring Post?',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will permanently delete your video from Nostr relays after the expiration time.',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              SizedBox(height: 16),
              Text(
                'This action cannot be undone. Once expired, the video will be gone forever.',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                backgroundColor: Colors.orange.withValues(alpha: 0.2),
              ),
              child: const Text(
                'Yes, Make It Expire',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  String _formatExpirationDuration() {
    if (_expirationHours >= 87600)
      return '${(_expirationHours / 87600).round()} decade${_expirationHours >= 175200 ? 's' : ''}';
    if (_expirationHours >= 8760)
      return '${(_expirationHours / 8760).round()} year${_expirationHours >= 17520 ? 's' : ''}';
    if (_expirationHours >= 720)
      return '${(_expirationHours / 720).round()} month${_expirationHours >= 1440 ? 's' : ''}';
    if (_expirationHours >= 168)
      return '${(_expirationHours / 168).round()} week${_expirationHours >= 336 ? 's' : ''}';
    if (_expirationHours >= 24)
      return '${(_expirationHours / 24).round()} day${_expirationHours >= 48 ? 's' : ''}';
    return '$_expirationHours hour${_expirationHours != 1 ? 's' : ''}';
  }

  Widget _buildDurationButton(String label, int hours) {
    final isSelected = _expirationHours == hours;
    return GestureDetector(
      onTap: () {
        setState(() {
          _expirationHours = hours;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? VineTheme.vineGreen : Colors.grey[900],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? VineTheme.vineGreen : Colors.grey[700]!,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[400],
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Future<void> _publishVideo() async {
    if (_currentDraft == null) return;

    // Stop video playback when publishing starts
    if (_videoController != null && _videoController!.value.isPlaying) {
      await _videoController!.pause();
      Log.info(
        '📝 Paused video playback for publishing',
        category: LogCategory.video,
      );
    }

    // Get upload manager and check if background upload exists
    final uploadManager = ref.read(uploadManagerProvider);

    // Check if we have a background upload ID and its status
    if (_backgroundUploadId != null) {
      final upload = uploadManager.getUpload(_backgroundUploadId!);

      if (upload != null) {
        // Handle different upload states
        if (upload.status == UploadStatus.uploading ||
            upload.status == UploadStatus.processing) {
          // Show blocking progress dialog and wait for upload to complete
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => UploadProgressDialog(
              uploadId: _backgroundUploadId!,
              uploadManager: uploadManager,
            ),
          );

          // After dialog closes, check if upload succeeded
          final completedUpload = uploadManager.getUpload(_backgroundUploadId!);
          if (completedUpload == null ||
              completedUpload.status == UploadStatus.failed) {
            // Upload failed during progress dialog
            await _showUploadErrorDialog();
            return;
          }
        } else if (upload.status == UploadStatus.failed) {
          // Show error dialog with retry option
          final shouldRetry = await _showUploadErrorDialog();
          if (shouldRetry) {
            await _retryUpload();
            // Recursively call _publishVideo after retry to check status again
            return _publishVideo();
          } else {
            return; // User cancelled
          }
        }
        // If status is readyToPublish, proceed with Nostr event creation below
      }
    }

    // Original publishing logic continues here...
    setState(() {
      _isPublishing = true;
      _publishingStatus = 'Preparing to publish...';
    });

    try {
      // Update draft status to "publishing"
      final prefs = await SharedPreferences.getInstance();
      final draftService = DraftStorageService(prefs);

      final publishing = _currentDraft!.copyWith(
        publishStatus: PublishStatus.publishing,
      );
      await draftService.saveDraft(publishing);
      setState(() {
        _currentDraft = publishing;
      });

      Log.info(
        '📝 VideoMetadataScreenPure: Publishing video: ${_currentDraft!.videoFile.path}',
        category: LogCategory.video,
      );

      // Verify user is fully authenticated (not just has keys)
      final authService = ref.read(authServiceProvider);
      if (!authService.isAuthenticated) {
        throw Exception(
          'Not authenticated (state: ${authService.authState.name}) - cannot publish video',
        );
      }
      final pubkey = authService.currentPublicKeyHex!;

      // Get video event publisher
      final videoEventPublisher = ref.read(videoEventPublisherProvider);

      // Use existing upload if available, otherwise start new upload
      PendingUpload pendingUpload;
      if (_backgroundUploadId != null) {
        final existingUpload = uploadManager.getUpload(_backgroundUploadId!);
        if (existingUpload != null &&
            existingUpload.status == UploadStatus.readyToPublish) {
          pendingUpload = existingUpload;
          Log.info(
            '📝 Using existing background upload: ${pendingUpload.id}',
            category: LogCategory.video,
          );
        } else {
          // Background upload not ready, start new upload
          pendingUpload = await _startNewUpload(uploadManager, pubkey);
        }
      } else {
        // No background upload, start new upload
        pendingUpload = await _startNewUpload(uploadManager, pubkey);
      }

      // Publish Nostr event
      Log.info('📝 Publishing Nostr event...', category: LogCategory.video);

      setState(() {
        _publishingStatus = 'Publishing to Nostr...';
      });

      // Only add expiration tag if user explicitly confirmed (double-check safety)
      final shouldExpire = _isExpiringPost && _expirationConfirmed;

      // Use current form values for metadata (not the original upload metadata)
      // This ensures user edits to title/description are applied
      final currentTitle = _titleController.text.trim().isEmpty
          ? null
          : _titleController.text.trim();
      final currentDescription = _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim();
      final currentHashtags = _hashtags.isEmpty ? null : _hashtags;

      final published = await videoEventPublisher.publishVideoEvent(
        upload: pendingUpload,
        title: currentTitle,
        description: currentDescription,
        hashtags: currentHashtags,
        expirationTimestamp: shouldExpire
            ? DateTime.now().millisecondsSinceEpoch ~/ 1000 +
                  (_expirationHours * 3600)
            : null,
        allowAudioReuse: _allowAudioReuse ?? false,
      );

      if (!published) {
        throw Exception('Failed to publish Nostr event');
      }

      Log.info(
        '📝 Video publishing complete, deleting draft and returning to main screen',
        category: LogCategory.video,
      );

      // Success: delete draft
      await draftService.deleteDraft(_currentDraft!.id);

      // Mark recording as published to prevent auto-save on dispose
      ref.read(vineRecordingProvider.notifier).markAsPublished();

      // Clean up recording segments and temp files after successful publish
      await ref.read(vineRecordingProvider.notifier).cleanupAndReset();

      // Clear clip manager to allow recording new videos without "clear" prompt
      ref.read(clipManagerProvider.notifier).clearAll();

      // Clear selected sound from lip sync recording flow
      ref.read(selectedSoundProvider.notifier).clear();

      if (mounted) {
        setState(() {
          _publishingStatus = 'Published successfully!';
        });

        // Show success message for longer so user can see it
        await Future.delayed(const Duration(milliseconds: 1200));

        if (mounted) {
          // Reset publishing state
          setState(() {
            _isPublishing = false;
            _publishingStatus = '';
            _uploadProgress = 0.0;
            _currentUploadId = null;
          });

          // Go to the profile screen to see the new video
          context.goMyProfile();

          Log.info(
            '📝 Published successfully, returned to main screen',
            category: LogCategory.video,
          );
        }
      }
    } catch (e, stackTrace) {
      Log.error(
        '📝 VideoMetadataScreenPure: Failed to publish video: $e',
        category: LogCategory.video,
      );

      // Failed: update draft with error
      try {
        final prefs = await SharedPreferences.getInstance();
        final draftService = DraftStorageService(prefs);

        final failed = _currentDraft!.copyWith(
          publishStatus: PublishStatus.failed,
          publishError: e.toString(),
          publishAttempts: _currentDraft!.publishAttempts + 1,
        );
        await draftService.saveDraft(failed);

        if (mounted) {
          setState(() {
            _currentDraft = failed;
            _isPublishing = false;
            _publishingStatus = '';
            _uploadProgress = 0.0;
            _currentUploadId = null;
          });
        }
      } catch (saveError) {
        Log.error(
          '📝 Failed to save error state: $saveError',
          category: LogCategory.video,
        );
        if (mounted) {
          setState(() {
            _isPublishing = false;
            _publishingStatus = '';
            _uploadProgress = 0.0;
            _currentUploadId = null;
          });
        }
      }

      if (mounted) {
        // Get the current Blossom server for error message
        final blossomService = ref.read(blossomUploadServiceProvider);
        String serverName = 'Unknown server';
        try {
          final serverUrl = await blossomService.getBlossomServer();
          if (serverUrl != null && serverUrl.isNotEmpty) {
            // Extract domain from URL for display
            final uri = Uri.tryParse(serverUrl);
            serverName = uri?.host ?? serverUrl;
          }
        } catch (_) {
          // If we can't get the server name, just use the generic message
        }

        // Convert technical error to user-friendly message
        String userMessage;
        if (e.toString().contains('404') ||
            e.toString().contains('not_found')) {
          userMessage =
              'The Blossom media server ($serverName) is not working. You can choose another in your settings.';
        } else if (e.toString().contains('500')) {
          userMessage =
              'The Blossom media server ($serverName) encountered an error. You can choose another in your settings.';
        } else if (e.toString().contains('network') ||
            e.toString().contains('connection')) {
          userMessage =
              'Network error. Please check your connection and try again.';
        } else if (e.toString().contains('Not authenticated')) {
          userMessage = 'Please sign in to publish videos.';
        } else {
          userMessage = 'Failed to publish video. Please try again.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Details',
              textColor: Colors.white,
              onPressed: () {
                // Show technical details in a dialog
                final errorDetails =
                    '''
Error: ${e.toString()}

Stack Trace:
${stackTrace.toString()}

Operation: Video Upload
Time: ${DateTime.now().toIso8601String()}
Video: ${_currentDraft?.videoFile.path ?? 'Unknown'}
''';

                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: Colors.grey[900],
                    title: Row(
                      children: [
                        const Icon(Icons.bug_report, color: Colors.red),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Error Details',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    content: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Please share these details with support:',
                            style: TextStyle(
                              color: VineTheme.vineGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[700]!),
                            ),
                            child: SelectableText(
                              errorDetails,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: errorDetails),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Error details copied to clipboard',
                                ),
                                backgroundColor: VineTheme.vineGreen,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        icon: const Icon(
                          Icons.copy,
                          color: VineTheme.vineGreen,
                        ),
                        label: const Text(
                          'Copy',
                          style: TextStyle(color: VineTheme.vineGreen),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Close',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      }
    }
  }

  /// Show error dialog when upload has failed
  /// Returns true if user wants to retry, false if cancelled
  Future<bool> _showUploadErrorDialog() async {
    final uploadManager = ref.read(uploadManagerProvider);
    final upload = _backgroundUploadId != null
        ? uploadManager.getUpload(_backgroundUploadId!)
        : null;

    final errorMessage = upload?.errorMessage ?? 'Unknown error';

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Upload Failed',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        content: Text(
          'Upload failed: $errorMessage\n\nWould you like to retry?',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(backgroundColor: VineTheme.vineGreen),
            child: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// Retry a failed upload
  Future<void> _retryUpload() async {
    if (_backgroundUploadId == null) return;

    final uploadManager = ref.read(uploadManagerProvider);

    setState(() {
      _isPublishing = true;
      _publishingStatus = 'Retrying upload...';
    });

    try {
      await uploadManager.retryUpload(_backgroundUploadId!);

      // Show progress dialog while retrying
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => UploadProgressDialog(
            uploadId: _backgroundUploadId!,
            uploadManager: uploadManager,
          ),
        );
      }
    } catch (e) {
      Log.error('📝 Failed to retry upload: $e', category: LogCategory.video);
      if (mounted) {
        setState(() {
          _isPublishing = false;
          _publishingStatus = '';
        });
      }
      rethrow;
    } finally {
      if (mounted) {
        setState(() {
          _isPublishing = false;
          _publishingStatus = '';
        });
      }
    }
  }

  /// Start a new upload and poll for progress
  Future<PendingUpload> _startNewUpload(
    UploadManager uploadManager,
    String pubkey,
  ) async {
    // Ensure upload manager is initialized
    if (!uploadManager.isInitialized) {
      Log.info(
        '📝 Initializing upload manager...',
        category: LogCategory.video,
      );
      setState(() {
        _publishingStatus = 'Initializing upload system...';
      });
      await uploadManager.initialize();
    }

    // Start upload to Blossom
    Log.info(
      '📝 Starting upload to Blossom server...',
      category: LogCategory.video,
    );

    // Debug: Check if draft has ProofMode data
    final hasProofMode = _currentDraft!.hasProofMode;
    final nativeProof = _currentDraft!.nativeProof;
    Log.info(
      '📜 Draft hasProofMode: $hasProofMode, nativeProof: ${nativeProof != null ? "present" : "null"}',
      category: LogCategory.video,
    );
    if (hasProofMode && nativeProof == null) {
      Log.error(
        '📜 WARNING: Draft has proofManifestJson but nativeProof getter returned null - deserialization failed!',
        category: LogCategory.video,
      );
    }
    if (nativeProof != null) {
      Log.info(
        '📜 NativeProof videoHash: ${nativeProof.videoHash}, deviceAttestation: ${nativeProof.deviceAttestation != null}, pgpSignature: ${nativeProof.pgpSignature != null}',
        category: LogCategory.video,
      );
    }

    setState(() {
      _publishingStatus = 'Uploading video...';
    });

    // Update draft with edited metadata before upload
    final updatedDraft = _currentDraft!.copyWith(
      title: _titleController.text.trim().isEmpty
          ? null
          : _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      hashtags: _hashtags.isEmpty ? null : _hashtags,
    );

    // Get video duration with fallback
    final videoDuration = await _getVideoDuration();

    final pendingUpload = await uploadManager.startUploadFromDraft(
      draft: updatedDraft,
      nostrPubkey: pubkey,
      videoDuration: videoDuration,
    );

    Log.info(
      '📝 Upload started with duration ${videoDuration.inSeconds}s, ID: ${pendingUpload.id}',
      category: LogCategory.video,
    );

    // Track upload progress
    setState(() {
      _currentUploadId = pendingUpload.id;
    });

    // Poll for upload progress
    while (mounted && _currentUploadId != null) {
      final upload = uploadManager.getUpload(_currentUploadId!);
      if (upload == null) break;

      final progress = upload.uploadProgress ?? 0.0;
      if (mounted) {
        setState(() {
          _uploadProgress = progress;
          if (progress < 1.0) {
            _publishingStatus =
                'Uploading video... ${(progress * 100).toInt()}%';
          }
        });
      }

      // If upload is complete or failed, stop polling
      if (upload.status == UploadStatus.readyToPublish ||
          upload.status == UploadStatus.failed ||
          upload.status == UploadStatus.processing) {
        break;
      }

      await Future.delayed(const Duration(milliseconds: 100));
    }

    return pendingUpload;
  }
}
