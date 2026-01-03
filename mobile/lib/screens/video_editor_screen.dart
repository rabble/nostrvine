// ABOUTME: Video editor screen for adding text overlays and sound to recorded videos
// ABOUTME: Dark-themed interface with video preview, text editing, and sound selection

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:openvine/models/vine_draft.dart';
import 'package:openvine/providers/sound_library_service_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/vine_recording_provider.dart';
import 'package:openvine/screens/pure/video_metadata_screen_pure.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/text_overlay_renderer.dart';
import 'package:openvine/services/video_export_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/sound_picker/sound_picker_modal.dart';
import 'package:openvine/widgets/text_overlay/draggable_text_overlay.dart';
import 'package:openvine/widgets/text_overlay/text_overlay_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

class VideoEditorScreen extends ConsumerStatefulWidget {
  const VideoEditorScreen({
    super.key,
    required this.videoPath,
    this.onExport,
    this.onBack,
    this.externalAudioEventId,
    this.externalAudioUrl,
    this.externalAudioIsBundled = false,
    this.externalAudioAssetPath,
  });

  final String videoPath;
  final VoidCallback? onExport;
  final VoidCallback? onBack;

  /// External audio event ID from lip sync recording on camera screen.
  /// When provided, this audio will be mixed into the final video.
  final String? externalAudioEventId;

  /// Direct URL to the external audio file (avoids re-fetching).
  final String? externalAudioUrl;

  /// Whether the external audio is a bundled asset.
  final bool externalAudioIsBundled;

  /// Asset path for bundled external audio.
  final String? externalAudioAssetPath;

  @override
  ConsumerState<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends ConsumerState<VideoEditorScreen> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  AudioPlayer? _audioPlayer;
  String? _currentSoundId;
  Size? _lastPreviewSize; // Store preview size for text overlay scaling

  @override
  void initState() {
    super.initState();
    Log.info(
      '📹 VideoEditorScreen.initState() START - videoPath: ${widget.videoPath}',
      category: LogCategory.video,
    );

    // Log external audio info from lip sync recording
    if (widget.externalAudioEventId != null) {
      Log.info(
        '📹 External audio from lip sync: ${widget.externalAudioEventId}'
        '${widget.externalAudioIsBundled ? " (bundled: ${widget.externalAudioAssetPath})" : ""}'
        '${widget.externalAudioUrl != null && !widget.externalAudioIsBundled ? " (url: ${widget.externalAudioUrl})" : ""}',
        category: LogCategory.video,
      );
    }

    _initializeVideo();
    _audioPlayer = AudioPlayer();
    Log.info(
      '📹 VideoEditorScreen.initState() END',
      category: LogCategory.video,
    );
  }

  Future<void> _initializeVideo() async {
    Log.info('📹 _initializeVideo() START', category: LogCategory.video);
    try {
      final file = File(widget.videoPath);
      Log.info(
        '📹 Video file exists: ${file.existsSync()}, path: ${widget.videoPath}',
        category: LogCategory.video,
      );

      final controller = VideoPlayerController.file(file);
      Log.info(
        '📹 VideoPlayerController created, calling initialize()...',
        category: LogCategory.video,
      );

      await controller.initialize();
      Log.info(
        '📹 VideoPlayerController initialized, size: ${controller.value.size}',
        category: LogCategory.video,
      );

      await controller.setLooping(true);

      // If we have external audio from lip sync, mute video
      if (widget.externalAudioUrl != null ||
          widget.externalAudioAssetPath != null) {
        await controller.setVolume(0.0);
      }

      // Set state BEFORE calling play() - on macOS, play() can hang
      // This ensures the video displays even if play() blocks
      if (mounted) {
        setState(() {
          _videoController = controller;
          _isVideoInitialized = true;
        });
        Log.info(
          '📹 _initializeVideo() - video controller ready, starting playback',
          category: LogCategory.video,
        );
      }

      // Don't await play() - let it run asynchronously to avoid blocking
      unawaited(controller.play());
      Log.info('📹 Video playback started', category: LogCategory.video);

      // Load external audio AFTER video is displayed - don't block on it
      if (widget.externalAudioUrl != null ||
          widget.externalAudioAssetPath != null) {
        unawaited(_loadExternalAudio());
      }
    } catch (e, stackTrace) {
      Log.error(
        '📹 _initializeVideo() FAILED: $e',
        category: LogCategory.video,
      );
      Log.error('📹 Stack trace: $stackTrace', category: LogCategory.video);
    }
  }

  /// Load external audio from lip sync recording for preview playback
  Future<void> _loadExternalAudio() async {
    try {
      if (widget.externalAudioIsBundled &&
          widget.externalAudioAssetPath != null) {
        // Bundled sound - load from asset
        Log.info(
          '📹 Loading bundled audio for preview: ${widget.externalAudioAssetPath}',
          category: LogCategory.video,
        );
        await _audioPlayer?.setAsset(widget.externalAudioAssetPath!);
      } else if (widget.externalAudioUrl != null) {
        final audioUrl = widget.externalAudioUrl!;
        if (audioUrl.startsWith('http://') || audioUrl.startsWith('https://')) {
          // Remote sound - load from URL
          Log.info(
            '📹 Loading remote audio for preview: $audioUrl',
            category: LogCategory.video,
          );
          await _audioPlayer?.setUrl(audioUrl);
        }
      }

      await _audioPlayer?.setLoopMode(LoopMode.one);
      await _audioPlayer?.play();

      Log.info(
        '📹 External audio loaded and playing for preview',
        category: LogCategory.video,
      );
    } catch (e) {
      Log.error(
        '📹 Failed to load external audio for preview: $e',
        category: LogCategory.video,
      );
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }

  /// Load and play the selected sound, synced with video
  Future<void> _loadAndPlaySound(String? soundId) async {
    if (soundId == _currentSoundId) return;
    _currentSoundId = soundId;

    // Stop current audio
    await _audioPlayer?.stop();

    if (soundId == null) {
      // No sound selected - unmute video
      await _videoController?.setVolume(1.0);
      return;
    }

    // Mute video's original audio when playing selected sound
    await _videoController?.setVolume(0.0);

    // Get the sound's asset path
    final soundService = await ref.read(soundLibraryServiceProvider.future);
    final sound = soundService.getSoundById(soundId);

    if (sound == null) {
      Log.warning('Sound not found: $soundId', category: LogCategory.video);
      return;
    }

    try {
      String filePath;

      // Load the audio - handle both asset paths and file paths
      if (sound.assetPath.startsWith('/') ||
          sound.assetPath.startsWith('file://')) {
        // Custom sound - file path
        filePath = sound.assetPath.replaceFirst('file://', '');
      } else {
        // Bundled asset - copy to temp file for reliable playback on desktop
        final tempDir = await getTemporaryDirectory();
        final extension = sound.assetPath.split('.').last;
        filePath = '${tempDir.path}/editor_${sound.id}.$extension';

        final tempFile = File(filePath);
        if (!await tempFile.exists()) {
          final assetData = await rootBundle.load(sound.assetPath);
          await tempFile.writeAsBytes(assetData.buffer.asUint8List());
        }
      }

      await _audioPlayer?.setFilePath(filePath);

      // Set looping to match video
      await _audioPlayer?.setLoopMode(LoopMode.one);

      // Play the audio
      await _audioPlayer?.play();

      Log.info('Playing sound: ${sound.title}', category: LogCategory.video);
    } catch (e) {
      Log.error('Failed to play sound: $e', category: LogCategory.video);
      // Unmute video on error
      await _videoController?.setVolume(1.0);
    }
  }

  void _handleAddText() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TextOverlayEditor(
        onSave: (overlay) {
          ref
              .read(videoEditorProvider(widget.videoPath).notifier)
              .addTextOverlay(overlay);
          Navigator.of(context).pop();
        },
        onCancel: () => Navigator.of(context).pop(),
      ),
    );
  }

  void _handleAddSound() async {
    // Pause video and audio while selecting sound
    await _videoController?.pause();
    await _audioPlayer?.pause();

    // Wait for sounds to load
    final soundServiceAsync = await ref.read(
      soundLibraryServiceProvider.future,
    );

    if (!mounted) return;

    String? selectedSoundId;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SoundPickerModal(
          sounds: soundServiceAsync.sounds,
          selectedSoundId: ref
              .read(videoEditorProvider(widget.videoPath))
              .selectedSoundId,
          onSoundSelected: (soundId) {
            ref
                .read(videoEditorProvider(widget.videoPath).notifier)
                .selectSound(soundId);
            // Store selected sound ID to load after navigation completes
            selectedSoundId = soundId;
            Navigator.of(context).pop();
          },
        ),
      ),
    );

    // Load and play sound after returning from sound picker
    // This ensures the navigation is complete before we start playing
    if (mounted) {
      if (selectedSoundId != null) {
        await _loadAndPlaySound(selectedSoundId);
      }
      await _videoController?.play();
    }
  }

  Future<void> _handleDone() async {
    // Stop audio preview before processing
    await _audioPlayer?.stop();

    try {
      Log.info(
        '📹 VideoEditorScreen: Creating draft for video: ${widget.videoPath}',
        category: LogCategory.video,
      );

      // Get the current editor state for text overlays and sound
      final editorState = ref.read(videoEditorProvider(widget.videoPath));
      String finalVideoPath = widget.videoPath;

      Log.info(
        '📹 Editor state - overlays: ${editorState.textOverlays.length}, sound: ${editorState.selectedSoundId}',
        category: LogCategory.video,
      );

      // Apply text overlays if any exist
      if (editorState.textOverlays.isNotEmpty &&
          _isVideoInitialized &&
          _videoController != null) {
        Log.info(
          '📹 Burning ${editorState.textOverlays.length} text overlays into video',
          category: LogCategory.video,
        );

        // Use the actual video resolution for rendering overlays
        final videoSize = _videoController!.value.size;

        // Render text overlays to PNG, scaling fonts from preview to video size
        final renderer = TextOverlayRenderer();
        final overlayImage = await renderer.renderOverlays(
          editorState.textOverlays,
          videoSize,
          previewSize: _lastPreviewSize,
        );

        // Apply overlay to video using FFmpeg
        final exportService = VideoExportService();
        finalVideoPath = await exportService.applyTextOverlay(
          widget.videoPath,
          overlayImage,
        );

        Log.info(
          '📹 Text overlays burned into video: $finalVideoPath',
          category: LogCategory.video,
        );
      }

      // Apply sound overlay - prioritize external audio from lip sync flow
      if (widget.externalAudioUrl != null ||
          widget.externalAudioAssetPath != null) {
        // External audio from lip sync recording on camera screen
        Log.info(
          '📹 Mixing external audio from lip sync: ${widget.externalAudioEventId}',
          category: LogCategory.video,
        );

        final exportService = VideoExportService();
        final previousPath = finalVideoPath;

        // Check if it's a bundled asset or remote URL
        if (widget.externalAudioIsBundled &&
            widget.externalAudioAssetPath != null) {
          // Bundled sound - use mixAudio with asset path
          Log.info(
            '📹 Mixing bundled audio: ${widget.externalAudioAssetPath}',
            category: LogCategory.video,
          );
          finalVideoPath = await exportService.mixAudio(
            finalVideoPath,
            widget.externalAudioAssetPath!,
          );
        } else if (widget.externalAudioUrl != null) {
          final audioUrl = widget.externalAudioUrl!;

          if (audioUrl.startsWith('http://') ||
              audioUrl.startsWith('https://')) {
            // Remote sound - download first then mix
            Log.info(
              '📹 Downloading remote audio: $audioUrl',
              category: LogCategory.video,
            );

            // Download audio file to temp directory
            final tempDir = await getTemporaryDirectory();
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final audioFilePath = '${tempDir.path}/audio_$timestamp.mp3';

            final response = await http.get(Uri.parse(audioUrl));
            if (response.statusCode == 200) {
              await File(audioFilePath).writeAsBytes(response.bodyBytes);

              finalVideoPath = await exportService.mixExternalAudio(
                finalVideoPath,
                audioFilePath,
              );

              // Clean up downloaded audio file
              try {
                await File(audioFilePath).delete();
              } catch (_) {}
            } else {
              Log.warning(
                '📹 Failed to download audio: HTTP ${response.statusCode}',
                category: LogCategory.video,
              );
            }
          } else {
            Log.warning(
              '📹 Unknown audio URL format: $audioUrl',
              category: LogCategory.video,
            );
          }
        }

        // Clean up previous temp file if it was a temp file (not original)
        if (previousPath != widget.videoPath &&
            previousPath != finalVideoPath) {
          try {
            await File(previousPath).delete();
          } catch (e) {
            Log.warning(
              'Failed to delete temp file: $previousPath',
              category: LogCategory.video,
            );
          }
        }

        Log.info(
          '📹 External audio mixed into video: $finalVideoPath',
          category: LogCategory.video,
        );
      } else if (editorState.selectedSoundId != null) {
        // Bundled sound from editor sound picker
        Log.info(
          '📹 Mixing sound: ${editorState.selectedSoundId}',
          category: LogCategory.video,
        );

        // Look up the sound's asset path from the sound library
        final soundService = await ref.read(soundLibraryServiceProvider.future);
        final sound = soundService.getSoundById(editorState.selectedSoundId!);

        if (sound != null) {
          final exportService = VideoExportService();
          final previousPath = finalVideoPath;
          finalVideoPath = await exportService.mixAudio(
            finalVideoPath,
            sound.assetPath,
          );

          // Clean up previous temp file if it was a temp file (not original)
          if (previousPath != widget.videoPath) {
            try {
              await File(previousPath).delete();
            } catch (e) {
              Log.warning(
                'Failed to delete temp file: $previousPath',
                category: LogCategory.video,
              );
            }
          }

          Log.info(
            '📹 Sound mixed into video: $finalVideoPath',
            category: LogCategory.video,
          );
        } else {
          Log.warning(
            '📹 Sound not found: ${editorState.selectedSoundId}',
            category: LogCategory.video,
          );
        }
      }

      // Create draft storage service
      final prefs = await SharedPreferences.getInstance();
      final draftService = DraftStorageService(prefs);

      // Get the aspect ratio from recording state
      final recordingState = ref.read(vineRecordingProvider);
      final aspectRatio = recordingState.aspectRatio;

      // Create a draft for the edited video (with overlays burned in)
      final draft = VineDraft.create(
        videoFile: File(finalVideoPath),
        title: '',
        description: '',
        hashtags: [],
        frameCount: 0,
        selectedApproach: 'video',
        aspectRatio: aspectRatio,
      );

      await draftService.saveDraft(draft);

      Log.info(
        '📹 Created draft with ID: ${draft.id}',
        category: LogCategory.video,
      );

      if (mounted) {
        // Dispose video controller to free memory before navigating
        // The metadata screen will create its own player
        _videoController?.dispose();
        _videoController = null;
        _audioPlayer?.dispose();
        _audioPlayer = null;
        setState(() {
          _isVideoInitialized = false;
        });

        // Navigate to metadata screen
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => VideoMetadataScreenPure(draftId: draft.id),
          ),
        );

        // Re-initialize video when returning from metadata screen
        if (mounted) {
          _audioPlayer = AudioPlayer();
          await _initializeVideo();
          // Re-apply sound if one was selected
          if (_currentSoundId != null) {
            await _loadAndPlaySound(_currentSoundId);
          }
        }
      }

      // Call original callback if exists
      widget.onExport?.call();
    } catch (e) {
      Log.error('Failed to create draft: $e', category: LogCategory.video);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleBack() {
    // Stop audio preview when going back
    _audioPlayer?.stop();

    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      // Pop back to ClipManager since we got here via push
      context.pop();
    }
  }

  void _updateTextOverlayPosition(String id, Offset normalizedPosition) {
    final state = ref.read(videoEditorProvider(widget.videoPath));
    final overlay = state.textOverlays.firstWhere((o) => o.id == id);
    final updatedOverlay = overlay.copyWith(
      normalizedPosition: normalizedPosition,
    );
    ref
        .read(videoEditorProvider(widget.videoPath).notifier)
        .updateTextOverlay(id, updatedOverlay);
  }

  @override
  Widget build(BuildContext context) {
    Log.info(
      '📹 VideoEditorScreen.build() START - isVideoInitialized: $_isVideoInitialized',
      category: LogCategory.video,
    );
    final editorState = ref.watch(videoEditorProvider(widget.videoPath));
    final soundServiceAsync = ref.watch(soundLibraryServiceProvider);
    final soundService = soundServiceAsync.value;

    Log.info(
      '📹 VideoEditorScreen.build() returning Scaffold',
      category: LogCategory.video,
    );
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _handleBack,
        ),
        title: const Text('Edit Video', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: _handleDone,
            child: const Text(
              'Done',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Video preview area
          Expanded(
            child: Container(
              color: Colors.black,
              child: Center(
                child: _isVideoInitialized && _videoController != null
                    ? AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            // Use actual rendered size, not native video resolution
                            final renderedSize = Size(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            );
                            // Store preview size for text overlay scaling during export
                            _lastPreviewSize = renderedSize;
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                VideoPlayer(_videoController!),
                                // Text overlays
                                ...editorState.textOverlays.map((overlay) {
                                  return DraggableTextOverlay(
                                    overlay: overlay,
                                    videoSize: renderedSize,
                                    onPositionChanged: (position) =>
                                        _updateTextOverlayPosition(
                                          overlay.id,
                                          position,
                                        ),
                                  );
                                }),
                              ],
                            );
                          },
                        ),
                      )
                    : const CircularProgressIndicator(color: Colors.white),
              ),
            ),
          ),

          // Selected sound indicator
          if (editorState.selectedSoundId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey[900],
              child: Row(
                children: [
                  const Icon(Icons.music_note, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Sound: ${soundService?.getSoundById(editorState.selectedSoundId!)?.title ?? 'Loading...'}',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),

          // Bottom action buttons
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[900],
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _handleAddText,
                    icon: const Icon(Icons.text_fields),
                    label: const Text('Add Text'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _handleAddSound,
                    icon: const Icon(Icons.volume_up),
                    label: const Text('Add Sound'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
