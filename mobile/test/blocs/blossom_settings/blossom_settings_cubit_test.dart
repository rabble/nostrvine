// ABOUTME: Unit tests for BlossomSettingsCubit — load snapshot, enable toggle,
// ABOUTME: URL validation (https + loopback-http carve-out), and the
// ABOUTME: save success / failure transitions the View listens on.

import 'package:bloc_test/bloc_test.dart';
import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/blossom_settings/blossom_settings_cubit.dart';
import 'package:openvine/blocs/blossom_settings/blossom_settings_state.dart';

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

void main() {
  group(BlossomSettingsCubit, () {
    late _MockBlossomUploadService service;

    setUp(() {
      service = _MockBlossomUploadService();
      when(() => service.isBlossomEnabled()).thenAnswer((_) async => false);
      when(() => service.getBlossomServer()).thenAnswer((_) async => null);
      when(() => service.setBlossomEnabled(any())).thenAnswer((_) async {});
      when(() => service.setBlossomServer(any())).thenAnswer((_) async {});
    });

    BlossomSettingsCubit buildCubit() =>
        BlossomSettingsCubit(blossomUploadService: service);

    blocTest<BlossomSettingsCubit, BlossomSettingsState>(
      'load snapshots persisted settings into state',
      setUp: () {
        when(() => service.isBlossomEnabled()).thenAnswer((_) async => true);
        when(
          () => service.getBlossomServer(),
        ).thenAnswer((_) async => 'https://blossom.band');
      },
      build: buildCubit,
      act: (cubit) => cubit.load(),
      expect: () => [
        const BlossomSettingsState(status: BlossomSettingsStatus.loading),
        const BlossomSettingsState(
          status: BlossomSettingsStatus.ready,
          isBlossomEnabled: true,
          initialServerUrl: 'https://blossom.band',
        ),
      ],
    );

    blocTest<BlossomSettingsCubit, BlossomSettingsState>(
      'load emits ready with empty serverUrl when none persisted',
      build: buildCubit,
      act: (cubit) => cubit.load(),
      expect: () => [
        const BlossomSettingsState(status: BlossomSettingsStatus.loading),
        const BlossomSettingsState(status: BlossomSettingsStatus.ready),
      ],
    );

    blocTest<BlossomSettingsCubit, BlossomSettingsState>(
      'load surfaces service failure via addError and falls back to ready',
      setUp: () {
        when(
          () => service.isBlossomEnabled(),
        ).thenThrow(StateError('prefs unavailable'));
      },
      build: buildCubit,
      act: (cubit) => cubit.load(),
      expect: () => [
        const BlossomSettingsState(status: BlossomSettingsStatus.loading),
        const BlossomSettingsState(status: BlossomSettingsStatus.ready),
      ],
      errors: () => [isA<StateError>()],
    );

    blocTest<BlossomSettingsCubit, BlossomSettingsState>(
      'setEnabled toggles isBlossomEnabled without persisting',
      seed: () =>
          const BlossomSettingsState(status: BlossomSettingsStatus.ready),
      build: buildCubit,
      act: (cubit) => cubit.setEnabled(true),
      expect: () => [
        const BlossomSettingsState(
          status: BlossomSettingsStatus.ready,
          isBlossomEnabled: true,
        ),
      ],
      verify: (_) {
        verifyNever(() => service.setBlossomEnabled(any()));
        verifyNever(() => service.setBlossomServer(any()));
      },
    );

    blocTest<BlossomSettingsCubit, BlossomSettingsState>(
      'save with https URL persists and emits saveSuccess',
      seed: () => const BlossomSettingsState(
        status: BlossomSettingsStatus.ready,
        isBlossomEnabled: true,
      ),
      build: buildCubit,
      act: (cubit) => cubit.save('https://blossom.band'),
      expect: () => [
        const BlossomSettingsState(
          status: BlossomSettingsStatus.saving,
          isBlossomEnabled: true,
        ),
        const BlossomSettingsState(
          status: BlossomSettingsStatus.saveSuccess,
          isBlossomEnabled: true,
        ),
      ],
      verify: (_) {
        verify(() => service.setBlossomEnabled(true)).called(1);
        verify(
          () => service.setBlossomServer('https://blossom.band'),
        ).called(1);
      },
    );

    blocTest<BlossomSettingsCubit, BlossomSettingsState>(
      'save with disabled toggle clears the server URL (null)',
      seed: () =>
          const BlossomSettingsState(status: BlossomSettingsStatus.ready),
      build: buildCubit,
      act: (cubit) => cubit.save('https://blossom.band'),
      expect: () => [
        const BlossomSettingsState(status: BlossomSettingsStatus.saving),
        const BlossomSettingsState(status: BlossomSettingsStatus.saveSuccess),
      ],
      verify: (_) {
        verify(() => service.setBlossomEnabled(false)).called(1);
        verify(() => service.setBlossomServer(null)).called(1);
      },
    );

    blocTest<BlossomSettingsCubit, BlossomSettingsState>(
      'save with loopback http://10.0.2.2 URL succeeds',
      seed: () => const BlossomSettingsState(
        status: BlossomSettingsStatus.ready,
        isBlossomEnabled: true,
      ),
      build: buildCubit,
      act: (cubit) => cubit.save('http://10.0.2.2:8000'),
      verify: (_) {
        verify(
          () => service.setBlossomServer('http://10.0.2.2:8000'),
        ).called(1);
      },
    );

    blocTest<BlossomSettingsCubit, BlossomSettingsState>(
      'save rejects non-loopback http:// with mustUseHttps failure key',
      seed: () => const BlossomSettingsState(
        status: BlossomSettingsStatus.ready,
        isBlossomEnabled: true,
      ),
      build: buildCubit,
      act: (cubit) => cubit.save('http://example.com/blossom'),
      expect: () => [
        const BlossomSettingsState(
          status: BlossomSettingsStatus.saveFailure,
          isBlossomEnabled: true,
          saveFailureMessageKey: BlossomSaveFailureKey.mustUseHttps,
        ),
      ],
      verify: (_) {
        verifyNever(() => service.setBlossomEnabled(any()));
        verifyNever(() => service.setBlossomServer(any()));
      },
    );

    blocTest<BlossomSettingsCubit, BlossomSettingsState>(
      'save rejects unparseable URL with invalidServerUrl failure key',
      seed: () => const BlossomSettingsState(
        status: BlossomSettingsStatus.ready,
        isBlossomEnabled: true,
      ),
      build: buildCubit,
      act: (cubit) => cubit.save('not a url'),
      expect: () => [
        const BlossomSettingsState(
          status: BlossomSettingsStatus.saveFailure,
          isBlossomEnabled: true,
          saveFailureMessageKey: BlossomSaveFailureKey.invalidServerUrl,
        ),
      ],
      verify: (_) {
        verifyNever(() => service.setBlossomServer(any()));
      },
    );

    blocTest<BlossomSettingsCubit, BlossomSettingsState>(
      'repeated validation failures emit a fresh saveFailure transition',
      seed: () => const BlossomSettingsState(
        status: BlossomSettingsStatus.ready,
        isBlossomEnabled: true,
      ),
      build: buildCubit,
      act: (cubit) async {
        await cubit.save('http://example.com/blossom');
        await cubit.save('http://example.com/blossom');
      },
      expect: () => [
        const BlossomSettingsState(
          status: BlossomSettingsStatus.saveFailure,
          isBlossomEnabled: true,
          saveFailureMessageKey: BlossomSaveFailureKey.mustUseHttps,
        ),
        const BlossomSettingsState(
          status: BlossomSettingsStatus.ready,
          isBlossomEnabled: true,
        ),
        const BlossomSettingsState(
          status: BlossomSettingsStatus.saveFailure,
          isBlossomEnabled: true,
          saveFailureMessageKey: BlossomSaveFailureKey.mustUseHttps,
        ),
      ],
      verify: (_) {
        verifyNever(() => service.setBlossomEnabled(any()));
        verifyNever(() => service.setBlossomServer(any()));
      },
    );

    blocTest<BlossomSettingsCubit, BlossomSettingsState>(
      'save service failure emits genericFailure key + addError',
      seed: () => const BlossomSettingsState(
        status: BlossomSettingsStatus.ready,
        isBlossomEnabled: true,
      ),
      setUp: () {
        when(
          () => service.setBlossomEnabled(any()),
        ).thenThrow(StateError('prefs write failed'));
      },
      build: buildCubit,
      act: (cubit) => cubit.save('https://blossom.band'),
      expect: () => [
        const BlossomSettingsState(
          status: BlossomSettingsStatus.saving,
          isBlossomEnabled: true,
        ),
        const BlossomSettingsState(
          status: BlossomSettingsStatus.saveFailure,
          isBlossomEnabled: true,
          saveFailureMessageKey: BlossomSaveFailureKey.genericFailure,
        ),
      ],
      errors: () => [isA<StateError>()],
    );

    blocTest<BlossomSettingsCubit, BlossomSettingsState>(
      'save trims whitespace before validating',
      seed: () => const BlossomSettingsState(
        status: BlossomSettingsStatus.ready,
        isBlossomEnabled: true,
      ),
      build: buildCubit,
      act: (cubit) => cubit.save('  https://blossom.band  '),
      verify: (_) {
        verify(
          () => service.setBlossomServer('https://blossom.band'),
        ).called(1);
      },
    );

    blocTest<BlossomSettingsCubit, BlossomSettingsState>(
      'save with enabled+empty URL clears server without validation error',
      seed: () => const BlossomSettingsState(
        status: BlossomSettingsStatus.ready,
        isBlossomEnabled: true,
      ),
      build: buildCubit,
      act: (cubit) => cubit.save(''),
      expect: () => [
        const BlossomSettingsState(
          status: BlossomSettingsStatus.saving,
          isBlossomEnabled: true,
        ),
        const BlossomSettingsState(
          status: BlossomSettingsStatus.saveSuccess,
          isBlossomEnabled: true,
        ),
      ],
      verify: (_) {
        verify(() => service.setBlossomEnabled(true)).called(1);
        verify(() => service.setBlossomServer(null)).called(1);
      },
    );
  });
}
