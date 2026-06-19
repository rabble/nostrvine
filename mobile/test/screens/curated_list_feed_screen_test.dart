// ABOUTME: Tests for curated list feed owner/subscription actions.
// ABOUTME: Verifies subscribed external lists expose an explicit unfollow menu.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/curated_list_feed_screen.dart';
import 'package:openvine/services/curated_list_service.dart';

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
      String authorPubkey = 'external-pubkey',
      MockGoRouter? goRouter,
    }) {
      final list = CuratedList(
        id: listId,
        name: listName,
        videoEventIds: const [],
        pubkey: authorPubkey,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      final screen = CuratedListFeedScreen(
        listId: listId,
        listName: listName,
        videoIds: const [],
        authorPubkey: authorPubkey,
      );

      final app = ProviderScope(
        overrides: [
          ...getStandardTestOverrides(),
          curatedListsStateProvider.overrideWith(
            () => _TestCuratedListsState(mockService, list),
          ),
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

    testWidgets('shows unfollow list action for subscribed external list', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      await tester.tap(find.byTooltip(l10n.curatedListActionsTooltip));
      await tester.pumpAndSettle();

      expect(find.text(l10n.curatedListUnfollowAction), findsOneWidget);
      expect(find.text(l10n.listDeleteAction), findsNothing);
    });

    testWidgets('hides list actions for unsubscribed external list', (
      tester,
    ) async {
      isSubscribed = false;

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byTooltip(l10n.curatedListActionsTooltip), findsNothing);
      expect(find.text(l10n.curatedListUnfollowAction), findsNothing);
      expect(find.text(l10n.listDeleteAction), findsNothing);
    });

    testWidgets('omits custom app bar actions for unsubscribed external list', (
      tester,
    ) async {
      isSubscribed = false;

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final appBar = tester.widget<DiVineAppBar>(find.byType(DiVineAppBar));
      expect(appBar.customActions, isEmpty);
    });

    testWidgets('shows subscribe action for external list', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final appBar = tester.widget<DiVineAppBar>(find.byType(DiVineAppBar));
      expect(appBar.actions, hasLength(1));
    });

    testWidgets('hides subscribe action for owned list', (tester) async {
      when(() => mockService.isSubscribedToList('owned-list')).thenReturn(true);
      when(() => mockService.isOwnedList('owned-list')).thenReturn(true);

      await tester.pumpWidget(
        buildSubject(
          listId: 'owned-list',
          listName: 'Owned List',
          authorPubkey: 'owned-pubkey',
        ),
      );
      await tester.pump();

      final appBar = tester.widget<DiVineAppBar>(find.byType(DiVineAppBar));
      expect(appBar.actions, isEmpty);
    });

    testWidgets('shows delete action for owned subscribed list', (
      tester,
    ) async {
      when(() => mockService.isSubscribedToList('owned-list')).thenReturn(true);
      when(() => mockService.isOwnedList('owned-list')).thenReturn(true);

      await tester.pumpWidget(
        buildSubject(
          listId: 'owned-list',
          listName: 'Owned List',
          authorPubkey: 'owned-pubkey',
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip(l10n.curatedListActionsTooltip));
      await tester.pumpAndSettle();

      expect(find.text(l10n.listDeleteAction), findsOneWidget);
      expect(find.text(l10n.curatedListUnfollowAction), findsNothing);
    });

    testWidgets('delete confirms then calls service and pops', (tester) async {
      when(() => mockService.isSubscribedToList('owned-list')).thenReturn(true);
      when(() => mockService.isOwnedList('owned-list')).thenReturn(true);
      when(
        () => mockService.deleteOwnedList('owned-list'),
      ).thenAnswer((_) async => true);
      final goRouter = MockGoRouter();
      when(goRouter.canPop).thenReturn(true);
      when(() => goRouter.pop<Object?>()).thenReturn(null);

      await tester.pumpWidget(
        buildSubject(
          listId: 'owned-list',
          listName: 'Owned List',
          authorPubkey: 'owned-pubkey',
          goRouter: goRouter,
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip(l10n.curatedListActionsTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.listDeleteAction));
      await tester.pumpAndSettle();
      expect(find.text(l10n.curatedListDeleteConfirmTitle), findsOneWidget);

      await tester.tap(find.text(l10n.commonDelete));
      await tester.pumpAndSettle();

      verify(() => mockService.deleteOwnedList('owned-list')).called(1);
      verify(() => goRouter.pop<Object?>()).called(1);
      expect(find.text(l10n.curatedListDeletedSnack), findsOneWidget);
      expect(find.text(l10n.curatedListUnfollowAction), findsNothing);
    });

    testWidgets('unfollow calls service and updates action state', (
      tester,
    ) async {
      when(() => mockService.unsubscribeFromList('external-list')).thenAnswer((
        _,
      ) async {
        isSubscribed = false;
        return true;
      });

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      await tester.tap(find.byTooltip(l10n.curatedListActionsTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.curatedListUnfollowAction));
      await tester.pumpAndSettle();

      verify(() => mockService.unsubscribeFromList('external-list')).called(1);
      expect(find.text(l10n.curatedListUnfollowedSnack), findsOneWidget);

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byTooltip(l10n.curatedListActionsTooltip), findsNothing);
      expect(find.text(l10n.curatedListUnfollowAction), findsNothing);
    });
  });
}
