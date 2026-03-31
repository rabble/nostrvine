import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/widgets/web_video_player.dart';
import 'package:video_player/video_player.dart';

class _MockVideoPlayerController extends Mock
    implements VideoPlayerController {}

void main() {
  testWidgets('shows an error state when web video initialization times out', (
    tester,
  ) async {
    final controller = _MockVideoPlayerController();
    final initializeCompleter = Completer<void>();

    when(controller.initialize).thenAnswer((_) => initializeCompleter.future);
    when(controller.dispose).thenAnswer((_) async {});

    await tester.pumpWidget(
      MaterialApp(
        home: WebVideoPlayer(
          url: 'https://example.com/video.mp4',
          initializeTimeout: const Duration(milliseconds: 50),
          controllerFactory: ({required url, required headers}) => controller,
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 60));

    expect(find.text('Failed to load video'), findsOneWidget);
  });
}
