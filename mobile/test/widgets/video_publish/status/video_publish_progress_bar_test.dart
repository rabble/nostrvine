import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_publish/video_publish_provider_state.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/widgets/video_publish/status/video_publish_progress_bar.dart';

void main() {
  group('VideoPublishProgressBar', () {
    Widget buildTestWidget({double uploadProgress = 0.0}) {
      return ProviderScope(
        overrides: [
          videoPublishProvider.overrideWith(
            () => _TestVideoPublishNotifier(
              VideoPublishProviderState(uploadProgress: uploadProgress),
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: VideoPublishProgressBar()),
        ),
      );
    }

    testWidgets('displays correct percentage for progress value', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(uploadProgress: 0.5));

      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets('displays 0% for zero progress', (tester) async {
      await tester.pumpWidget(buildTestWidget(uploadProgress: 0));

      expect(find.text('0%'), findsOneWidget);
    });

    testWidgets('displays 100% for complete progress', (tester) async {
      await tester.pumpWidget(buildTestWidget(uploadProgress: 1));

      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('displays 25% for quarter progress', (tester) async {
      await tester.pumpWidget(buildTestWidget(uploadProgress: 0.25));

      expect(find.text('25%'), findsOneWidget);
    });

    testWidgets('displays 75% for three quarter progress', (tester) async {
      await tester.pumpWidget(buildTestWidget(uploadProgress: 0.75));

      expect(find.text('75%'), findsOneWidget);
    });

    testWidgets('contains LinearProgressIndicator', (tester) async {
      await tester.pumpWidget(buildTestWidget(uploadProgress: 0.5));

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });
}

class _TestVideoPublishNotifier extends VideoPublishNotifier {
  _TestVideoPublishNotifier(this._state);
  final VideoPublishProviderState _state;

  @override
  VideoPublishProviderState build() => _state;
}
