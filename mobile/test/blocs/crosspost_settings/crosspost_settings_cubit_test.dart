import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/crosspost_settings/crosspost_settings_cubit.dart';
import 'package:openvine/services/crosspost_api_client.dart';

class _MockCrosspostApiClient extends Mock implements CrosspostApiClient {}

void main() {
  group(CrosspostSettingsCubit, () {
    late _MockCrosspostApiClient apiClient;

    const testPubkey = 'abc123def456';
    const loadedStatus = CrosspostStatus(
      crosspostEnabled: true,
      handle: 'testuser.divine.video',
      provisioningState: 'ready',
      did: 'did:plc:test123',
    );

    setUp(() {
      apiClient = _MockCrosspostApiClient();
    });

    group('initial state', () {
      test('is CrosspostSettingsState with initial status', () {
        when(
          () => apiClient.getStatus(testPubkey),
        ).thenAnswer((_) async => loadedStatus);
        final cubit = CrosspostSettingsCubit(
          apiClient: apiClient,
          pubkey: testPubkey,
        );
        expect(cubit.state.status, CrosspostSettingsStatus.loading);
        addTearDown(cubit.close);
      });
    });

    group('loadStatus', () {
      test('emits loaded state on successful status fetch', () async {
        when(
          () => apiClient.getStatus(testPubkey),
        ).thenAnswer((_) async => loadedStatus);

        final cubit = CrosspostSettingsCubit(
          apiClient: apiClient,
          pubkey: testPubkey,
        );
        addTearDown(cubit.close);

        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.status, CrosspostSettingsStatus.loaded);
        expect(cubit.state.enabled, isTrue);
        expect(cubit.state.handle, 'testuser.divine.video');
        expect(cubit.state.provisioningState, 'ready');
      });

      test('emits failure state when status fetch fails', () async {
        when(() => apiClient.getStatus(testPubkey)).thenAnswer(
          (_) async => throw const CrosspostApiException('Network error'),
        );

        final cubit = CrosspostSettingsCubit(
          apiClient: apiClient,
          pubkey: testPubkey,
        );
        addTearDown(cubit.close);

        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.status, CrosspostSettingsStatus.failure);
      });

      test('emits disabled state when 404 (no account link)', () async {
        when(() => apiClient.getStatus(testPubkey)).thenAnswer(
          (_) async => const CrosspostStatus(crosspostEnabled: false),
        );

        final cubit = CrosspostSettingsCubit(
          apiClient: apiClient,
          pubkey: testPubkey,
        );
        addTearDown(cubit.close);

        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.status, CrosspostSettingsStatus.loaded);
        expect(cubit.state.enabled, isFalse);
      });
    });

    group('toggleCrosspost', () {
      blocTest<CrosspostSettingsCubit, CrosspostSettingsState>(
        'emits loaded with enabled=false on successful toggle',
        setUp: () {
          when(
            () => apiClient.getStatus(testPubkey),
          ).thenAnswer((_) async => loadedStatus);
          when(
            () => apiClient.setCrosspost(pubkey: testPubkey, enabled: false),
          ).thenAnswer(
            (_) async => const CrosspostStatus(
              crosspostEnabled: false,
              handle: 'testuser.divine.video',
              provisioningState: 'ready',
            ),
          );
        },
        build: () =>
            CrosspostSettingsCubit(apiClient: apiClient, pubkey: testPubkey),
        act: (cubit) async {
          await Future<void>.delayed(Duration.zero);
          await cubit.toggleCrosspost(enabled: false);
        },
        skip: 2, // Skip loading and loaded from initial load
        expect: () => [
          const CrosspostSettingsState(
            status: CrosspostSettingsStatus.loaded,
            handle: 'testuser.divine.video',
            provisioningState: 'ready',
          ),
        ],
        verify: (cubit) => expect(cubit.state.enabled, isFalse),
      );

      blocTest<CrosspostSettingsCubit, CrosspostSettingsState>(
        'reverts to previous enabled value on toggle failure',
        setUp: () {
          when(
            () => apiClient.getStatus(testPubkey),
          ).thenAnswer((_) async => loadedStatus);
          when(
            () => apiClient.setCrosspost(pubkey: testPubkey, enabled: false),
          ).thenAnswer(
            (_) async => throw const CrosspostApiException('Server error'),
          );
        },
        build: () =>
            CrosspostSettingsCubit(apiClient: apiClient, pubkey: testPubkey),
        act: (cubit) async {
          await Future<void>.delayed(Duration.zero);
          await cubit.toggleCrosspost(enabled: false);
        },
        skip: 2,
        expect: () => const [
          CrosspostSettingsState(
            status: CrosspostSettingsStatus.failure,
            enabled: true,
            handle: 'testuser.divine.video',
            provisioningState: 'ready',
          ),
        ],
        errors: () => [isA<CrosspostApiException>()],
      );

      test('emits toggling state optimistically before API call', () async {
        final completer = Completer<CrosspostStatus>();
        when(
          () => apiClient.getStatus(testPubkey),
        ).thenAnswer((_) async => loadedStatus);
        when(
          () => apiClient.setCrosspost(pubkey: testPubkey, enabled: false),
        ).thenAnswer((_) => completer.future);

        final cubit = CrosspostSettingsCubit(
          apiClient: apiClient,
          pubkey: testPubkey,
        );
        addTearDown(cubit.close);
        await Future<void>.delayed(Duration.zero);

        // Start toggle but don't complete
        unawaited(cubit.toggleCrosspost(enabled: false));
        await Future<void>.delayed(Duration.zero);

        // Should be in toggling state with optimistic value
        expect(cubit.state.status, CrosspostSettingsStatus.toggling);
        expect(cubit.state.enabled, isFalse);

        // Complete the API call
        completer.complete(
          const CrosspostStatus(
            crosspostEnabled: false,
            handle: 'testuser.divine.video',
            provisioningState: 'ready',
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.status, CrosspostSettingsStatus.loaded);
        expect(cubit.state.enabled, isFalse);
      });
    });
  });
}
