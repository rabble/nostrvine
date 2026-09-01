// ABOUTME: Drives the Support Center "Clear Logs" action
// ABOUTME: Keeps BugReportService out of the widget layer (UI -> Cubit -> Service)

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/clear_logs/clear_logs_state.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/services/bug_report_service.dart';

export 'package:openvine/blocs/clear_logs/clear_logs_state.dart';

class ClearLogsCubit extends Cubit<ClearLogsState>
    with CloseGuardedEmit<ClearLogsState> {
  ClearLogsCubit({required BugReportService bugReportService})
    : _bugReportService = bugReportService,
      super(const ClearLogsState());

  final BugReportService _bugReportService;

  /// Empties the in-memory log capture buffer.
  ///
  /// Emits [ClearLogsStatus.clearing] then [ClearLogsStatus.cleared] so a
  /// repeat clear still produces a transition the UI can react to.
  Future<void> clear() async {
    emitIfOpen(const ClearLogsState(status: ClearLogsStatus.clearing));
    await _bugReportService.clearCapturedLogs();
    emitIfOpen(const ClearLogsState(status: ClearLogsStatus.cleared));
  }
}
