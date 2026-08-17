// ABOUTME: Provides the shared outage-diagnosis service
// ABOUTME: Kept alive so its verdict cache is shared across failure surfaces

import 'package:openvine/services/outage_diagnosis_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'outage_diagnosis_provider.g.dart';

/// The app-wide [OutageDiagnosisService].
///
/// Kept alive so the verdict cache survives a failure view being disposed and
/// rebuilt — a user tapping "try again" repeatedly during one incident must
/// not turn into one status request per tap.
@Riverpod(keepAlive: true)
OutageDiagnosisService outageDiagnosisService(Ref ref) {
  final service = OutageDiagnosisService();
  ref.onDispose(service.dispose);
  return service;
}
