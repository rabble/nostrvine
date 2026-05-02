import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/apps/nostr_app_sandbox_screen.dart';
import 'package:openvine/screens/badges/badges_screen.dart';
import 'package:openvine/services/badges/badge_repository.dart';
import 'package:openvine/services/badges/nip58_badge_models.dart';

import '../../helpers/go_router.dart';

class _MockBadgeRepository extends Mock implements BadgeRepository {}

void main() {
  group('BadgesScreen', () {
    late _MockBadgeRepository repository;
    late BadgeAwardViewData awardedBadge;
    late IssuedBadgeViewData issuedBadge;
    final l10n = lookupAppLocalizations(const Locale('en'));

    setUpAll(() {
      registerFallbackValue(_awardViewData(isAccepted: false));
    });

    setUp(() {
      repository = _MockBadgeRepository();
      awardedBadge = _awardViewData(isAccepted: false);
      issuedBadge = _issuedViewData(recipientAccepted: true);
    });

    Widget buildSubject({MockGoRouter? goRouter}) {
      const app = MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BadgesScreen(),
      );

      return ProviderScope(
        overrides: [badgeRepositoryProvider.overrideWithValue(repository)],
        child: goRouter == null
            ? app
            : MockGoRouterProvider(goRouter: goRouter, child: app),
      );
    }

    testWidgets('loads awarded and issued badge context', (tester) async {
      when(repository.loadDashboard).thenAnswer(
        (_) async =>
            BadgeDashboardData(awarded: [awardedBadge], issued: [issuedBadge]),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byType(DiVineAppBar), findsOneWidget);
      expect(find.text(l10n.badgesTitle), findsOneWidget);
      expect(find.text(l10n.badgesAwardedSectionTitle), findsOneWidget);
      expect(find.text('Diviner of the Day'), findsOneWidget);
      expect(find.text(l10n.badgesStatusNotAccepted), findsOneWidget);
      expect(find.text(l10n.badgesActionAccept), findsOneWidget);
      expect(find.text(l10n.badgesActionReject), findsOneWidget);
      expect(find.text(l10n.badgesIssuedSectionTitle), findsOneWidget);
      expect(find.text(l10n.badgesRecipientAcceptedStatus), findsOneWidget);
    });

    testWidgets('accept button delegates to the repository', (tester) async {
      when(repository.loadDashboard).thenAnswer(
        (_) async =>
            BadgeDashboardData(awarded: [awardedBadge], issued: const []),
      );
      when(() => repository.acceptAward(any())).thenAnswer((_) async {});

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.badgesActionAccept));
      await tester.pumpAndSettle();

      verify(() => repository.acceptAward(awardedBadge)).called(1);
      verify(repository.loadDashboard).called(greaterThanOrEqualTo(2));
    });

    testWidgets('opens the embedded Divine Badges app', (tester) async {
      final mockGoRouter = MockGoRouter();
      when(() => mockGoRouter.push(any())).thenAnswer((_) async => null);
      when(repository.loadDashboard).thenAnswer(
        (_) async => const BadgeDashboardData(awarded: [], issued: []),
      );

      await tester.pumpWidget(buildSubject(goRouter: mockGoRouter));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.badgesOpenApp));
      await tester.pumpAndSettle();

      verify(
        () => mockGoRouter.push(
          NostrAppSandboxScreen.pathForAppId('bundled-badges'),
        ),
      ).called(1);
    });
  });
}

BadgeAwardViewData _awardViewData({required bool isAccepted}) {
  final issuerPubkey = _pubkey(2);
  final definitionCoordinate = '30009:$issuerPubkey:daily-diviner';
  return BadgeAwardViewData(
    award: Nip58BadgeAward(
      event: _event(
        id: _eventId(1),
        pubkey: issuerPubkey,
        kind: EventKind.badgeAward,
        tags: [
          ['a', definitionCoordinate],
          ['p', _pubkey(1)],
        ],
      ),
      definitionCoordinate: definitionCoordinate,
      recipientPubkeys: [_pubkey(1)],
    ),
    definition: Nip58BadgeDefinition(
      event: _event(
        id: _eventId(2),
        pubkey: issuerPubkey,
        kind: EventKind.badgeDefinition,
      ),
      coordinate: definitionCoordinate,
      dTag: 'daily-diviner',
      name: 'Diviner of the Day',
      description: 'Awarded for showing up with a good eye.',
    ),
    isAccepted: isAccepted,
  );
}

IssuedBadgeViewData _issuedViewData({required bool recipientAccepted}) {
  final issuerPubkey = _pubkey(1);
  final recipientPubkey = _pubkey(3);
  final definitionCoordinate = '30009:$issuerPubkey:weekly-diviner';
  return IssuedBadgeViewData(
    award: Nip58BadgeAward(
      event: _event(
        id: _eventId(3),
        pubkey: issuerPubkey,
        kind: EventKind.badgeAward,
        tags: [
          ['a', definitionCoordinate],
          ['p', recipientPubkey],
        ],
      ),
      definitionCoordinate: definitionCoordinate,
      recipientPubkeys: [recipientPubkey],
    ),
    definition: Nip58BadgeDefinition(
      event: _event(
        id: _eventId(4),
        pubkey: issuerPubkey,
        kind: EventKind.badgeDefinition,
      ),
      coordinate: definitionCoordinate,
      dTag: 'weekly-diviner',
      name: 'Diviner of the Week',
    ),
    recipients: [
      IssuedBadgeRecipientViewData(
        pubkey: recipientPubkey,
        isAccepted: recipientAccepted,
      ),
    ],
  );
}

Event _event({
  required String id,
  required String pubkey,
  int kind = 1,
  List<List<String>> tags = const [],
  int createdAt = 1000,
  String content = '',
}) {
  return Event.fromJson({
    'id': id,
    'pubkey': pubkey,
    'created_at': createdAt,
    'kind': kind,
    'tags': tags,
    'content': content,
    'sig': '',
  });
}

String _eventId(int seed) => seed.toRadixString(16).padLeft(64, '0');

String _pubkey(int seed) => (seed + 100).toRadixString(16).padLeft(64, '0');
