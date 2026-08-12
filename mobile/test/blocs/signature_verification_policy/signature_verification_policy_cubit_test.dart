// ABOUTME: Tests for SignatureVerificationPolicyCubit persistence boundary.
// ABOUTME: Keeps signature-policy UI from reaching preference services directly.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/signature_verification_policy/signature_verification_policy_cubit.dart';
import 'package:openvine/models/nostr_signature_verification_policy.dart';
import 'package:openvine/services/nostr_signature_verification_preference_service.dart';

class _MockPreferenceService extends Mock
    implements NostrSignatureVerificationPreferenceService {}

void main() {
  setUpAll(() {
    registerFallbackValue(NostrSignatureVerificationPolicy.all);
  });

  group('SignatureVerificationPolicyCubit', () {
    late _MockPreferenceService service;
    late int changeNotifications;

    setUp(() {
      service = _MockPreferenceService();
      changeNotifications = 0;
      when(
        () => service.currentPolicy,
      ).thenReturn(NostrSignatureVerificationPolicy.all);
      when(() => service.setPolicy(any())).thenAnswer((_) async {});
    });

    SignatureVerificationPolicyCubit buildCubit() {
      return SignatureVerificationPolicyCubit(
        preferenceService: service,
        onPolicyChanged: () => changeNotifications++,
      );
    }

    test('starts from the persisted policy', () {
      when(
        () => service.currentPolicy,
      ).thenReturn(NostrSignatureVerificationPolicy.nonDivineRelays);

      final cubit = buildCubit();
      addTearDown(cubit.close);

      expect(cubit.state, NostrSignatureVerificationPolicy.nonDivineRelays);
    });

    blocTest<
      SignatureVerificationPolicyCubit,
      NostrSignatureVerificationPolicy
    >(
      'persists a changed policy and notifies Riverpod consumers',
      build: buildCubit,
      act: (cubit) =>
          cubit.setPolicy(NostrSignatureVerificationPolicy.untrustedRelays),
      expect: () => [NostrSignatureVerificationPolicy.untrustedRelays],
      verify: (_) {
        verify(
          () => service.setPolicy(
            NostrSignatureVerificationPolicy.untrustedRelays,
          ),
        ).called(1);
        expect(changeNotifications, 1);
      },
    );

    blocTest<
      SignatureVerificationPolicyCubit,
      NostrSignatureVerificationPolicy
    >(
      'does not persist or notify when the policy is unchanged',
      build: buildCubit,
      act: (cubit) => cubit.setPolicy(NostrSignatureVerificationPolicy.all),
      expect: () => <NostrSignatureVerificationPolicy>[],
      verify: (_) {
        verifyNever(() => service.setPolicy(any()));
        expect(changeNotifications, 0);
      },
    );

    blocTest<
      SignatureVerificationPolicyCubit,
      NostrSignatureVerificationPolicy
    >(
      'reverts optimistic state when persistence fails',
      setUp: () {
        when(
          () => service.setPolicy(any()),
        ).thenThrow(Exception('write failed'));
      },
      build: buildCubit,
      act: (cubit) =>
          cubit.setPolicy(NostrSignatureVerificationPolicy.nonDivineRelays),
      expect: () => [
        NostrSignatureVerificationPolicy.nonDivineRelays,
        NostrSignatureVerificationPolicy.all,
      ],
      verify: (_) => expect(changeNotifications, 0),
    );
  });
}
