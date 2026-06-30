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
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/mixins/codec_heavy_surface_guard.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/utils/video_controller_cleanup.dart';
import 'package:openvine/widgets/camera_permission_gate.dart';
import 'package:openvine/widgets/video_recorder/modes/capture/video_recorder_capture_stack.dart';
import 'package:openvine/widgets/video_recorder/modes/classic/video_recorder_classic_stack.dart';
import 'package:openvine/widgets/video_recorder/modes/lip_sync/video_recorder_lip_sync_stack.dart';
import 'package:openvine/widgets/video_recorder/modes/upload/video_recorder_upload_stack.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_bottom_bar.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_navigation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

const _kWhySixSecondsShownKey = 'why_six_seconds_shown';

/// Route shell for the standalone recorder flow.
///
/// The permission gate renders recorder chrome while permissions are pending,
/// so the [VideoRecorderBloc] must sit above both the gate and recorder view.
class VideoRecorderRoute extends ConsumerWidget {
  const VideoRecorderRoute({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _VideoRecorderBlocScope(
      child: CameraPermissionGate(child: VideoRecorderView()),
    );
  }
}

/// Video recorder screen with camera preview and recording controls.
///
/// Owns the [VideoRecorderBloc]: it bridges the sibling Riverpod
/// dependencies the bloc reads (clip manager, video editor, shared
/// preferences) and re-keys the [BlocProvider] on their identity so a
/// runtime dependency swap rebuilds the bloc with fresh wiring (see
/// `state_management.md`).
class VideoRecorderScreen extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    return _VideoRecorderBlocScope(
      child: VideoRecorderView(fromEditor: fromEditor),
    );
  }
}

class _VideoRecorderBlocScope extends ConsumerWidget {
  const _VideoRecorderBlocScope({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clipManager = ref.watch(clipManagerProvider.notifier);
    final videoEditor = ref.watch(videoEditorProvider.notifier);
    final sharedPreferences = ref.watch(sharedPreferencesProvider);

    return BlocProvider<VideoRecorderBloc>(
      key: ValueKey((clipManager, videoEditor, sharedPreferences)),
      create: (_) => VideoRecorderBloc(
        readClipManager: () => ref.read(clipManagerProvider.notifier),
        readVideoEditor: () => ref.read(videoEditorProvider.notifier),
        readVideoEditorState: () => ref.read(videoEditorProvider),
        readSharedPreferences: () => ref.read(sharedPreferencesProvider),
      ),
      child: child,
    );
  }
}

/// The recorder UI under the [BlocProvider]. Public for widget tests, which
/// pump it directly with a mock [VideoRecorderBloc].
@visibleForTesting
class VideoRecorderView extends ConsumerStatefulWidget {
  const VideoRecorderView({super.key, this.fromEditor = false});

  /// Whether the screen is opened from the video editor.
  final bool fromEditor;

  @override
  ConsumerState<VideoRecorderView> createState() => _VideoRecorderViewState();
}

class _VideoRecorderViewState extends ConsumerState<VideoRecorderView>
    with WidgetsBindingObserver, CodecHeavySurfaceGuard {
  ProviderSubscription<AudioEvent?>? _soundSubscription;
  OverlayVisibility? _overlayVisibilityNotifier;
  VideoRecorderMode? _lastRecorderMode;

  bool get _isAutosavedDraft => ref.read(videoEditorProvider).isAutosavedDraft;

  @override
  void initState() {
    super.initState();

    _lastRecorderMode = context.read<VideoRecorderBloc>().state.recorderMode;

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

  /// Initialize camera and free background video resources.
  void _initializeCamera() {
    Log.info(
      '📹 _initializeCamera called',
      name: 'VideoRecorderScreen',
      category: LogCategory.video,
    );

    _disposeVideoControllers();

    context.read<VideoRecorderBloc>().add(
      VideoRecorderInitializeRequested(fromEditor: widget.fromEditor),
    );
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

          // Match the restored clips' aspect ratio so the user can't mix
          // ratios on subsequent recordings. The legacy restoreDraft set this
          // on the recorder directly; with the bloc the View owns the
          // cross-feature dispatch.
          final clips = ref.read(clipManagerProvider).clips;
          if (clips.isNotEmpty) {
            context.read<VideoRecorderBloc>().add(
              VideoRecorderAspectRatioSet(clips.first.targetAspectRatio),
            );
          }

          await openVideoEditorFromRecorder(context, ref);
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

    final event = SoundWaveformExtract.forSound(sound);
    if (event != null) {
      bloc.add(event);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    context.read<VideoRecorderBloc>().add(
      VideoRecorderAppLifecycleChanged(state),
    );
  }

  @override
  void dispose() {
    try {
      _overlayVisibilityNotifier?.setPageOpen(false);
    } catch (e) {
      Log.warning(
        '📹 Failed to clear overlay visibility on dispose: $e',
        name: 'VideoRecorderScreen',
        category: .video,
      );
    }
    _soundSubscription?.close();

    WidgetsBinding.instance.removeObserver(this);

    super.dispose();

    Log.info('📹 Disposed', name: 'VideoRecorderScreen', category: .video);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SoundWaveformBloc>(
      // Eager: the create factory installs the selected-sound listener that
      // drives waveform extraction. The only consumer (the lip-sync audio
      // progress bar) mounts during recording, but extraction must already be
      // running when the user picks a sound beforehand so the waveform is
      // ready by the time recording starts.
      lazy: false,
      create: (context) {
        final bloc = SoundWaveformBloc();
        _setupSoundWaveformListener(bloc);

        return bloc;
      },
      // Release the camera while the Upload tab's static explainer is showing,
      // and re-initialize it when the user returns to a recording mode. Reuses
      // the recorder's existing pause/resume lifecycle plumbing so we don't
      // burn battery or trigger the OS recording indicator on a tab with no
      // preview.
      child: BlocListener<VideoRecorderBloc, VideoRecorderBlocState>(
        listenWhen: (previous, current) =>
            previous.recorderMode != current.recorderMode,
        listener: (context, state) {
          final previous = _lastRecorderMode;
          _lastRecorderMode = state.recorderMode;
          if (state.recorderMode == VideoRecorderMode.upload) {
            context.read<VideoRecorderBloc>().add(
              const VideoRecorderAppLifecycleChanged(AppLifecycleState.paused),
            );
          } else if (previous == VideoRecorderMode.upload) {
            _initializeCamera();
          }
        },
        child: PopScope(
          onPopInvokedWithResult: (didPop, value) {
            if (didPop && !widget.fromEditor && !_isAutosavedDraft) {
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
                      child: switch (context.select(
                        (VideoRecorderBloc b) => b.state.recorderMode,
                      )) {
                        .upload => const VideoRecorderUploadStack(),
                        .capture => VideoRecorderCaptureStack(
                          fromEditor: widget.fromEditor,
                        ),
                        .lipSync => const VideoRecorderLipSyncStack(),
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
      ),
    );
  }
}
