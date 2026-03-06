import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/invite_gate/invite_gate_cubit.dart';
import 'package:openvine/blocs/invite_gate/invite_gate_state.dart';
import 'package:openvine/models/invite_models.dart';
import 'package:openvine/services/api_service.dart';
import 'package:openvine/services/invite_api_service.dart';

class _MockInviteApiService extends Mock implements InviteApiService {}

void main() {
  group('InviteGateCubit', () {
    late _MockInviteApiService mockInviteApiService;

    setUp(() {
      mockInviteApiService = _MockInviteApiService();
    });

    InviteGateCubit buildCubit() {
      return InviteGateCubit(inviteApiService: mockInviteApiService);
    }

    blocTest<InviteGateCubit, InviteGateState>(
      'loads invite client config successfully',
      setUp: () {
        when(() => mockInviteApiService.getClientConfig()).thenAnswer(
          (_) async => const InviteClientConfig(
            mode: OnboardingMode.inviteCodeRequired,
            supportEmail: 'support@divine.video',
          ),
        );
      },
      build: buildCubit,
      act: (cubit) => cubit.ensureConfigLoaded(),
      expect: () => [
        const InviteGateState(configStatus: InviteGateConfigStatus.loading),
        const InviteGateState(
          configStatus: InviteGateConfigStatus.success,
          config: InviteClientConfig(
            mode: OnboardingMode.inviteCodeRequired,
            supportEmail: 'support@divine.video',
          ),
        ),
      ],
    );

    blocTest<InviteGateCubit, InviteGateState>(
      'surfaces malformed invite codes immediately',
      build: buildCubit,
      act: (cubit) => cubit.validateCode('abc'),
      expect: () => [
        const InviteGateState(
          inviteCodeError: 'Enter an invite code like ABCD-EFGH.',
        ),
      ],
    );

    blocTest<InviteGateCubit, InviteGateState>(
      'grants access after a valid invite validation',
      setUp: () {
        when(
          () => mockInviteApiService.validateCode('AB12-EF34'),
        ).thenAnswer(
          (_) async => const InviteValidationResult(
            valid: true,
            used: false,
            code: 'AB12-EF34',
          ),
        );
      },
      build: buildCubit,
      act: (cubit) => cubit.validateCode('ab12ef34'),
      expect: () => [
        const InviteGateState(isValidatingCode: true),
        isA<InviteGateState>()
            .having(
              (state) => state.isValidatingCode,
              'isValidatingCode',
              false,
            )
            .having((state) => state.hasAccessGrant, 'hasAccessGrant', true)
            .having(
              (state) => state.accessGrant?.code,
              'accessGrant.code',
              'AB12-EF34',
            )
            .having((state) => state.inviteCodeError, 'inviteCodeError', isNull)
            .having((state) => state.generalError, 'generalError', isNull),
      ],
    );

    blocTest<InviteGateCubit, InviteGateState>(
      'maps used invite validations to invite code error state',
      setUp: () {
        when(
          () => mockInviteApiService.validateCode('USED-0003'),
        ).thenAnswer(
          (_) async => const InviteValidationResult(
            valid: false,
            used: true,
            code: 'USED-0003',
          ),
        );
      },
      build: buildCubit,
      act: (cubit) => cubit.validateCode('used0003'),
      expect: () => [
        const InviteGateState(isValidatingCode: true),
        const InviteGateState(
          inviteCodeError: 'That invite code has already been used or revoked.',
        ),
      ],
    );

    blocTest<InviteGateCubit, InviteGateState>(
      'surfaces validation transport errors as general errors',
      setUp: () {
        when(
          () => mockInviteApiService.validateCode('AB12-EF34'),
        ).thenThrow(const ApiException('Invite service unavailable'));
      },
      build: buildCubit,
      act: (cubit) => cubit.validateCode('ab12ef34'),
      expect: () => [
        const InviteGateState(isValidatingCode: true),
        const InviteGateState(generalError: 'Invite service unavailable'),
      ],
    );

    test(
      'ignores duplicate validation submissions while request is in flight',
      () async {
        final completer = Completer<InviteValidationResult>();
        when(
          () => mockInviteApiService.validateCode('AB12-EF34'),
        ).thenAnswer((_) => completer.future);

        final cubit = buildCubit();
        final first = cubit.validateCode('ab12ef34');
        final second = cubit.validateCode('ab12ef34');

        verify(() => mockInviteApiService.validateCode('AB12-EF34')).called(1);

        completer.complete(
          const InviteValidationResult(
            valid: true,
            used: false,
            code: 'AB12-EF34',
          ),
        );

        await Future.wait([first, second]);

        expect(cubit.state.hasAccessGrant, isTrue);
        expect(cubit.state.accessGrant?.code, 'AB12-EF34');

        await cubit.close();
      },
    );
  });
}
