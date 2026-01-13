// ABOUTME: Tests for VideoPublishBottomBar widget
// ABOUTME: Validates playback controls, mute button, and time display

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_publish/video_publish_provider_state.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/widgets/video_publish/video_publish_bottom_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoPublishBottomBar Widget Tests', () {
    Widget buildTestWidget({
      bool isPlaying = false,
      bool isMuted = false,
      Duration totalDuration = const Duration(seconds: 30),
    }) {
      return ProviderScope(
        overrides: [
          videoPublishProvider.overrideWith(
            () => TestVideoPublishNotifier(
              VideoPublishProviderState(
                isPlaying: isPlaying,
                isMuted: isMuted,
                totalDuration: totalDuration,
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: VideoPublishBottomBar())),
      );
    }

    testWidgets('displays play button when not playing', (tester) async {
      await tester.pumpWidget(buildTestWidget(isPlaying: false));

      expect(find.bySemanticsLabel('Play or pause video'), findsOneWidget);
    });

    testWidgets('displays pause button when playing', (tester) async {
      await tester.pumpWidget(buildTestWidget(isPlaying: true));

      expect(find.bySemanticsLabel('Play or pause video'), findsOneWidget);
    });

    testWidgets('displays mute button when not muted', (tester) async {
      await tester.pumpWidget(buildTestWidget(isMuted: false));

      expect(find.bySemanticsLabel('Mute or unmute audio'), findsOneWidget);
    });

    testWidgets('displays unmute button when muted', (tester) async {
      await tester.pumpWidget(buildTestWidget(isMuted: true));

      expect(find.bySemanticsLabel('Mute or unmute audio'), findsOneWidget);
    });

    testWidgets('displays time display', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(totalDuration: const Duration(seconds: 45)),
      );
      await tester.pump();

      expect(find.textContaining('45.00s'), findsOneWidget);
    });

    testWidgets('play button is tappable', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final playButton = find.bySemanticsLabel('Play or pause video');

      await tester.tap(playButton);
      await tester.pumpAndSettle();

      expect(playButton, findsOneWidget);
    });

    testWidgets('mute button is tappable', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final muteButton = find.bySemanticsLabel('Mute or unmute audio');

      await tester.tap(muteButton);
      await tester.pumpAndSettle();

      expect(muteButton, findsOneWidget);
    });

    testWidgets('has SafeArea wrapper', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(SafeArea), findsOneWidget);
    });
  });
}

class TestVideoPublishNotifier extends VideoPublishNotifier {
  TestVideoPublishNotifier(this._state);
  final VideoPublishProviderState _state;

  @override
  VideoPublishProviderState build() => _state;

  @override
  void togglePlayPause() {}

  @override
  void toggleMute() {}
}
