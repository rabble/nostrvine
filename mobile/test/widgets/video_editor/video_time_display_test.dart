// ABOUTME: Tests for VideoTimeDisplay widget
// ABOUTME: Validates time formatting and display structure

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_editor/video_time_display.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoTimeDisplay Widget Tests', () {
    Widget buildTestWidget({
      bool isPlaying = false,
      Duration currentPosition = Duration.zero,
      Duration totalDuration = const Duration(seconds: 30),
    }) {
      return ProviderScope(
        overrides: [
          videoEditorProvider.overrideWith(
            () => TestVideoEditorNotifier(
              VideoEditorProviderState(
                isPlaying: isPlaying,
                currentPosition: currentPosition,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: VideoTimeDisplay(
              isPlayingSelector: videoEditorProvider.select((s) => s.isPlaying),
              currentPositionSelector: videoEditorProvider.select(
                (s) => s.currentPosition,
              ),
              totalDuration: totalDuration,
            ),
          ),
        ),
      );
    }

    testWidgets('displays time with separator and total duration', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(totalDuration: const Duration(seconds: 30)),
      );
      await tester.pump();

      // Widget should render
      expect(find.byType(VideoTimeDisplay), findsOneWidget);

      // Should contain separator and total duration
      expect(find.textContaining('/'), findsOneWidget);
      expect(find.textContaining('30.00s'), findsOneWidget);
    });

    testWidgets('displays different total duration correctly', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          totalDuration: const Duration(seconds: 75, milliseconds: 500),
        ),
      );
      await tester.pump();

      expect(find.textContaining('75.50s'), findsOneWidget);
    });
  });
}

class TestVideoEditorNotifier extends VideoEditorNotifier {
  TestVideoEditorNotifier(this._state);
  final VideoEditorProviderState _state;

  @override
  VideoEditorProviderState build() => _state;
}
