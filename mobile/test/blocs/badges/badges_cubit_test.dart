import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/blocs/badges/badges_cubit.dart';
import 'package:openvine/services/badges/badge_repository.dart';
import 'package:openvine/services/badges/nip58_badge_models.dart';

class _MockBadgeRepository extends Mock implements BadgeRepository {}

void main() {
  group('BadgesCubit', () {
    late _MockBadgeRepository repository;
    late BadgeAwardViewData awardedBadge;
    late IssuedBadgeViewData issuedBadge;
    late BadgeDashboardData dashboard;

    setUpAll(() {
      registerFallbackValue(_awardViewData());
    });

    setUp(() {
      repository = _MockBadgeRepository();
      awardedBadge = _awardViewData();
      issuedBadge = _issuedViewData();
      dashboard = BadgeDashboardData(
        awarded: [awardedBadge],
        issued: [issuedBadge],
      );
    });

    test('initial state is correct', () {
      final cubit = BadgesCubit(repository: repository);

      expect(cubit.state.status, BadgesStatus.initial);
      expect(cubit.state.actionStatus, BadgeActionStatus.idle);
      expect(cubit.state.awarded, isEmpty);
      expect(cubit.state.issued, isEmpty);
    });

    blocTest<BadgesCubit, BadgesState>(
      'emits loading then loaded data when load succeeds',
      setUp: () {
        when(
          repository.loadDashboard,
        ).thenAnswer((_) async => dashboard);
      },
      build: () => BadgesCubit(repository: repository),
      act: (cubit) => cubit.load(),
      expect: () => [
        const BadgesState(status: BadgesStatus.loading),
        isA<BadgesState>()
            .having((state) => state.status, 'status', BadgesStatus.loaded)
            .having((state) => state.awarded, 'awarded', [awardedBadge])
            .having((state) => state.issued, 'issued', [issuedBadge]),
      ],
    );

    blocTest<BadgesCubit, BadgesState>(
      'emits error when load fails',
      setUp: () {
        when(
          repository.loadDashboard,
        ).thenThrow(Exception('relay unavailable'));
      },
      build: () => BadgesCubit(repository: repository),
      act: (cubit) => cubit.load(),
      expect: () => [
        const BadgesState(status: BadgesStatus.loading),
        const BadgesState(status: BadgesStatus.error),
      ],
      errors: () => [isA<Exception>()],
    );

    blocTest<BadgesCubit, BadgesState>(
      'acceptAward delegates then refreshes dashboard',
      setUp: () {
        when(() => repository.acceptAward(any())).thenAnswer((_) async {});
        when(
          repository.loadDashboard,
        ).thenAnswer((_) async => dashboard);
      },
      build: () => BadgesCubit(repository: repository),
      seed: () => BadgesState(
        status: BadgesStatus.loaded,
        awarded: [awardedBadge],
      ),
      act: (cubit) => cubit.acceptAward(awardedBadge),
      expect: () => [
        BadgesState(
          status: BadgesStatus.loaded,
          actionStatus: BadgeActionStatus.accepting,
          awarded: [awardedBadge],
        ),
        isA<BadgesState>()
            .having((state) => state.status, 'status', BadgesStatus.loaded)
            .having(
              (state) => state.actionStatus,
              'actionStatus',
              BadgeActionStatus.completed,
            )
            .having((state) => state.awarded, 'awarded', [awardedBadge])
            .having((state) => state.issued, 'issued', [issuedBadge]),
      ],
      verify: (_) {
        verify(() => repository.acceptAward(awardedBadge)).called(1);
        verify(repository.loadDashboard).called(1);
      },
    );

    blocTest<BadgesCubit, BadgesState>(
      'removeAward delegates then refreshes dashboard',
      setUp: () {
        when(() => repository.removeAward(any())).thenAnswer((_) async {});
        when(
          repository.loadDashboard,
        ).thenAnswer((_) async => dashboard);
      },
      build: () => BadgesCubit(repository: repository),
      seed: () => BadgesState(
        status: BadgesStatus.loaded,
        awarded: [awardedBadge],
      ),
      act: (cubit) => cubit.removeAward(awardedBadge),
      expect: () => [
        BadgesState(
          status: BadgesStatus.loaded,
          actionStatus: BadgeActionStatus.removing,
          awarded: [awardedBadge],
        ),
        isA<BadgesState>().having(
          (state) => state.actionStatus,
          'actionStatus',
          BadgeActionStatus.completed,
        ),
      ],
      verify: (_) {
        verify(() => repository.removeAward(awardedBadge)).called(1);
      },
    );

    blocTest<BadgesCubit, BadgesState>(
      'hideAward stores dismissal by award event id then refreshes dashboard',
      setUp: () {
        when(() => repository.hideAward(any())).thenAnswer((_) async {});
        when(
          repository.loadDashboard,
        ).thenAnswer(
          (_) async => const BadgeDashboardData(
            awarded: [],
            issued: [],
          ),
        );
      },
      build: () => BadgesCubit(repository: repository),
      seed: () => BadgesState(
        status: BadgesStatus.loaded,
        awarded: [awardedBadge],
      ),
      act: (cubit) => cubit.hideAward(awardedBadge),
      expect: () => [
        BadgesState(
          status: BadgesStatus.loaded,
          actionStatus: BadgeActionStatus.hiding,
          awarded: [awardedBadge],
        ),
        const BadgesState(
          status: BadgesStatus.loaded,
          actionStatus: BadgeActionStatus.completed,
        ),
      ],
      verify: (_) {
        verify(() => repository.hideAward(awardedBadge.awardEventId)).called(1);
      },
    );

    blocTest<BadgesCubit, BadgesState>(
      'emits action error when acceptAward fails',
      setUp: () {
        when(
          () => repository.acceptAward(any()),
        ).thenThrow(Exception('publish failed'));
      },
      build: () => BadgesCubit(repository: repository),
      seed: () => BadgesState(
        status: BadgesStatus.loaded,
        awarded: [awardedBadge],
      ),
      act: (cubit) => cubit.acceptAward(awardedBadge),
      expect: () => [
        BadgesState(
          status: BadgesStatus.loaded,
          actionStatus: BadgeActionStatus.accepting,
          awarded: [awardedBadge],
        ),
        BadgesState(
          status: BadgesStatus.loaded,
          actionStatus: BadgeActionStatus.error,
          awarded: [awardedBadge],
        ),
      ],
      errors: () => [isA<Exception>()],
    );
  });
}

BadgeAwardViewData _awardViewData() {
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
    ),
  );
}

IssuedBadgeViewData _issuedViewData() {
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
    recipients: [
      IssuedBadgeRecipientViewData(pubkey: recipientPubkey, isAccepted: true),
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
