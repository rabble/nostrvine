# Error Handling

This file is the discoverability anchor for error-handling conventions in
divine-mobile. The canonical rule lives at
[`.claude/rules/error_handling.md`](../../.claude/rules/error_handling.md) and is
the source of truth.

## Three anchors to know

- **[Per-layer failure contract](../../.claude/rules/error_handling.md#per-layer-failure-contract)** —
  what each of Client / Repository / BLoC / UI throws, catches, surfaces, and
  refuses to do. Read this first if you are designing a new feature.
- **[Decision matrix](../../.claude/rules/error_handling.md#decision-matrix)** —
  when an error is `Reportable` (forwarded to Crashlytics) and when it stays in
  the local unified log only. Default is **not** reportable.
- **[Migration recipe](../../.claude/rules/error_handling.md#migration-recipe)** —
  how to wrap an inner error at the `addError` call site, plus the
  `Reportable<T>` test-assertion gotcha when asserting in `blocTest`.

## Canonical examples (read before opening a sweep PR)

- **BLoC multi-site pattern**:
  [`video_interactions_bloc.dart`](../lib/blocs/video_interactions/video_interactions_bloc.dart)
  paired with
  [`reportable_sites.dart`](../lib/blocs/video_interactions/reportable_sites.dart)
  — multi-site files lift identifiers into a `*ReportableSites` constants
  class.
- **Service-layer pattern**:
  [`outgoing_dm_retry_service.dart`](../lib/services/outgoing_dm_retry_service.dart)
  with its colocated
  [`outgoing_dm_retry_service_reportable_sites.dart`](../lib/services/outgoing_dm_retry_service_reportable_sites.dart).
- **Pure-Dart package (reporter port)**:
  [`dm_repository.dart`](../packages/dm_repository/lib/src/dm_repository.dart)
  +
  [`dm_repository_reportable_sites.dart`](../packages/dm_repository/lib/src/dm_repository_reportable_sites.dart)
  — the only approved Crashlytics surface for packages that can't depend on
  `openvine/observability`.
- **"Explicitly NOT Reportable" precedent**:
  [`my_profile_bloc.dart`](../lib/blocs/my_profile/my_profile_bloc.dart#L186)
  — when the matrix says NO, leave the raw `addError(e, st)` and add an
  inline comment citing the rule and decision.

## Foundation

- [`divine_bloc_observer.dart`](../lib/observability/divine_bloc_observer.dart)
  — `Bloc.observer`;
  forwards Bloc errors to Crashlytics, gated on `ReportableError`.
- [`reportable_error.dart`](../lib/observability/reportable_error.dart) — the
  `ReportableError` marker, the `Reportable<T>` wrapper, and
  `sanitizeForCrashReport` (strips `npub1…` / `nsec1…` / email identifiers).
- [`crash_reporting_service.dart`](../lib/services/crash_reporting_service.dart)
  — Firebase Crashlytics facade exposing `recordError`, `setCustomKey`, and
  breadcrumb `log`.
