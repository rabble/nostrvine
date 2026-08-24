import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invite_api_client/invite_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/invite_availability/invite_availability_cubit.dart';
import 'package:openvine/models/invite_availability.dart';
import 'package:openvine/repositories/invite_availability_repository.dart';

class _MockInviteApiClient extends Mock implements InviteApiClient {}

void main() {
  group(InviteAvailabilityCubit, () {
    late _MockInviteApiClient client;
    late InviteAvailabilityRepository repository;

    setUp(() {
      client = _MockInviteApiClient();
      repository = InviteAvailabilityRepository(client: client);
    });

    tearDown(() {
      repository.dispose();
    });

    blocTest<InviteAvailabilityCubit, InviteAvailabilityState>(
      'loads a server-enabled value',
      setUp: () {
        when(() => client.getClientConfig()).thenAnswer(
          (_) async => const InviteClientConfig(
            mode: OnboardingMode.inviteCodeRequired,
            supportEmail: 'support@divine.video',
          ),
        );
      },
      build: () => InviteAvailabilityCubit(repository: repository),
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<InviteAvailabilityState>()
            .having((s) => s.hasResolved, 'hasResolved', isTrue)
            .having((s) => s.isEnabled, 'isEnabled', isTrue)
            .having(
              (s) => s.serverMode,
              'serverMode',
              OnboardingMode.inviteCodeRequired,
            ),
      ],
    );

    blocTest<InviteAvailabilityCubit, InviteAvailabilityState>(
      'loads a server-disabled value',
      setUp: () {
        when(() => client.getClientConfig()).thenAnswer(
          (_) async => const InviteClientConfig(
            mode: OnboardingMode.open,
            supportEmail: 'support@divine.video',
          ),
        );
      },
      build: () => InviteAvailabilityCubit(repository: repository),
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<InviteAvailabilityState>()
            .having((s) => s.hasResolved, 'hasResolved', isTrue)
            .having((s) => s.isEnabled, 'isEnabled', isFalse)
            .having((s) => s.serverMode, 'serverMode', OnboardingMode.open),
      ],
    );

    blocTest<InviteAvailabilityCubit, InviteAvailabilityState>(
      'defaults to disabled when configuration is unavailable',
      setUp: () {
        when(
          () => client.getClientConfig(),
        ).thenThrow(const InviteApiException('down'));
      },
      build: () => InviteAvailabilityCubit(repository: repository),
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<InviteAvailabilityState>()
            .having((s) => s.hasResolved, 'hasResolved', isTrue)
            .having((s) => s.isEnabled, 'isEnabled', isFalse)
            .having((s) => s.serverMode, 'serverMode', isNull),
      ],
    );

    blocTest<InviteAvailabilityCubit, InviteAvailabilityState>(
      'switches the running override immediately',
      build: () {
        final seeded = InviteAvailabilityRepository(
          client: client,
          seed: const InviteAvailabilityState(
            hasResolved: true,
            serverMode: OnboardingMode.inviteCodeRequired,
          ),
        );
        addTearDown(seeded.dispose);
        return InviteAvailabilityCubit(repository: seeded);
      },
      act: (cubit) {
        cubit.setOverride(InviteAvailabilityOverride.forceDisabled);
        cubit.setOverride(InviteAvailabilityOverride.forceEnabled);
        cubit.setOverride(InviteAvailabilityOverride.useServer);
      },
      expect: () => [
        isA<InviteAvailabilityState>().having(
          (s) => s.isEnabled,
          'forceDisabled',
          isFalse,
        ),
        isA<InviteAvailabilityState>().having(
          (s) => s.isEnabled,
          'forceEnabled',
          isTrue,
        ),
        isA<InviteAvailabilityState>().having(
          (s) => s.isEnabled,
          'useServer',
          isTrue,
        ),
      ],
    );
  });
}
