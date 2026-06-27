// ABOUTME: Service for managing video upload state and local persistence
// ABOUTME: Handles upload queue, retries, and coordination between UI and Blossom upload service

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:models/models.dart' show NativeProofData;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/services/circuit_breaker_service.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/services/upload/pending_upload_store.dart';
import 'package:openvine/services/upload/upload_ports.dart';
import 'package:openvine/services/upload/upload_progress_reporter.dart';
import 'package:openvine/services/upload/upload_retry_policy.dart';
import 'package:openvine/services/upload/upload_session_errors.dart';
import 'package:openvine/services/upload_initialization_helper.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

/// Exception thrown when a [BlossomUploadResult] indicates failure.
///
/// Carries the HTTP [statusCode] and the typed [failureReason] so that
/// [categorizeError] and [isRetriableError] can branch on them directly
/// instead of parsing error-message strings. The [failureReason]
/// distinguishes a transient inability to *produce* a signed auth header
/// ([BlossomUploadFailureReason.authUnavailable]) from a permanent
/// server-side auth rejection ([BlossomUploadFailureReason.auth]) — a
/// distinction the bare error string cannot carry.
class BlossomUploadFailureException implements Exception {
  const BlossomUploadFailureException(
    this.message, {
    this.statusCode,
    this.failureReason,
  });

  final String message;
  final int? statusCode;
  final BlossomUploadFailureReason? failureReason;

  @override
  String toString() => message;
}

/// Upload retry configuration
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class UploadRetryConfig {
  const UploadRetryConfig({
    this.maxRetries = 5,
    this.initialDelay = const Duration(seconds: 2),
    this.maxDelay = const Duration(minutes: 5),
    this.backoffMultiplier = 2.0,
    this.networkTimeout = const Duration(minutes: 10),
  });
  final int maxRetries;
  final Duration initialDelay;
  final Duration maxDelay;
  final double backoffMultiplier;
  final Duration networkTimeout;
}

/// Upload performance metrics
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class UploadMetrics {
  const UploadMetrics({
    required this.uploadId,
    required this.startTime,
    required this.retryCount,
    required this.fileSizeMB,
    required this.wasSuccessful,
    this.endTime,
    this.uploadDuration,
    this.throughputMBps,
    this.errorCategory,
  });
  final String uploadId;
  final DateTime startTime;
  final DateTime? endTime;
  final Duration? uploadDuration;
  final int retryCount;
  final double fileSizeMB;
  final double? throughputMBps;
  final String? errorCategory;
  final bool wasSuccessful;
}

/// Upload target options

/// App-layer adapter forwarding the upload pipeline's [UploadCrashReporter]
/// port to the Firebase-backed [CrashReportingService].
///
/// Keeps the extracted upload concerns free of a direct Firebase import so
/// they can move into a pure-Dart package; the manager injects this adapter
/// by default.
class CrashReportingUploadReporter implements UploadCrashReporter {
  const CrashReportingUploadReporter();

  @override
  Future<void> setCustomKey(String key, Object value) =>
      CrashReportingService.instance.setCustomKey(key, value);

  @override
  void log(String message) => CrashReportingService.instance.log(message);

  @override
  Future<void> recordError(Object error, StackTrace? stack, {String? reason}) =>
      CrashReportingService.instance.recordError(error, stack, reason: reason);
}

/// Manages video uploads and their persistent state with enhanced reliability
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class UploadManager {
  UploadManager({
    required BlossomUploadService blossomService,
    String? defaultBlossomUrl,
    String? currentNostrPubkey,
    bool scopeUploadsToCurrentUser = false,
    VideoCircuitBreaker? circuitBreaker,
    UploadRetryConfig? retryConfig,
    UploadCrashReporter? crashReporter,
  }) : _blossomService = blossomService,
       _defaultBlossomUrl =
           defaultBlossomUrl ?? BlossomUploadService.defaultBlossomServer,
       _circuitBreaker = circuitBreaker ?? VideoCircuitBreaker(),
       _retryConfig = retryConfig ?? const UploadRetryConfig(),
       _store = PendingUploadStore(
         scopeUploadsToCurrentUser: scopeUploadsToCurrentUser,
         currentNostrPubkey: currentNostrPubkey,
       ) {
    _retryPolicy = UploadRetryPolicy(
      store: _store,
      retryConfig: _retryConfig,
    );
    _reporter = UploadProgressReporter(
      store: _store,
      circuitBreaker: _circuitBreaker,
      retryConfig: _retryConfig,
      crashReporter: crashReporter ?? const CrashReportingUploadReporter(),
    );
  }

  // Core services
  final PendingUploadStore _store;
  final BlossomUploadService _blossomService;
  final String _defaultBlossomUrl;
  final VideoCircuitBreaker _circuitBreaker;
  final UploadRetryConfig _retryConfig;
  final Dio _dio = Dio();

  // Extracted concerns
  late final UploadRetryPolicy _retryPolicy;
  late final UploadProgressReporter _reporter;

  // Processing-completion polls keyed by upload id, so dispose() can
  // cancel them — an untracked periodic timer would keep firing against
  // a disposed manager for up to 5 minutes.
  final Map<String, Timer> _processingPollTimers = {};

  bool _isInitialized = false;

  /// Check if the upload manager is initialized
  bool get isInitialized => _isInitialized && _store.isReady;

  /// Initialize the upload manager and load persisted uploads
  /// Uses robust initialization with retry logic and recovery strategies
  Future<void> initialize() async {
    if (_isInitialized && _store.isReady) {
      Log.info(
        'UploadManager already initialized',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      return;
    }

    Log.info(
      '🚀 Initializing UploadManager with robust retry logic',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    try {
      // Delegate box open to the store.
      await _store.open();

      if (!_store.isReady) {
        throw Exception(
          'Failed to initialize uploads box after all recovery attempts',
        );
      }

      _isInitialized = true;

      Log.info(
        '✅ UploadManager initialized successfully with ${_store.length} existing uploads',
        name: 'UploadManager',
        category: LogCategory.video,
      );

      // Clean up any problematic uploads first
      await cleanupProblematicUploads();

      // Clean up old completed/published uploads to prevent accumulation
      await cleanupCompletedUploads();

      // Interrupted resumable uploads are NOT auto-resumed here.
      // The bottom sheet flow (resumePendingPublishes → BackgroundPublishBloc)
      // lets the user decide whether to retry or save to drafts.
      // VideoPublishService._getOrCreateUpload reuses existing PendingUpload
      // records (and their resumable sessions) when the user taps "Try Again".
    } catch (e, stackTrace) {
      _isInitialized = false;

      // Log the error but don't rethrow immediately - the helper already retried
      Log.error(
        '❌ Failed to initialize UploadManager after all retries: $e',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      Log.verbose(
        '📱 Stack trace: $stackTrace',
        name: 'UploadManager',
        category: LogCategory.video,
      );

      // Send crash report for initialization failure
      await _reporter.sendInitializationFailureCrashReport(e, stackTrace);

      // Don't rethrow - allow the app to continue and retry on demand
      // rethrow;
    }
  }

  /// Get pending uploads visible to the current owner.
  ///
  /// Production providers opt into owner scoping so account switches do not
  /// surface another user's persisted Hive uploads. Tests and maintenance
  /// harnesses that construct [UploadManager] directly keep the historical
  /// unscoped view unless they pass [scopeUploadsToCurrentUser].
  List<PendingUpload> get pendingUploads => _store.pendingUploads;

  /// Get a specific upload by ID
  PendingUpload? getUpload(String id) => _store.getUpload(id);

  /// Get an upload by file path
  PendingUpload? getUploadByFilePath(String filePath) =>
      _store.getUploadByFilePath(filePath);

  /// Finds a reusable upload for the given video file path.
  ///
  /// Returns the most recent upload matching [filePath] that is in a
  /// resumable state (uploading, retrying, processing, readyToPublish,
  /// or failed with a resumable session). Skips published, pending, and
  /// paused uploads.
  ///
  /// Relies on [pendingUploads] being sorted newest-first (by
  /// [PendingUpload.createdAt] descending) so the first match is the
  /// most recent candidate.
  PendingUpload? findReusableUpload(String filePath) =>
      _store.findReusableUpload(filePath);

  /// Start upload from VineDraft (preferred method - single source of truth)
  Future<PendingUpload> startUploadFromDraft({
    required DivineVideoDraft draft,
    required String nostrPubkey,
    Duration? videoDuration,
    ValueChanged<double>? onProgress,
  }) async {
    Log.info(
      '🚀 === STARTING UPLOAD FROM DRAFT ===',
      name: 'UploadManager',
      category: LogCategory.video,
    );
    Log.info(
      '📜 Draft ID: ${draft.id}, hasProofMode: ${draft.hasProofMode}',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    if (draft.hasProofMode) {
      Log.info(
        '📜 Native ProofMode JSON length: ${draft.proofManifestJson?.length ?? 0} characters',
        name: 'UploadManager',
        category: LogCategory.video,
      );
    }

    Future<String> prepareUploadFromSourceClips() async {
      if (draft.clips.length == 1) {
        return draft.clips.first.video.safeFilePath();
      }

      final tempDir = await getTemporaryDirectory();
      final mergedPath = path.join(
        tempDir.path,
        'merged_${DateTime.now().microsecondsSinceEpoch}.mp4',
      );
      Log.info(
        '🎬 Merging ${draft.clips.length} clips into single video '
        '(unexpected: clips should be pre-merged at this point)...',
        name: 'UploadManager',
        category: .video,
      );
      await VideoEditorRenderService.renderNativeVideoToFile(
        mergedPath,
        VideoRenderData(
          videoSegments: draft.clips
              .map((clip) => VideoSegment(video: clip.video))
              .toList(),
          endTime: VideoEditorConstants.maxDuration,
          shouldOptimizeForNetworkUse: true,
        ),
      );
      Log.info(
        '✅ Video merge completed: $mergedPath',
        name: 'UploadManager',
        category: .video,
      );
      return mergedPath;
    }

    // Prefer the persisted final render when available. It preserves editor
    // overlays and gives retries/background uploads a stable file path.
    String videoFilePath;
    final renderedClip = draft.finalRenderedClip;
    if (renderedClip != null) {
      final renderedPath = await renderedClip.video.safeFilePath();
      if (File(renderedPath).existsSync()) {
        videoFilePath = renderedPath;
        videoDuration ??= renderedClip.duration;
        Log.info(
          '🎬 Using final rendered clip for upload: $videoFilePath',
          name: 'UploadManager',
          category: .video,
        );
      } else {
        Log.warning(
          '⚠️ Final rendered clip missing at $renderedPath - falling back to source clips',
          name: 'UploadManager',
          category: .video,
        );
        videoFilePath = await prepareUploadFromSourceClips();
      }
    } else {
      videoFilePath = await prepareUploadFromSourceClips();
    }

    int? videoWidth;
    int? videoHeight;

    try {
      final meta = await ProVideoEditor.instance.getMetadata(
        EditorVideo.file(videoFilePath),
      );
      videoDuration ??= meta.duration;
      final resolution = meta.resolution;
      videoWidth = resolution.width.round();
      videoHeight = resolution.height.round();
    } catch (e) {
      Log.warning(
        '⚠️ Could not extract video metadata: $e',
        name: 'UploadManager',
        category: LogCategory.video,
      );
    }

    return _startUploadInternal(
      videoFile: File(videoFilePath),
      nostrPubkey: nostrPubkey,
      title: draft.title,
      description: draft.description,
      hashtags: draft.hashtags.toList(),
      videoWidth: videoWidth,
      videoHeight: videoHeight,
      videoDuration: videoDuration,
      proofManifestJson: draft.proofManifestJson,
      onProgress: onProgress,
      thumbnailTimestamp: draft.thumbnailTimestamp,
    );
  }

  /// Start a new video upload (legacy method - prefer startUploadFromDraft)
  Future<PendingUpload> startUpload({
    required File videoFile,
    required String nostrPubkey,
    Duration? thumbnailTimestamp,
    ValueChanged<double>? onProgress,
    String? thumbnailPath,
    String? title,
    String? description,
    List<String>? hashtags,
    int? videoWidth,
    int? videoHeight,
    Duration? videoDuration,
    NativeProofData? nativeProof,
  }) async {
    Log.warning(
      '⚠️ Using legacy startUpload() - prefer startUploadFromDraft()',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    // Convert NativeProofData to JSON if present
    String? proofManifestJson;
    if (nativeProof != null) {
      try {
        proofManifestJson = jsonEncode(nativeProof.toJson());
        Log.info(
          '📜 Native ProofMode data attached to upload',
          name: 'UploadManager',
          category: LogCategory.video,
        );
      } catch (e) {
        Log.error(
          'Failed to serialize NativeProofData: $e',
          name: 'UploadManager',
          category: LogCategory.system,
        );
      }
    }

    return _startUploadInternal(
      videoFile: videoFile,
      nostrPubkey: nostrPubkey,
      title: title,
      description: description,
      hashtags: hashtags,
      videoWidth: videoWidth,
      videoHeight: videoHeight,
      videoDuration: videoDuration,
      proofManifestJson: proofManifestJson,
      onProgress: onProgress,
      thumbnailTimestamp: thumbnailTimestamp,
    );
  }

  /// Internal upload method - handles actual upload logic
  Future<PendingUpload> _startUploadInternal({
    required File videoFile,
    required String nostrPubkey,
    Duration? thumbnailTimestamp,
    ValueChanged<double>? onProgress,
    String? thumbnailPath,
    String? title,
    String? description,
    List<String>? hashtags,
    int? videoWidth,
    int? videoHeight,
    Duration? videoDuration,
    String? proofManifestJson,
  }) async {
    Log.info(
      '🚀 === STARTING UPLOAD ===',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    // Ensure initialization with robust retry
    if (!isInitialized || !_store.isReady) {
      Log.warning(
        'UploadManager not ready, attempting robust initialization...',
        name: 'UploadManager',
        category: LogCategory.video,
      );

      try {
        // Delegate force-reinit to the store.
        await _store.ensureOpen();

        if (_store.isReady) {
          _isInitialized = true;
          Log.info(
            '✅ Robust initialization successful',
            name: 'UploadManager',
            category: LogCategory.video,
          );
        } else {
          throw Exception('Box initialization returned null or closed box');
        }
      } catch (e) {
        Log.error(
          '❌ Robust initialization failed: $e',
          name: 'UploadManager',
          category: LogCategory.video,
        );

        // Check if circuit breaker is active
        final debugState = UploadInitializationHelper.getDebugState();
        if (debugState['circuitBreakerActive'] == true) {
          throw Exception(
            'Upload service temporarily unavailable - too many failures. Please try again later.',
          );
        }

        throw Exception(
          'Failed to initialize upload storage after multiple retries: $e',
        );
      }
    }

    Log.info(
      '📁 Video path: ${videoFile.path}',
      name: 'UploadManager',
      category: LogCategory.video,
    );
    Log.info(
      '📊 File exists: ${videoFile.existsSync()}',
      name: 'UploadManager',
      category: LogCategory.video,
    );
    if (videoFile.existsSync()) {
      Log.info(
        '📊 File size: ${videoFile.lengthSync()} bytes',
        name: 'UploadManager',
        category: LogCategory.video,
      );
    }

    // Validate file format - reject WebM videos (not supported on iOS/macOS)
    final fileName = videoFile.path.toLowerCase();
    if (fileName.endsWith('.webm')) {
      Log.error(
        '❌ WebM format not supported - rejecting upload',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      throw Exception(
        'WebM video format is not supported. Please use MP4 format instead.',
      );
    }
    Log.info(
      '👤 Nostr pubkey: $nostrPubkey',
      name: 'UploadManager',
      category: LogCategory.video,
    );
    Log.info(
      '📝 Title: $title',
      name: 'UploadManager',
      category: LogCategory.video,
    );
    Log.info(
      '🏷️ Hashtags: $hashtags',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    // Create pending upload record
    Log.info(
      '📦 Creating PendingUpload record...',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    // Log ProofMode status
    if (proofManifestJson != null && proofManifestJson.isNotEmpty) {
      Log.info(
        '📜 Native ProofMode data attached to upload (${proofManifestJson.length} characters)',
        name: 'UploadManager',
        category: LogCategory.video,
      );
    } else {
      Log.info(
        '📜 No native ProofMode data provided to upload',
        name: 'UploadManager',
        category: LogCategory.video,
      );
    }

    final upload = PendingUpload.create(
      localVideoPath: videoFile.path,
      nostrPubkey: nostrPubkey,
      thumbnailPath: thumbnailPath,
      title: title,
      description: description,
      hashtags: hashtags,
      videoWidth: videoWidth,
      videoHeight: videoHeight,
      videoDuration: videoDuration,
      proofManifestJson: proofManifestJson,
      thumbnailTimestamp:
          thumbnailTimestamp ??
          VideoEditorConstants.defaultThumbnailExtractTime,
    );
    Log.info(
      '✅ Created upload with ID: ${upload.id}',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    // Save to local storage
    Log.info(
      '💾 Saving upload to local storage...',
      name: 'UploadManager',
      category: LogCategory.video,
    );
    await _store.save(upload);
    Log.info(
      '✅ Upload saved to storage',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    // Start the upload process and WAIT for it to complete
    Log.info(
      '🔄 Starting upload process...',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    // CRITICAL FIX: Await upload completion before returning
    // This ensures videoId and cdnUrl are populated before publishing
    try {
      await _performUpload(upload, onProgress: onProgress);

      // Fetch the updated upload with videoId and cdnUrl populated
      final completedUpload = getUpload(upload.id);
      if (completedUpload == null) {
        throw Exception('Upload not found after completion: ${upload.id}');
      }
      if (completedUpload.status == UploadStatus.failed) {
        throw Exception(
          completedUpload.errorMessage ?? 'Upload failed: ${upload.id}',
        );
      }

      Log.info(
        '✅ Upload completed with ID: ${upload.id}',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      return completedUpload;
    } catch (error) {
      Log.error(
        '❌ Upload failed: $error',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      rethrow;
    }
  }

  /// Perform upload with circuit breaker and retry logic
  Future<void> _performUpload(
    PendingUpload upload, {
    ValueChanged<double>? onProgress,
  }) async {
    Log.info(
      '🏃 === PERFORM UPLOAD STARTED ===',
      name: 'UploadManager',
      category: LogCategory.video,
    );
    Log.info(
      '🆔 Upload ID: ${upload.id}',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    // Web platform uses different upload flow (File picker -> Blob upload)
    if (kIsWeb) {
      Log.warning(
        'Web platform upload not yet implemented - skipping',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      await _handleUploadFailure(
        upload,
        Exception('Web platform uploads not yet implemented'),
      );
      return;
    }

    final startTime = DateTime.now();
    final videoFile = File(upload.localVideoPath);

    Log.info(
      '📁 Checking video file: ${upload.localVideoPath}',
      name: 'UploadManager',
      category: LogCategory.video,
    );
    Log.info(
      '📊 File exists: ${videoFile.existsSync()}',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    if (!videoFile.existsSync()) {
      Log.error(
        '❌ VIDEO FILE DOES NOT EXIST!',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      await _handleUploadFailure(upload, Exception('Video file not found'));
      return;
    }

    // Initialize metrics
    final fileSizeMB = videoFile.lengthSync() / (1024 * 1024);
    Log.info(
      '📊 File size: ${fileSizeMB.toStringAsFixed(2)} MB',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    _reporter.recordStart(
      upload.id,
      UploadMetrics(
        uploadId: upload.id,
        startTime: startTime,
        retryCount: upload.retryCount ?? 0,
        fileSizeMB: fileSizeMB,
        wasSuccessful: false,
      ),
    );

    try {
      Log.info(
        '🔁 Starting upload with retry logic...',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      await _performUploadWithRetry(upload, videoFile, onProgress);
    } catch (e) {
      Log.error(
        '❌ Upload failed: $e',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      await _handleUploadFailure(upload, e);
    }
  }

  /// Perform upload with exponential backoff retry using proper async patterns.
  ///
  /// Delegates retry orchestration to [UploadRetryPolicy]. The execute callback
  /// re-fetches the current upload from the store on each attempt so resumable
  /// session updates from prior chunk callbacks are picked up automatically.
  Future<void> _performUploadWithRetry(
    PendingUpload upload,
    File videoFile,
    ValueChanged<double>? onProgress,
  ) async {
    await _retryPolicy.performWithRetry(
      upload,
      () async {
        final currentUpload = _store.getUpload(upload.id) ?? upload;

        // Validate file still exists
        if (!videoFile.existsSync()) {
          throw Exception('Video file not found: ${upload.localVideoPath}');
        }

        // Execute upload with timeout
        final result = await _executeUploadWithTimeout(
          currentUpload,
          videoFile,
          onProgress,
        );

        // Success - record metrics and complete
        await _handleUploadSuccess(currentUpload, result);
      },
      isRetriable: _retryPolicy.isRetriableError,
    );
  }

  /// Execute upload with timeout and progress tracking
  Future<dynamic> _executeUploadWithTimeout(
    PendingUpload upload,
    File videoFile,
    ValueChanged<double>? onProgress,
  ) async {
    Log.info(
      '📤 === EXECUTING UPLOAD ===',
      name: 'UploadManager',
      category: LogCategory.video,
    );
    Log.info(
      '📁 Video: ${videoFile.path}',
      name: 'UploadManager',
      category: LogCategory.video,
    );
    Log.info(
      '👤 Pubkey: ${upload.nostrPubkey}',
      name: 'UploadManager',
      category: LogCategory.video,
    );
    Log.info(
      '📝 Title: ${upload.title}',
      name: 'UploadManager',
      category: LogCategory.video,
    );
    Log.info(
      '⏱️ Timeout: ${_retryConfig.networkTimeout.inMinutes} minutes',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    try {
      // Use Blossom upload service exclusively
      Log.info(
        '🌸 Using Blossom upload service',
        name: 'UploadManager',
        category: LogCategory.video,
      );

      // Check if custom server is enabled, otherwise use default Divine server
      final isCustomServerEnabled = await _blossomService.isBlossomEnabled();
      String blossomServer;

      if (isCustomServerEnabled) {
        final customServer = await _blossomService.getBlossomServer();
        if (customServer == null || customServer.isEmpty) {
          throw Exception(
            'Custom Blossom server enabled but not configured. Please configure a server in settings.',
          );
        }
        blossomServer = customServer;
        Log.info(
          '🌸 Uploading to custom Blossom server: $blossomServer',
          name: 'UploadManager',
          category: LogCategory.video,
        );
      } else {
        blossomServer = _defaultBlossomUrl;
        Log.info(
          '🌸 Uploading to default Divine Blossom server: $blossomServer',
          name: 'UploadManager',
          category: LogCategory.video,
        );
      }

      final result = await _blossomService
          .uploadVideo(
            videoFile: videoFile,
            nostrPubkey: upload.nostrPubkey,
            title: upload.title ?? '',
            description: upload.description,
            hashtags: upload.hashtags,
            proofManifestJson: upload.proofManifestJson,
            resumableSession: upload.resumableSession,
            onResumableSessionUpdated: (session) {
              _retryPolicy.enqueueSessionPersist(
                upload.id,
                session,
                videoFile.lengthSync(),
              );
            },
            onProgress: (value) {
              final progress = value * 0.8; // Reserve 20% for thumbnail

              _reporter.updateProgress(upload.id, progress);
              onProgress?.call(progress);
            },
          )
          .timeout(
            _retryConfig.networkTimeout,
            onTimeout: () {
              Log.error(
                '⏱️ Upload timed out!',
                name: 'UploadManager',
                category: LogCategory.video,
              );
              final timeoutError = TimeoutException(
                'Upload timed out after ${_retryConfig.networkTimeout.inMinutes} minutes',
              );

              // Send timeout crash report asynchronously
              _reporter.sendTimeoutCrashReport(upload, timeoutError).catchError(
                (e) {
                  Log.error(
                    'Failed to send timeout crash report: $e',
                    name: 'UploadManager',
                    category: LogCategory.video,
                  );
                },
              );

              throw timeoutError;
            },
          );

      // Generate and upload thumbnail after video upload succeeds
      String? thumbnailCdnUrl;
      if (result.success && result.cdnUrl != null) {
        Log.info(
          '✅ Video uploaded successfully',
          name: 'UploadManager',
          category: LogCategory.video,
        );

        // Generate and upload thumbnail to Blossom CDN
        thumbnailCdnUrl = await _generateAndUploadThumbnail(
          videoFile: videoFile,
          nostrPubkey: upload.nostrPubkey,
          upload: upload,
        );

        if (thumbnailCdnUrl != null) {
          Log.info(
            '✅ Thumbnail uploaded to CDN: $thumbnailCdnUrl',
            name: 'UploadManager',
            category: LogCategory.video,
          );
        } else {
          Log.error(
            '❌ Failed to upload required thumbnail to CDN',
            name: 'UploadManager',
            category: LogCategory.video,
          );
        }
      }

      if (result.success &&
          !_hasHttpThumbnailUrl(
            result: result,
            generatedThumbnailUrl: thumbnailCdnUrl,
            existingThumbnailUrl: upload.thumbnailPath,
          )) {
        throw StateError('Thumbnail upload failed');
      }

      if (result.success) {
        _reporter.updateProgress(upload.id, 1.0);
        onProgress?.call(1.0);
      }

      // Store thumbnail URL in upload for later use
      if (thumbnailCdnUrl != null) {
        await _store.update(upload.copyWith(thumbnailPath: thumbnailCdnUrl));
      }

      Log.info(
        '✅ Upload execution completed',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      return result;
    } catch (e) {
      Log.error(
        '❌ Upload execution failed: $e',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      rethrow;
    }
  }

  /// Handle successful upload
  Future<void> _handleUploadSuccess(
    PendingUpload upload,
    dynamic result,
  ) async {
    final endTime = DateTime.now();
    final metrics = _reporter.metricsFor(upload.id);

    if (result.success == true) {
      // Get the LATEST upload record from Hive (may have been updated with thumbnail URL)
      final latestUpload = getUpload(upload.id) ?? upload;

      // Create updated upload with success metadata
      final updatedUpload = _createSuccessfulUpload(latestUpload, result);
      await _store.update(updatedUpload);

      // Record successful metrics
      if (metrics != null) {
        final updatedMetrics = _reporter.createSuccessMetrics(
          metrics,
          endTime,
          upload.retryCount ?? 0,
        );
        _reporter.recordSuccess(upload.id, updatedMetrics);

        // Log success with formatted output
        _reporter.logUploadSuccess(result, updatedMetrics);
      }

      // If upload is in processing state, start polling for completion
      if (updatedUpload.status == UploadStatus.processing) {
        startProcessingPoll(updatedUpload);
      }
    } else {
      throw BlossomUploadFailureException(
        (result.errorMessage as String?) ?? 'Upload failed with unknown error',
        statusCode: result.statusCode as int?,
        failureReason: result.failureReason as BlossomUploadFailureReason?,
      );
    }
  }

  /// Handle upload failure with comprehensive crash reporting
  Future<void> _handleUploadFailure(PendingUpload upload, Object error) async {
    final endTime = DateTime.now();
    final metrics = _reporter.metricsFor(upload.id);
    final latestUpload = getUpload(upload.id) ?? upload;

    // Check network connectivity and categorize error
    final connectivity = await _reporter.checkNetworkConnectivity();
    final errorCategory = await _reporter.categorizeError(error);
    final userMessage = _reporter.getUserFriendlyErrorMessage(
      errorCategory,
      connectivity,
    );

    Log.error(
      'Upload failed for ${upload.id}: $error',
      name: 'UploadManager',
      category: LogCategory.video,
    );
    Log.error(
      'Error category: $errorCategory',
      name: 'UploadManager',
      category: LogCategory.video,
    );
    Log.error(
      'Network: ${_reporter.getNetworkTypeString(connectivity)}',
      name: 'UploadManager',
      category: LogCategory.video,
    );
    Log.error(
      'User message: $userMessage',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    // Send comprehensive crash report to Crashlytics with network state
    await _reporter.sendUploadFailureCrashReport(
      upload,
      error,
      errorCategory,
      metrics,
      connectivity,
      isManagerInitialized: _isInitialized,
    );

    // Store user-friendly error message instead of raw exception
    await _store.update(
      latestUpload.copyWith(
        status: UploadStatus.failed,
        errorMessage: userMessage,
        retryCount: latestUpload.retryCount ?? 0,
        resumableSession: isExpiredResumableSessionError(error)
            ? null
            : latestUpload.resumableSession,
      ),
    );

    // Record failure metrics
    if (metrics != null) {
      _reporter.recordFailure(
        upload.id,
        UploadMetrics(
          uploadId: upload.id,
          startTime: metrics.startTime,
          endTime: endTime,
          uploadDuration: endTime.difference(metrics.startTime),
          retryCount: latestUpload.retryCount ?? 0,
          fileSizeMB: metrics.fileSizeMB,
          errorCategory: errorCategory,
          wasSuccessful: false,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Thin delegators for moved methods (keep @visibleForTesting annotations)
  // ---------------------------------------------------------------------------

  /// Delegates to [UploadRetryPolicy.isRetriableError].
  @visibleForTesting
  bool isRetriableError(dynamic error) => _retryPolicy.isRetriableError(error);

  /// Delegates to [UploadProgressReporter.getNetworkTypeString].
  @visibleForTesting
  String getNetworkTypeString(ConnectivityResult connectivity) =>
      _reporter.getNetworkTypeString(connectivity);

  /// Delegates to [UploadProgressReporter.categorizeError].
  @visibleForTesting
  Future<String> categorizeError(dynamic error) =>
      _reporter.categorizeError(error);

  /// Delegates to [UploadProgressReporter.getUserFriendlyErrorMessage].
  @visibleForTesting
  String getUserFriendlyErrorMessage(
    String category,
    ConnectivityResult connectivity,
  ) => _reporter.getUserFriendlyErrorMessage(category, connectivity);

  /// Pause an active upload
  Future<void> pauseUpload(String uploadId) async {
    final upload = getUpload(uploadId);
    if (upload == null) {
      Log.error(
        'Upload not found for pause: $uploadId',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      return;
    }

    if (upload.status != UploadStatus.uploading) {
      Log.error(
        'Upload is not currently uploading: ${upload.status}',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      return;
    }

    Log.debug(
      'Pausing upload: $uploadId',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    // Cancel the active upload (Blossom uploads are canceled by stopping the request)
    // No additional cleanup needed for Blossom uploads

    // Update status to paused instead of failed
    final pausedUpload = upload.copyWith(
      status: UploadStatus.paused,
      // Keep current progress and don't set error message
    );

    await _store.update(pausedUpload);

    // Cancel progress subscription
    _reporter.cancelAndRemoveSubscription(uploadId);

    Log.info(
      'Upload paused: $uploadId',
      name: 'UploadManager',
      category: LogCategory.video,
    );
  }

  /// Resume a paused upload
  Future<void> resumeUpload(String uploadId) async {
    final upload = getUpload(uploadId);
    if (upload == null) {
      Log.error(
        'Upload not found for resume: $uploadId',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      return;
    }

    if (upload.status != UploadStatus.paused) {
      Log.error(
        'Upload is not paused: ${upload.status}',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      return;
    }

    Log.debug(
      '▶️ Resuming upload: $uploadId',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    // Reset to pending to restart upload from beginning
    final resumedUpload = upload.copyWith(
      status: UploadStatus.pending,
      uploadProgress: upload.resumableSession == null
          ? 0
          : upload.uploadProgress,
    );

    await _store.update(resumedUpload);

    // Start upload process again and wait for completion
    await _performUpload(resumedUpload);

    Log.info(
      'Upload resumed: $uploadId',
      name: 'UploadManager',
      category: LogCategory.video,
    );
  }

  /// Retry a failed upload. Delegates to [UploadRetryPolicy.retryUpload].
  Future<void> retryUpload(String uploadId) async {
    await _retryPolicy.retryUpload(
      uploadId,
      performUpload: _performUpload,
    );
  }

  /// Resumes a single interrupted upload.
  ///
  /// For uploads left in [UploadStatus.uploading] or
  /// [UploadStatus.retrying] after an app restart. Delegates to
  /// [UploadRetryPolicy.resumeInterruptedUpload].
  void resumeInterruptedUpload(String uploadId) {
    _retryPolicy.resumeInterruptedUpload(
      uploadId,
      performUpload: _performUpload,
    );
  }

  /// Cancel an upload (stops the upload but keeps it for retry)
  Future<void> cancelUpload(String uploadId) async {
    final upload = getUpload(uploadId);
    if (upload == null) return;

    Log.debug(
      'Cancelling upload: $uploadId',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    // Cancel any active upload
    if (upload.cloudinaryPublicId != null) {
      // Blossom upload cancellation handled by request timeout
    }

    // Update status to failed so it can be retried later
    final cancelledUpload = upload.copyWith(
      status: UploadStatus.failed,
      errorMessage: 'Upload cancelled by user',
    );

    await _store.update(cancelledUpload);

    // Cancel progress subscription
    _reporter.cancelAndRemoveSubscription(uploadId);

    Log.warning(
      'Upload cancelled and available for retry: $uploadId',
      name: 'UploadManager',
      category: LogCategory.video,
    );
  }

  /// Remove completed, published, or unrecoverable failed uploads.
  Future<void> cleanupCompletedUploads() => _store.cleanupCompletedUploads();

  /// Update upload status (public method for VideoEventPublisher)
  Future<void> updateUploadStatus(
    String uploadId,
    UploadStatus status, {
    String? nostrEventId,
  }) async {
    final upload = getUpload(uploadId);
    if (upload == null) {
      Log.warning(
        'Upload not found for status update: $uploadId',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      return;
    }

    final updatedUpload = upload.copyWith(
      status: status,
      nostrEventId: nostrEventId ?? upload.nostrEventId,
      completedAt: status == UploadStatus.published
          ? DateTime.now()
          : upload.completedAt,
    );

    await _store.update(updatedUpload);
    Log.info(
      'Updated upload status: $uploadId -> $status',
      name: 'UploadManager',
      category: LogCategory.video,
    );
  }

  /// Get upload statistics
  Map<String, int> get uploadStats => _store.uploadStats;

  /// Fix uploads stuck in readyToPublish without proper data (debug method)
  Future<void> cleanupProblematicUploads() =>
      _store.cleanupProblematicUploads();

  /// Delegates to [UploadProgressReporter.getPerformanceMetrics].
  Map<String, dynamic> getPerformanceMetrics() =>
      _reporter.getPerformanceMetrics();

  /// Enhanced retry mechanism for manual retry.
  ///
  /// Delegates to [UploadRetryPolicy.retryUploadWithBackoff].
  Future<void> retryUploadWithBackoff(String uploadId) async {
    await _retryPolicy.retryUploadWithBackoff(
      uploadId,
      performUpload: _performUpload,
    );
  }

  /// Create successful upload with metadata
  PendingUpload _createSuccessfulUpload(PendingUpload upload, dynamic result) {
    final resultThumbnailUrl = _resultThumbnailUrl(result);

    final existingThumbnailUrl = upload.thumbnailPath;
    String? thumbnailUrl;
    if (_isHttpUrl(resultThumbnailUrl)) {
      thumbnailUrl = resultThumbnailUrl;
    } else if (_isHttpUrl(existingThumbnailUrl)) {
      thumbnailUrl = existingThumbnailUrl;
    }

    if (resultThumbnailUrl != null && !_isHttpUrl(resultThumbnailUrl)) {
      Log.error(
        '⚠️ thumbnailUrl is not an HTTP URL: $resultThumbnailUrl',
        name: 'UploadManager',
        category: LogCategory.video,
      );
    }

    Log.info(
      '📸 Upload result type: ${result.runtimeType}',
      name: 'UploadManager',
      category: LogCategory.system,
    );
    Log.info(
      '📸 Upload result thumbnail URL: $resultThumbnailUrl',
      name: 'UploadManager',
      category: LogCategory.system,
    );
    Log.info(
      '📸 Storing thumbnail URL in PendingUpload: $thumbnailUrl',
      name: 'UploadManager',
      category: LogCategory.system,
    );

    // Check if video is still processing (Blossom 202 response)
    final isProcessing = result.errorMessage == 'processing';

    // For Cloudflare Stream integration via Blossom, we have the final CDN URLs immediately
    // Skip processing state since cdn.divine.video URLs are available right away
    final skipProcessing = isProcessing && result.cdnUrl != null;

    if (skipProcessing) {
      Log.info(
        '🎬 Skipping processing state - CDN URL already available: ${result.cdnUrl}',
        name: 'UploadManager',
        category: LogCategory.video,
      );
    }

    // Validate all URLs are HTTP/HTTPS before storing
    // This prevents local file paths from being persisted and later published
    String? validatedCdnUrl = result.cdnUrl as String?;
    String? validatedStreamingMp4 = result.streamingMp4Url as String?;
    String? validatedStreamingHls = result.streamingHlsUrl as String?;
    String? validatedFallback = result.fallbackUrl as String?;

    if (validatedCdnUrl != null && !_isHttpUrl(validatedCdnUrl)) {
      Log.error(
        '⚠️ cdnUrl is not an HTTP URL (possible local path): $validatedCdnUrl',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      validatedCdnUrl = null;
    }
    if (validatedStreamingMp4 != null && !_isHttpUrl(validatedStreamingMp4)) {
      Log.error(
        '⚠️ streamingMp4Url is not an HTTP URL: $validatedStreamingMp4',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      validatedStreamingMp4 = null;
    }
    if (validatedStreamingHls != null && !_isHttpUrl(validatedStreamingHls)) {
      Log.error(
        '⚠️ streamingHlsUrl is not an HTTP URL: $validatedStreamingHls',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      validatedStreamingHls = null;
    }
    if (validatedFallback != null && !_isHttpUrl(validatedFallback)) {
      Log.error(
        '⚠️ fallbackUrl is not an HTTP URL: $validatedFallback',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      validatedFallback = null;
    }

    return upload.copyWith(
      status: (isProcessing && !skipProcessing)
          ? UploadStatus.processing
          : UploadStatus.readyToPublish,
      cloudinaryPublicId:
          result.videoId as String?, // Use videoId for existing systems
      videoId:
          result.videoId as String?, // Store videoId for new publishing system
      cdnUrl: validatedCdnUrl, // Store CDN URL (validated HTTP only)
      streamingMp4Url: validatedStreamingMp4, // Store BunnyStream MP4 URL
      streamingHlsUrl: validatedStreamingHls, // Store BunnyStream HLS URL
      fallbackUrl: validatedFallback, // Store R2 fallback MP4 URL
      thumbnailPath: thumbnailUrl, // Store thumbnail URL
      uploadProgress: (isProcessing && !skipProcessing)
          ? 0.9
          : 1.0, // Skip processing = 100% ready
      completedAt: (isProcessing && !skipProcessing)
          ? null
          : DateTime.now(), // Mark as completed if skipping processing
      resumableSession: null,
    );
  }

  /// Check if a URL is a valid HTTP/HTTPS URL (not a local file path)
  static bool _isHttpUrl(String? url) {
    final value = url?.trim();
    if (value == null || value.isEmpty) return false;
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  static String? _resultThumbnailUrl(dynamic result) {
    try {
      return result.thumbnailUrl as String?;
    } catch (_) {
      return null;
    }
  }

  static bool _hasHttpThumbnailUrl({
    required dynamic result,
    required String? generatedThumbnailUrl,
    required String? existingThumbnailUrl,
  }) {
    return _isHttpUrl(_resultThumbnailUrl(result)) ||
        _isHttpUrl(generatedThumbnailUrl) ||
        _isHttpUrl(existingThumbnailUrl);
  }

  /// Generate and upload thumbnail to Blossom CDN
  Future<String?> _generateAndUploadThumbnail({
    required File videoFile,
    required String nostrPubkey,
    required PendingUpload upload,
  }) async {
    try {
      Log.info(
        '📸 Extracting thumbnail from video: ${videoFile.path}',
        name: 'UploadManager',
        category: LogCategory.video,
      );

      // Generate thumbnail at optimal timestamp
      final thumbnailExtraction = await VideoThumbnailService.extractThumbnail(
        videoPath: videoFile.path,
        quality: 85,
        targetTimestamp:
            upload.thumbnailTimestamp ??
            VideoEditorConstants.defaultThumbnailExtractTime,
      );

      if (thumbnailExtraction == null) {
        Log.warning(
          '❌ Failed to extract thumbnail from video',
          name: 'UploadManager',
          category: LogCategory.video,
        );
        return null;
      }

      final thumbnailFile = File(thumbnailExtraction.path);
      if (!thumbnailFile.existsSync()) {
        Log.warning(
          '❌ Thumbnail file not found after extraction',
          name: 'UploadManager',
          category: LogCategory.video,
        );
        return null;
      }

      Log.info(
        '✅ Thumbnail extracted, uploading to Blossom server',
        name: 'UploadManager',
        category: LogCategory.video,
      );

      _reporter.updateProgress(upload.id, 0.85);

      // Upload thumbnail to Blossom server. Divine relay publishing requires
      // a CDN thumbnail, so keep the image upload's own retry enabled here.
      // If no HTTP thumbnail URL is available after that, the outer video
      // pipeline treats it as terminal to avoid re-uploading the whole video.
      final uploadResult = await _blossomService.uploadImage(
        imageFile: thumbnailFile,
        nostrPubkey: nostrPubkey,
        onProgress: (progress) {
          // Map thumbnail progress to 85%-100% of total upload
          _reporter.updateProgress(upload.id, 0.85 + (progress * 0.15));
        },
      );

      // Clean up local thumbnail file
      try {
        await thumbnailFile.delete();
        Log.debug(
          '🧹 Cleaned up local thumbnail file',
          name: 'UploadManager',
          category: LogCategory.video,
        );
      } catch (e) {
        Log.warning(
          'Failed to clean up thumbnail file: $e',
          name: 'UploadManager',
          category: LogCategory.video,
        );
      }

      if (uploadResult.success && uploadResult.cdnUrl != null) {
        return uploadResult.cdnUrl;
      }

      return null;
    } catch (e) {
      Log.error(
        'Error generating/uploading thumbnail: $e',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      return null;
    }
  }

  void dispose() {
    // Delegate to extracted policy/reporter (handles subscriptions, timers,
    // session futures, and metrics cleanup).
    _retryPolicy.dispose();
    _reporter.dispose();

    // Cancel all processing-completion polls
    for (final timer in _processingPollTimers.values) {
      timer.cancel();
    }
    _processingPollTimers.clear();

    // Delegate storage teardown (timer, queue, box pointer) to the store.
    _store.disposeStore();
    _isInitialized = false;

    Log.info(
      'UploadManager disposed',
      name: 'UploadManager',
      category: LogCategory.video,
    );
  }

  /// Start polling for processing upload completion.
  ///
  /// Visible for testing so the timer lifecycle (cancellation on
  /// completion, timeout, and [dispose]) can be exercised directly.
  @visibleForTesting
  void startProcessingPoll(PendingUpload upload) {
    Log.info(
      '🔄 Starting processing poll for upload: ${upload.id}',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    void stopPoll(Timer timer) {
      timer.cancel();
      if (identical(_processingPollTimers[upload.id], timer)) {
        _processingPollTimers.remove(upload.id);
      }
    }

    // Poll every 10 seconds for up to 5 minutes
    _processingPollTimers[upload.id]?.cancel();
    _processingPollTimers[upload.id] = Timer.periodic(
      const Duration(seconds: 10),
      (timer) async {
        try {
          // Check if upload still exists and is still processing
          final currentUpload = getUpload(upload.id);
          if (currentUpload == null ||
              currentUpload.status != UploadStatus.processing) {
            stopPoll(timer);
            return;
          }

          // Check processing status using Blossom service
          final isReady = await _checkVideoProcessingStatus(currentUpload);
          if (isReady) {
            // Update upload to ready state
            final readyUpload = currentUpload.copyWith(
              status: UploadStatus.readyToPublish,
              uploadProgress: 1.0,
              completedAt: DateTime.now(),
            );
            await _store.update(readyUpload);

            Log.info(
              '✅ Video processing complete: ${upload.id}',
              name: 'UploadManager',
              category: LogCategory.video,
            );
            stopPoll(timer);
          }
        } catch (e) {
          Log.warning(
            'Error checking processing status: $e',
            name: 'UploadManager',
            category: LogCategory.video,
          );
        }

        // Cancel after 5 minutes to avoid infinite polling
        if (timer.tick > 30) {
          // 30 * 10 seconds = 5 minutes
          stopPoll(timer);
          Log.warning(
            'Processing poll timeout for upload: ${upload.id}',
            name: 'UploadManager',
            category: LogCategory.video,
          );
        }
      },
    );
  }

  /// Check if video processing is complete
  Future<bool> _checkVideoProcessingStatus(PendingUpload upload) async {
    if (upload.videoId == null) return false;

    // Use Blossom service to check video status
    final serverUrl = await _blossomService.getBlossomServer();
    if (serverUrl == null) return false;

    try {
      // For Cloudflare Stream integration, try status endpoint first
      final statusResponse = await _dio.get(
        '$serverUrl/status/${upload.videoId}',
      );

      if (statusResponse.statusCode == 200) {
        Log.info(
          '📹 Video processing complete via status endpoint',
          name: 'UploadManager',
          category: LogCategory.video,
        );
        return true;
      }
    } catch (statusError) {
      Log.info(
        'Status endpoint not available, trying blob descriptor: $statusError',
        name: 'UploadManager',
        category: LogCategory.video,
      );

      // Fallback to blob descriptor endpoint
      try {
        final response = await _dio.get('$serverUrl/${upload.videoId}');

        // If we get 200, the video is ready with full metadata
        if (response.statusCode == 200) {
          Log.info(
            '📹 Video processing complete, full metadata available',
            name: 'UploadManager',
            category: LogCategory.video,
          );
          return true;
        }

        // If still 202, keep polling
        if (response.statusCode == 202) {
          Log.info(
            '🔄 Video still processing...',
            name: 'UploadManager',
            category: LogCategory.video,
          );
          return false;
        }

        return false;
      } catch (e) {
        Log.warning(
          'Error checking video status: $e',
          name: 'UploadManager',
          category: LogCategory.video,
        );

        // For Cloudflare Stream, assume it's ready after a few attempts
        // since CF Stream processes very quickly (usually < 30 seconds)
        Log.info(
          '⚡ Assuming Cloudflare Stream video is ready due to polling errors',
          name: 'UploadManager',
          category: LogCategory.video,
        );
        return true;
      }
    }

    return false;
  }
}
