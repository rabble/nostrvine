import 'package:badge_repository/badge_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/blocs/badges/badge_detail_cubit.dart';

class _MockBadgeRepository extends Mock implements BadgeRepository {}

void main() {
  group(BadgeDetailCubit, () {
    late _MockBadgeRepository repository;

    setUpAll(() {
      registerFallbackValue(const BadgeCoordinate(pubkey: '', identifier: ''));
      registerFallbackValue(BadgeAwardViewData(award: _award()));
    });

    setUp(() {
      repository = _MockBadgeRepository();
    });

    BadgeDetailCubit buildCubit() => BadgeDetailCubit(
      repository: repository,
      coordinate: _coordinate,
    );

    blocTest<BadgeDetailCubit, BadgeDetailState>(
      'load emits loading then the loaded badge',
      setUp: () {
        when(
          () => repository.loadBadgeDetail(any()),
        ).thenAnswer((_) async => _detail(definition: _definition()));
      },
      build: buildCubit,
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<BadgeDetailState>().having(
          (state) => state.status,
          'status',
          BadgeDetailStatus.loading,
        ),
        isA<BadgeDetailState>()
            .having((state) => state.status, 'status', BadgeDetailStatus.loaded)
            .having(
              (state) => state.detail?.definition?.name,
              'name',
              'Scene Stealer',
            )
            .having((state) => state.isMissing, 'isMissing', isFalse),
      ],
    );

    blocTest<BadgeDetailCubit, BadgeDetailState>(
      'load flags a badge with no definition event as missing',
      setUp: () {
        when(
          () => repository.loadBadgeDetail(any()),
        ).thenAnswer((_) async => _detail());
      },
      build: buildCubit,
      act: (cubit) => cubit.load(),
      skip: 1,
      expect: () => [
        isA<BadgeDetailState>().having(
          (state) => state.isMissing,
          'isMissing',
          isTrue,
        ),
      ],
    );

    blocTest<BadgeDetailCubit, BadgeDetailState>(
      'load emits failure when the lookup throws',
      setUp: () {
        when(
          () => repository.loadBadgeDetail(any()),
        ).thenThrow(Exception('relay unavailable'));
      },
      build: buildCubit,
      act: (cubit) => cubit.load(),
      skip: 1,
      expect: () => [
        isA<BadgeDetailState>().having(
          (state) => state.status,
          'status',
          BadgeDetailStatus.failure,
        ),
      ],
      errors: () => [isA<Exception>()],
    );

    blocTest<BadgeDetailCubit, BadgeDetailState>(
      'award publishes for the given recipients then reloads',
      setUp: () {
        when(
          () => repository.awardBadge(
            coordinate: any(named: 'coordinate'),
            recipientPubkeys: any(named: 'recipientPubkeys'),
          ),
        ).thenAnswer((_) async => _award());
        when(
          () => repository.loadBadgeDetail(any()),
        ).thenAnswer((_) async => _detail(definition: _definition()));
      },
      build: buildCubit,
      act: (cubit) => cubit.award([_pubkey(2)]),
      expect: () => [
        isA<BadgeDetailState>().having(
          (state) => state.actionStatus,
          'actionStatus',
          BadgeDetailActionStatus.awarding,
        ),
        isA<BadgeDetailState>().having(
          (state) => state.actionStatus,
          'actionStatus',
          BadgeDetailActionStatus.completed,
        ),
      ],
      verify: (_) {
        verify(
          () => repository.awardBadge(
            coordinate: _coordinate,
            recipientPubkeys: [_pubkey(2)],
          ),
        ).called(1);
      },
    );

    blocTest<BadgeDetailCubit, BadgeDetailState>(
      'award reports a publish failure',
      setUp: () {
        when(
          () => repository.awardBadge(
            coordinate: any(named: 'coordinate'),
            recipientPubkeys: any(named: 'recipientPubkeys'),
          ),
        ).thenThrow(Exception('no relay accepted'));
      },
      build: buildCubit,
      act: (cubit) => cubit.award([_pubkey(2)]),
      skip: 1,
      expect: () => [
        isA<BadgeDetailState>().having(
          (state) => state.actionStatus,
          'actionStatus',
          BadgeDetailActionStatus.failure,
        ),
      ],
      errors: () => [isA<Exception>()],
    );

    blocTest<BadgeDetailCubit, BadgeDetailState>(
      'acceptAward pins the viewer award then reloads',
      setUp: () {
        when(() => repository.acceptAward(any())).thenAnswer((_) async {});
        when(() => repository.loadBadgeDetail(any())).thenAnswer(
          (_) async => _detail(
            definition: _definition(),
            viewerAward: BadgeAwardViewData(award: _award()),
          ),
        );
      },
      build: buildCubit,
      act: (cubit) async {
        await cubit.load();
        await cubit.acceptAward();
      },
      skip: 2,
      expect: () => [
        isA<BadgeDetailState>().having(
          (state) => state.actionStatus,
          'actionStatus',
          BadgeDetailActionStatus.accepting,
        ),
        isA<BadgeDetailState>().having(
          (state) => state.actionStatus,
          'actionStatus',
          BadgeDetailActionStatus.completed,
        ),
      ],
      verify: (_) => verify(() => repository.acceptAward(any())).called(1),
    );

    blocTest<BadgeDetailCubit, BadgeDetailState>(
      'removeAward unpins the viewer award then reloads',
      setUp: () {
        when(() => repository.removeAward(any())).thenAnswer((_) async {});
        when(() => repository.loadBadgeDetail(any())).thenAnswer(
          (_) async => _detail(
            definition: _definition(),
            viewerAward: BadgeAwardViewData(award: _award(), isAccepted: true),
          ),
        );
      },
      build: buildCubit,
      act: (cubit) async {
        await cubit.load();
        await cubit.removeAward();
      },
      skip: 2,
      expect: () => [
        isA<BadgeDetailState>().having(
          (state) => state.actionStatus,
          'actionStatus',
          BadgeDetailActionStatus.removing,
        ),
        isA<BadgeDetailState>().having(
          (state) => state.actionStatus,
          'actionStatus',
          BadgeDetailActionStatus.completed,
        ),
      ],
      verify: (_) => verify(() => repository.removeAward(any())).called(1),
    );

    blocTest<BadgeDetailCubit, BadgeDetailState>(
      'deleteBadge publishes the request and does not reload',
      setUp: () {
        when(() => repository.deleteBadge(any())).thenAnswer((_) async {});
      },
      build: buildCubit,
      act: (cubit) => cubit.deleteBadge(),
      expect: () => [
        isA<BadgeDetailState>().having(
          (state) => state.actionStatus,
          'actionStatus',
          BadgeDetailActionStatus.deleting,
        ),
        isA<BadgeDetailState>().having(
          (state) => state.actionStatus,
          'actionStatus',
          BadgeDetailActionStatus.deleted,
        ),
      ],
      verify: (_) {
        verify(() => repository.deleteBadge(_coordinate)).called(1);
        verifyNever(() => repository.loadBadgeDetail(any()));
      },
    );

    blocTest<BadgeDetailCubit, BadgeDetailState>(
      'deleteBadge reports a failed request',
      setUp: () {
        when(
          () => repository.deleteBadge(any()),
        ).thenThrow(Exception('no relay accepted'));
      },
      build: buildCubit,
      act: (cubit) => cubit.deleteBadge(),
      skip: 1,
      expect: () => [
        isA<BadgeDetailState>().having(
          (state) => state.actionStatus,
          'actionStatus',
          BadgeDetailActionStatus.failure,
        ),
      ],
      errors: () => [isA<Exception>()],
    );

    blocTest<BadgeDetailCubit, BadgeDetailState>(
      'deleteBadge separates an outright relay refusal from other failures',
      setUp: () {
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
      },
      build: buildCubit,
      act: (cubit) => cubit.deleteBadge(),
      skip: 1,
      expect: () => [
        isA<BadgeDetailState>().having(
          (state) => state.actionStatus,
          'actionStatus',
          BadgeDetailActionStatus.deleteRejected,
        ),
      ],
      errors: () => [isA<BadgePublishException>()],
    );

    blocTest<BadgeDetailCubit, BadgeDetailState>(
      'deleteBadge reports a publish that no relay answered as a failure',
      setUp: () {
        when(() => repository.deleteBadge(any())).thenThrow(
          const BadgePublishException(
            'no relay responded',
            outcome: PublishOutcome(
              eventId: 'deadbeef',
              acceptedBy: [],
              rejectedBy: {},
              noResponseFrom: ['wss://relay.divine.video'],
            ),
          ),
        );
      },
      build: buildCubit,
      act: (cubit) => cubit.deleteBadge(),
      skip: 1,
      expect: () => [
        isA<BadgeDetailState>().having(
          (state) => state.actionStatus,
          'actionStatus',
          BadgeDetailActionStatus.failure,
        ),
      ],
      errors: () => [isA<BadgePublishException>()],
    );

    blocTest<BadgeDetailCubit, BadgeDetailState>(
      'acceptAward does nothing when the viewer has no award',
      build: buildCubit,
      act: (cubit) => cubit.acceptAward(),
      expect: () => <BadgeDetailState>[],
      verify: (_) => verifyNever(() => repository.acceptAward(any())),
    );

    blocTest<BadgeDetailCubit, BadgeDetailState>(
      'removeAward does nothing when the viewer has no award',
      build: buildCubit,
      act: (cubit) => cubit.removeAward(),
      expect: () => <BadgeDetailState>[],
      verify: (_) => verifyNever(() => repository.removeAward(any())),
    );
  });
}

const _coordinate = BadgeCoordinate(
  pubkey: '0000000000000000000000000000000000000000000000000000000000000065',
  identifier: 'scene-stealer',
);

BadgeDetailData _detail({
  Nip58BadgeDefinition? definition,
  BadgeAwardViewData? viewerAward,
}) {
  return BadgeDetailData(
    coordinate: _coordinate,
    definition: definition,
    recipients: const [],
    isOwner: true,
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
