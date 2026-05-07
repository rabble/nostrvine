import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/comments/widgets/video_comment_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  testWidgets('opens the full video page from the inline comment player', (
    tester,
  ) async {
    var opened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VideoCommentPlayer(
            videoUrl: 'https://media.divine.video/comment-video.mp4',
            onOpenVideo: () => opened = true,
          ),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('Open video comment'));
    await tester.pump();

    expect(opened, isTrue);
  });
}
