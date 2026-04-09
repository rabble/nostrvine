// ABOUTME: Unit tests for InviteStatusCubit

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/invite_status/invite_status_cubit.dart';
import 'package:openvine/models/invite_models.dart';
import 'package:openvine/services/invite_api_service.dart';

class _MockInviteApiService extends Mock implements InviteApiService {}

void main() {
  group(InviteStatusCubit, () {
    late _MockInviteApiService mockInviteApiService;

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
      mockInviteApiService = _MockInviteApiService();
    });

    InviteStatusCubit buildCubit() => InviteStatusCubit(
      inviteApiService: mockInviteApiService,
    );

    test('initial state is correct', () {
      final cubit = buildCubit();
      expect(cubit.state.status, equals(InviteStatusLoadingStatus.initial));
      expect(cubit.state.inviteStatus, isNull);
      expect(cubit.state.hasUnclaimedCodes, isFalse);
      expect(cubit.state.unclaimedCount, equals(0));
    });

    blocTest<InviteStatusCubit, InviteStatusState>(
      'load emits loading then loaded with invite status',
      setUp: () {
        when(
          () => mockInviteApiService.getInviteStatus(),
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
          () => mockInviteApiService.getInviteStatus(),
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
          () => mockInviteApiService.getInviteStatus(),
        ).thenAnswer((_) async => testStatus);
      },
      build: buildCubit,
      seed: () => const InviteStatusState(
        status: InviteStatusLoadingStatus.loading,
      ),
      act: (cubit) => cubit.load(),
      expect: () => <InviteStatusState>[],
      verify: (_) {
        verifyNever(() => mockInviteApiService.getInviteStatus());
      },
    );

    blocTest<InviteStatusCubit, InviteStatusState>(
      'load after error re-fetches successfully',
      setUp: () {
        when(
          () => mockInviteApiService.getInviteStatus(),
        ).thenAnswer((_) async => testStatus);
      },
      build: buildCubit,
      seed: () => const InviteStatusState(
        status: InviteStatusLoadingStatus.error,
      ),
      act: (cubit) => cubit.load(),
      expect: () => [
        const InviteStatusState(status: InviteStatusLoadingStatus.loading),
        const InviteStatusState(
          status: InviteStatusLoadingStatus.loaded,
          inviteStatus: testStatus,
        ),
      ],
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
      });
    });
  });
}
