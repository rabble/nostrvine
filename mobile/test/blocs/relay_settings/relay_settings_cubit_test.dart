// ABOUTME: Unit tests for RelaySettingsCubit — load snapshot, capability
// ABOUTME: fetch lifecycle, addRelay validation (scheme + insecure),
// ABOUTME: removeRelay, restoreDefaultRelay, retryConnection.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/blocs/relay_settings/relay_settings_cubit.dart';
import 'package:openvine/blocs/relay_settings/relay_settings_state.dart';
import 'package:openvine/services/relay_capability_service.dart';
import 'package:openvine/services/video_event_service.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockRelayCapabilityService extends Mock
    implements RelayCapabilityService {}

class _MockVideoEventService extends Mock implements VideoEventService {}

void main() {
  group(RelaySettingsCubit, () {
    late _MockNostrClient nostr;
    late _MockRelayCapabilityService capabilities;
    late _MockVideoEventService videos;

    setUp(() {
      nostr = _MockNostrClient();
      capabilities = _MockRelayCapabilityService();
      videos = _MockVideoEventService();
      when(() => nostr.configuredRelays).thenReturn(const []);
      when(() => nostr.connectedRelayCount).thenReturn(0);
      when(() => nostr.addRelay(any())).thenAnswer((_) async => true);
      when(() => nostr.removeRelay(any())).thenAnswer((_) async => true);
      when(nostr.forceReconnectAll).thenAnswer((_) async {});
      when(videos.resetAndResubscribeAll).thenAnswer((_) async {});
    });

    RelaySettingsCubit buildCubit() => RelaySettingsCubit(
      nostrClient: nostr,
      relayCapabilityService: capabilities,
      videoEventService: videos,
    );

    blocTest<RelaySettingsCubit, RelaySettingsState>(
      'load snapshots configured relays',
      setUp: () {
        when(() => nostr.configuredRelays).thenReturn([
          'wss://a.example',
          'wss://b.example',
        ]);
      },
      build: buildCubit,
      act: (cubit) => cubit.load(),
      expect: () => [
        const RelaySettingsState(
          relays: ['wss://a.example', 'wss://b.example'],
        ),
      ],
    );

    blocTest<RelaySettingsCubit, RelaySettingsState>(
      'fetchCapabilities emits loading then fetched',
      setUp: () {
        when(
          () => capabilities.getRelayCapabilities('wss://a.example'),
        ).thenAnswer(
          (_) async => RelayCapabilities(
            relayUrl: 'wss://a.example',
            supportedNips: const [1, 11],
            rawData: const {},
          ),
        );
      },
      build: buildCubit,
      act: (cubit) => cubit.fetchCapabilities('wss://a.example'),
      // `RelayCapabilities` doesn't extend Equatable, so use matchers
      // instead of concrete equality on the second emit.
      expect: () => [
        const RelaySettingsState(
          capabilities: {
            'wss://a.example': RelayCapabilityEntry(loading: true),
          },
        ),
        isA<RelaySettingsState>().having(
          (s) => s.capabilities['wss://a.example'],
          'fetched entry',
          isA<RelayCapabilityEntry>()
              .having((e) => e.loading, 'loading', isFalse)
              .having((e) => e.fetched, 'fetched', isTrue)
              .having(
                (e) => e.capabilities?.supportedNips,
                'supportedNips',
                [1, 11],
              ),
        ),
      ],
    );

    blocTest<RelaySettingsCubit, RelaySettingsState>(
      'fetchCapabilities short-circuits on second call',
      seed: () => const RelaySettingsState(
        capabilities: {
          'wss://a.example': RelayCapabilityEntry(fetched: true),
        },
      ),
      build: buildCubit,
      act: (cubit) => cubit.fetchCapabilities('wss://a.example'),
      expect: () => const <RelaySettingsState>[],
      verify: (_) {
        verifyNever(() => capabilities.getRelayCapabilities(any()));
      },
    );

    blocTest<RelaySettingsCubit, RelaySettingsState>(
      'fetchCapabilities surfaces service errors via addError + fetched=true',
      setUp: () {
        when(
          () => capabilities.getRelayCapabilities('wss://b.example'),
        ).thenThrow(StateError('nip-11 timed out'));
      },
      build: buildCubit,
      act: (cubit) => cubit.fetchCapabilities('wss://b.example'),
      expect: () => [
        const RelaySettingsState(
          capabilities: {
            'wss://b.example': RelayCapabilityEntry(loading: true),
          },
        ),
        const RelaySettingsState(
          capabilities: {
            'wss://b.example': RelayCapabilityEntry(fetched: true),
          },
        ),
      ],
      errors: () => [isA<StateError>()],
    );

    blocTest<RelaySettingsCubit, RelaySettingsState>(
      'addRelay rejects empty and non-ws schemes as invalidUrl',
      build: buildCubit,
      act: (cubit) async {
        expect(await cubit.addRelay(''), AddRelayOutcome.invalidUrl);
        expect(
          await cubit.addRelay('https://example.com'),
          AddRelayOutcome.invalidUrl,
        );
        expect(await cubit.addRelay('not a url'), AddRelayOutcome.invalidUrl);
      },
      expect: () => const <RelaySettingsState>[],
      verify: (_) {
        verifyNever(() => nostr.addRelay(any()));
      },
    );

    blocTest<RelaySettingsCubit, RelaySettingsState>(
      'addRelay accepts wss:// and re-snapshots relays',
      setUp: () {
        when(
          () => nostr.configuredRelays,
        ).thenReturn(['wss://added.example']);
      },
      build: buildCubit,
      act: (cubit) async {
        final outcome = await cubit.addRelay('wss://added.example');
        expect(outcome, AddRelayOutcome.added);
      },
      expect: () => [
        const RelaySettingsState(relays: ['wss://added.example']),
      ],
      verify: (_) {
        verify(() => nostr.addRelay('wss://added.example')).called(1);
      },
    );

    blocTest<RelaySettingsCubit, RelaySettingsState>(
      'addRelay returns failed when service returns false',
      setUp: () {
        when(() => nostr.addRelay(any())).thenAnswer((_) async => false);
      },
      build: buildCubit,
      act: (cubit) async {
        final outcome = await cubit.addRelay('wss://noop.example');
        expect(outcome, AddRelayOutcome.failed);
      },
      expect: () => const <RelaySettingsState>[],
    );

    blocTest<RelaySettingsCubit, RelaySettingsState>(
      'addRelay surfaces service throw via addError + failed outcome',
      setUp: () {
        when(() => nostr.addRelay(any())).thenThrow(StateError('boom'));
      },
      build: buildCubit,
      act: (cubit) async {
        expect(
          await cubit.addRelay('wss://throws.example'),
          AddRelayOutcome.failed,
        );
      },
      expect: () => const <RelaySettingsState>[],
      errors: () => [isA<StateError>()],
    );

    blocTest<RelaySettingsCubit, RelaySettingsState>(
      'removeRelay re-snapshots on success',
      seed: () => const RelaySettingsState(
        relays: ['wss://a.example', 'wss://b.example'],
      ),
      setUp: () {
        when(() => nostr.configuredRelays).thenReturn(['wss://a.example']);
      },
      build: buildCubit,
      act: (cubit) async {
        final outcome = await cubit.removeRelay('wss://b.example');
        expect(outcome, RemoveRelayOutcome.removed);
      },
      expect: () => [
        const RelaySettingsState(relays: ['wss://a.example']),
      ],
      verify: (_) {
        verify(() => nostr.removeRelay('wss://b.example')).called(1);
      },
    );

    blocTest<RelaySettingsCubit, RelaySettingsState>(
      'removeRelay returns failed when service returns false',
      setUp: () {
        when(() => nostr.removeRelay(any())).thenAnswer((_) async => false);
      },
      build: buildCubit,
      act: (cubit) async {
        expect(
          await cubit.removeRelay('wss://a.example'),
          RemoveRelayOutcome.failed,
        );
      },
      expect: () => const <RelaySettingsState>[],
    );

    blocTest<RelaySettingsCubit, RelaySettingsState>(
      'restoreDefaultRelay delegates to addRelay(defaultUrl)',
      setUp: () {
        when(() => nostr.configuredRelays).thenReturn(['wss://default']);
      },
      build: buildCubit,
      act: (cubit) async {
        expect(
          await cubit.restoreDefaultRelay(),
          RestoreDefaultRelayOutcome.restored,
        );
      },
      verify: (_) {
        verify(() => nostr.addRelay(any())).called(1);
      },
    );

    blocTest<RelaySettingsCubit, RelaySettingsState>(
      'retryConnection emits connected with count when relays reconnect',
      setUp: () {
        when(() => nostr.connectedRelayCount).thenReturn(2);
      },
      build: buildCubit,
      act: (cubit) async {
        final outcome = await cubit.retryConnection();
        expect(outcome.kind, RetryConnectionOutcomeKind.connected);
        expect(outcome.connectedCount, 2);
      },
      expect: () => const <RelaySettingsState>[],
      verify: (_) {
        verify(nostr.forceReconnectAll).called(1);
        verify(videos.resetAndResubscribeAll).called(1);
      },
    );

    blocTest<RelaySettingsCubit, RelaySettingsState>(
      'retryConnection emits notConnected when count is zero',
      build: buildCubit,
      act: (cubit) async {
        final outcome = await cubit.retryConnection();
        expect(outcome.kind, RetryConnectionOutcomeKind.notConnected);
      },
      verify: (_) {
        verifyNever(videos.resetAndResubscribeAll);
      },
    );

    blocTest<RelaySettingsCubit, RelaySettingsState>(
      'retryConnection emits failed and addError on service throw',
      setUp: () {
        when(nostr.forceReconnectAll).thenThrow(StateError('nope'));
      },
      build: buildCubit,
      act: (cubit) async {
        final outcome = await cubit.retryConnection();
        expect(outcome.kind, RetryConnectionOutcomeKind.failed);
      },
      errors: () => [isA<StateError>()],
    );
  });
}
