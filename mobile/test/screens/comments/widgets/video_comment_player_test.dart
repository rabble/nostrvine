import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/comments/widgets/video_comment_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  testWidgets('clips to the provided border radius', (tester) async {
    const borderRadius = BorderRadius.all(Radius.circular(12));

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: VideoCommentPlayer(
            videoUrl: 'https://media.divine.video/comment-video.mp4',
            borderRadius: borderRadius,
          ),
        ),
      ),
    );

    final clip = tester.widget<ClipRRect>(
      find.ancestor(
        of: find.byType(VisibilityDetector),
        matching: find.byType(ClipRRect),
      ),
    );
    expect(clip.borderRadius, borderRadius);
  });

  testWidgets('opens the full video page from the inline comment player', (
    tester,
  ) async {
    var opened = false;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: VideoCommentPlayer(
            videoUrl: 'https://media.divine.video/comment-video.mp4',
            onOpenVideo: () => opened = true,
          ),
        ),
      ),
    );

    expect(find.byType(VideoCommentPlayer), findsOneWidget);
    await tester.tap(find.byType(DivineIconButton));
    await tester.pump();

    expect(opened, isTrue);
  });
}
