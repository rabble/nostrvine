import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/widgets/video_feed_item/subtitle_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

VideoEvent _makeVideo() => VideoEvent(
  id: 'a1b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234',
  pubkey: 'd4e5f6789012345678901234567890abcdef123456789012345678901234a1b2c3',
  createdAt: 1700000000,
  content: 'Test video',
  timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
  videoUrl: 'https://example.com/video.mp4',
  textTrackContent: '''
WEBVTT

1
00:00:00.100 --> 00:00:01.000
Hello there

2
00:00:01.100 --> 00:00:02.000
Second line
''',
);

void main() {
  testWidgets('does not rebuild the caption pill for ticks within one cue', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final positions = StreamController<Duration>.broadcast();
    addTearDown(positions.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SubtitleCueStreamPill(
                video: _makeVideo(),
                positionStream: positions.stream,
                initialPosition: const Duration(milliseconds: 300),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Hello there'), findsOneWidget);
    final initialTextWidget = tester.widget<Text>(find.text('Hello there'));

    positions.add(const Duration(milliseconds: 500));
    await tester.pump();
    await tester.pump();

    expect(find.text('Hello there'), findsOneWidget);
    expect(
      identical(
        initialTextWidget,
        tester.widget<Text>(find.text('Hello there')),
      ),
      isTrue,
    );

    positions.add(const Duration(milliseconds: 1200));
    await tester.pump();
    await tester.pump();

    expect(find.text('Second line'), findsOneWidget);
  });
}
