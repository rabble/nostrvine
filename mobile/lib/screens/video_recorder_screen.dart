// ABOUTME: Video recorder screen with camera preview and recording controls.
// ABOUTME: Supports classic and capture modes; opened standalone or from the video editor.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/blocs/sound_waveform/sound_waveform_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/providers/video_recorder_provider.dart';
import 'package:openvine/utils/video_controller_cleanup.dart';
import 'package:openvine/widgets/video_recorder/modes/capture/video_recorder_capture_stack.dart';
import 'package:openvine/widgets/video_recorder/modes/classic/video_recorder_classic_stack.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_bottom_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

const _kWhySixSecondsShownKey = 'why_six_seconds_shown';

/// Video recorder screen with camera preview and recording controls.
class VideoRecorderScreen extends ConsumerStatefulWidget {
  /// Creates a video recorder screen.
  const VideoRecorderScreen({super.key, this.fromEditor = false});

  /// Whether the screen is opened from the video editor.
  ///
  /// When `true`, the bottom bar is hidden and navigation uses `context.pop`
  /// instead of the standard recorder close flow.
  final bool fromEditor;

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
  OverlayVisibility? _overlayVisibilityNotifier;

  bool get _isAutosavedDraft => ref.read(videoEditorProvider).isAutosavedDraft;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    _pauseBackgroundPlayback();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _initializeCamera();
      await _maybeShowWhySixSeconds();
      if (!mounted) return;
      _checkAutosavedChanges();
    });
    Log.info('📹 Initialized', name: 'VideoRecorderScreen', category: .video);
  }

  /// Shows the "Why six seconds?" prompt only once per user.
  Future<void> _maybeShowWhySixSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kWhySixSecondsShownKey) ?? false) return;
    await prefs.setBool(_kWhySixSecondsShownKey, true);
    if (!mounted) return;

    await VineBottomSheetPrompt.show(
      context: context,
      sticker: .grandfather,
      title: context.l10n.videoRecorderWhySixSecondsTitle,
      subtitle: context.l10n.videoRecorderWhySixSecondsSubtitle,
      secondaryButtonText: context.l10n.videoRecorderWhySixSecondsButton,
      onSecondaryPressed: context.pop,
    );
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

    if (draft != null && draft.hasBeenEdited) {
      Log.info(
        '📹 Found valid autosaved draft',
        name: 'VideoRecorderScreen',
        category: LogCategory.video,
      );
      await VineBottomSheetPrompt.show(
        context: context,
        sticker: .videoClapBoard,
        title: context.l10n.videoRecorderAutosaveFoundTitle,
        subtitle: context.l10n.videoRecorderAutosaveFoundSubtitle,
        primaryButtonText: context.l10n.videoRecorderAutosaveContinueButton,
        onPrimaryPressed: () async {
          final restoreSuccessful = await ref
              .read(videoEditorProvider.notifier)
              .restoreDraft();

          if (!mounted) return;
          context.pop();

          if (!restoreSuccessful) {
            ScaffoldMessenger.of(context).showSnackBar(
              DivineSnackbarContainer.snackBar(
                context.l10n.videoRecorderAutosaveRestoreFailure,
                error: true,
              ),
            );
            return;
          }

          ref.read(videoRecorderProvider.notifier).openVideoEditor(context);
        },
        secondaryButtonText: context.l10n.videoRecorderAutosaveDiscardButton,
        onSecondaryPressed: () {
          ref.read(videoEditorProvider.notifier).removeAutosavedDraft();
          context.pop();
        },
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
      _overlayVisibilityNotifier = ref.read(overlayVisibilityProvider.notifier);
      _overlayVisibilityNotifier!.setPageOpen(true);
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
    final initialSound = ref.read(videoEditorProvider).selectedSound;
    Log.info(
      '🎵 initialSound: ${initialSound?.id ?? 'null'}',
      name: 'VideoRecorderScreen',
      category: LogCategory.video,
    );
    _triggerWaveformExtraction(bloc, initialSound);

    // Listen for future changes using listenManual (works outside build phase)
    _soundSubscription = ref.listenManual<AudioEvent?>(
      videoEditorProvider.select((s) => s.selectedSound),
      (previous, next) {
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
      _overlayVisibilityNotifier?.setPageOpen(false);
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
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: VideoEditorConstants.uiOverlayStyle,
          child: Scaffold(
            backgroundColor: VineTheme.backgroundCamera,
            resizeToAvoidBottomInset: false,
            body: Column(
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: switch (ref
                        .watch(videoRecorderProvider)
                        .recorderMode) {
                      .capture => VideoRecorderCaptureStack(
                        fromEditor: widget.fromEditor,
                      ),
                      .classic => const VideoRecorderClassicStack(),
                    },
                  ),
                ),

                if (!widget.fromEditor)
                  const Padding(
                    padding: .symmetric(vertical: 22),
                    child: VideoRecorderBottomBar(),
                  )
                else
                  SizedBox(height: MediaQuery.viewPaddingOf(context).bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
