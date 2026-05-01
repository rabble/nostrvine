// ABOUTME: Unit tests for InviteStatusCubit

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invite_api_client/invite_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/invite_status/invite_status_cubit.dart';

class _MockInviteApiClient extends Mock implements InviteApiClient {}

void main() {
  group(InviteStatusCubit, () {
    late _MockInviteApiClient mockInviteApiClient;

    const testStatus = InviteStatus(
      canInvite: true,
      remaining: 3,
      total: 5,
      codes: [
        InviteCode(code: 'AB23-EF7K', claimed: false),
        InviteCode(
          code: 'HN4P-QR56',
          claimed: true,
          claimedBy:
              'aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa1',
        ),
      ],
    );

    setUp(() {
      mockInviteApiClient = _MockInviteApiClient();
    });

    InviteStatusCubit buildCubit() =>
        InviteStatusCubit(inviteApiClient: mockInviteApiClient);

    test('initial state is correct', () {
      final cubit = buildCubit();
      expect(cubit.state.status, equals(InviteStatusLoadingStatus.initial));
      expect(cubit.state.inviteStatus, isNull);
      expect(cubit.state.hasUnclaimedCodes, isFalse);
      expect(cubit.state.unclaimedCount, equals(0));
      expect(cubit.state.hasAvailableInvites, isFalse);
      expect(cubit.state.availableInviteCount, equals(0));
    });

    blocTest<InviteStatusCubit, InviteStatusState>(
      'load emits loading then loaded with invite status',
      setUp: () {
        when(
          () => mockInviteApiClient.getInviteStatus(),
        ).thenAnswer((_) async => testStatus);
      },
      build: buildCubit,
      act: (cubit) => cubit.load(),
      expect: () => [
        const InviteStatusState(status: InviteStatusLoadingStatus.loading),
        const InviteStatusState(
          status: InviteStatusLoadingStatus.loaded,
          inviteStatus: testStatus,
        ),
      ],
    );

    blocTest<InviteStatusCubit, InviteStatusState>(
      'load emits loading then error on failure',
      setUp: () {
        when(
          () => mockInviteApiClient.getInviteStatus(),
        ).thenThrow(Exception('network error'));
      },
      build: buildCubit,
      act: (cubit) => cubit.load(),
      expect: () => [
        const InviteStatusState(status: InviteStatusLoadingStatus.loading),
        const InviteStatusState(status: InviteStatusLoadingStatus.error),
      ],
      errors: () => [isA<Exception>()],
    );

    blocTest<InviteStatusCubit, InviteStatusState>(
      'load does not re-fetch if already loading',
      setUp: () {
        when(
          () => mockInviteApiClient.getInviteStatus(),
        ).thenAnswer((_) async => testStatus);
      },
      build: buildCubit,
      seed: () =>
          const InviteStatusState(status: InviteStatusLoadingStatus.loading),
      act: (cubit) => cubit.load(),
      expect: () => <InviteStatusState>[],
      verify: (_) {
        verifyNever(() => mockInviteApiClient.getInviteStatus());
      },
    );

    blocTest<InviteStatusCubit, InviteStatusState>(
      'load after error re-fetches successfully',
      setUp: () {
        when(
          () => mockInviteApiClient.getInviteStatus(),
        ).thenAnswer((_) async => testStatus);
      },
      build: buildCubit,
      seed: () =>
          const InviteStatusState(status: InviteStatusLoadingStatus.error),
      act: (cubit) => cubit.load(),
      expect: () => [
        const InviteStatusState(status: InviteStatusLoadingStatus.loading),
        const InviteStatusState(
          status: InviteStatusLoadingStatus.loaded,
          inviteStatus: testStatus,
        ),
      ],
    );

    blocTest<InviteStatusCubit, InviteStatusState>(
      'generateInvite creates one code then reloads invite status',
      setUp: () {
        when(
          () => mockInviteApiClient.generateInvite(),
        ).thenAnswer(
          (_) async => const GenerateInviteResult(
            code: 'WX56-3MKT',
            remaining: 4,
          ),
        );
        when(
          () => mockInviteApiClient.getInviteStatus(),
        ).thenAnswer((_) async => testStatus);
      },
      build: buildCubit,
      act: (cubit) => cubit.generateInvite(),
      expect: () => [
        const InviteStatusState(status: InviteStatusLoadingStatus.loading),
        const InviteStatusState(
          status: InviteStatusLoadingStatus.loaded,
          inviteStatus: testStatus,
        ),
      ],
      verify: (_) {
        verify(() => mockInviteApiClient.generateInvite()).called(1);
        verify(() => mockInviteApiClient.getInviteStatus()).called(1);
      },
    );

    group('state computed properties', () {
      test('hasUnclaimedCodes returns true when unclaimed exist', () {
        const state = InviteStatusState(
          status: InviteStatusLoadingStatus.loaded,
          inviteStatus: InviteStatus(
            canInvite: true,
            remaining: 1,
            total: 1,
            codes: [InviteCode(code: 'AAAA-BBBB', claimed: false)],
          ),
        );
        expect(state.hasUnclaimedCodes, isTrue);
        expect(state.unclaimedCount, equals(1));
        expect(state.hasAvailableInvites, isTrue);
        expect(state.availableInviteCount, equals(1));
      });

      test('hasUnclaimedCodes returns false when all claimed', () {
        const state = InviteStatusState(
          status: InviteStatusLoadingStatus.loaded,
          inviteStatus: InviteStatus(
            canInvite: true,
            remaining: 0,
            total: 1,
            codes: [InviteCode(code: 'AAAA-BBBB', claimed: true)],
          ),
        );
        expect(state.hasUnclaimedCodes, isFalse);
        expect(state.unclaimedCount, equals(0));
        expect(state.hasAvailableInvites, isFalse);
        expect(state.availableInviteCount, equals(0));
      });

      test('hasAvailableInvites includes remaining invite capacity', () {
        const state = InviteStatusState(
          status: InviteStatusLoadingStatus.loaded,
          inviteStatus: InviteStatus(
            canInvite: true,
            remaining: 5,
            total: 5,
            codes: [],
          ),
        );
        expect(state.hasUnclaimedCodes, isFalse);
        expect(state.unclaimedCount, equals(0));
        expect(state.hasAvailableInvites, isTrue);
        expect(state.availableInviteCount, equals(5));
      });
    });
  });
}
