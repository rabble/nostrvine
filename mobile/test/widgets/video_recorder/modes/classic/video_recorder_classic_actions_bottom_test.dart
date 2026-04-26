import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/video_recorder/video_recorder_provider_state.dart';
import 'package:openvine/models/video_recorder/video_recorder_state.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_recorder_provider.dart';
import 'package:openvine/widgets/video_recorder/modes/classic/video_recorder_classic_actions_bottom.dart';

import '../../../../mocks/mock_camera_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(VideoRecorderClassicActionsBottom, () {
    late MockCameraService mockCamera;

    setUp(() async {
      mockCamera = MockCameraService.create(
        onUpdateState: ({forceCameraRebuild}) {},
        onAutoStopped: (_) {},
      );
      await mockCamera.initialize();
    });

    Widget buildWidget({
      VideoRecorderState recordingState = VideoRecorderState.idle,
    }) {
      return ProviderScope(
        overrides: [
          videoRecorderProvider.overrideWith(
            () => _TestVideoRecorderNotifier(
              mockCamera,
              recordingState: recordingState,
            ),
          ),
          clipManagerProvider.overrideWith(_TestClipManagerNotifier.new),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: VideoRecorderClassicActionsBottom()),
        ),
      );
    }

    group('renders', () {
      testWidgets('renders $VideoRecorderClassicActionsBottom', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(VideoRecorderClassicActionsBottom), findsOneWidget);
      });

      testWidgets('renders three action buttons', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(DivineIconButton), findsNWidgets(3));
      });
    });

    group('visibility', () {
      testWidgets('is fully opaque when not recording', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        final opacity = tester.widget<AnimatedOpacity>(
          find
              .ancestor(
                of: find.byType(Row),
                matching: find.byType(AnimatedOpacity),
              )
              .first,
        );
        expect(opacity.opacity, equals(1));
      });

      testWidgets('fades out when recording', (tester) async {
        await tester.pumpWidget(
          buildWidget(recordingState: VideoRecorderState.recording),
        );
        await tester.pumpAndSettle();

        final opacity = tester.widget<AnimatedOpacity>(
          find
              .ancestor(
                of: find.byType(Row),
                matching: find.byType(AnimatedOpacity),
              )
              .first,
        );
        expect(opacity.opacity, equals(0));
      });
    });

    group('interactions', () {
      testWidgets('shows snackbar when ghost frame is toggled', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        // The ghost button is the third DivineIconButton
        final ghostButtons = tester
            .widgetList<DivineIconButton>(find.byType(DivineIconButton))
            .toList();
        expect(ghostButtons.length, equals(3));

        // Tap the ghost button (third one)
        await tester.tap(find.byType(DivineIconButton).at(2));
        await tester.pump();

        // Should show snackbar
        expect(find.byType(SnackBar), findsOneWidget);
      });
    });
  });
}

class _TestVideoRecorderNotifier extends VideoRecorderNotifier {
  _TestVideoRecorderNotifier(
    super.cameraService, {
    this.recordingState = VideoRecorderState.idle,
  });

  final VideoRecorderState recordingState;

  @override
  VideoRecorderProviderState build() {
    return VideoRecorderProviderState(
      recordingState: recordingState,
      isCameraInitialized: true,
      canRecord: true,
    );
  }
}

class _TestClipManagerNotifier extends ClipManagerNotifier {
  @override
  ClipManagerState build() {
    return ClipManagerState();
  }
}
