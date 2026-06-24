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

  group('gesture arena vs. vertical paging', () {
    testWidgets('horizontal swipe tunes WITHOUT changing the page', (
      tester,
    ) async {
      final tuned = <FeedTuningDirection>[];
      final controller = PageController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: FeedTuningSwipeOverlay(
              onTuned: tuned.add,
              child: PageView(
                controller: controller,
                scrollDirection: Axis.vertical,
                children: const [
                  SizedBox.expand(child: Center(child: Text('page-0'))),
                  SizedBox.expand(child: Center(child: Text('page-1'))),
                  SizedBox.expand(child: Center(child: Text('page-2'))),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.fling(
        find.byType(FeedTuningSwipeOverlay),
        const Offset(-300, 0),
        1000,
      );
      await tester.pumpAndSettle();

      expect(tuned, [FeedTuningDirection.less]);
      expect(controller.page, 0); // vertical pager untouched
    });

    testWidgets('vertical swipe pages WITHOUT tuning', (tester) async {
      final tuned = <FeedTuningDirection>[];
      final controller = PageController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: FeedTuningSwipeOverlay(
              onTuned: tuned.add,
              child: PageView(
                controller: controller,
                scrollDirection: Axis.vertical,
                children: const [
                  SizedBox.expand(child: Center(child: Text('page-0'))),
                  SizedBox.expand(child: Center(child: Text('page-1'))),
                  SizedBox.expand(child: Center(child: Text('page-2'))),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.fling(
        find.byType(FeedTuningSwipeOverlay),
        const Offset(0, -600),
        1500,
      );
      await tester.pumpAndSettle();

      expect(tuned, isEmpty);
      expect(controller.page, 1); // advanced one page
    });
  });

  group(FeedTuningSwipeGate, () {
    testWidgets('wraps the child with the overlay when enabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: FeedTuningSwipeGate(
              enabled: true,
              onTuned: (_) {},
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      );

      expect(find.byType(FeedTuningSwipeOverlay), findsOneWidget);
    });

    testWidgets('renders only the child when disabled', (tester) async {
      const childKey = Key('feed-child');
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FeedTuningSwipeGate(
              enabled: false,
              onTuned: _noop,
              child: SizedBox(key: childKey, width: 100, height: 100),
            ),
          ),
        ),
      );

      expect(find.byType(FeedTuningSwipeOverlay), findsNothing);
      expect(find.byKey(childKey), findsOneWidget);
    });
  });
}

void _noop(FeedTuningDirection _) {}
