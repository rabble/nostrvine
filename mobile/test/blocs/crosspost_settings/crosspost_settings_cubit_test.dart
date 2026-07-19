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
      username: 'testuser',
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
          () => apiClient.getStatus(),
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
          () => apiClient.getStatus(),
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
        when(() => apiClient.getStatus()).thenAnswer(
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
        when(() => apiClient.getStatus()).thenAnswer(
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
            () => apiClient.getStatus(),
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
            username: 'testuser',
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
            () => apiClient.getStatus(),
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
            username: 'testuser',
            handle: 'testuser.divine.video',
            provisioningState: 'ready',
            error: CrosspostSettingsError.generic,
            attempt: 1,
          ),
        ],
        errors: () => [isA<CrosspostApiException>()],
      );

      blocTest<CrosspostSettingsCubit, CrosspostSettingsState>(
        'short-circuits to usernameNotClaimed when enabling without a username',
        setUp: () {
          when(() => apiClient.getStatus()).thenAnswer(
            (_) async => const CrosspostStatus(crosspostEnabled: false),
          );
        },
        build: () =>
            CrosspostSettingsCubit(apiClient: apiClient, pubkey: testPubkey),
        act: (cubit) async {
          await Future<void>.delayed(Duration.zero);
          await cubit.toggleCrosspost(enabled: true);
        },
        skip: 1,
        expect: () => const [
          CrosspostSettingsState(
            status: CrosspostSettingsStatus.failure,
            error: CrosspostSettingsError.usernameNotClaimed,
            attempt: 1,
          ),
        ],
        verify: (_) {
          verifyNever(
            () => apiClient.setCrosspost(
              pubkey: any(named: 'pubkey'),
              enabled: any(named: 'enabled'),
            ),
          );
        },
      );

      blocTest<CrosspostSettingsCubit, CrosspostSettingsState>(
        'emits a distinct state on each repeated failed enable attempt',
        setUp: () {
          when(() => apiClient.getStatus()).thenAnswer(
            (_) async => const CrosspostStatus(crosspostEnabled: false),
          );
        },
        build: () =>
            CrosspostSettingsCubit(apiClient: apiClient, pubkey: testPubkey),
        act: (cubit) async {
          await Future<void>.delayed(Duration.zero);
          await cubit.toggleCrosspost(enabled: true);
          await cubit.toggleCrosspost(enabled: true);
        },
        skip: 1,
        expect: () => const [
          CrosspostSettingsState(
            status: CrosspostSettingsStatus.failure,
            error: CrosspostSettingsError.usernameNotClaimed,
            attempt: 1,
          ),
          CrosspostSettingsState(
            status: CrosspostSettingsStatus.failure,
            error: CrosspostSettingsError.usernameNotClaimed,
            attempt: 2,
          ),
        ],
      );

      blocTest<CrosspostSettingsCubit, CrosspostSettingsState>(
        'maps a 404 toggle failure to usernameNotClaimed',
        setUp: () {
          when(
            () => apiClient.getStatus(),
          ).thenAnswer((_) async => loadedStatus);
          when(
            () => apiClient.setCrosspost(pubkey: testPubkey, enabled: true),
          ).thenAnswer(
            (_) async => throw const CrosspostApiException(
              'not found',
              statusCode: 404,
              kind: CrosspostApiErrorKind.usernameNotClaimed,
            ),
          );
        },
        build: () =>
            CrosspostSettingsCubit(apiClient: apiClient, pubkey: testPubkey),
        act: (cubit) async {
          await Future<void>.delayed(Duration.zero);
          await cubit.toggleCrosspost(enabled: true);
        },
        skip: 2,
        expect: () => const [
          CrosspostSettingsState(
            status: CrosspostSettingsStatus.failure,
            enabled: true,
            username: 'testuser',
            handle: 'testuser.divine.video',
            provisioningState: 'ready',
            error: CrosspostSettingsError.usernameNotClaimed,
            attempt: 1,
          ),
        ],
        errors: () => [isA<CrosspostApiException>()],
      );

      blocTest<CrosspostSettingsCubit, CrosspostSettingsState>(
        'maps a 503 toggle failure to unavailable',
        setUp: () {
          when(
            () => apiClient.getStatus(),
          ).thenAnswer((_) async => loadedStatus);
          when(
            () => apiClient.setCrosspost(pubkey: testPubkey, enabled: true),
          ).thenAnswer(
            (_) async => throw const CrosspostApiException(
              'unavailable',
              statusCode: 503,
              kind: CrosspostApiErrorKind.unavailable,
            ),
          );
        },
        build: () =>
            CrosspostSettingsCubit(apiClient: apiClient, pubkey: testPubkey),
        act: (cubit) async {
          await Future<void>.delayed(Duration.zero);
          await cubit.toggleCrosspost(enabled: true);
        },
        skip: 2,
        expect: () => const [
          CrosspostSettingsState(
            status: CrosspostSettingsStatus.failure,
            enabled: true,
            username: 'testuser',
            handle: 'testuser.divine.video',
            provisioningState: 'ready',
            error: CrosspostSettingsError.unavailable,
            attempt: 1,
          ),
        ],
        errors: () => [isA<CrosspostApiException>()],
      );

      blocTest<CrosspostSettingsCubit, CrosspostSettingsState>(
        'acknowledgeError clears the error and returns to loaded',
        setUp: () {
          when(() => apiClient.getStatus()).thenAnswer(
            (_) async => const CrosspostStatus(crosspostEnabled: false),
          );
        },
        build: () =>
            CrosspostSettingsCubit(apiClient: apiClient, pubkey: testPubkey),
        act: (cubit) async {
          await Future<void>.delayed(Duration.zero);
          await cubit.toggleCrosspost(enabled: true);
          cubit.acknowledgeError();
        },
        skip: 2,
        expect: () => const [
          CrosspostSettingsState(
            status: CrosspostSettingsStatus.loaded,
            attempt: 1,
          ),
        ],
      );

      test('emits toggling state optimistically before API call', () async {
        final completer = Completer<CrosspostStatus>();
        when(
          () => apiClient.getStatus(),
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
