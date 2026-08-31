// ABOUTME: Tests for the curated list detail screen: hero header, viewer
// ABOUTME: follow/share actions, owner actions sheet, and manage-posts mode.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/screens/curated_list_feed_screen.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/widgets/composable_video_grid.dart';
import 'package:riverpod/misc.dart' show Override;

import '../helpers/go_router.dart';
import '../helpers/test_provider_overrides.dart';

class _MockCuratedListService extends Mock implements CuratedListService {}

class _TestCuratedListsState extends CuratedListsState {
  _TestCuratedListsState(this._mockService, this._list);

  final CuratedListService? _mockService;
  final CuratedList _list;

  @override
  CuratedListService? get service => _mockService;

  @override
  Future<List<CuratedList>> build() async => [_list];
}

void main() {
  group(CuratedListFeedScreen, () {
    late _MockCuratedListService mockService;
    var isSubscribed = true;
    final l10n = lookupAppLocalizations(const Locale('en'));

    setUp(() {
      mockService = _MockCuratedListService();
      isSubscribed = true;

      when(
        () => mockService.isSubscribedToList('external-list'),
      ).thenAnswer((_) => isSubscribed);
      when(() => mockService.isOwnedList('external-list')).thenReturn(false);
      when(
        () => mockService.unsubscribeFromList('external-list'),
      ).thenAnswer((_) async => true);
      when(
        () => mockService.deleteOwnedList('owned-list'),
      ).thenAnswer((_) async => true);
    });

    Widget buildSubject({
      String listId = 'external-list',
      String listName = 'External List',
      String? authorPubkey = 'external-pubkey',
      List<String>? videoIds = const [],
      bool isPublic = true,
      MockGoRouter? goRouter,
      List<Override> extraOverrides = const [],
      bool overrideVideoEvents = true,
    }) {
      final list = CuratedList(
        id: listId,
        name: listName,
        videoEventIds: videoIds ?? const ['one', 'two', 'three'],
        pubkey: authorPubkey,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        isPublic: isPublic,
      );

      final screen = CuratedListFeedScreen(
        listId: listId,
        listName: listName,
        videoIds: videoIds,
        authorPubkey: authorPubkey,
      );

      final app = ProviderScope(
        overrides: [
          ...getStandardTestOverrides(),
          curatedListsStateProvider.overrideWith(
            () => _TestCuratedListsState(mockService, list),
          ),
          // The hero header and grid live in the videos provider's data
          // branch, so resolve it with an empty grid instead of leaving the
          // screen on the loading spinner. Callers that override the same
          // providers themselves win via extraOverrides (last one applies).
          if (overrideVideoEvents && videoIds != null)
            videoEventsByIdsProvider(
              videoIds,
            ).overrideWith((ref) => Stream.value(const <VideoEvent>[]))
          else if (overrideVideoEvents)
            curatedListVideoEventsProvider(
              listId,
            ).overrideWith((ref) => Stream.value(const <VideoEvent>[])),
          ...extraOverrides,
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: goRouter == null
              ? screen
              : MockGoRouterProvider(goRouter: goRouter, child: screen),
        ),
      );

      return app;
    }

    void stubOwnedList({
      String listId = 'owned-list',
      String name = 'Owned List',
      String? pubkey = 'owned-pubkey',
      List<String> videoEventIds = const [],
      bool isPublic = true,
    }) {
      when(() => mockService.isOwnedList(listId)).thenReturn(true);
      when(() => mockService.isSubscribedToList(listId)).thenReturn(false);
      when(() => mockService.getListById(listId)).thenReturn(
        CuratedList(
          id: listId,
          name: name,
          pubkey: pubkey,
          videoEventIds: videoEventIds,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          isPublic: isPublic,
        ),
      );
    }

    Future<void> openOwnerSheet(WidgetTester tester) async {
      await tester.tap(find.byTooltip(l10n.curatedListActionsTooltip));
      await tester.pumpAndSettle();
    }

    group('navigation', () {
      testWidgets('back button pops when the router can pop', (tester) async {
        final goRouter = MockGoRouter();
        when(goRouter.canPop).thenReturn(true);
        when(() => goRouter.pop<Object?>()).thenReturn(null);

        await tester.pumpWidget(buildSubject(goRouter: goRouter));
        await tester.pump();
        await tester.pump();

        await tester.tap(find.byTooltip('Back'));

        verify(() => goRouter.pop<Object?>()).called(1);
      });

      testWidgets(
        'back button falls back to the home feed when there is nothing to pop '
        '(cold-start deep link)',
        (tester) async {
          final goRouter = MockGoRouter();
          when(goRouter.canPop).thenReturn(false);
          when(() => goRouter.go(any())).thenReturn(null);

          await tester.pumpWidget(buildSubject(goRouter: goRouter));
          await tester.pump();
          await tester.pump();

          await tester.tap(find.byTooltip('Back'));

          verify(() => goRouter.go(defaultSafePopFallback)).called(1);
          verifyNever(() => goRouter.pop<Object?>());
        },
      );
    });

    group('hero header', () {
      testWidgets('shows title, count, and visibility for an owned list', (
        tester,
      ) async {
        stubOwnedList(
          name: 'Puppets',
          videoEventIds: const ['one', 'two', 'three'],
          isPublic: false,
        );

        await tester.pumpWidget(
          buildSubject(
            listId: 'owned-list',
            listName: 'Puppets',
            authorPubkey: null,
            videoIds: null,
            isPublic: false,
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Puppets'), findsOneWidget);
        expect(find.text(l10n.listVideoCount(3)), findsOneWidget);
        expect(find.text(l10n.listVisibilityPrivate), findsOneWidget);
        expect(find.text(l10n.listByAuthorPrefix), findsNothing);
      });

      testWidgets("shows author attribution for someone else's list", (
        tester,
      ) async {
        when(() => mockService.isOwnedList('external-list')).thenReturn(false);
        when(() => mockService.getListById('external-list')).thenReturn(
          CuratedList(
            id: 'external-list',
            name: 'Subscribed List',
            pubkey:
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            videoEventIds: const ['one', 'two', 'three'],
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        );

        await tester.pumpWidget(
          buildSubject(
            listName: 'Subscribed List',
            authorPubkey: null,
            videoIds: null,
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text(l10n.listByAuthorPrefix), findsOneWidget);
        expect(find.text(l10n.listVideoCount(3)), findsOneWidget);
        expect(find.text(l10n.listVisibilityPublic), findsNothing);
      });

      testWidgets('shows the list description when one exists', (tester) async {
        stubOwnedList(name: 'Puppets');
        when(() => mockService.getListById('owned-list')).thenReturn(
          CuratedList(
            id: 'owned-list',
            name: 'Puppets',
            pubkey: 'owned-pubkey',
            description: 'Hands in socks.',
            videoEventIds: const [],
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        );

        await tester.pumpWidget(
          buildSubject(listId: 'owned-list', listName: 'Puppets'),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Hands in socks.'), findsOneWidget);
      });
    });

    group('viewer actions', () {
      testWidgets('shows follow pill and share action for a public list', (
        tester,
      ) async {
        isSubscribed = false;
        when(() => mockService.getListById('external-list')).thenReturn(
          CuratedList(
            id: 'external-list',
            name: 'External List',
            pubkey: 'external-pubkey',
            videoEventIds: const [],
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        );

        await tester.pumpWidget(buildSubject());
        await tester.pump();
        await tester.pump();

        expect(find.text(l10n.listFollowButton), findsOneWidget);
        expect(find.byTooltip(l10n.listShareAction), findsOneWidget);
        expect(find.byTooltip(l10n.curatedListActionsTooltip), findsNothing);
      });

      testWidgets('follow pill reads Following when subscribed', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject());
        await tester.pump();
        await tester.pump();

        expect(find.text(l10n.listFollowingButton), findsOneWidget);
        expect(find.text(l10n.listFollowButton), findsNothing);
      });

      testWidgets('hides the share action for a private or unknown list', (
        tester,
      ) async {
        when(
          () => mockService.getListById('external-list'),
        ).thenReturn(null);

        await tester.pumpWidget(buildSubject());
        await tester.pump();
        await tester.pump();

        expect(find.byTooltip(l10n.listShareAction), findsNothing);
      });

      testWidgets('tapping the pill toggles the subscription', (tester) async {
        when(() => mockService.unsubscribeFromList('external-list')).thenAnswer(
          (_) async {
            isSubscribed = false;
            return true;
          },
        );

        await tester.pumpWidget(buildSubject());
        await tester.pump();
        await tester.pump();

        await tester.tap(find.text(l10n.listFollowingButton));
        await tester.pumpAndSettle();

        verify(
          () => mockService.unsubscribeFromList('external-list'),
        ).called(1);
        expect(find.text(l10n.listFollowButton), findsOneWidget);
      });

      testWidgets('viewer never sees the owner actions menu', (tester) async {
        isSubscribed = false;

        await tester.pumpWidget(buildSubject());
        await tester.pump();
        await tester.pump();

        expect(find.byTooltip(l10n.curatedListActionsTooltip), findsNothing);
      });
    });

    group('owner actions sheet', () {
      testWidgets('owner sees the menu and no follow pill', (tester) async {
        stubOwnedList();

        await tester.pumpWidget(
          buildSubject(listId: 'owned-list', listName: 'Owned List'),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byTooltip(l10n.curatedListActionsTooltip), findsOneWidget);
        expect(find.text(l10n.listFollowButton), findsNothing);
        expect(find.text(l10n.listFollowingButton), findsNothing);
        final appBar = tester.widget<DiVineAppBar>(find.byType(DiVineAppBar));
        expect(appBar.customActions, isEmpty);
      });

      testWidgets('sheet offers edit, manage posts, share, and delete', (
        tester,
      ) async {
        stubOwnedList();

        await tester.pumpWidget(
          buildSubject(listId: 'owned-list', listName: 'Owned List'),
        );
        await tester.pump();
        await tester.pump();
        await openOwnerSheet(tester);

        expect(find.text(l10n.listEditInfoAction), findsOneWidget);
        expect(find.text(l10n.listManagePostsAction), findsOneWidget);
        expect(find.text(l10n.listShareAction), findsOneWidget);
        expect(find.text(l10n.listDeleteAction), findsOneWidget);
      });

      testWidgets('sheet hides share for a list without an author', (
        tester,
      ) async {
        stubOwnedList(pubkey: null);

        await tester.pumpWidget(
          buildSubject(listId: 'owned-list', listName: 'Owned List'),
        );
        await tester.pump();
        await tester.pump();
        await openOwnerSheet(tester);

        expect(find.text(l10n.listShareAction), findsNothing);
        expect(find.text(l10n.listEditInfoAction), findsOneWidget);
        expect(find.text(l10n.listDeleteAction), findsOneWidget);
      });

      testWidgets('delete confirms then calls service and pops', (
        tester,
      ) async {
        stubOwnedList();
        final goRouter = MockGoRouter();
        when(goRouter.canPop).thenReturn(true);
        when(() => goRouter.pop<Object?>()).thenReturn(null);

        await tester.pumpWidget(
          buildSubject(
            listId: 'owned-list',
            listName: 'Owned List',
            goRouter: goRouter,
          ),
        );
        await tester.pump();
        await tester.pump();

        await openOwnerSheet(tester);
        await tester.tap(find.text(l10n.listDeleteAction));
        await tester.pumpAndSettle();
        expect(find.text(l10n.curatedListDeleteConfirmTitle), findsOneWidget);

        await tester.tap(find.text(l10n.commonDelete));
        await tester.pumpAndSettle();

        verify(() => mockService.deleteOwnedList('owned-list')).called(1);
        verify(() => goRouter.pop<Object?>()).called(1);
        expect(find.text(l10n.curatedListDeletedSnack), findsOneWidget);
      });

      testWidgets('delete cancel dismisses without deleting', (tester) async {
        stubOwnedList();

        await tester.pumpWidget(
          buildSubject(listId: 'owned-list', listName: 'Owned List'),
        );
        await tester.pump();
        await tester.pump();

        await openOwnerSheet(tester);
        await tester.tap(find.text(l10n.listDeleteAction));
        await tester.pumpAndSettle();
        expect(find.text(l10n.curatedListDeleteConfirmTitle), findsOneWidget);

        await tester.tap(find.text(l10n.commonCancel));
        await tester.pumpAndSettle();

        verifyNever(() => mockService.deleteOwnedList('owned-list'));
        expect(find.text(l10n.curatedListDeleteConfirmTitle), findsNothing);
      });

      testWidgets(
        'delete confirmation buttons no-op once their route is torn down',
        (tester) async {
          stubOwnedList();

          await tester.pumpWidget(
            buildSubject(listId: 'owned-list', listName: 'Owned List'),
          );
          await tester.pump();
          await tester.pump();

          await openOwnerSheet(tester);
          await tester.tap(find.text(l10n.listDeleteAction));
          await tester.pumpAndSettle();

          VoidCallback actionFor(String label) => tester
              .widget<TextButton>(
                find.ancestor(
                  of: find.text(label),
                  matching: find.byType(TextButton),
                ),
              )
              .onPressed!;

          final cancel = actionFor(l10n.commonCancel);
          final confirm = actionFor(l10n.commonDelete);

          // Stands in for anything that drops the dialog's route while the
          // tap is in flight — a feature-flag flip re-inflating the app
          // shell, a redirect, a deep link.
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();

          expect(cancel, returnsNormally);
          expect(confirm, returnsNormally);
        },
      );
    });

    group('grid viewport', () {
      testWidgets('clips the scrolling grid region at the top corners', (
        tester,
      ) async {
        stubOwnedList();

        await tester.pumpWidget(
          buildSubject(listId: 'owned-list', listName: 'Owned List'),
        );
        await tester.pump();
        await tester.pump();

        final clip = tester.widget<ClipRRect>(
          find
              .ancestor(
                of: find.byType(ComposableVideoGrid),
                matching: find.byType(ClipRRect),
              )
              .first,
        );
        expect(
          clip.borderRadius,
          const BorderRadius.vertical(
            top: Radius.circular(VineTheme.shellInnerCornerRadius),
          ),
        );
      });
    });

    group('manage posts mode', () {
      Future<void> enterManageMode(WidgetTester tester) async {
        await openOwnerSheet(tester);
        await tester.tap(find.text(l10n.listManagePostsAction));
        await tester.pumpAndSettle();
      }

      testWidgets('entering shows the inline title and disabled remove bar', (
        tester,
      ) async {
        stubOwnedList();

        await tester.pumpWidget(
          buildSubject(listId: 'owned-list', listName: 'Owned List'),
        );
        await tester.pump();
        await tester.pump();
        await enterManageMode(tester);

        // Title moves from the hero into the app bar; with the hero hidden
        // the name renders exactly once.
        expect(find.text('Owned List'), findsOneWidget);
        expect(find.text(l10n.listRemovePostsButton(0)), findsOneWidget);
        final button = tester.widget<DivineButton>(
          find.ancestor(
            of: find.text(l10n.listRemovePostsButton(0)),
            matching: find.byType(DivineButton),
          ),
        );
        expect(button.onPressed, isNull);
        // Hero header is hidden while managing.
        expect(find.text(l10n.listVideoCount(0)), findsNothing);
      });

      testWidgets('removal refreshes the id provider so the tile disappears', (
        tester,
      ) async {
        stubOwnedList();
        when(
          () => mockService.removeVideoFromList('owned-list', any()),
        ).thenAnswer((_) async => true);
        // Keep the real subscribed-list cache out of the tile chain, as the
        // grid's own tests do.

        final video = VideoEvent(
          id: 'a' * 64,
          pubkey: 'b' * 64,
          content: 'A cat video',
          title: 'A cat video',
          videoUrl: 'https://example.com/video.mp4',
          thumbnailUrl: 'https://example.com/thumb.jpg',
          duration: 5,
          createdAt: DateTime(2026).millisecondsSinceEpoch ~/ 1000,
          timestamp: DateTime(2026),
        );

        // Mirrors production's two cached layers: the video stream watches
        // the id-list provider. The id provider serves one id on the first
        // read and none after that, so the removed tile only disappears if
        // the removal listener invalidates the ID layer too — invalidating
        // just the stream re-runs it against the cached ids (the bug).
        var idReads = 0;
        await tester.pumpWidget(
          buildSubject(
            listId: 'owned-list',
            listName: 'Owned List',
            videoIds: null,
            overrideVideoEvents: false,
            extraOverrides: [
              subscribedListVideoCacheProvider.overrideWithValue(null),
              curatedListVideosProvider('owned-list').overrideWith((ref) async {
                idReads++;
                return idReads == 1 ? [video.id] : const <String>[];
              }),
              curatedListVideoEventsProvider('owned-list').overrideWith((
                ref,
              ) async* {
                final ids = await ref.watch(
                  curatedListVideosProvider('owned-list').future,
                );
                yield [for (final _ in ids) video];
              }),
            ],
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('A cat video'), findsOneWidget);

        await enterManageMode(tester);
        await tester.tap(find.text('A cat video'));
        await tester.pump();
        await tester.tap(find.text(l10n.listRemovePostsButton(1)));
        await tester.pumpAndSettle();

        verify(
          () => mockService.removeVideoFromList('owned-list', video.id),
        ).called(1);
        expect(find.text(l10n.listRemovePostsSuccess(1)), findsOneWidget);
        expect(find.text('A cat video'), findsNothing);
        expect(find.text(l10n.curatedListEmptyTitle), findsOneWidget);
      });

      testWidgets('back exits manage mode instead of popping the route', (
        tester,
      ) async {
        stubOwnedList();
        final goRouter = MockGoRouter();
        when(goRouter.canPop).thenReturn(true);
        when(() => goRouter.pop<Object?>()).thenReturn(null);

        await tester.pumpWidget(
          buildSubject(
            listId: 'owned-list',
            listName: 'Owned List',
            goRouter: goRouter,
          ),
        );
        await tester.pump();
        await tester.pump();
        await enterManageMode(tester);

        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();

        verifyNever(() => goRouter.pop<Object?>());
        expect(find.text(l10n.listRemovePostsButton(0)), findsNothing);
        expect(find.byTooltip(l10n.curatedListActionsTooltip), findsOneWidget);
      });
    });
  });
}
