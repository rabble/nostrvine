// ABOUTME: Widget tests for VideoDescriptionOverlay's loop-count visibility gate.
// ABOUTME: Pins the behavior that drove the profile-feed "0 loops" regression.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/widgets/video_feed_item/actions/video_description_overlay.dart';

VideoEvent _video({
  int? originalLoops,
  Map<String, String> rawTags = const {},
  String content = 'caption',
}) {
  return VideoEvent(
    id: 'a' * 64,
    pubkey: 'b' * 64,
    createdAt: 1704067200,
    content: content,
    timestamp: DateTime.fromMillisecondsSinceEpoch(
      1704067200 * 1000,
      isUtc: true,
    ),
    originalLoops: originalLoops,
    rawTags: rawTags,
  );
}

Future<void> _pump(WidgetTester tester, VideoEvent video) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: VideoDescriptionOverlay(video: video)),
    ),
  );
}

void main() {
  group(VideoDescriptionOverlay, () {
    group('loop count visibility', () {
      testWidgets(
        'renders "N loops" when originalLoops is null but rawTags[views] is set',
        (tester) async {
          // This is the profile-feed regression case: a fresh diVine upload
          // has originalLoops=null in REST but a non-zero ClickHouse views
          // count. The old gate (originalLoops != null && > 0) hid the
          // count here, re-introducing the "0 loops" symptom in this widget.
          await _pump(tester, _video(rawTags: const {'views': '34'}));

          expect(find.text('🔁 34 loops'), findsOneWidget);
        },
      );

      testWidgets(
        'renders combined count when originalLoops and views are both set',
        (tester) async {
          await _pump(
            tester,
            _video(originalLoops: 6, rawTags: const {'views': '34'}),
          );

          expect(find.text('🔁 40 loops'), findsOneWidget);
        },
      );

      testWidgets(
        'renders archive count when only originalLoops is set (classic Vine)',
        (tester) async {
          await _pump(tester, _video(originalLoops: 13565));

          // Don't pin the compact format — count_formatter handles rounding.
          // Just assert the "loops" row is rendered with the emoji prefix.
          expect(
            find.byWidgetPredicate(
              (w) =>
                  w is Text &&
                  (w.data?.startsWith('🔁 ') ?? false) &&
                  (w.data?.endsWith(' loops') ?? false),
            ),
            findsOneWidget,
          );
        },
      );

      testWidgets('hides the row when no loop metadata is present', (
        tester,
      ) async {
        await _pump(tester, _video());

        expect(find.textContaining('loops'), findsNothing);
      });

      testWidgets(
        'hides the row when totalLoops is 0 even with metadata present',
        (tester) async {
          // originalLoops=0 is metadata (non-null), but "0 loops" would be
          // a worse UI than hiding the row entirely.
          await _pump(tester, _video(originalLoops: 0));

          expect(find.textContaining('loops'), findsNothing);
        },
      );
    });
  });
}
