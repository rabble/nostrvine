import 'package:flutter_test/flutter_test.dart';
import 'package:invite_api_client/invite_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/invite_availability.dart';
import 'package:openvine/repositories/invite_availability_repository.dart';

class _MockInviteApiClient extends Mock implements InviteApiClient {}

void main() {
  group(InviteAvailabilityRepository, () {
    late _MockInviteApiClient client;

    setUp(() {
      client = _MockInviteApiClient();
    });

    test('loads invite_code_required as enabled once per session', () async {
      var calls = 0;
      when(() => client.getClientConfig()).thenAnswer((_) async {
        calls += 1;
        return const InviteClientConfig(
          mode: OnboardingMode.inviteCodeRequired,
          supportEmail: 'support@divine.video',
        );
      });

      final repository = InviteAvailabilityRepository(client: client);
      addTearDown(repository.dispose);

      final first = await repository.loadOnce();
      final second = await repository.loadOnce();

      expect(first.isEnabled, isTrue);
      expect(second.isEnabled, isTrue);
      expect(first.serverMode, OnboardingMode.inviteCodeRequired);
      expect(calls, 1);
    });

    test('loads open as disabled', () async {
      when(() => client.getClientConfig()).thenAnswer(
        (_) async => const InviteClientConfig(
          mode: OnboardingMode.open,
          supportEmail: 'support@divine.video',
        ),
      );

      final repository = InviteAvailabilityRepository(client: client);
      addTearDown(repository.dispose);

      final state = await repository.loadOnce();
      expect(state.hasResolved, isTrue);
      expect(state.isEnabled, isFalse);
    });

    test('defaults to enabled when client config fails', () async {
      when(
        () => client.getClientConfig(),
      ).thenThrow(const InviteApiException('unavailable'));

      final repository = InviteAvailabilityRepository(client: client);
      addTearDown(repository.dispose);

      final state = await repository.loadOnce();
      expect(state.hasResolved, isTrue);
      expect(state.serverMode, isNull);
      expect(state.isEnabled, isTrue);
    });

    test('does not refetch after a failed load', () async {
      var calls = 0;
      when(() => client.getClientConfig()).thenAnswer((_) async {
        calls += 1;
        throw const InviteApiException('unavailable');
      });

      final repository = InviteAvailabilityRepository(client: client);
      addTearDown(repository.dispose);

      await repository.loadOnce();
      await repository.loadOnce();
      expect(calls, 1);
    });

    test(
      'applies a developer override without calling the server again',
      () async {
        when(() => client.getClientConfig()).thenAnswer(
          (_) async => const InviteClientConfig(
            mode: OnboardingMode.inviteCodeRequired,
            supportEmail: 'support@divine.video',
          ),
        );

        final repository = InviteAvailabilityRepository(client: client);
        addTearDown(repository.dispose);
        await repository.loadOnce();
        clearInteractions(client);

        repository.setOverride(InviteAvailabilityOverride.forceDisabled);
        expect(repository.current.isEnabled, isFalse);
        expect(
          repository.current.developerOverride,
          InviteAvailabilityOverride.forceDisabled,
        );
        verifyNever(() => client.getClientConfig());
      },
    );
  });
}
