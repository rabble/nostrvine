import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_publish/video_publish_provider_state.dart';
import 'package:openvine/models/video_publish/video_publish_state.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_upload_status.dart';

void main() {
  group('VideoMetadataUploadStatus', () {
    Widget buildTestWidget({
      VideoPublishState publishState = VideoPublishState.idle,
      String? errorMessage,
      double uploadProgress = 0.0,
    }) {
      return ProviderScope(
        overrides: [
          videoPublishProvider.overrideWith(
            () => _TestVideoPublishNotifier(
              VideoPublishProviderState(
                publishState: publishState,
                errorMessage: errorMessage,
                uploadProgress: uploadProgress,
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: VideoMetadataUploadStatus()),
        ),
      );
    }

    testWidgets('hides content when state is idle', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Should render SizedBox.shrink (no status message visible)
      expect(find.text('Initializing...'), findsNothing);
      expect(find.text('Preparing video...'), findsNothing);
    });

    testWidgets('shows initializing message for initialize state', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(publishState: VideoPublishState.initialize),
      );

      expect(find.text('Initializing...'), findsOneWidget);
    });

    testWidgets('shows preparing message for preparing state', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(publishState: VideoPublishState.preparing),
      );

      expect(find.text('Preparing video...'), findsOneWidget);
    });

    testWidgets('shows retry message for retryUpload state', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(publishState: VideoPublishState.retryUpload),
      );

      expect(find.text('Retrying upload...'), findsOneWidget);
    });

    testWidgets('shows publishing message for publishToNostr state', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(publishState: VideoPublishState.publishToNostr),
      );

      expect(find.text('Publishing to Nostr...'), findsOneWidget);
    });

    testWidgets('shows completed message for completed state', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(publishState: VideoPublishState.completed),
      );

      expect(find.text('Published!'), findsOneWidget);
    });

    testWidgets('shows error message and dismiss button for error state', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          publishState: VideoPublishState.error,
          errorMessage: 'Network error occurred',
        ),
      );

      expect(find.text('Network error occurred'), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);
    });

    testWidgets('shows default error message when errorMessage is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(publishState: VideoPublishState.error),
      );

      expect(find.text('Upload failed'), findsOneWidget);
    });

    testWidgets('does not show dismiss button for non-error states', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(publishState: VideoPublishState.uploading),
      );

      expect(find.text('Dismiss'), findsNothing);
    });

    testWidgets('contains AnimatedOpacity for transitions', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(publishState: VideoPublishState.uploading),
      );

      expect(find.byType(AnimatedOpacity), findsOneWidget);
    });
  });
}

class _TestVideoPublishNotifier extends VideoPublishNotifier {
  _TestVideoPublishNotifier(this._state);
  final VideoPublishProviderState _state;

  @override
  VideoPublishProviderState build() => _state;

  @override
  void clearError() {
    // No-op for testing
  }
}
