// ABOUTME: Tests the clear-logs cubit's transient-then-cleared transitions
// ABOUTME: The transient clearing state lets a repeat clear re-fire the UI

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/clear_logs/clear_logs_cubit.dart';
import 'package:openvine/services/bug_report_service.dart';

class _MockBugReportService extends Mock implements BugReportService {}

void main() {
  group(ClearLogsCubit, () {
    late _MockBugReportService bugReportService;

    setUp(() {
      bugReportService = _MockBugReportService();
    });

    ClearLogsCubit build() =>
        ClearLogsCubit(bugReportService: bugReportService);

    group('clear', () {
      blocTest<ClearLogsCubit, ClearLogsState>(
        'clears the buffer and reports cleared',
        setUp: () => when(
          () => bugReportService.clearCapturedLogs(),
        ).thenAnswer((_) async {}),
        build: build,
        act: (cubit) => cubit.clear(),
        expect: () => const [
          ClearLogsState(status: ClearLogsStatus.clearing),
          ClearLogsState(status: ClearLogsStatus.cleared),
        ],
        verify: (_) {
          verify(() => bugReportService.clearCapturedLogs()).called(1);
        },
      );

      // A repeat clear must transition again so the UI re-fires its snackbar;
      // the transient clearing state is what makes the state actually change.
      blocTest<ClearLogsCubit, ClearLogsState>(
        'transitions again on a repeat clear',
        setUp: () => when(
          () => bugReportService.clearCapturedLogs(),
        ).thenAnswer((_) async {}),
        build: build,
        act: (cubit) async {
          await cubit.clear();
          await cubit.clear();
        },
        expect: () => const [
          ClearLogsState(status: ClearLogsStatus.clearing),
          ClearLogsState(status: ClearLogsStatus.cleared),
          ClearLogsState(status: ClearLogsStatus.clearing),
          ClearLogsState(status: ClearLogsStatus.cleared),
        ],
      );

      blocTest<ClearLogsCubit, ClearLogsState>(
        'ignores a second clear while one is in flight',
        setUp: () => when(
          () => bugReportService.clearCapturedLogs(),
        ).thenAnswer((_) => Completer<void>().future),
        build: build,
        act: (cubit) {
          unawaited(cubit.clear());
          unawaited(cubit.clear());
        },
        expect: () => const [
          ClearLogsState(status: ClearLogsStatus.clearing),
        ],
        verify: (_) {
          verify(() => bugReportService.clearCapturedLogs()).called(1);
        },
      );

      // close() does not cancel an in-flight clear; the resumed emit would
      // throw without the guard (#7370).
      test('drops the outcome when closed mid-clear', () async {
        final gate = Completer<void>();
        when(
          () => bugReportService.clearCapturedLogs(),
        ).thenAnswer((_) => gate.future);

        final cubit = build();
        final pending = cubit.clear();
        await cubit.close();
        gate.complete();

        await expectLater(pending, completes);
      });
    });
  });
}
