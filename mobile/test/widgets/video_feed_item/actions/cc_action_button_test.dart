// ABOUTME: Tests for CcActionButton widget.
// ABOUTME: Verifies rendering, visibility toggle, and active state display.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/widgets/video_feed_item/actions/cc_action_button.dart';

void main() {
  const testPubkey =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  late VideoEvent videoWithSubtitles;
  late VideoEvent videoWithoutSubtitles;

  setUp(() {
    videoWithSubtitles = VideoEvent(
      id: 'video-with-subs-0123456789abcdef0123456789abcdef0123456789abcdef',
      pubkey: testPubkey,
      createdAt: 1757385263,
      content: '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
      textTrackRef: '39307:$testPubkey:subtitles:test-vine-id',
    );

    videoWithoutSubtitles = VideoEvent(
      id: 'video-no-subs-0123456789abcdef0123456789abcdef0123456789abcdef01',
      pubkey: testPubkey,
      createdAt: 1757385263,
      content: '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
    );
  });

  Widget buildSubject({required VideoEvent video}) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(body: CcActionButton(video: video)),
      ),
    );
  }

  group(CcActionButton, () {
    testWidgets('renders nothing when video has no subtitles', (tester) async {
      await tester.pumpWidget(buildSubject(video: videoWithoutSubtitles));

      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.byIcon(Icons.closed_caption), findsNothing);
    });

    testWidgets('renders CC icon when video has subtitles', (tester) async {
      await tester.pumpWidget(buildSubject(video: videoWithSubtitles));

      expect(find.byIcon(Icons.closed_caption), findsOneWidget);
    });

    testWidgets('shows white icon when subtitles are hidden', (tester) async {
      await tester.pumpWidget(buildSubject(video: videoWithSubtitles));

      final icon = tester.widget<Icon>(find.byIcon(Icons.closed_caption));
      expect(icon.color, equals(Colors.white));
    });

    testWidgets('shows green icon after toggling subtitles on', (tester) async {
      await tester.pumpWidget(buildSubject(video: videoWithSubtitles));

      // Tap to toggle on
      await tester.tap(find.byIcon(Icons.closed_caption));
      await tester.pump();

      final icon = tester.widget<Icon>(find.byIcon(Icons.closed_caption));
      expect(icon.color, equals(VineTheme.vineGreen));
    });

    testWidgets('toggles back to white after two taps', (tester) async {
      await tester.pumpWidget(buildSubject(video: videoWithSubtitles));

      // Tap twice: on then off
      await tester.tap(find.byIcon(Icons.closed_caption));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.closed_caption));
      await tester.pump();

      final icon = tester.widget<Icon>(find.byIcon(Icons.closed_caption));
      expect(icon.color, equals(Colors.white));
    });

    testWidgets('has correct semantics label when hidden', (tester) async {
      await tester.pumpWidget(buildSubject(video: videoWithSubtitles));

      final semantics = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.identifier == 'cc_button',
        ),
      );
      expect(semantics.properties.label, equals('Show subtitles'));
    });

    testWidgets('has correct semantics label when visible', (tester) async {
      await tester.pumpWidget(buildSubject(video: videoWithSubtitles));

      // Toggle on
      await tester.tap(find.byIcon(Icons.closed_caption));
      await tester.pump();

      final semantics = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.identifier == 'cc_button',
        ),
      );
      expect(semantics.properties.label, equals('Hide subtitles'));
    });
  });
}
