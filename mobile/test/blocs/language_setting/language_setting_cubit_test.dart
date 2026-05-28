// ABOUTME: Unit tests for LanguageSettingCubit — load snapshot, setLanguage,
// ABOUTME: clearLanguage, all emitting the post-write canonical snapshot.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/language_setting/language_setting_cubit.dart';
import 'package:openvine/blocs/language_setting/language_setting_state.dart';
import 'package:openvine/services/language_preference_service.dart';

class _MockLanguagePreferenceService extends Mock
    implements LanguagePreferenceService {}

void main() {
  group(LanguageSettingCubit, () {
    late _MockLanguagePreferenceService service;

    setUp(() {
      service = _MockLanguagePreferenceService();
      when(service.initialize).thenAnswer((_) async {});
      when(() => service.contentLanguage).thenReturn('en');
      when(() => service.isCustomLanguageSet).thenReturn(false);
      when(() => service.setContentLanguage(any())).thenAnswer((_) async {});
      when(service.clearContentLanguage).thenAnswer((_) async {});
    });

    LanguageSettingCubit buildCubit() => LanguageSettingCubit(service: service);

    blocTest<LanguageSettingCubit, LanguageSettingState>(
      'load snapshots service state',
      setUp: () {
        when(() => service.contentLanguage).thenReturn('es');
        when(() => service.isCustomLanguageSet).thenReturn(true);
      },
      build: buildCubit,
      act: (cubit) => cubit.load(),
      expect: () => [
        const LanguageSettingState(),
        const LanguageSettingState(
          status: LanguageSettingStatus.ready,
          currentCode: 'es',
          isCustomLanguageSet: true,
        ),
      ],
      verify: (_) {
        verify(service.initialize).called(1);
      },
    );

    blocTest<LanguageSettingCubit, LanguageSettingState>(
      'setLanguage delegates to service and emits re-read snapshot',
      seed: () => const LanguageSettingState(
        status: LanguageSettingStatus.ready,
        currentCode: 'en',
      ),
      setUp: () {
        when(() => service.contentLanguage).thenReturn('pt');
        when(() => service.isCustomLanguageSet).thenReturn(true);
      },
      build: buildCubit,
      act: (cubit) => cubit.setLanguage('pt'),
      expect: () => [
        const LanguageSettingState(
          status: LanguageSettingStatus.ready,
          currentCode: 'pt',
          isCustomLanguageSet: true,
        ),
      ],
      verify: (_) {
        verify(() => service.setContentLanguage('pt')).called(1);
      },
    );

    blocTest<LanguageSettingCubit, LanguageSettingState>(
      'clearLanguage delegates to service and emits device-default snapshot',
      seed: () => const LanguageSettingState(
        status: LanguageSettingStatus.ready,
        currentCode: 'pt',
        isCustomLanguageSet: true,
      ),
      setUp: () {
        when(() => service.contentLanguage).thenReturn('en');
        when(() => service.isCustomLanguageSet).thenReturn(false);
      },
      build: buildCubit,
      act: (cubit) => cubit.clearLanguage(),
      expect: () => [
        const LanguageSettingState(
          status: LanguageSettingStatus.ready,
          currentCode: 'en',
        ),
      ],
      verify: (_) {
        verify(service.clearContentLanguage).called(1);
      },
    );
  });
}
