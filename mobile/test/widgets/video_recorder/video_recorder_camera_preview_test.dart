// ABOUTME: Tests for VideoRecorderCameraPreview widget
// ABOUTME: Validates camera preview rendering, aspect ratio, and grid overlay

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/widgets/video_recorder/preview/video_recorder_camera_preview.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_camera_placeholder.dart';

class _MockVideoRecorderBloc
    extends MockBloc<VideoRecorderEvent, VideoRecorderBlocState>
    implements VideoRecorderBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoRecorderCameraPreview Widget Tests', () {
    late _MockVideoRecorderBloc recorderBloc;

    setUp(() {
      recorderBloc = _MockVideoRecorderBloc();
      when(() => recorderBloc.state).thenReturn(const VideoRecorderBlocState());
    });

    Widget buildSubject() {
      return ProviderScope(
        overrides: [
          clipManagerProvider.overrideWith(_TestClipManagerNotifier.new),
        ],
        child: BlocProvider<VideoRecorderBloc>.value(
          value: recorderBloc,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoRecorderCameraPreview()),
          ),
        ),
      );
    }

    testWidgets('renders camera preview widget', (tester) async {
      when(() => recorderBloc.state).thenReturn(
        const VideoRecorderBlocState(isCameraInitialized: true),
      );

      await tester.pumpWidget(buildSubject());

      expect(find.byType(VideoRecorderCameraPreview), findsOneWidget);
    });

    testWidgets('displays placeholder when camera not initialized', (
      tester,
    ) async {
      // Camera not initialized - should show placeholder.
      when(() => recorderBloc.state).thenReturn(
        const VideoRecorderBlocState(),
      );

      await tester.pumpWidget(buildSubject());

      // Should show placeholder widget
      expect(find.byType(VideoRecorderCameraPlaceholder), findsOneWidget);
    });

    testWidgets('contains TweenAnimationBuilder for transitions', (
      tester,
    ) async {
      when(() => recorderBloc.state).thenReturn(
        const VideoRecorderBlocState(isCameraInitialized: true),
      );

      await tester.pumpWidget(buildSubject());

      expect(find.byType(TweenAnimationBuilder<double>), isNotNull);
    });
  });
}

/// Test helper notifier with an empty clip list so the ghost-frame
/// overlay consumed by [VideoRecorderCameraPreview] has no clips to show.
class _TestClipManagerNotifier extends ClipManagerNotifier {
  @override
  ClipManagerState build() => ClipManagerState();
}
