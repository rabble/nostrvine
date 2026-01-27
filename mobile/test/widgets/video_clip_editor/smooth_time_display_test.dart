// ABOUTME: Tests for SmoothTimeDisplay widget
// ABOUTME: Validates time display formatting and styling

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_clip_editor/smooth_time_display.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SmoothTimeDisplay Widget Tests', () {
    Widget buildTestWidget({
      bool isPlaying = false,
      Duration currentPosition = Duration.zero,
      TextStyle? style,
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
            body: SmoothTimeDisplay(
              isPlayingSelector: videoEditorProvider.select((s) => s.isPlaying),
              currentPositionSelector: videoEditorProvider.select(
                (s) => s.currentPosition,
              ),
              style: style,
            ),
          ),
        ),
      );
    }

    testWidgets('displays formatted time at zero position', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('0.00'), findsOneWidget);
    });

    testWidgets('displays formatted time at specific position', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(currentPosition: const Duration(seconds: 5)),
      );
      await tester.pump();

      expect(find.text('5.00'), findsOneWidget);
    });

    testWidgets('displays different time at different position', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          currentPosition: const Duration(seconds: 12, milliseconds: 500),
        ),
      );
      await tester.pump();

      expect(find.text('12.50'), findsOneWidget);
    });
  });
}

class TestVideoEditorNotifier extends VideoEditorNotifier {
  TestVideoEditorNotifier(this._state);
  final VideoEditorProviderState _state;

  @override
  VideoEditorProviderState build() => _state;
}
