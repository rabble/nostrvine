// ABOUTME: Widget tests for FeedModeSwitch
// ABOUTME: Tests feed source labels, tap interactions, and bottom sheet selection

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/feed/feed_mode_switch.dart';

class _MockVideoFeedBloc extends MockBloc<VideoFeedEvent, VideoFeedBlocState>
    implements VideoFeedBloc {}

void main() {
  group(FeedModeSwitch, () {
    late _MockVideoFeedBloc mockBloc;
    late AppLocalizations l10n;

    setUp(() {
      mockBloc = _MockVideoFeedBloc();
    });

    setUpAll(() {
      registerFallbackValue(
        const VideoFeedSourceChanged(VideoFeedSource.forYou()),
      );
      l10n = lookupAppLocalizations(const Locale('en'));
    });

    tearDown(() {
      mockBloc.close();
    });

    Widget createTestWidget() {
      return ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Stack(
              children: [
                BlocProvider<VideoFeedBloc>.value(
                  value: mockBloc,
                  child: const FeedModeSwitch(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    CuratedList curatedList({required String id, required String name}) {
      final now = DateTime(2026);
      return CuratedList(
        id: id,
        name: name,
        videoEventIds: const [],
        createdAt: now,
        updatedAt: now,
      );
    }

    group('Feed Source Labels', () {
      testWidgets('displays "For You" label for the default home source', (
        tester,
      ) async {
        when(
          () => mockBloc.state,
        ).thenReturn(const VideoFeedBlocState(status: VideoFeedStatus.success));
        await tester.pumpWidget(createTestWidget());

        expect(find.text(l10n.feedModeForYou), findsOneWidget);
      });

      testWidgets('displays "Classics" label for the classic source', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const VideoFeedBlocState(
            status: VideoFeedStatus.success,
            source: VideoFeedSource.classic(),
          ),
        );
        await tester.pumpWidget(createTestWidget());

        expect(find.text(l10n.feedModeClassics), findsOneWidget);
      });

      testWidgets('displays selected subscribed-list name for list source', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          VideoFeedBlocState(
            status: VideoFeedStatus.success,
            source: const VideoFeedSource.subscribedList(
              listId: 'best',
              listName: 'Best Vines',
            ),
            subscribedLists: [curatedList(id: 'best', name: 'Best Vines')],
          ),
        );
        await tester.pumpWidget(createTestWidget());

        expect(find.text('Best Vines'), findsOneWidget);
      });
    });

    group('Tap Interaction', () {
      testWidgets('opens VineBottomSheet on tap', (tester) async {
        when(() => mockBloc.state).thenReturn(
          const VideoFeedBlocState(
            status: VideoFeedStatus.success,
            source: VideoFeedSource.forYou(),
          ),
        );
        await tester.pumpWidget(createTestWidget());

        await tester.tap(find.text(l10n.feedModeForYou));
        await tester.pumpAndSettle();

        expect(find.byType(VineBottomSheet), findsOneWidget);
      });

      testWidgets(
        'dropdown shows For You, Following, New, Classics, and subscribed lists',
        (tester) async {
          when(() => mockBloc.state).thenReturn(
            VideoFeedBlocState(
              status: VideoFeedStatus.success,
              source: const VideoFeedSource.forYou(),
              subscribedLists: [curatedList(id: 'best', name: 'Best Vines')],
            ),
          );
          await tester.pumpWidget(createTestWidget());

          await tester.tap(find.text(l10n.feedModeForYou));
          await tester.pumpAndSettle();

          expect(find.text(l10n.feedModeForYou), findsWidgets);
          expect(find.text(l10n.feedModeFollowing), findsOneWidget);
          expect(find.text(l10n.feedModeNew), findsOneWidget);
          expect(find.text(l10n.feedModeClassics), findsOneWidget);
          expect(find.text('Best Vines'), findsOneWidget);
        },
      );

      testWidgets('dispatches VideoFeedSourceChanged when For You selected', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const VideoFeedBlocState(
            status: VideoFeedStatus.success,
            source: VideoFeedSource.following(),
          ),
        );
        await tester.pumpWidget(createTestWidget());

        await tester.tap(find.text(l10n.feedModeFollowing));
        await tester.pumpAndSettle();

        await tester.tap(find.text(l10n.feedModeForYou));
        await tester.pumpAndSettle();

        verify(
          () => mockBloc.add(
            const VideoFeedSourceChanged(VideoFeedSource.forYou()),
          ),
        ).called(1);
      });

      testWidgets('dispatches VideoFeedSourceChanged when following selected', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const VideoFeedBlocState(
            status: VideoFeedStatus.success,
            source: VideoFeedSource.forYou(),
          ),
        );
        await tester.pumpWidget(createTestWidget());

        await tester.tap(find.text(l10n.feedModeForYou));
        await tester.pumpAndSettle();

        await tester.tap(find.text(l10n.feedModeFollowing));
        await tester.pumpAndSettle();

        verify(
          () => mockBloc.add(
            const VideoFeedSourceChanged(VideoFeedSource.following()),
          ),
        ).called(1);
      });

      testWidgets('dispatches VideoFeedSourceChanged when New selected', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const VideoFeedBlocState(
            status: VideoFeedStatus.success,
            source: VideoFeedSource.forYou(),
          ),
        );
        await tester.pumpWidget(createTestWidget());

        await tester.tap(find.text(l10n.feedModeForYou));
        await tester.pumpAndSettle();

        await tester.tap(find.text(l10n.feedModeNew));
        await tester.pumpAndSettle();

        verify(
          () => mockBloc.add(
            const VideoFeedSourceChanged(VideoFeedSource.newVideos()),
          ),
        ).called(1);
      });

      testWidgets('dispatches VideoFeedSourceChanged when Classics selected', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const VideoFeedBlocState(
            status: VideoFeedStatus.success,
            source: VideoFeedSource.forYou(),
          ),
        );
        await tester.pumpWidget(createTestWidget());

        await tester.tap(find.text(l10n.feedModeForYou));
        await tester.pumpAndSettle();

        await tester.tap(find.text(l10n.feedModeClassics));
        await tester.pumpAndSettle();

        verify(
          () => mockBloc.add(
            const VideoFeedSourceChanged(VideoFeedSource.classic()),
          ),
        ).called(1);
      });

      testWidgets(
        'dispatches VideoFeedSourceChanged when subscribed list selected',
        (tester) async {
          when(() => mockBloc.state).thenReturn(
            VideoFeedBlocState(
              status: VideoFeedStatus.success,
              source: const VideoFeedSource.forYou(),
              subscribedLists: [curatedList(id: 'best', name: 'Best Vines')],
            ),
          );
          await tester.pumpWidget(createTestWidget());

          await tester.tap(find.text(l10n.feedModeForYou));
          await tester.pumpAndSettle();

          await tester.tap(find.text('Best Vines'));
          await tester.pumpAndSettle();

          verify(
            () => mockBloc.add(
              const VideoFeedSourceChanged(
                VideoFeedSource.subscribedList(
                  listId: 'best',
                  listName: 'Best Vines',
                ),
              ),
            ),
          ).called(1);
        },
      );

      testWidgets('does not dispatch event when bottom sheet dismissed', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const VideoFeedBlocState(
            status: VideoFeedStatus.success,
            source: VideoFeedSource.forYou(),
          ),
        );
        await tester.pumpWidget(createTestWidget());

        await tester.tap(find.text(l10n.feedModeForYou));
        await tester.pumpAndSettle();

        // Dismiss by tapping outside (on the barrier).
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        verifyNever(() => mockBloc.add(any()));
      });
    });

    group('Tap Area Coverage', () {
      // Regression: before HitTestBehavior.opaque was set on the
      // GestureDetector, taps on the caret icon and the spacing gap
      // between label and caret fell through -- only the text label itself
      // responded.

      testWidgets(
        'opens bottom sheet when caret icon is tapped (not the text label)',
        (tester) async {
          when(() => mockBloc.state).thenReturn(
            const VideoFeedBlocState(
              status: VideoFeedStatus.success,
              source: VideoFeedSource.forYou(),
            ),
          );
          await tester.pumpWidget(createTestWidget());

          // The visible caret uses VineTheme.whiteText; shadow copies use
          // VineTheme.innerShadow -- filter to the real icon only.
          final caretIcon = find.descendant(
            of: find.byType(FeedModeSwitch),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is DivineIcon &&
                  w.icon == DivineIconName.caretDown &&
                  w.color == VineTheme.whiteText,
            ),
          );
          expect(caretIcon, findsOneWidget);

          await tester.tap(caretIcon);
          await tester.pumpAndSettle();

          expect(find.byType(VineBottomSheet), findsOneWidget);
        },
      );

      testWidgets(
        'opens bottom sheet when tapping the spacing gap between label and caret',
        (tester) async {
          // The 12 px Row spacing gap has no child widget drawn in it;
          // HitTestBehavior.opaque ensures it still registers taps.
          when(() => mockBloc.state).thenReturn(
            const VideoFeedBlocState(
              status: VideoFeedStatus.success,
              source: VideoFeedSource.forYou(),
            ),
          );
          await tester.pumpWidget(createTestWidget());

          final textRect = tester.getRect(find.text(l10n.feedModeForYou));
          final caretIcon = find.descendant(
            of: find.byType(FeedModeSwitch),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is DivineIcon &&
                  w.icon == DivineIconName.caretDown &&
                  w.color == VineTheme.whiteText,
            ),
          );
          final caretRect = tester.getRect(caretIcon);

          await tester.tapAt(
            Offset(
              (textRect.right + caretRect.left) / 2,
              textRect.center.dy,
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(VineBottomSheet), findsOneWidget);
        },
      );
    });

    group('Accessibility', () {
      // Helper: finds the Semantics widget that wraps the feed-mode
      // GestureDetector by walking up from the visible label text.
      Semantics findFeedModeSemanticsWidget(WidgetTester tester, String label) {
        final expectedLabel = l10n.feedModeSemanticLabel(label);
        return tester.widget<Semantics>(
          find
              .ancestor(
                of: find.text(label),
                matching: find.byWidgetPredicate(
                  (w) => w is Semantics && w.properties.label == expectedLabel,
                ),
              )
              .first,
        );
      }

      testWidgets(
        'Semantics widget carries button=true and the current source label',
        (tester) async {
          when(() => mockBloc.state).thenReturn(
            const VideoFeedBlocState(
              status: VideoFeedStatus.success,
              source: VideoFeedSource.forYou(),
            ),
          );
          await tester.pumpWidget(createTestWidget());

          final semanticsWidget = findFeedModeSemanticsWidget(
            tester,
            l10n.feedModeForYou,
          );
          expect(
            semanticsWidget.properties.label,
            equals(l10n.feedModeSemanticLabel(l10n.feedModeForYou)),
          );
          expect(semanticsWidget.properties.button, isTrue);
        },
      );

      testWidgets(
        'semantics label updates when the feed source changes',
        (tester) async {
          whenListen(
            mockBloc,
            Stream.fromIterable([
              const VideoFeedBlocState(
                status: VideoFeedStatus.success,
                source: VideoFeedSource.following(),
              ),
            ]),
            initialState: const VideoFeedBlocState(
              status: VideoFeedStatus.success,
              source: VideoFeedSource.forYou(),
            ),
          );
          await tester.pumpWidget(createTestWidget());
          await tester.pump();

          final semanticsWidget = findFeedModeSemanticsWidget(
            tester,
            l10n.feedModeFollowing,
          );
          expect(
            semanticsWidget.properties.label,
            equals(
              l10n.feedModeSemanticLabel(l10n.feedModeFollowing),
            ),
          );
        },
      );

      testWidgets(
        'opens bottom sheet when the Semantics button area is tapped',
        (tester) async {
          when(() => mockBloc.state).thenReturn(
            const VideoFeedBlocState(
              status: VideoFeedStatus.success,
              source: VideoFeedSource.forYou(),
            ),
          );
          await tester.pumpWidget(createTestWidget());

          await tester.tap(
            find
                .ancestor(
                  of: find.text(l10n.feedModeForYou),
                  matching: find.byWidgetPredicate(
                    (w) =>
                        w is Semantics &&
                        w.properties.label ==
                            l10n.feedModeSemanticLabel(l10n.feedModeForYou),
                  ),
                )
                .first,
          );
          await tester.pumpAndSettle();

          expect(find.byType(VineBottomSheet), findsOneWidget);
        },
      );
    });

    testWidgets('label gets updated when source changes', (tester) async {
      whenListen(
        mockBloc,
        Stream.fromIterable([
          const VideoFeedBlocState(
            status: VideoFeedStatus.success,
            source: VideoFeedSource.forYou(),
          ),
        ]),
        initialState: const VideoFeedBlocState(
          status: VideoFeedStatus.success,
          source: VideoFeedSource.following(),
        ),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.text(l10n.feedModeForYou), findsOneWidget);
    });
  });
}
