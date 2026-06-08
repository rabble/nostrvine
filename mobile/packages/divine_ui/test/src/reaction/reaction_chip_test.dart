// ABOUTME: Strict-coverage tests for ReactionChip variants.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(body: Center(child: child)),
      ),
    );
  }

  group(ReactionChip, () {
    testWidgets('renders emoji and count when count > 1', (tester) async {
      await pump(
        tester,
        const ReactionChip(
          emoji: '❤️',
          count: 3,
          variant: ReactionChipVariant.own,
        ),
      );
      expect(find.text('❤️'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('hides count when count == 1', (tester) async {
      await pump(
        tester,
        const ReactionChip(
          emoji: '🔥',
          count: 1,
          variant: ReactionChipVariant.theirs,
        ),
      );
      expect(find.text('🔥'), findsOneWidget);
      expect(find.text('1'), findsNothing);
    });

    testWidgets('shows retry icon for failed variant', (tester) async {
      await pump(
        tester,
        const ReactionChip(
          emoji: '😢',
          count: 1,
          variant: ReactionChipVariant.failed,
        ),
      );
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('does not show retry icon for non-failed variants', (
      tester,
    ) async {
      await pump(
        tester,
        const ReactionChip(
          emoji: '😮',
          count: 1,
          variant: ReactionChipVariant.pending,
        ),
      );
      expect(find.byIcon(Icons.refresh), findsNothing);
    });

    testWidgets('invokes onTap when tapped', (tester) async {
      var tapped = false;
      await pump(
        tester,
        ReactionChip(
          emoji: '👍',
          count: 2,
          variant: ReactionChipVariant.own,
          onTap: () => tapped = true,
        ),
      );
      await tester.tap(find.byType(ReactionChip));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('invokes onLongPress when long-pressed', (tester) async {
      var longPressed = false;
      await pump(
        tester,
        ReactionChip(
          emoji: '👍',
          count: 1,
          variant: ReactionChipVariant.failed,
          onLongPress: () => longPressed = true,
        ),
      );
      await tester.longPress(find.byType(ReactionChip));
      await tester.pumpAndSettle();
      expect(longPressed, isTrue);
    });

    testWidgets('semantic label is announced when provided', (tester) async {
      const label = 'Your reaction: heart';
      await pump(
        tester,
        const ReactionChip(
          emoji: '❤️',
          count: 1,
          variant: ReactionChipVariant.own,
          semanticLabel: label,
        ),
      );
      expect(
        tester.getSemantics(find.byType(ReactionChip)).label.contains(label),
        isTrue,
      );
    });

    testWidgets('pending variant renders at reduced opacity', (tester) async {
      await pump(
        tester,
        const ReactionChip(
          emoji: '😂',
          count: 1,
          variant: ReactionChipVariant.pending,
        ),
      );
      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, lessThan(1.0));
      expect(opacity.opacity, greaterThan(0.4));
    });

    testWidgets('own variant renders at full opacity', (tester) async {
      await pump(
        tester,
        const ReactionChip(
          emoji: '🔥',
          count: 1,
          variant: ReactionChipVariant.own,
        ),
      );
      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, closeTo(1.0, 0.001));
    });

    // The emoji is nudged right only on Apple platforms to cancel Apple
    // Color Emoji's left-side bearing; Noto (Android et al.) is symmetric
    // and must not be nudged, or the glyph drifts off-centre right (#4954).
    group('emoji horizontal nudge', () {
      final cases = <(TargetPlatform, double)>[
        (TargetPlatform.iOS, 2),
        (TargetPlatform.macOS, 2),
        (TargetPlatform.android, 0),
        (TargetPlatform.linux, 0),
      ];
      for (final (platform, expectedDx) in cases) {
        testWidgets('translates emoji by $expectedDx dp on $platform', (
          tester,
        ) async {
          debugDefaultTargetPlatformOverride = platform;
          try {
            await pump(
              tester,
              const ReactionChip(
                emoji: '🔥',
                count: 1,
                variant: ReactionChipVariant.theirs,
              ),
            );
            final transform = tester.widget<Transform>(
              find.descendant(
                of: find.byType(ReactionChip),
                matching: find.byType(Transform),
              ),
            );
            expect(transform.transform.storage[12], expectedDx);
          } finally {
            debugDefaultTargetPlatformOverride = null;
          }
        });
      }
    });
  });
}
