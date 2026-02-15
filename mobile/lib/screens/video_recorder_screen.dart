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

    final draftService = DraftStorageService();
    final draft = await draftService.getDraftById(
      VideoEditorConstants.autoSaveId,
    );
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: backgroundColor,
        statusBarIconBrightness: .light,
        statusBarBrightness: .dark,
      ),
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: Stack(
          fit: .expand,
          children: [
            const Column(
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
            const VideoRecorderCountdownOverlay(),

            // TEST: Lens selector (temporary)
            const Positioned(
              bottom: 180,
              left: 0,
              right: 0,
              child: _LensSelectorTest(),
            ),
          ],
        ),
      ),
    );
  }
}

/// TEST WIDGET: Temporary lens selector for testing multi-lens support.
/// Remove this widget once proper UI is implemented.
class _LensSelectorTest extends ConsumerWidget {
  const _LensSelectorTest();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the provider to rebuild on state changes
    ref.watch(videoRecorderProvider);

    final notifier = ref.read(videoRecorderProvider.notifier);
    final availableLenses = notifier.availableLenses;
    final currentLens = notifier.currentLens;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: availableLenses.map((lens) {
            final isSelected = lens == currentLens;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () => notifier.setLens(lens),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white
                        : Colors.black.withAlpha(150),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.white38,
                    ),
                  ),
                  child: Text(
                    lens.shortLabel,
                    style: TextStyle(
                      color: isSelected ? Colors.black : Colors.white,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
