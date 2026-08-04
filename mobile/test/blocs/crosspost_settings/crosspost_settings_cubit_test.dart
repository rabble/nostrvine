import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/crosspost_settings/crosspost_settings_cubit.dart';
import 'package:openvine/models/atproto_provisioning_state.dart';
import 'package:openvine/repositories/bluesky_crosspost_repository.dart';
import 'package:openvine/services/crosspost_api_client.dart';

class _MockBlueskyCrosspostRepository extends Mock
    implements BlueskyCrosspostRepository {}

void main() {
  group(CrosspostSettingsCubit, () {
    late _MockBlueskyCrosspostRepository repository;

    const testPubkey = 'abc123def456';
    const loadedStatus = BlueskyCrosspostAccountStatus(
      crosspostEnabled: true,
      username: 'testuser',
      handle: 'testuser.divine.video',
      provisioningState: AtprotoProvisioningState.ready,
      did: 'did:plc:test123',
      usernameClaimStatus: UsernameClaimStatus.claimed,
    );

    CrosspostSettingsCubit buildCubit({
      Duration pollInterval = const Duration(seconds: 5),
    }) {
      return CrosspostSettingsCubit(
        repository: repository,
        pubkey: testPubkey,
        provisioningPollInterval: pollInterval,
      );
    }

    setUp(() {
      repository = _MockBlueskyCrosspostRepository();
      when(
        () => repository.loadStatus(pubkey: any(named: 'pubkey')),
      ).thenAnswer((_) async => loadedStatus);
    });

    group('initial state', () {
      test('starts loading status on creation', () {
        final cubit = buildCubit();
        expect(cubit.state.status, CrosspostSettingsStatus.loading);
        addTearDown(cubit.close);
      });
    });

    group('loadStatus', () {
      test('emits loaded state on successful status fetch', () async {
        final cubit = buildCubit();
        addTearDown(cubit.close);

        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.status, CrosspostSettingsStatus.loaded);
        expect(cubit.state.enabled, isTrue);
        expect(cubit.state.handle, 'testuser.divine.video');
        expect(
          cubit.state.provisioningState,
          AtprotoProvisioningState.ready,
        );
        expect(cubit.state.did, 'did:plc:test123');
        expect(cubit.state.usernameClaimStatus, UsernameClaimStatus.claimed);
      });

      test('emits failure state when status fetch fails', () async {
        when(() => repository.loadStatus(pubkey: testPubkey)).thenAnswer(
          (_) async => throw const CrosspostApiException('Network error'),
        );

        final cubit = buildCubit();
        addTearDown(cubit.close);

        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.status, CrosspostSettingsStatus.failure);
      });

      test(
        'loads not-linked state while preserving claimed username',
        () async {
          when(() => repository.loadStatus(pubkey: testPubkey)).thenAnswer(
            (_) async => const BlueskyCrosspostAccountStatus(
              crosspostEnabled: false,
              username: 'testuser',
              handle: 'testuser.divine.video',
              provisioningState: AtprotoProvisioningState.notLinked,
              usernameClaimStatus: UsernameClaimStatus.claimed,
            ),
          );

          final cubit = buildCubit();
          addTearDown(cubit.close);

          await Future<void>.delayed(Duration.zero);

          expect(cubit.state.status, CrosspostSettingsStatus.loaded);
          expect(cubit.state.enabled, isFalse);
          expect(cubit.state.username, 'testuser');
          expect(
            cubit.state.provisioningState,
            AtprotoProvisioningState.notLinked,
          );
        },
      );

      test('loads notClaimed when no Divine username is claimed', () async {
        when(() => repository.loadStatus(pubkey: testPubkey)).thenAnswer(
          (_) async => const BlueskyCrosspostAccountStatus(
            crosspostEnabled: false,
            provisioningState: AtprotoProvisioningState.notLinked,
            usernameClaimStatus: UsernameClaimStatus.notClaimed,
          ),
        );

        final cubit = buildCubit();
        addTearDown(cubit.close);

        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.status, CrosspostSettingsStatus.loaded);
        expect(
          cubit.state.usernameClaimStatus,
          UsernameClaimStatus.notClaimed,
        );
        expect(cubit.state.username, isNull);
      });
    });

    group('toggleCrosspost', () {
      blocTest<CrosspostSettingsCubit, CrosspostSettingsState>(
        'emits loaded with enabled=false on successful toggle',
        setUp: () {
          when(
            () => repository.setCrosspost(
              pubkey: testPubkey,
              enabled: false,
            ),
          ).thenAnswer(
            (_) async => const BlueskyCrosspostAccountStatus(
              crosspostEnabled: false,
              username: 'testuser',
              handle: 'testuser.divine.video',
              provisioningState: AtprotoProvisioningState.disabled,
              usernameClaimStatus: UsernameClaimStatus.claimed,
            ),
          );
        },
        build: buildCubit,
        act: (cubit) async {
          await Future<void>.delayed(Duration.zero);
          await cubit.toggleCrosspost(enabled: false);
        },
        skip: 2,
        expect: () => const [
          CrosspostSettingsState(
            status: CrosspostSettingsStatus.loaded,
            username: 'testuser',
            handle: 'testuser.divine.video',
            provisioningState: AtprotoProvisioningState.disabled,
            usernameClaimStatus: UsernameClaimStatus.claimed,
          ),
        ],
        verify: (cubit) => expect(cubit.state.enabled, isFalse),
      );

      blocTest<CrosspostSettingsCubit, CrosspostSettingsState>(
        'reverts to previous enabled value on toggle failure',
        setUp: () {
          when(
            () => repository.setCrosspost(
              pubkey: testPubkey,
              enabled: false,
            ),
          ).thenAnswer(
            (_) async => throw const CrosspostApiException('Server error'),
          );
        },
        build: buildCubit,
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
            provisioningState: AtprotoProvisioningState.ready,
            did: 'did:plc:test123',
            usernameClaimStatus: UsernameClaimStatus.claimed,
            error: CrosspostSettingsError.generic,
            attempt: 1,
          ),
        ],
        errors: () => [isA<CrosspostApiException>()],
      );

      blocTest<CrosspostSettingsCubit, CrosspostSettingsState>(
        'short-circuits to usernameNotClaimed when enabling without username',
        setUp: () {
          when(() => repository.loadStatus(pubkey: testPubkey)).thenAnswer(
            (_) async => const BlueskyCrosspostAccountStatus(
              crosspostEnabled: false,
              provisioningState: AtprotoProvisioningState.notLinked,
              usernameClaimStatus: UsernameClaimStatus.notClaimed,
            ),
          );
        },
        build: buildCubit,
        act: (cubit) async {
          await Future<void>.delayed(Duration.zero);
          await cubit.toggleCrosspost(enabled: true);
        },
        skip: 1,
        expect: () => const [
          CrosspostSettingsState(
            status: CrosspostSettingsStatus.failure,
            usernameClaimStatus: UsernameClaimStatus.notClaimed,
            error: CrosspostSettingsError.usernameNotClaimed,
            attempt: 1,
          ),
        ],
        verify: (_) {
          verifyNever(
            () => repository.setCrosspost(
              pubkey: any(named: 'pubkey'),
              enabled: any(named: 'enabled'),
            ),
          );
        },
      );

      blocTest<CrosspostSettingsCubit, CrosspostSettingsState>(
        'maps 503 toggle failure to unavailable',
        setUp: () {
          when(
            () => repository.setCrosspost(
              pubkey: testPubkey,
              enabled: true,
            ),
          ).thenAnswer(
            (_) async => throw const CrosspostApiException(
              'unavailable',
              statusCode: 503,
              kind: CrosspostApiErrorKind.unavailable,
            ),
          );
        },
        build: buildCubit,
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
            provisioningState: AtprotoProvisioningState.ready,
            did: 'did:plc:test123',
            usernameClaimStatus: UsernameClaimStatus.claimed,
            error: CrosspostSettingsError.unavailable,
            attempt: 1,
          ),
        ],
        errors: () => [isA<CrosspostApiException>()],
      );
    });

    group('provisioning polling', () {
      test('polls pending status until a terminal state is loaded', () async {
        var loadCount = 0;
        when(() => repository.loadStatus(pubkey: testPubkey)).thenAnswer((
          _,
        ) async {
          loadCount += 1;
          if (loadCount == 1) {
            return const BlueskyCrosspostAccountStatus(
              crosspostEnabled: true,
              username: 'testuser',
              handle: 'testuser.divine.video',
              provisioningState: AtprotoProvisioningState.pending,
              usernameClaimStatus: UsernameClaimStatus.claimed,
            );
          }
          return loadedStatus;
        });

        final cubit = buildCubit(
          pollInterval: const Duration(milliseconds: 1),
        );
        addTearDown(cubit.close);

        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(loadCount, greaterThanOrEqualTo(2));
        expect(
          cubit.state.provisioningState,
          AtprotoProvisioningState.ready,
        );
        final settledCount = loadCount;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(loadCount, settledCount);
      });

      test('stops polling when the cubit closes', () async {
        var loadCount = 0;
        when(() => repository.loadStatus(pubkey: testPubkey)).thenAnswer((
          _,
        ) async {
          loadCount += 1;
          return const BlueskyCrosspostAccountStatus(
            crosspostEnabled: true,
            username: 'testuser',
            handle: 'testuser.divine.video',
            provisioningState: AtprotoProvisioningState.pending,
            usernameClaimStatus: UsernameClaimStatus.claimed,
          );
        });

        final cubit = buildCubit(
          pollInterval: const Duration(milliseconds: 1),
        );
        await Future<void>.delayed(const Duration(milliseconds: 5));
        await cubit.close();

        final countAfterClose = loadCount;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        expect(loadCount, countAfterClose);
      });

      test(
        'retryProvisioning re-enables crossposting from failed state',
        () async {
          when(() => repository.loadStatus(pubkey: testPubkey)).thenAnswer(
            (_) async => const BlueskyCrosspostAccountStatus(
              crosspostEnabled: false,
              username: 'testuser',
              handle: 'testuser.divine.video',
              provisioningState: AtprotoProvisioningState.failed,
              provisioningError: 'PDS quota exhausted',
              usernameClaimStatus: UsernameClaimStatus.claimed,
            ),
          );
          when(
            () => repository.setCrosspost(pubkey: testPubkey, enabled: true),
          ).thenAnswer(
            (_) async => const BlueskyCrosspostAccountStatus(
              crosspostEnabled: true,
              username: 'testuser',
              handle: 'testuser.divine.video',
              provisioningState: AtprotoProvisioningState.pending,
              usernameClaimStatus: UsernameClaimStatus.claimed,
            ),
          );

          final cubit = buildCubit();
          addTearDown(cubit.close);
          await Future<void>.delayed(Duration.zero);

          await cubit.retryProvisioning();

          verify(
            () => repository.setCrosspost(pubkey: testPubkey, enabled: true),
          ).called(1);
          expect(cubit.state.enabled, isTrue);
          expect(
            cubit.state.provisioningState,
            AtprotoProvisioningState.pending,
          );
        },
      );
    });
  });
}
