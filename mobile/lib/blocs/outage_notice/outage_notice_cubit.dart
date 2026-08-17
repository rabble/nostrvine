// ABOUTME: Diagnoses a failed load so the failure view can explain itself
// ABOUTME: Runs only while a failure is on screen, never in the background

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/services/outage_diagnosis_service.dart';

part 'outage_notice_state.dart';

/// Explains why a surface failed to load.
///
/// Constructed by the failure view itself, so the status page is consulted
/// only when a user is already looking at a failure — never on a healthy
/// session, and never for a subsystem the user is not using.
class OutageNoticeCubit extends Cubit<OutageNoticeState>
    with CloseGuardedEmit<OutageNoticeState> {
  OutageNoticeCubit({
    required OutageDiagnosisService diagnosisService,
    this.components = OutageDiagnosisService.feedComponents,
  }) : _diagnosisService = diagnosisService,
       super(const OutageNoticeState());

  final OutageDiagnosisService _diagnosisService;

  /// Status-page components this surface actually depends on.
  final List<String> components;

  Future<void> diagnose() async {
    final diagnosis = await _diagnosisService.diagnose(components: components);

    emitIfOpen(
      OutageNoticeState(
        status: switch (diagnosis.verdict) {
          OutageVerdict.divineOutage => OutageNoticeStatus.divineOutage,
          OutageVerdict.noConnection => OutageNoticeStatus.noConnection,
          OutageVerdict.indeterminate => OutageNoticeStatus.indeterminate,
        },
        operatorMessage: diagnosis.operatorMessage,
      ),
    );
  }
}
