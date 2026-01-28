// ABOUTME: Video recorder screen with modern UI design
// ABOUTME: Features top search bar, camera preview with grid, and bottom controls

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_recorder_provider.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/utils/video_controller_cleanup.dart';
import 'package:openvine/widgets/video_clip_editor/sheets/video_editor_restore_autosave_sheet.dart';
import 'package:openvine/widgets/video_recorder/preview/video_recorder_camera_preview.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_bottom_bar.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_countdown_overlay.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_record_button.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_segment_bar.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_top_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initializeCamera();
      _checkAutosavedChanges();
    });
    Log.info('📹 Initialized', name: 'VideoRecorderScreen', category: .video);
  }

  /// Initialize camera and handle permission failures
  Future<void> _initializeCamera() async {
    _disposeVideoControllers();

    _notifier = ref.read(videoRecorderProvider.notifier);
    await _notifier!.initialize(context: context);
  }

  Future<void> _checkAutosavedChanges() async {
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
      category: .video,
    );

    final prefs = await SharedPreferences.getInstance();
    final draftService = DraftStorageService(prefs);
    final draft = await draftService.getDraftById(
      VideoEditorConstants.autoSaveId,
    );
    if (draft != null && draft.clips.isNotEmpty) {
      Log.info(
        '📹 Found autosaved draft with ${draft.clips.length} clip(s)',
        name: 'VideoRecorderScreen',
        category: .video,
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
        '📹 No autosaved draft found',
        name: 'VideoRecorderScreen',
        category: .video,
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

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    await ref
        .read(videoRecorderProvider.notifier)
        .handleAppLifecycleState(state);
  }

  @override
  Future<void> dispose() async {
    unawaited(_notifier?.destroy());

    WidgetsBinding.instance.removeObserver(this);

    super.dispose();

    Log.info('📹 Disposed', name: 'VideoRecorderScreen', category: .video);
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFF000A06);

    return const AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: backgroundColor,
        statusBarIconBrightness: .light,
        statusBarBrightness: .dark,
      ),
      child: Scaffold(
        backgroundColor: backgroundColor,
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
    );
  }
}
