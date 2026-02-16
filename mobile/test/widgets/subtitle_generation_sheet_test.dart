// ABOUTME: Tests for SubtitleGenerationSheet widget.
// ABOUTME: Verifies progress stages, success/error states, and retry.
//
// NOTE: Tests temporarily disabled due to Android build issues
// with whisper_ggml_plus v1.3.1. See: https://github.com/divinevideo/divine-mobile/issues/1568

// import 'dart:async';

// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// import 'package:mocktail/mocktail.dart';
// import 'package:models/models.dart';
// import 'package:openvine/providers/subtitle_providers.dart';
// import 'package:openvine/services/subtitle_generation_service.dart';
// import 'package:openvine/widgets/subtitle_generation_sheet.dart';

// class _MockSubtitleGenerationService extends Mock
//     implements SubtitleGenerationService {}

void main() {
  test(
    'Subtitle generation sheet tests temporarily disabled',
    () {},
    skip: 'See: https://github.com/divinevideo/divine-mobile/issues/1568',
  );
}

/*
  const testPubkey =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  late _MockSubtitleGenerationService mockService;
  late VideoEvent testVideo;

  setUpAll(() {
    registerFallbackValue(
      VideoEvent(
        id: 'fallback-id-abcdef0123456789abcdef0123456789abcdef0123456789abcd',
        pubkey: testPubkey,
        createdAt: 0,
        content: '',
        timestamp: DateTime.fromMillisecondsSinceEpoch(0),
      ),
    );
  });

  setUp(() {
    mockService = _MockSubtitleGenerationService();
    testVideo = VideoEvent(
      id: 'test-event-id-0123456789abcdef0123456789abcdef0123456789abcdef01234',
      pubkey: testPubkey,
      createdAt: 1757385263,
      content: '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
      vineId: 'test-vine-id',
      title: 'Test Video',
    );
  });

  Widget buildSubject() {
    return ProviderScope(
      overrides: [
        subtitleGenerationServiceProvider.overrideWithValue(mockService),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SubtitleGenerationSheet(
            video: testVideo,
            videoFilePath: '/path/to/video.mp4',
          ),
        ),
      ),
    );
  }

  group(SubtitleGenerationSheet, () {
    testWidgets('shows progress indicator during generation', (tester) async {
      final completer = Completer<void>();
      when(
        () => mockService.generateAndPublish(
          video: any(named: 'video'),
          videoFilePath: any(named: 'videoFilePath'),
          onStage: any(named: 'onStage'),
        ),
      ).thenAnswer((_) => completer.future);

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete to avoid pending timer
      completer.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('shows success state with Done button when complete', (
      tester,
    ) async {
      when(
        () => mockService.generateAndPublish(
          video: any(named: 'video'),
          videoFilePath: any(named: 'videoFilePath'),
          onStage: any(named: 'onStage'),
        ),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Subtitles generated!'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('shows error state with Retry button on failure', (
      tester,
    ) async {
      when(
        () => mockService.generateAndPublish(
          video: any(named: 'video'),
          videoFilePath: any(named: 'videoFilePath'),
          onStage: any(named: 'onStage'),
        ),
      ).thenThrow(SubtitleGenerationException('No speech detected'));

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('No speech detected'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('retry restarts generation', (tester) async {
      var callCount = 0;
      when(
        () => mockService.generateAndPublish(
          video: any(named: 'video'),
          videoFilePath: any(named: 'videoFilePath'),
          onStage: any(named: 'onStage'),
        ),
      ).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) {
          throw SubtitleGenerationException('No speech detected');
        }
        // Second call succeeds
      });

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // First attempt failed
      expect(find.text('No speech detected'), findsOneWidget);

      // Tap retry
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      // Second attempt succeeded
      expect(find.text('Subtitles generated!'), findsOneWidget);
    });

    testWidgets('shows Starting... text initially', (tester) async {
      final completer = Completer<void>();
      when(
        () => mockService.generateAndPublish(
          video: any(named: 'video'),
          videoFilePath: any(named: 'videoFilePath'),
          onStage: any(named: 'onStage'),
        ),
      ).thenAnswer((_) => completer.future);

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.text('Starting...'), findsOneWidget);

      // Complete to avoid pending timer
      completer.complete();
      await tester.pumpAndSettle();
    });

    testWidgets(
      'shows generic error message for non-SubtitleGenerationException',
      (tester) async {
        when(
          () => mockService.generateAndPublish(
            video: any(named: 'video'),
            videoFilePath: any(named: 'videoFilePath'),
            onStage: any(named: 'onStage'),
          ),
        ).thenThrow(Exception('unexpected'));

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        expect(find.text('Something went wrong'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
      },
    );
  });
}
*/
