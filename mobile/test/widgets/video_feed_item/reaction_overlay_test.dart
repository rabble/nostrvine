// ABOUTME: Widget test for the full-screen reaction overlay animation.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/video_feed_item/reaction_overlay.dart';

void main() {
  testWidgets('renders the emoji then fires onComplete', (tester) async {
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReactionOverlay(
            emoji: '❤️',
            onComplete: () => completed = true,
          ),
        ),
      ),
    );
    await tester.pump();

    // Hero glyph + the floating particles all render the emoji.
    expect(find.text('❤️'), findsWidgets);
    expect(completed, isFalse);

    // Past the 1100ms animation → completes and notifies.
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
  });

  testWidgets('does not absorb pointer events (IgnorePointer)', (tester) async {
    var tappedBehind = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => tappedBehind = true,
                child: const SizedBox.expand(),
              ),
              const ReactionOverlay(emoji: '🔥'),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tapAt(const Offset(10, 10));
    expect(tappedBehind, isTrue);
    // Let the animation finish so no timer leaks into teardown.
    await tester.pump(const Duration(milliseconds: 1200));
  });
}
