// ABOUTME: BlocObserver that forwards Bloc errors to Crashlytics + UnifiedLogger
// ABOUTME: Wired once in main.dart before runApp; covers addError, handler throws, emit failures

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// Forwards Bloc/Cubit errors to the project's crash reporter and the unified
/// log.
///
/// Bloc's [BlocObserver.onError] fires for three things:
/// 1. An explicit `bloc.addError(error, stackTrace)` from a handler.
/// 2. An uncaught exception thrown inside an event handler.
/// 3. A failure inside `emit(...)` (e.g. emitting from a closed bloc).
///
/// All three are written to the unified log (so the in-memory bug-report
/// capture flow stays complete). Forwarding to Crashlytics is **gated** on
/// the error implementing [ReportableError] — without that gate, expected
/// domain errors (network timeouts, "no public key yet" during cold start,
/// 4xx responses, validation failures) flood the dashboard and drown the
/// real bugs. See the decision matrix in `.claude/rules/error_handling.md`.
///
/// Wire once at app start, before `runApp`:
///
/// ```dart
/// Bloc.observer = DivineBlocObserver();
/// runApp(...);
/// ```
class DivineBlocObserver extends BlocObserver {
  DivineBlocObserver({CrashReportingService? crashReporting})
    : _crashReporting = crashReporting ?? CrashReportingService.instance;

  final CrashReportingService _crashReporting;

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    final runtimeType = bloc.runtimeType;
    Log.error(
      'Bloc error: $runtimeType',
      name: 'BlocObserver',
      error: error,
      stackTrace: stackTrace,
    );
    if (error is! ReportableError) return;
    final reason = sanitizeForCrashReport('Bloc.addError $runtimeType');
    // CrashReportingService.recordError swallows its own failures (returns
    // early when uninitialized, wraps the FirebaseCrashlytics call in
    // try/catch); see crash_reporting_service.dart for the contract.
    unawaited(_crashReporting.recordError(error, stackTrace, reason: reason));
  }
}
