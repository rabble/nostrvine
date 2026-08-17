// ABOUTME: Tests the outage notice cubit that feeds user-facing failure copy.
// ABOUTME: Pins diagnosis mapping and async error handling.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/outage_notice/outage_notice_cubit.dart';
import 'package:openvine/services/outage_diagnosis_service.dart';

class _MockOutageDiagnosisService extends Mock
    implements OutageDiagnosisService {}

void main() {
  group(OutageNoticeCubit, () {
    late _MockOutageDiagnosisService diagnosisService;

    setUp(() {
      diagnosisService = _MockOutageDiagnosisService();
    });

    blocTest<OutageNoticeCubit, OutageNoticeState>(
      'maps a Divine outage verdict',
      build: () {
        when(
          () => diagnosisService.diagnose(
            components: any(named: 'components'),
          ),
        ).thenAnswer(
          (_) async => const OutageDiagnosis(
            OutageVerdict.divineOutage,
            operatorMessage: 'Fix rolling out.',
          ),
        );
        return OutageNoticeCubit(diagnosisService: diagnosisService);
      },
      act: (cubit) => cubit.diagnose(),
      expect: () => const [
        OutageNoticeState(
          status: OutageNoticeStatus.divineOutage,
          operatorMessage: 'Fix rolling out.',
        ),
      ],
    );

    blocTest<OutageNoticeCubit, OutageNoticeState>(
      'maps a no-connection verdict',
      build: () {
        when(
          () => diagnosisService.diagnose(
            components: any(named: 'components'),
          ),
        ).thenAnswer(
          (_) async => const OutageDiagnosis(OutageVerdict.noConnection),
        );
        return OutageNoticeCubit(diagnosisService: diagnosisService);
      },
      act: (cubit) => cubit.diagnose(),
      expect: () => const [
        OutageNoticeState(status: OutageNoticeStatus.noConnection),
      ],
    );

    blocTest<OutageNoticeCubit, OutageNoticeState>(
      'maps an indeterminate verdict',
      build: () {
        when(
          () => diagnosisService.diagnose(
            components: any(named: 'components'),
          ),
        ).thenAnswer((_) async => OutageDiagnosis.indeterminate);
        return OutageNoticeCubit(diagnosisService: diagnosisService);
      },
      act: (cubit) => cubit.diagnose(),
      expect: () => const [
        OutageNoticeState(status: OutageNoticeStatus.indeterminate),
      ],
    );

    blocTest<OutageNoticeCubit, OutageNoticeState>(
      'reports diagnosis errors and stays generic',
      build: () {
        when(
          () => diagnosisService.diagnose(
            components: any(named: 'components'),
          ),
        ).thenThrow(StateError('bad status payload'));
        return OutageNoticeCubit(diagnosisService: diagnosisService);
      },
      act: (cubit) => cubit.diagnose(),
      expect: () => const [
        OutageNoticeState(status: OutageNoticeStatus.indeterminate),
      ],
      errors: () => [isA<StateError>()],
    );

    blocTest<OutageNoticeCubit, OutageNoticeState>(
      'passes custom component scope to the diagnosis service',
      build: () {
        when(
          () => diagnosisService.diagnose(components: const ['uploads']),
        ).thenAnswer(
          (_) async => const OutageDiagnosis(OutageVerdict.divineOutage),
        );
        return OutageNoticeCubit(
          diagnosisService: diagnosisService,
          components: const ['uploads'],
        );
      },
      act: (cubit) => cubit.diagnose(),
      verify: (_) {
        verify(
          () => diagnosisService.diagnose(components: const ['uploads']),
        ).called(1);
      },
    );
  });
}
