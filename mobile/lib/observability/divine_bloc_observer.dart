// ABOUTME: BlocObserver that forwards Bloc errors to Crashlytics + UnifiedLogger
// ABOUTME: Wired once in main.dart before runApp; covers addError, handler throws, emit failures, and attaches last event/state/transition

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// Crashlytics custom-key names for the per-bloc diagnostics attached when a
/// [ReportableError] is forwarded. Public so dashboards and tests share one
/// source of truth.
const String kBlocLastEventKey = 'bloc.lastEvent';
const String kBlocLastStateKey = 'bloc.lastState';
const String kBlocLastTransitionAtKey = 'bloc.lastTransitionAt';
const String kBlocDiagnosticNotObserved = '<not observed>';

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
/// the error implementing [ReportableError] or being a bare programming
/// invariant error ([StateError], [TypeError], or [RangeError]) — without that
/// gate, expected domain errors (network timeouts, "no public key yet" during
/// cold start, 4xx responses, validation failures) flood the dashboard and
/// drown the real bugs. See the decision matrix in
/// `.claude/rules/error_handling.md`.
///
/// On a forwarded error the observer also attaches the bloc's most recent
/// event, state, and transition time as Crashlytics custom keys
/// ([kBlocLastEventKey] / [kBlocLastStateKey] / [kBlocLastTransitionAtKey]),
/// each sanitized through [sanitizeForCrashReport]. Event and state are
/// tracked per bloc via [onEvent] / [onChange] with no IO until [onError]
/// fires, so the hot path stays allocation-light. The triage gap this closes
/// is the one that made the #3503 auth-timing investigation expensive. See
/// #3758.
///
/// A second gate suppresses Crashlytics forwarding for database failures once
/// the local database has already reported corruption — see the
/// `isDatabaseCorrupted` constructor argument.
///
/// Wire once at app start, before `runApp`:
///
/// ```dart
/// Bloc.observer = DivineBlocObserver(
///   isDatabaseCorrupted: () => corruptionService.isCorrupted.value,
/// );
/// runApp(...);
/// ```
class DivineBlocObserver extends BlocObserver {
  DivineBlocObserver({
    CrashReportingService? crashReporting,
    bool Function()? isDatabaseCorrupted,
  }) : _crashReporting = crashReporting ?? CrashReportingService.instance,
       _isDatabaseCorrupted = isDatabaseCorrupted ?? _databaseIsHealthy;

  static bool _databaseIsHealthy() => false;

  final CrashReportingService _crashReporting;

  /// Whether this session has already classified the local database as
  /// corrupt. Wired to `DatabaseCorruptionService.isCorrupted`, which flips in
  /// exactly one place — the first statement that fails with `SQLITE_CORRUPT` /
  /// `SQLITE_NOTADB` — and never resets.
  ///
  /// While it reads `true`, recovery is already scheduled for the next launch
  /// and the corruption gate has already replaced the UI with the restart
  /// prompt, so every further database failure is a duplicate of a handled
  /// event rather than a defect: matrix-NO per
  /// `.claude/rules/error_handling.md`. Without this, one corrupt database
  /// raised five distinct Crashlytics groups for the same incident, because
  /// each downstream bloc wrapped and reported it independently (#7507).
  ///
  /// The flip itself is still reported once, by the service that sets it, so
  /// suppression here cannot hide the incident — only its echoes. Defaults to
  /// "healthy" so tests and any container built without the corruption service
  /// keep the previous behaviour.
  final bool Function() _isDatabaseCorrupted;

  /// Per-bloc diagnostics. An [Expando] holds its keys weakly, so a bloc's
  /// entry becomes collectible the moment the bloc itself is — observing every
  /// bloc in the app does not retain any of them.
  final Expando<_BlocDiagnostics> _diagnostics = Expando<_BlocDiagnostics>(
    'DivineBlocObserver',
  );

  _BlocDiagnostics _diagnosticsFor(BlocBase<dynamic> bloc) =>
      _diagnostics[bloc] ??= _BlocDiagnostics();

  @override
  void onEvent(Bloc<dynamic, dynamic> bloc, Object? event) {
    super.onEvent(bloc, event);
    _diagnosticsFor(bloc).lastEvent = event;
  }

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    _diagnosticsFor(bloc)
      ..lastState = change.nextState
      ..lastTransitionAt = DateTime.now();
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    final runtimeType = bloc.runtimeType;
    Log.error(
      'Bloc error: $runtimeType: $error',
      name: 'BlocObserver',
      error: error,
      stackTrace: stackTrace,
    );
    final reportableError = _asReportable(error);
    if (reportableError == null) return;
    if (_echoesHandledCorruption(error)) return;
    // Dispatch the diagnostic keys before recordError so they attach to the
    // report it emits. Both are fire-and-forget, but invoked synchronously and
    // in order, so the platform-channel messages stay ordered without blocking
    // the bloc error path. recordError and setCustomKey each swallow their own
    // failures and return early when uninitialized (see
    // crash_reporting_service.dart).
    _attachDiagnosticKeys(_diagnostics[bloc]);
    final reason = sanitizeForCrashReport('Bloc.addError $runtimeType');
    unawaited(
      _crashReporting.recordError(reportableError, stackTrace, reason: reason),
    );
  }

  /// Whether [error] is another view of the corruption this session has
  /// already reported and scheduled recovery for.
  ///
  /// Both halves are required. The session flag alone would drop unrelated
  /// defects that happen to fire after the flag flips; classification alone
  /// would drop the very first corrupt statement, which is the report worth
  /// keeping. Ordered flag-first because it is a field read, and it is false
  /// for every healthy session — classification only runs on a database that
  /// is already known to be broken.
  bool _echoesHandledCorruption(Object error) =>
      _isDatabaseCorrupted() &&
      mentionsDatabaseCorruption(
        error is Reportable<Object> ? error.unwrap() : error,
      );

  ReportableError? _asReportable(Object error) {
    if (error is ReportableError) return error;
    if (error is StateError || error is TypeError || error is RangeError) {
      return Reportable(error, context: 'DivineBlocObserver.onError');
    }
    return null;
  }

  void _attachDiagnosticKeys(_BlocDiagnostics? diagnostics) {
    unawaited(
      _crashReporting.setCustomKey(
        kBlocLastEventKey,
        _stringValueOrSentinel(diagnostics?.lastEvent),
      ),
    );
    unawaited(
      _crashReporting.setCustomKey(
        kBlocLastStateKey,
        _stringValueOrSentinel(diagnostics?.lastState),
      ),
    );
    unawaited(
      _crashReporting.setCustomKey(
        kBlocLastTransitionAtKey,
        diagnostics?.lastTransitionAt?.toUtc().toIso8601String() ??
            kBlocDiagnosticNotObserved,
      ),
    );
  }

  String _stringValueOrSentinel(Object? value) {
    if (value == null) return kBlocDiagnosticNotObserved;
    return sanitizeForCrashReport(value.toString());
  }
}

/// Latest observed event, state, and transition time for a single bloc,
/// attached as Crashlytics custom keys when that bloc forwards an error.
class _BlocDiagnostics {
  Object? lastEvent;
  Object? lastState;
  DateTime? lastTransitionAt;
}
