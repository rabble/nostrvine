// ABOUTME: Widget tests for BadgeDetailScreen — which actions each viewer role
// ABOUTME: gets, and how a badge with no definition event is surfaced.

import 'package:badge_repository/badge_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/badges/badge_detail_screen.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockBadgeRepository extends Mock implements BadgeRepository {}

void main() {
  group('BadgeDetailScreen', () {
    late _MockBadgeRepository repository;
    final l10n = lookupAppLocalizations(const Locale('en'));

    setUpAll(() {
      registerFallbackValue(const BadgeCoordinate(pubkey: '', identifier: ''));
      registerFallbackValue(BadgeAwardViewData(award: _award()));
    });

    setUp(() {
      repository = _MockBadgeRepository();
    });

    /// Pumps the screen behind a real [GoRouter].
    ///
    /// The screen pops itself once a deletion lands, and `context.pop` is a
    /// GoRouter extension — a bare `MaterialApp` would throw there instead of
    /// exercising the flow.
    Widget buildSubject() {
      final router = GoRouter(
        initialLocation: '/badges/b/badge',
        routes: [
          GoRoute(
            path: '/badges',
            builder: (_, _) => const Scaffold(body: Text('badge dashboard')),
            routes: [
              GoRoute(
                path: 'b/badge',
                builder: (_, _) =>
                    const BadgeDetailScreen(coordinate: _coordinate),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      return testProviderScope(
        additionalOverrides: [
          badgeRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
    }

    testWidgets('offers awarding and editing to the badge owner', (
      tester,
    ) async {
      when(() => repository.loadBadgeDetail(any())).thenAnswer(
        (_) async => _detail(definition: _definition(), isOwner: true),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Scene Stealer'), findsWidgets);
      expect(find.text(l10n.badgeDetailAwardAction), findsOneWidget);
      expect(find.text(l10n.badgeDetailNoRecipients), findsOneWidget);
    });

    testWidgets('offers accepting to a recipient who has not accepted', (
      tester,
    ) async {
      when(() => repository.loadBadgeDetail(any())).thenAnswer(
        (_) async => _detail(
          definition: _definition(),
          isOwner: false,
          viewerAward: BadgeAwardViewData(award: _award()),
        ),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text(l10n.badgesActionAccept), findsOneWidget);
      expect(find.text(l10n.badgeDetailAwardAction), findsNothing);
    });

    testWidgets('offers removing to a recipient who already accepted', (
      tester,
    ) async {
      when(() => repository.loadBadgeDetail(any())).thenAnswer(
        (_) async => _detail(
          definition: _definition(),
          isOwner: false,
          viewerAward: BadgeAwardViewData(award: _award(), isAccepted: true),
        ),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text(l10n.badgesActionRemove), findsOneWidget);
      expect(find.text(l10n.badgesActionAccept), findsNothing);
    });

    testWidgets('deletes only after the owner confirms', (tester) async {
      when(() => repository.loadBadgeDetail(any())).thenAnswer(
        (_) async => _detail(definition: _definition(), isOwner: true),
      );
      when(() => repository.deleteBadge(any())).thenAnswer((_) async {});

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel(l10n.badgeDetailDeleteAction));
      await tester.pumpAndSettle();

      expect(find.text(l10n.badgeDetailDeleteTitle), findsOneWidget);
      expect(find.text(l10n.badgeDetailDeleteBody), findsOneWidget);

      await tester.tap(find.text(l10n.commonCancel));
      await tester.pumpAndSettle();
      verifyNever(() => repository.deleteBadge(any()));

      await tester.tap(find.bySemanticsLabel(l10n.badgeDetailDeleteAction));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.badgeDetailDeleteConfirm));
      await tester.pumpAndSettle();

      verify(() => repository.deleteBadge(_coordinate)).called(1);
    });

    testWidgets('tells the owner when a relay refuses the deletion', (
      tester,
    ) async {
      when(() => repository.loadBadgeDetail(any())).thenAnswer(
        (_) async => _detail(definition: _definition(), isOwner: true),
      );
      when(() => repository.deleteBadge(any())).thenThrow(
        const BadgePublishException(
          'rejected',
          outcome: PublishOutcome(
            eventId: 'deadbeef',
            acceptedBy: [],
            rejectedBy: {'wss://relay.divine.video': 'delete not authorized'},
            noResponseFrom: [],
          ),
        ),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel(l10n.badgeDetailDeleteAction));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.badgeDetailDeleteConfirm));
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.shareMenuDeleteFailedRelayRejected),
        findsOneWidget,
      );
      // The badge is still there, so the page must not have popped.
      expect(find.text('Scene Stealer'), findsWidgets);
    });

    testWidgets('hides the delete action from non-owners', (tester) async {
      when(() => repository.loadBadgeDetail(any())).thenAnswer(
        (_) async => _detail(definition: _definition(), isOwner: false),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(l10n.badgeDetailDeleteAction),
        findsNothing,
      );
    });

    testWidgets('says so when no definition event could be found', (
      tester,
    ) async {
      when(
        () => repository.loadBadgeDetail(any()),
      ).thenAnswer((_) async => _detail(isOwner: false));

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text(l10n.badgeDetailMissing), findsOneWidget);
    });

    testWidgets('offers a retry when the lookup fails', (tester) async {
      when(
        () => repository.loadBadgeDetail(any()),
      ).thenThrow(Exception('relay unavailable'));

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text(l10n.badgeDetailLoadError), findsOneWidget);
      expect(find.text(l10n.commonRetry), findsOneWidget);
    });
  });
}

const _coordinate = BadgeCoordinate(
  pubkey: '0000000000000000000000000000000000000000000000000000000000000065',
  identifier: 'scene-stealer',
);

BadgeDetailData _detail({
  required bool isOwner,
  Nip58BadgeDefinition? definition,
  BadgeAwardViewData? viewerAward,
}) {
  return BadgeDetailData(
    coordinate: _coordinate,
    definition: definition,
    recipients: const [],
    isOwner: isOwner,
    viewerAward: viewerAward,
  );
}

Nip58BadgeDefinition _definition() {
  return Nip58BadgeDefinition(
    event: _event(kind: EventKind.badgeDefinition),
    coordinate: _coordinate.value,
    dTag: _coordinate.identifier,
    name: 'Scene Stealer',
  );
}

Nip58BadgeAward _award() {
  return Nip58BadgeAward(
    event: _event(kind: EventKind.badgeAward),
    definitionCoordinate: _coordinate.value,
    recipientPubkeys: [_pubkey(2)],
  );
}

Event _event({required int kind}) {
  return Event.fromJson({
    'id': '1'.padLeft(64, '0'),
    'pubkey': _pubkey(1),
    'created_at': 1000,
    'kind': kind,
    'tags': <List<String>>[],
    'content': '',
    'sig': '',
  });
}

String _pubkey(int seed) => (seed + 100).toRadixString(16).padLeft(64, '0');
