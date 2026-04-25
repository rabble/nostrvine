import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invite_api_client/invite_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/invite_gate/invite_gate_bloc.dart';
import 'package:openvine/blocs/invite_gate/invite_gate_event.dart';
import 'package:openvine/blocs/invite_gate/invite_gate_state.dart';

class _MockInviteApiClient extends Mock implements InviteApiClient {}

void main() {
  group('InviteGateBloc', () {
    late _MockInviteApiClient mockInviteApiClient;

    setUp(() {
      mockInviteApiClient = _MockInviteApiClient();
    });

    InviteGateBloc buildBloc() {
      return InviteGateBloc(inviteApiClient: mockInviteApiClient);
    }

    blocTest<InviteGateBloc, InviteGateState>(
      'loads invite client config successfully',
      setUp: () {
        when(() => mockInviteApiClient.getClientConfig()).thenAnswer(
          (_) async => const InviteClientConfig(
            mode: OnboardingMode.inviteCodeRequired,
            supportEmail: 'support@divine.video',
          ),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const InviteGateConfigRequested()),
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

    blocTest<InviteGateBloc, InviteGateState>(
      'surfaces malformed invite codes immediately',
      build: buildBloc,
      act: (bloc) => bloc.add(const InviteGateCodeSubmitted('abc')),
      expect: () => [
        const InviteGateState(
          inviteCodeError: 'Enter an invite code like ABCD-EFGH.',
        ),
      ],
    );

    blocTest<InviteGateBloc, InviteGateState>(
      'grants access after a valid invite validation',
      setUp: () {
        when(
          () => mockInviteApiClient.validateCode('AB12-EF34'),
        ).thenAnswer(
          (_) async => const InviteValidationResult(
            valid: true,
            used: false,
            code: 'AB12-EF34',
          ),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const InviteGateCodeSubmitted('ab12ef34')),
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

    blocTest<InviteGateBloc, InviteGateState>(
      'stores creator metadata when reusable creator invite validates',
      setUp: () {
        when(
          () => mockInviteApiClient.validateCode('LELE-PONS'),
        ).thenAnswer(
          (_) async => const InviteValidationResult(
            valid: true,
            used: true,
            available: true,
            code: 'LELE-PONS',
            creatorSlug: 'lele-pons',
            creatorDisplayName: 'Lele Pons',
            remaining: 842,
          ),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const InviteGateCodeSubmitted('lele-pons')),
      expect: () => [
        const InviteGateState(isValidatingCode: true),
        isA<InviteGateState>()
            .having((state) => state.hasAccessGrant, 'hasAccessGrant', true)
            .having(
              (state) => state.accessGrant?.code,
              'accessGrant.code',
              'LELE-PONS',
            )
            .having(
              (state) => state.accessGrant?.creatorSlug,
              'accessGrant.creatorSlug',
              'lele-pons',
            )
            .having(
              (state) => state.accessGrant?.creatorDisplayName,
              'accessGrant.creatorDisplayName',
              'Lele Pons',
            )
            .having(
              (state) => state.accessGrant?.remaining,
              'accessGrant.remaining',
              842,
            ),
      ],
    );

    blocTest<InviteGateBloc, InviteGateState>(
      'maps used invite validations to invite code error state',
      setUp: () {
        when(
          () => mockInviteApiClient.validateCode('USED-0003'),
        ).thenAnswer(
          (_) async => const InviteValidationResult(
            valid: false,
            used: true,
            code: 'USED-0003',
          ),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const InviteGateCodeSubmitted('used0003')),
      expect: () => [
        const InviteGateState(isValidatingCode: true),
        const InviteGateState(
          inviteCodeError: 'That invite code has already been used or revoked.',
        ),
      ],
    );

    blocTest<InviteGateBloc, InviteGateState>(
      'maps unavailable creator codes to waitlist-friendly general error',
      setUp: () {
        when(
          () => mockInviteApiClient.validateCode('LELE-PONS'),
        ).thenAnswer(
          (_) async => const InviteValidationResult(
            valid: false,
            used: false,
            available: false,
            code: 'LELE-PONS',
            errorCode: 'creator_page_full',
            creatorSlug: 'lele-pons',
            creatorDisplayName: 'Lele Pons',
          ),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const InviteGateCodeSubmitted('lele-pons')),
      expect: () => [
        const InviteGateState(isValidatingCode: true),
        const InviteGateState(generalError: "This creator's invites are full"),
      ],
    );

    blocTest<InviteGateBloc, InviteGateState>(
      'keeps invalid invite codes editable',
      setUp: () {
        when(
          () => mockInviteApiClient.validateCode('NOPE-CODE'),
        ).thenAnswer(
          (_) async => const InviteValidationResult(
            valid: false,
            used: false,
            available: false,
            code: 'NOPE-CODE',
            errorCode: 'invite_invalid_format',
          ),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const InviteGateCodeSubmitted('nope-code')),
      expect: () => [
        const InviteGateState(isValidatingCode: true),
        const InviteGateState(
          inviteCodeError: 'That invite code does not look valid.',
        ),
      ],
    );

    blocTest<InviteGateBloc, InviteGateState>(
      'surfaces validation transport errors as general errors',
      setUp: () {
        when(
          () => mockInviteApiClient.validateCode('AB12-EF34'),
        ).thenThrow(
          const InviteApiException('Invite service unavailable'),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const InviteGateCodeSubmitted('ab12ef34')),
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
          () => mockInviteApiClient.validateCode('AB12-EF34'),
        ).thenAnswer((_) => completer.future);

        final bloc = buildBloc();
        bloc.add(const InviteGateCodeSubmitted('ab12ef34'));
        bloc.add(const InviteGateCodeSubmitted('ab12ef34'));

        await Future<void>.delayed(Duration.zero);

        verify(() => mockInviteApiClient.validateCode('AB12-EF34')).called(1);

        completer.complete(
          const InviteValidationResult(
            valid: true,
            used: false,
            code: 'AB12-EF34',
          ),
        );

        await Future<void>.delayed(Duration.zero);

        expect(bloc.state.hasAccessGrant, isTrue);
        expect(bloc.state.accessGrant?.code, 'AB12-EF34');

        await bloc.close();
      },
    );
  });
}
