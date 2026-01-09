// ABOUTME: Main screen for managing recorded video clips before editing
// ABOUTME: Horizontal timeline at bottom, video preview at top, swipe gestures

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:models/models.dart' as vine show AspectRatio;
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/models/saved_clip.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/providers/vine_recording_provider.dart';
import 'package:openvine/screens/clip_library_screen.dart';
import 'package:openvine/screens/video_editor_screen.dart';
import 'package:openvine/services/video_export_service.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:video_player/video_player.dart';

class ClipManagerScreen extends ConsumerStatefulWidget {
  const ClipManagerScreen({
    super.key,
    this.onRecordMore,
    this.onNext,
    this.onDiscard,
  });

  final VoidCallback? onRecordMore;
  final VoidCallback? onNext;
  final VoidCallback? onDiscard;

  @override
  ConsumerState<ClipManagerScreen> createState() => _ClipManagerScreenState();
}

class _ClipManagerScreenState extends ConsumerState<ClipManagerScreen> {
  bool _isProcessing = false;
  bool _isNavigatingAway = false;
  VideoPlayerController? _previewController;
  String? _currentPreviewClipId;
  AudioPlayer? _audioPlayer;
  bool _externalAudioLoaded = false;
  VoidCallback? _videoEndListener;

  @override
  void initState() {
    super.initState();
    // Schedule audio init after first frame when ref is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initExternalAudio();
    });
  }

  @override
  void dispose() {
    _removeVideoEndListener();
    _previewController?.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }

  void _removeVideoEndListener() {
    if (_videoEndListener != null && _previewController != null) {
      _previewController!.removeListener(_videoEndListener!);
      _videoEndListener = null;
    }
  }

  /// Initialize external audio player if a sound was selected for lip sync
  Future<void> _initExternalAudio() async {
    final selectedSound = ref.read(selectedSoundProvider);

    Log.info(
      '📹 ClipManager: _initExternalAudio called, selectedSound: ${selectedSound?.title ?? "null"}',
      category: LogCategory.video,
    );

    if (selectedSound == null) {
      Log.info(
        '📹 ClipManager: No sound selected, skipping external audio',
        category: LogCategory.video,
      );
      return;
    }

    try {
      _audioPlayer = AudioPlayer();

      Log.info(
        '📹 ClipManager: Sound details - isBundled: ${selectedSound.isBundled}, '
        'assetPath: ${selectedSound.assetPath}, url: ${selectedSound.url}',
        category: LogCategory.video,
      );

      if (selectedSound.isBundled && selectedSound.assetPath != null) {
        await _audioPlayer?.setAsset(selectedSound.assetPath!);
        Log.info(
          '📹 ClipManager: Loaded bundled audio for preview: ${selectedSound.assetPath}',
          category: LogCategory.video,
        );
        _externalAudioLoaded = true;
      } else if (selectedSound.url != null) {
        final audioUrl = selectedSound.url!;
        if (audioUrl.startsWith('http://') || audioUrl.startsWith('https://')) {
          await _audioPlayer?.setUrl(audioUrl);
          Log.info(
            '📹 ClipManager: Loaded remote audio for preview: $audioUrl',
            category: LogCategory.video,
          );
          _externalAudioLoaded = true;
        } else {
          Log.warning(
            '📹 ClipManager: Unknown audio URL format: $audioUrl',
            category: LogCategory.video,
          );
        }
      } else {
        Log.warning(
          '📹 ClipManager: No valid audio source found',
          category: LogCategory.video,
        );
      }

      if (_externalAudioLoaded) {
        await _audioPlayer?.setLoopMode(LoopMode.one);
        Log.info(
          '📹 ClipManager: External audio ready for playback',
          category: LogCategory.video,
        );
      }
    } catch (e) {
      Log.error(
        '📹 ClipManager: Failed to load external audio: $e',
        category: LogCategory.video,
      );
    }
  }

  /// Calculate the audio start position for a given clip.
  ///
  /// Returns the cumulative duration of all clips before this one,
  /// so audio playback syncs with the corresponding video segment.
  Duration _getAudioStartPositionForClip(RecordingClip clip) {
    final state = ref.read(clipManagerProvider);
    final sortedClips = state.sortedClips;

    var cumulativeDuration = Duration.zero;
    for (final c in sortedClips) {
      if (c.id == clip.id) {
        break;
      }
      cumulativeDuration += c.duration;
    }

    return cumulativeDuration;
  }

  Future<void> _loadPreview(RecordingClip clip) async {
    if (_currentPreviewClipId == clip.id) return;

    // Remove old listener before disposing controller
    _removeVideoEndListener();

    // Dispose and null out old controller before creating new one
    // This prevents "used after disposed" errors during async initialization
    final oldController = _previewController;
    _previewController = null;
    _currentPreviewClipId = clip.id;

    // Stop audio if playing
    unawaited(_audioPlayer?.pause());

    // Trigger rebuild to show loading state
    if (mounted) setState(() {});

    oldController?.dispose();

    final controller = VideoPlayerController.file(File(clip.filePath));
    await controller.initialize();
    await controller.setLooping(false); // Don't loop - play once then stop

    // If we have external audio loaded, mute the video and play audio separately
    if (_externalAudioLoaded) {
      await controller.setVolume(0.0);

      // Add listener to pause audio when video ends
      _videoEndListener = () {
        if (controller.value.position >= controller.value.duration) {
          _audioPlayer?.pause();
        }
      };
      controller.addListener(_videoEndListener!);
    } else {
      // Respect mute setting for original audio
      final state = ref.read(clipManagerProvider);
      await controller.setVolume(state.muteOriginalAudio ? 0.0 : 1.0);
    }

    // IMPORTANT: Set state BEFORE calling play() - on macOS, play() can hang
    // This ensures the video preview is displayed immediately
    if (mounted) {
      setState(() {
        _previewController = controller;
      });

      // Don't await play() - let it run asynchronously to avoid blocking on macOS
      unawaited(controller.play());

      // Start external audio playback after video starts (don't block on it)
      if (_externalAudioLoaded) {
        final audioStartPosition = _getAudioStartPositionForClip(clip);
        Log.info(
          '📹 ClipManager: Playing audio from ${audioStartPosition.inMilliseconds}ms for clip ${clip.id}',
          category: LogCategory.video,
        );
        unawaited(
          _audioPlayer?.seek(audioStartPosition).then((_) {
            _audioPlayer?.play();
          }),
        );
      }
    } else {
      // Widget was unmounted during async initialization, dispose the new controller
      _removeVideoEndListener();
      controller.dispose();
      unawaited(_audioPlayer?.pause());
    }
  }

  Future<void> _handleNext() async {
    if (_isProcessing) return;

    final state = ref.read(clipManagerProvider);
    if (!state.hasClips) return;

    // Capture ROOT navigator BEFORE async work - context may become stale
    // Use rootNavigator: true to bypass GoRouter's nested navigators
    final navigator = Navigator.of(context, rootNavigator: true);

    setState(() {
      _isProcessing = true;
    });

    try {
      // Get aspect ratio from recording settings
      final recordingState = ref.read(vineRecordingProvider);
      final aspectRatio = recordingState.aspectRatio;

      Log.info(
        '📹 Processing ${state.clips.length} clips with ${aspectRatio.name} aspect ratio${state.muteOriginalAudio ? " (muted)" : ""}',
        category: LogCategory.video,
      );

      final exportService = VideoExportService();
      final videoPath = await exportService.concatenateSegments(
        state.sortedClips,
        aspectRatio: aspectRatio,
        muteAudio: state.muteOriginalAudio,
      );

      Log.info(
        '📹 Clips processed to: $videoPath',
        category: LogCategory.video,
      );

      if (mounted) {
        // Dispose video and audio preview to free memory
        _previewController?.dispose();
        _previewController = null;
        _currentPreviewClipId = null;
        await _audioPlayer?.stop();
        _audioPlayer?.dispose();
        _audioPlayer = null;

        // Mark that we're navigating away to prevent auto-play during push
        _isNavigatingAway = true;

        // Release camera resources to free memory before navigating
        // The user is done recording, so we don't need the camera anymore
        ref.read(vineRecordingProvider.notifier).releaseCamera();

        // Get the selected sound from camera screen (if any) for lip sync flow
        final selectedSound = ref.read(selectedSoundProvider);
        final externalAudioEventId = selectedSound?.id;
        final externalAudioUrl = selectedSound?.url;
        final externalAudioIsBundled = selectedSound?.isBundled ?? false;
        final externalAudioAssetPath = selectedSound?.assetPath;

        Log.info(
          '📹 About to navigate to /edit-video with path: $videoPath'
          '${externalAudioEventId != null ? ", sound: $externalAudioEventId" : ""}'
          '${externalAudioIsBundled ? " (bundled: $externalAudioAssetPath)" : ""}'
          '${externalAudioUrl != null && !externalAudioIsBundled ? " (url: $externalAudioUrl)" : ""}',
          category: LogCategory.video,
        );

        // Navigate directly without scheduling - FFmpeg is done and the navigator
        // was captured before async work. Scheduling with Future.delayed or
        // addPostFrameCallback hangs on macOS after FFmpeg operations.
        Log.info(
          '📹 Calling navigator.push directly',
          category: LogCategory.video,
        );

        navigator
            .push<void>(
              MaterialPageRoute(
                builder: (ctx) => VideoEditorScreen(
                  videoPath: videoPath,
                  externalAudioEventId: externalAudioEventId,
                  externalAudioUrl: externalAudioUrl,
                  externalAudioIsBundled: externalAudioIsBundled,
                  externalAudioAssetPath: externalAudioAssetPath,
                ),
              ),
            )
            .then((_) async {
              // Clear navigation flag now that we've returned
              _isNavigatingAway = false;
              _isProcessing = false;

              // Re-initialize audio and preview when returning from video editor
              if (mounted) {
                _externalAudioLoaded = false;
                await _initExternalAudio();
                final currentState = ref.read(clipManagerProvider);
                if (currentState.sortedClips.isNotEmpty) {
                  _loadPreview(currentState.sortedClips.first);
                }
              }
            });
      }
    } catch (e) {
      Log.error('📹 Failed to process clips: $e', category: LogCategory.video);

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process clips: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _goToCamera() {
    context.go('/camera');
  }

  void _selectClip(RecordingClip clip) {
    ref.read(clipManagerProvider.notifier).selectClip(clip.id);
    _loadPreview(clip);
  }

  void _deleteClip(String clipId) {
    final notifier = ref.read(clipManagerProvider.notifier);
    final state = ref.read(clipManagerProvider);

    // If deleting the selected clip, select another one
    if (state.selectedClipId == clipId) {
      final clips = state.sortedClips;
      final currentIndex = clips.indexWhere((c) => c.id == clipId);
      if (clips.length > 1) {
        // Select the next clip, or previous if this was the last one
        final newIndex = currentIndex < clips.length - 1
            ? currentIndex + 1
            : currentIndex - 1;
        notifier.selectClip(clips[newIndex].id);
        _loadPreview(clips[newIndex]);
      } else {
        // This was the only clip
        notifier.selectClip(null);
        _previewController?.dispose();
        _previewController = null;
        _currentPreviewClipId = null;
      }
    }

    notifier.deleteClip(clipId);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(clipManagerProvider);
    final notifier = ref.read(clipManagerProvider.notifier);

    // Auto-select first clip if none selected, or load preview if controller is missing
    // Skip if we're navigating away (push to video editor) to prevent auto-play
    if (state.hasClips && !_isNavigatingAway) {
      if (state.selectedClipId == null) {
        // No clip selected - select the first one
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_isNavigatingAway) {
            final firstClip = state.sortedClips.first;
            notifier.selectClip(firstClip.id);
            _loadPreview(firstClip);
          }
        });
      } else if (_previewController == null && _currentPreviewClipId == null) {
        // Clip is selected but preview controller is missing (widget was recreated)
        // Load preview for the currently selected clip
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_isNavigatingAway) {
            final selectedClip = state.sortedClips.firstWhere(
              (c) => c.id == state.selectedClipId,
              orElse: () => state.sortedClips.first,
            );
            _loadPreview(selectedClip);
          }
        });
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: widget.onDiscard ?? () => Navigator.of(context).pop(),
        ),
        title: Text(
          '${(state.totalDuration.inMilliseconds / 1000).toStringAsFixed(1)}s / 6.3s',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          // Save for later button
          if (state.hasClips)
            IconButton(
              icon: const Icon(Icons.save_outlined, color: Colors.white),
              tooltip: 'Save for later',
              onPressed: _saveClipsForLater,
            ),
          // Mute original audio toggle
          IconButton(
            icon: Icon(
              state.muteOriginalAudio ? Icons.volume_off : Icons.volume_up,
              color: state.muteOriginalAudio
                  ? VineTheme.vineGreen
                  : Colors.white,
            ),
            tooltip: state.muteOriginalAudio ? 'Sound muted' : 'Mute sound',
            onPressed: () {
              ref.read(clipManagerProvider.notifier).toggleMuteOriginalAudio();
              // Also update preview player volume
              if (_previewController != null) {
                _previewController!.setVolume(
                  state.muteOriginalAudio ? 1.0 : 0.0,
                );
              }
            },
          ),
          TextButton(
            onPressed: state.hasClips && !_isProcessing
                ? () {
                    if (widget.onNext != null) {
                      widget.onNext!();
                    } else {
                      _handleNext();
                    }
                  }
                : null,
            child: _isProcessing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Next',
                    style: TextStyle(
                      color: state.hasClips ? VineTheme.vineGreen : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: state.hasClips
          ? Column(
              children: [
                // Video preview area
                Expanded(child: _buildPreviewArea(state)),
                // Horizontal timeline at bottom
                _buildTimeline(state, notifier),
              ],
            )
          : _buildEmptyState(),
    );
  }

  Widget _buildPreviewArea(dynamic state) {
    // Get the target aspect ratio from recording settings
    final recordingState = ref.watch(vineRecordingProvider);
    final targetAspectRatio = recordingState.aspectRatio;

    // Convert AspectRatio enum to numeric value
    final targetRatio = switch (targetAspectRatio) {
      vine.AspectRatio.square => 1.0,
      vine.AspectRatio.vertical => 9.0 / 16.0,
    };

    return Container(
      color: Colors.black,
      child: Center(
        child:
            _previewController != null &&
                _previewController!.value.isInitialized
            ? AspectRatio(
                // Use target aspect ratio (9:16 vertical or 1:1 square)
                aspectRatio: targetRatio,
                child: ClipRect(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _previewController!.value.size.width,
                      height: _previewController!.value.size.height,
                      child: VideoPlayer(_previewController!),
                    ),
                  ),
                ),
              )
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: VineTheme.vineGreen),
                  SizedBox(height: 16),
                  Text(
                    'Loading preview...',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTimeline(dynamic state, ClipManagerNotifier notifier) {
    final clips = state.sortedClips as List<RecordingClip>;
    final totalMs = state.totalDuration.inMilliseconds;
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - 32 - 70; // padding + record button
    const minSegmentWidth = 60.0;
    const segmentHeight = 60.0;

    return Container(
      height: 108,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Scrollable timeline
          Expanded(
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              buildDefaultDragHandles: false,
              itemCount: clips.length,
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex--;
                final reorderedIds = List<String>.from(clips.map((c) => c.id));
                final movedId = reorderedIds.removeAt(oldIndex);
                reorderedIds.insert(newIndex, movedId);
                notifier.reorderClips(reorderedIds);
              },
              proxyDecorator: (child, index, animation) {
                return Material(
                  elevation: 4,
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  child: child,
                );
              },
              itemBuilder: (context, index) {
                final clip = clips[index];
                final isSelected = state.selectedClipId == clip.id;

                // Calculate proportional width
                double segmentWidth;
                if (totalMs > 0) {
                  final proportion = clip.duration.inMilliseconds / totalMs;
                  segmentWidth = (availableWidth * proportion).clamp(
                    minSegmentWidth,
                    availableWidth,
                  );
                } else {
                  segmentWidth = minSegmentWidth;
                }

                return _TimelineSegment(
                  key: ValueKey(clip.id),
                  clip: clip,
                  width: segmentWidth,
                  height: segmentHeight,
                  isSelected: isSelected,
                  index: index,
                  onTap: () => _selectClip(clip),
                  onDelete: () => _deleteClip(clip.id),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          // Action buttons column
          if (state.canRecordMore)
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Import from clip library button (above record button)
                _buildImportFromClipsButton(),
                const SizedBox(height: 2),
                // Record more button
                _buildRecordButton(state),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildImportFromClipsButton() {
    return GestureDetector(
      onTap: _showClipLibrary,
      child: Container(
        width: 60,
        height: 20,
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.grey.withValues(alpha: 0.5),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Center(
          child: Icon(
            Icons.video_library_outlined,
            color: Colors.grey,
            size: 12,
          ),
        ),
      ),
    );
  }

  Future<void> _showClipLibrary() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ClipLibraryScreen(
          selectionMode: true,
          onClipSelected: (clip) async {
            await _importClipFromLibrary(clip);
          },
        ),
      ),
    );
  }

  Future<void> _importClipFromLibrary(SavedClip clip) async {
    try {
      Log.info(
        '📹 Importing clip from library: ${clip.id}',
        category: LogCategory.video,
      );

      // Verify the file exists
      final videoFile = File(clip.filePath);
      if (!await videoFile.exists()) {
        throw Exception('Video file not found');
      }

      // Add to clip manager
      ref
          .read(clipManagerProvider.notifier)
          .addClip(
            filePath: clip.filePath,
            duration: clip.duration,
            thumbnailPath: clip.thumbnailPath,
          );

      Log.info(
        '📹 Added clip from library: ${clip.filePath}, duration: ${clip.duration.inMilliseconds}ms',
        category: LogCategory.video,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Clip added'),
            backgroundColor: VineTheme.vineGreen,
          ),
        );
      }
    } catch (e) {
      Log.error('📹 Failed to import clip: $e', category: LogCategory.video);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to import clip: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveClipsForLater() async {
    final state = ref.read(clipManagerProvider);
    if (!state.hasClips) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      Log.info(
        '📹 Saving ${state.clips.length} clips to library',
        category: LogCategory.video,
      );

      // Get aspect ratio from recording settings
      final recordingState = ref.read(vineRecordingProvider);
      final aspectRatio = recordingState.aspectRatio;

      // Save each clip individually to the clip library
      final clipService = ref.read(clipLibraryServiceProvider);

      for (final clip in state.sortedClips) {
        final savedClip = SavedClip(
          id: clip.id,
          filePath: clip.filePath,
          thumbnailPath: clip.thumbnailPath,
          duration: clip.duration,
          createdAt: DateTime.now(),
          aspectRatio: aspectRatio.name,
        );
        await clipService.saveClip(savedClip);

        Log.info(
          '📹 Saved clip to library: ${clip.id}',
          category: LogCategory.video,
        );
      }

      Log.info(
        '📹 Saved ${state.clips.length} clips to library',
        category: LogCategory.video,
      );

      // Clear the clips
      ref.read(clipManagerProvider.notifier).clearAll();

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${state.clips.length} clips saved to library'),
            backgroundColor: VineTheme.vineGreen,
          ),
        );

        // Navigate back to camera
        context.go('/camera');
      }
    } catch (e) {
      Log.error('📹 Failed to save clips: $e', category: LogCategory.video);

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save clips: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildRecordButton(dynamic state) {
    final remaining = state.remainingDuration as Duration;
    final seconds = remaining.inMilliseconds / 1000;

    return GestureDetector(
      onTap: widget.onRecordMore ?? _goToCamera,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          border: Border.all(color: VineTheme.vineGreen, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, color: VineTheme.vineGreen, size: 24),
            Text(
              '${seconds.toStringAsFixed(1)}s',
              style: const TextStyle(color: VineTheme.vineGreen, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.videocam_off, color: Colors.grey, size: 64),
          const SizedBox(height: 16),
          const Text(
            'No clips recorded',
            style: TextStyle(color: Colors.grey, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap below to start recording',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: VineTheme.vineGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: widget.onRecordMore ?? _goToCamera,
            icon: const Icon(Icons.videocam),
            label: const Text('Record'),
          ),
        ],
      ),
    );
  }
}

/// Individual timeline segment with swipe-to-delete
class _TimelineSegment extends StatefulWidget {
  const _TimelineSegment({
    super.key,
    required this.clip,
    required this.width,
    required this.height,
    required this.isSelected,
    required this.index,
    required this.onTap,
    required this.onDelete,
  });

  final RecordingClip clip;
  final double width;
  final double height;
  final bool isSelected;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  State<_TimelineSegment> createState() => _TimelineSegmentState();
}

class _TimelineSegmentState extends State<_TimelineSegment> {
  double _dragOffset = 0;
  bool _isDragging = false;
  Offset? _dragStartPosition;
  bool _isVerticalDrag = false;

  void _handlePointerDown(PointerDownEvent event) {
    _dragStartPosition = event.position;
    _isVerticalDrag = false;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_dragStartPosition == null) return;

    final delta = event.position - _dragStartPosition!;

    // Determine drag direction on first significant movement
    if (!_isDragging && !_isVerticalDrag) {
      // Need at least 10 pixels of movement to determine direction
      if (delta.distance > 10) {
        // If vertical movement is greater than horizontal, treat as vertical drag
        if (delta.dy.abs() > delta.dx.abs() && delta.dy < 0) {
          _isVerticalDrag = true;
          setState(() {
            _isDragging = true;
          });
        }
      }
    }

    // Handle vertical drag for delete gesture
    if (_isVerticalDrag) {
      setState(() {
        // Only allow upward swipe (negative values)
        _dragOffset = delta.dy.clamp(-widget.height, 0.0);
      });
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_isVerticalDrag) {
      final deleteThreshold = widget.height * 0.5;
      if (_dragOffset.abs() > deleteThreshold) {
        widget.onDelete();
      }
    }

    setState(() {
      _isDragging = false;
      _dragOffset = 0;
    });
    _dragStartPosition = null;
    _isVerticalDrag = false;
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    setState(() {
      _isDragging = false;
      _dragOffset = 0;
    });
    _dragStartPosition = null;
    _isVerticalDrag = false;
  }

  Widget _buildSegmentContent(bool isDeleting) {
    return AnimatedContainer(
      duration: _isDragging ? Duration.zero : const Duration(milliseconds: 200),
      transform: Matrix4.translationValues(0, _dragOffset, 0),
      width: widget.width,
      height: widget.height,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.isSelected
              ? VineTheme.vineGreen
              : (isDeleting ? Colors.red : Colors.transparent),
          width: 2,
        ),
        color: isDeleting ? Colors.red.withValues(alpha: 0.3) : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail or placeholder
            if (widget.clip.thumbnailPath != null)
              Image.file(File(widget.clip.thumbnailPath!), fit: BoxFit.cover)
            else
              Container(
                color: Colors.grey[800],
                child: const Icon(Icons.videocam, color: Colors.grey),
              ),
            // Delete indicator
            if (isDeleting)
              Container(
                color: Colors.red.withValues(alpha: 0.5),
                child: const Center(
                  child: Icon(Icons.delete, color: Colors.white, size: 24),
                ),
              ),
            // Duration badge
            if (!isDeleting)
              Positioned(
                left: 4,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${widget.clip.durationInSeconds.toStringAsFixed(1)}s',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deleteThreshold = widget.height * 0.5;
    final isDeleting = _dragOffset.abs() > deleteThreshold;

    final content = _buildSegmentContent(isDeleting);

    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: GestureDetector(
        onTap: widget.onTap,
        // When doing vertical drag, don't wrap with ReorderableDragStartListener
        // to prevent gesture conflicts
        child: _isVerticalDrag
            ? content
            : ReorderableDragStartListener(index: widget.index, child: content),
      ),
    );
  }
}
