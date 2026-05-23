// ABOUTME: Tests for curated list feed owner/subscription actions.
// ABOUTME: Verifies subscribed external lists expose an explicit unfollow menu.

@Tags(['skip_very_good_optimization'])
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

import '../helpers/test_provider_overrides.dart';

class _MockCuratedListService extends Mock implements CuratedListService {}

class _TestCuratedListsState extends CuratedListsState {
  _TestCuratedListsState(this._mockService);

  final CuratedListService? _mockService;

  @override
  CuratedListService? get service => _mockService;

  @override
  Future<List<CuratedList>> build() async => [
    CuratedList(
      id: 'external-list',
      name: 'External List',
      videoEventIds: const [],
      pubkey: 'external-pubkey',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  ];
}

void main() {
  group(CuratedListFeedScreen, () {
    late _MockCuratedListService mockService;
    var isSubscribed = true;

    setUp(() {
      mockService = _MockCuratedListService();
      isSubscribed = true;

      when(
        () => mockService.isSubscribedToList('external-list'),
      ).thenAnswer((_) => isSubscribed);
      when(
        () => (mockService as dynamic).isOwnedList('external-list') as bool,
      ).thenReturn(false);
      when(
        () => mockService.unsubscribeFromList('external-list'),
      ).thenAnswer((_) async => true);
    });

    Widget buildSubject() {
      return ProviderScope(
        overrides: [
          ...getStandardTestOverrides(),
          curatedListsStateProvider.overrideWith(
            () => _TestCuratedListsState(mockService),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CuratedListFeedScreen(
            listId: 'external-list',
            listName: 'External List',
            videoIds: [],
            authorPubkey: 'external-pubkey',
          ),
        ),
      );
    }

    testWidgets(
      'shows unfollow list action for subscribed external list',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pump();

        await tester.tap(find.byTooltip('List actions'));
        await tester.pumpAndSettle();

        expect(find.text('Unfollow list'), findsOneWidget);
        expect(find.text('Delete list'), findsNothing);
      },
    );

    testWidgets('hides list actions for unsubscribed external list', (
      tester,
    ) async {
      isSubscribed = false;

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byTooltip('List actions'), findsNothing);
      expect(find.text('Unfollow list'), findsNothing);
      expect(find.text('Delete list'), findsNothing);
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

    testWidgets('hides list actions for owned subscribed list', (tester) async {
      when(
        () => (mockService as dynamic).isOwnedList('external-list') as bool,
      ).thenReturn(true);

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byTooltip('List actions'), findsNothing);
      expect(find.text('Unfollow list'), findsNothing);
      expect(find.text('Delete list'), findsNothing);
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

      await tester.tap(find.byTooltip('List actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unfollow list'));
      await tester.pumpAndSettle();

      verify(() => mockService.unsubscribeFromList('external-list')).called(1);
      expect(find.text('Unfollowed list'), findsOneWidget);
      expect(find.byTooltip('List actions'), findsNothing);
      expect(find.text('Unfollow list'), findsNothing);
    });
  });
}
