// ABOUTME: Unit tests for BugReportCubit — diagnostics + Zendesk submission
// ABOUTME: lifecycle, with the typed failure-key distinguishing
// ABOUTME: attachment-upload errors from generic failures.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show BugReportData;
import 'package:openvine/blocs/bug_report/bug_report_cubit.dart';
import 'package:openvine/blocs/bug_report/bug_report_state.dart';
import 'package:openvine/services/bug_report_service.dart';
import 'package:openvine/services/zendesk_support_service.dart';

class _MockBugReportService extends Mock implements BugReportService {}

BugReportData _makeReportData() => BugReportData(
  reportId: 'report-1',
  timestamp: DateTime.fromMillisecondsSinceEpoch(0),
  userDescription: '',
  deviceInfo: const {'platform': 'test'},
  appVersion: '1.0.0+1',
  recentLogs: const [],
  errorCounts: const {},
);

void main() {
  group(BugReportCubit, () {
    late _MockBugReportService service;

    setUp(() {
      service = _MockBugReportService();
      when(
        () => service.collectDiagnostics(
          userDescription: any(named: 'userDescription'),
          currentScreen: any(named: 'currentScreen'),
          userPubkey: any(named: 'userPubkey'),
          additionalContext: any(named: 'additionalContext'),
        ),
      ).thenAnswer((_) async => _makeReportData());
    });

    SubmitBugReportAction buildSubmit({
      bool returnValue = true,
      Object? throwError,
    }) {
      return ({
        required String subject,
        required String description,
        required String reportId,
        required String appVersion,
        required Map<String, dynamic> deviceInfo,
        String? stepsToReproduce,
        String? expectedBehavior,
        String? currentScreen,
        String? userPubkey,
        Map<String, int>? errorCounts,
        String? logsSummary,
        List<String>? attachmentPaths,
      }) async {
        if (throwError != null) throw throwError;
        return returnValue;
      };
    }

    BugReportCubit buildCubit({
      bool returnValue = true,
      Object? throwError,
    }) {
      return BugReportCubit(
        bugReportService: service,
        buildLogsSummary: (_) => null,
        submitBugReport: buildSubmit(
          returnValue: returnValue,
          throwError: throwError,
        ),
      );
    }

    blocTest<BugReportCubit, BugReportState>(
      'submit happy path emits submitting then success',
      build: buildCubit,
      act: (cubit) => cubit.submit(
        subject: 'Crash',
        description: 'It crashed',
        stepsToReproduce: '',
        expectedBehavior: '',
        attachments: const [],
      ),
      expect: () => [
        const BugReportState(status: BugReportStatus.submitting),
        const BugReportState(status: BugReportStatus.success),
      ],
    );

    blocTest<BugReportCubit, BugReportState>(
      'submit no-op when subject empty',
      build: buildCubit,
      act: (cubit) => cubit.submit(
        subject: '',
        description: 'desc',
        stepsToReproduce: '',
        expectedBehavior: '',
        attachments: const [],
      ),
      expect: () => const <BugReportState>[],
    );

    blocTest<BugReportCubit, BugReportState>(
      'submit emits failure with generic key when service returns false',
      build: () => buildCubit(returnValue: false),
      act: (cubit) => cubit.submit(
        subject: 'X',
        description: 'Y',
        stepsToReproduce: '',
        expectedBehavior: '',
        attachments: const [],
      ),
      expect: () => [
        const BugReportState(status: BugReportStatus.submitting),
        const BugReportState(
          status: BugReportStatus.failure,
          failureKey: BugReportFailureKey.generic,
        ),
      ],
    );

    blocTest<BugReportCubit, BugReportState>(
      'submit emits attachmentUpload key on ZendeskAttachmentUploadException',
      build: () => buildCubit(
        throwError: const ZendeskAttachmentUploadException(),
      ),
      act: (cubit) => cubit.submit(
        subject: 'X',
        description: 'Y',
        stepsToReproduce: '',
        expectedBehavior: '',
        attachments: [XFile('/tmp/x.png')],
      ),
      expect: () => [
        const BugReportState(status: BugReportStatus.submitting),
        const BugReportState(
          status: BugReportStatus.failure,
          failureKey: BugReportFailureKey.attachmentUpload,
        ),
      ],
      errors: () => [isA<ZendeskAttachmentUploadException>()],
    );

    blocTest<BugReportCubit, BugReportState>(
      'submit emits generic key on other exceptions',
      build: () => buildCubit(throwError: StateError('boom')),
      act: (cubit) => cubit.submit(
        subject: 'X',
        description: 'Y',
        stepsToReproduce: '',
        expectedBehavior: '',
        attachments: const [],
      ),
      expect: () => [
        const BugReportState(status: BugReportStatus.submitting),
        const BugReportState(
          status: BugReportStatus.failure,
          failureKey: BugReportFailureKey.generic,
        ),
      ],
      errors: () => [isA<StateError>()],
    );
  });
}
