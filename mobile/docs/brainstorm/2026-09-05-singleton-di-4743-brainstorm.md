# Brainstorm: converting the last singleton services to constructor injection (#4743)

Date: 2026-09-05
Seeded by: `tasks/findings_4743.md` (440 lines, 10 findings, convergence table)

## Problem Statement

#4743 is framed as "convert 14 singleton services". On `main` only **5** remain
(F0) — the rest were converted by #7265/#5631/#5632 or deleted. The real problem
is narrower and sharper: five services are reachable only through process-global
state, which blocks test seams. The repo already records two of them as deferred
debt in `scripts/baseline/untested_services.txt` naming this issue's epic.

## Constraints

- Layered flow UI → BLoC/Cubit → Repository → Client; BLoC-first, Riverpod legacy.
- `ProviderContainer` is built at `app_bootstrap.dart:633`, but two of the five
  are used from lines 185/213 — ~420 lines earlier (F6).
- `test/flutter_test_config.dart` runs a root heal-and-blame tearDown for
  `BackgroundActivityManager`; removing its `factory` breaks that harness (F7).
- Merged VGV isolate: process-global state leaks across every test in the bundle.
- CI-only ratchets (layer_direction, untested_services, placeholder_tests, …)
  are not covered by the pre-push hook.

## Prior Art

- **PR #7265** — the canonical precedent: same conversion, sibling services,
  "one public constructor + provider", escape hatches deleted, one PR with a
  commit per service.
- `lib/providers/device_scope.dart` — existing mechanism for pre-container
  singletons, already hoisting 7 dependencies via `overrideWithValue`.
- `PerformanceMonitoringService` / `LoggingConfigService` / `TopHashtagsService`
  — three already-converted siblings in `lib/services/`, uniform shape.
- PR #5757 — already injected BAM into `AuthService` / `UploadManager`.

## Approaches Explored

### Approach A — uniform mechanical conversion
Public ctor + provider for all five; the two pre-container ones pinned through
`DeviceScope.overrides`; delete the two top-level global aliases (F1).
**Layers:** Client/service + provider wiring + startup.
**Pros:** zero new patterns; mirrors #7265 exactly; lowest review risk.
**Cons:** leaves the BAM harness and its `resetForTesting` in place; nothing
stops the pattern regrowing — which is how the issue's own scope went stale.
**Complexity:** Medium (107 refs / 31 files for `CrashReportingService`).

### Approach B — A + retire the BackgroundActivityManager harness
Make the dependency **required** (per #7265's stranding lesson), convert the two
remaining global consumers (`analytics_service.dart:163`,
`app_lifecycle_handler.dart:44`), then remove the `factory`, `resetForTesting`,
and `healAndBlameBackgroundActivity`.
**Pros:** closes #6880's root cause instead of healing it every tearDown.
**Cons/Risks:** the harness protects the whole merged isolate. It can only be
removed *after* no production path can reach the global — ordering is
load-bearing, and getting it wrong re-opens #6880 silently.
**Complexity:** High.

### Approach C — A + a shrink-only regrowth ratchet
`check_singleton_services.sh` freezing `factory X() => _instance` /
`static final X _instance` at zero under `lib/services`, with a baseline.
**Pros:** matches how this repo makes wins stick (13+ ratchets); would have
prevented this issue's own drift.
**Cons:** one more CI check; needs an AST or a carefully-scoped grep to avoid
flagging legitimate federated-plugin `*_platform_interface.dart` statics.
**Complexity:** Low-Medium.

### Approach D (rejected) — keep singletons, add `@visibleForTesting` seams
Explicitly rejected: #7265's stated goal was deleting exactly those
`testInstance`/`resetInstance` hatches, and it fails the issue's own
"no reaching into static state".

## Recommendation (user-selected)

**A + B + C.** Sequenced so B's harness removal happens strictly after the
global becomes unreachable from production.

## Scope decisions taken

- **`CrashReportingService` silent drop is OUT of scope.** Mechanism confirmed
  1.0, live impact only 0.6 (no pre-init caller found). Filed as its own issue
  with the measured evidence rather than ridden on a refactor PR.
- The vacuous `markAuthShellReady is idempotent` test (F2, proven by mutation)
  **is** in scope — the DI conversion is what makes the real test writable.
- Extras outside the audited 15 (StartupProfiler, WebAuthService,
  LogMessageBatcher, LogCaptureService) stay out; noted as follow-ups.

## Open Questions for /plan

- [ ] Ordering within the single PR so the BAM harness is never removed while a
      production path can still reach the global.
- [ ] Whether `StartupPerformanceService` needs the same `DeviceScope` hoist as
      `CrashReportingService`, or can be provider-only.
- [ ] Ratchet detector: AST vs scoped grep, and the exclusion for
      `*_platform_interface.dart`.

## Next Step

`/plan 4743`, then implement on `refactor/4743-singleton-di`.
