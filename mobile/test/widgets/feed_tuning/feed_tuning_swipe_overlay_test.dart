import 'package:feed_tuning_repository/feed_tuning_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/feed_tuning/feed_tuning_swipe_overlay.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  Future<List<FeedTuningDirection>> pumpOverlay(WidgetTester tester) async {
    final tuned = <FeedTuningDirection>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: FeedTuningSwipeOverlay(
              onTuned: tuned.add,
              child: const SizedBox(width: 300, height: 500),
            ),
          ),
        ),
      ),
    );
    return tuned;
  }

  group(FeedTuningSwipeOverlay, () {
    testWidgets('swiping right past the threshold tunes "more"', (
      tester,
    ) async {
      final tuned = await pumpOverlay(tester);

      await tester.drag(
        find.byType(FeedTuningSwipeOverlay),
        const Offset(200, 0),
      );
      await tester.pumpAndSettle();

      expect(tuned, [FeedTuningDirection.more]);
    });

    testWidgets('swiping left past the threshold tunes "less"', (tester) async {
      final tuned = await pumpOverlay(tester);

      await tester.drag(
        find.byType(FeedTuningSwipeOverlay),
        const Offset(-200, 0),
      );
      await tester.pumpAndSettle();

      expect(tuned, [FeedTuningDirection.less]);
    });

    testWidgets('a short swipe below the threshold does not tune', (
      tester,
    ) async {
      final tuned = await pumpOverlay(tester);

      await tester.drag(
        find.byType(FeedTuningSwipeOverlay),
        const Offset(30, 0),
      );
      await tester.pumpAndSettle();

      expect(tuned, isEmpty);
    });

    testWidgets('shows the directional indicator during a drag', (
      tester,
    ) async {
      await pumpOverlay(tester);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(FeedTuningSwipeOverlay)),
      );
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump();

      expect(find.text(l10n.feedTuningMoreLabel), findsOneWidget);
      expect(find.text(l10n.feedTuningLessLabel), findsNothing);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('exposes more/less as custom semantic actions', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpOverlay(tester);

      final moreId = CustomSemanticsAction.getIdentifier(
        CustomSemanticsAction(label: l10n.feedTuningMoreLabel),
      );
      final lessId = CustomSemanticsAction.getIdentifier(
        CustomSemanticsAction(label: l10n.feedTuningLessLabel),
      );
      final node = tester.getSemantics(find.byType(FeedTuningSwipeOverlay));

      expect(
        node.getSemanticsData().customSemanticsActionIds,
        containsAll(<int>[moreId, lessId]),
      );
      handle.dispose();
    });
  });
}
