// ABOUTME: Video recorder screen with modern UI design
// ABOUTME: Features top search bar, camera preview with grid, and bottom controls

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/sound_waveform/sound_waveform_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/audio_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/providers/video_recorder_provider.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/utils/video_controller_cleanup.dart';
import 'package:openvine/widgets/video_clip_editor/sheets/video_editor_restore_autosave_sheet.dart';
import 'package:openvine/widgets/video_recorder/preview/video_recorder_camera_preview.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_audio_progress_bar.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_bottom_bar.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_countdown_overlay.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_ghost_frame.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_record_button.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_segment_bar.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_top_bar.dart';

/// Video recorder screen with camera preview and recording controls.
class VideoRecorderScreen extends ConsumerStatefulWidget {
  /// Creates a video recorder screen.
  const VideoRecorderScreen({super.key});

  /// Route name for this screen.
  static const routeName = 'video-recorder';

  /// Path for this route.
  static const path = '/video-recorder';

  @override
  ConsumerState<VideoRecorderScreen> createState() =>
      _VideoRecorderScreenState();
}

class _VideoRecorderScreenState extends ConsumerState<VideoRecorderScreen>
    with WidgetsBindingObserver {
  VideoRecorderNotifier? _notifier;
  ProviderSubscription<AudioEvent?>? _soundSubscription;

  bool get _isAutosavedDraft =>
      ref.read(videoEditorProvider.notifier).isAutosavedDraft;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pauseBackgroundPlayback();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initializeCamera();
      _checkAutosavedChanges();
    });
    Log.info('📹 Initialized', name: 'VideoRecorderScreen', category: .video);
  }

  /// Initialize camera and handle permission failures
  Future<void> _initializeCamera() async {
    Log.info(
      '📹 _initializeCamera called',
      name: 'VideoRecorderScreen',
      category: LogCategory.video,
    );

    _disposeVideoControllers();

    try {
      _notifier = ref.read(videoRecorderProvider.notifier);
      await _notifier!.initialize(context: context);
    } catch (e) {
      Log.error(
        '📹 Camera initialization exception: $e',
        name: 'VideoRecorderScreen',
        category: LogCategory.video,
      );
    }
  }

  Future<void> _checkAutosavedChanges() async {
    Log.debug(
      '📹 isAutosavedDraft: $_isAutosavedDraft',
      name: 'VideoRecorderScreen',
      category: LogCategory.video,
    );

    if (!_isAutosavedDraft) {
      return;
    }

    final hasClips = ref.read(clipManagerProvider).hasClips;
    if (hasClips) {
      Log.debug(
        '📹 Skipping autosave check - clips already loaded',
        name: 'VideoRecorderScreen',
        category: LogCategory.video,
      );
      return;
    }

    Log.debug(
      '📹 Checking for autosaved changes',
      name: 'VideoRecorderScreen',
      category: LogCategory.video,
    );

    final draftService = ref.read(draftStorageServiceProvider);
    final draft = await draftService.getDraftById(
      VideoEditorConstants.autoSaveId,
    );
    if (!mounted) return;

    if (draft != null && draft.clips.isNotEmpty) {
      Log.info(
        '📹 Found valid autosaved draft',
        name: 'VideoRecorderScreen',
        category: LogCategory.video,
      );
      await VineBottomSheet.show(
        context: context,
        expanded: false,
        scrollable: false,
        isScrollControlled: true,
        body: const VideoEditorRestoreAutosaveSheet(),
      );
    } else {
      Log.debug(
        '📹 No valid autosaved draft found',
        name: 'VideoRecorderScreen',
        category: LogCategory.video,
      );
    }
  }

  /// Dispose all video controllers to free resources before recording
  void _disposeVideoControllers() {
    try {
      disposeAllVideoControllers(ref);
      Log.info(
        '🗑️ Disposed all video controllers',
        name: 'VideoRecorderScreen',
        category: .video,
      );
    } catch (e) {
      Log.warning(
        '📹 Failed to dispose video controllers: $e',
        name: 'VideoRecorderScreen',
        category: .video,
      );
    }
  }

  /// Force all background video playback to pause while camera is open.
  void _pauseBackgroundPlayback() {
    try {
      ref.read(overlayVisibilityProvider.notifier).setPageOpen(true);
      ref.read(videoVisibilityManagerProvider).pauseAllVideos();
      _disposeVideoControllers();
      Log.info(
        '⏸️ Paused background playback for camera',
        name: 'VideoRecorderScreen',
        category: .video,
      );
    } catch (e) {
      Log.warning(
        '📹 Failed to pause background playback: $e',
        name: 'VideoRecorderScreen',
        category: .video,
      );
    }
  }

  /// Listens to sound selection changes and extracts waveform data.
  void _setupSoundWaveformListener(SoundWaveformBloc bloc) {
    Log.info(
      '🎵 _setupSoundWaveformListener called',
      name: 'VideoRecorderScreen',
      category: LogCategory.video,
    );

    // Handle initial sound if already selected
    final initialSound = ref.read(videoRecorderProvider).selectedSound;
    Log.info(
      '🎵 initialSound: ${initialSound?.id ?? 'null'}',
      name: 'VideoRecorderScreen',
      category: LogCategory.video,
    );
    _triggerWaveformExtraction(bloc, initialSound);

    // Listen for future changes using listenManual (works outside build phase)
    _soundSubscription = ref.listenManual<AudioEvent?>(
      videoRecorderProvider.select((s) => s.selectedSound),
      (
        previous,
        next,
      ) {
        Log.info(
          '🎵 Sound changed: ${previous?.id ?? 'null'} → ${next?.id ?? 'null'}',
          name: 'VideoRecorderScreen',
          category: LogCategory.video,
        );
        _triggerWaveformExtraction(bloc, next);
      },
    );
  }

  /// Triggers waveform extraction for the given sound.
  void _triggerWaveformExtraction(SoundWaveformBloc bloc, AudioEvent? sound) {
    Log.info(
      '🎵 _triggerWaveformExtraction: ${sound?.id ?? 'null'}, '
      'isBundled: ${sound?.isBundled}, url: ${sound?.url}',
      name: 'VideoRecorderScreen',
      category: LogCategory.video,
    );

    if (sound == null) {
      bloc.add(const SoundWaveformClear());
      return;
    }

    // Handle bundled sounds (from app assets)
    if (sound.isBundled) {
      final assetPath = sound.assetPath;
      Log.info(
        '🎵 Bundled sound assetPath: $assetPath',
        name: 'VideoRecorderScreen',
        category: LogCategory.video,
      );
      if (assetPath != null) {
        bloc.add(
          SoundWaveformExtract(
            path: assetPath,
            soundId: sound.id,
            isAsset: true,
          ),
        );
      }
      return;
    }

    // Handle network sounds
    if (sound.url != null) {
      bloc.add(SoundWaveformExtract(path: sound.url!, soundId: sound.id));
    }
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    await ref
        .read(videoRecorderProvider.notifier)
        .handleAppLifecycleState(state);
  }

  @override
  Future<void> dispose() async {
    try {
      ref.read(overlayVisibilityProvider.notifier).setPageOpen(false);
    } catch (e) {
      Log.warning(
        '📹 Failed to clear overlay visibility on dispose: $e',
        name: 'VideoRecorderScreen',
        category: .video,
      );
    }
    unawaited(_notifier?.destroy());
    _soundSubscription?.close();

    WidgetsBinding.instance.removeObserver(this);

    super.dispose();

    Log.info('📹 Disposed', name: 'VideoRecorderScreen', category: .video);
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = VineTheme.surfaceContainerHigh;

    return BlocProvider<SoundWaveformBloc>(
      create: (context) {
        final bloc = SoundWaveformBloc();
        _setupSoundWaveformListener(bloc);

        return bloc;
      },
      child: PopScope(
        onPopInvokedWithResult: (didPop, value) {
          if (didPop && !_isAutosavedDraft) {
            ref
                .read(videoPublishProvider.notifier)
                .clearAll(keepAutosavedDraft: true);
          }
        },
        child: const AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: backgroundColor,
            statusBarIconBrightness: .light,
            statusBarBrightness: .dark,
          ),
          child: Scaffold(
            backgroundColor: backgroundColor,
            resizeToAvoidBottomInset: false,
            body: Stack(
              fit: .expand,
              children: [
                Column(
                  spacing: 12,
                  children: [
                    Expanded(
                      child: Stack(
                        fit: .expand,
                        children: [
                          // Camera preview
                          VideoRecorderCameraPreview(),

                          // Ghost Frame
                          VideoRecorderGhostFrame(),

                          // Audio progress bar (shows during recording with sound)
                          VideoRecorderAudioProgressBar(),

                          // Segment bar
                          VideoRecorderSegmentBar(),

                          // Top bar with close-button and confirm-button
                          VideoRecorderTopBar(),

                          /// Record button
                          RecordButton(),
                        ],
                      ),
                    ),
                    // Bottom controls
                    VideoRecorderBottomBar(),
                  ],
                ),

                // Countdown overlay
                VideoRecorderCountdownOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
