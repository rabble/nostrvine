# Code Quality Issues

Issues related to code patterns, style violations, and maintainability.

Note: The codebase uses `very_good_analysis` across 33 packages and `unified_logger` in 250+ files. These issues cover pattern inconsistencies — `Future.delayed` misuse, serialization and equality divergence across models, API client boilerplate, and widget helper methods that should be extracted to widget classes.

---

### `Future.delayed` in app code
**Problem**: 22 files use `Future.delayed` in providers and screens where project rules discourage it in favor of proper async coordination.

**Evidence**: 22 files in `mobile/lib/` use `Future.delayed` in providers and screens. Project rules (CLAUDE.md, referencing AGENTS.md) explicitly state: "Avoid introducing arbitrary `Future.delayed()` calls in app code; prefer explicit async coordination." Common uses include waiting for animations to complete, debouncing user input, and timing workarounds where proper async coordination (streams, completers, `BlocListener`) should be used instead.

**Done well**: `scroll_pagination_mixin.dart` uses Future-based coordination to prevent duplicate requests. `main.dart` uses `WidgetsBinding.addPostFrameCallback` for post-frame work. `BlocListener` with `listenWhen` is used throughout for state-driven side effects.

**Impact**: Medium. `Future.delayed` is often a symptom of a deeper issue rather than the problem itself. Developers commonly reach for an arbitrary delay as a workaround when they encounter race conditions, missing state synchronization, or lifecycle timing issues they can't fully explain — "waiting a bit" makes the problem go away without understanding why. This means each instance is a potential indicator of an underlying coordination bug: a race condition that happens to lose on slower devices, a widget reading state before it's ready, or an async gap that hasn't been properly bridged. Addressing these goes beyond code quality — replacing each delay with explicit async coordination (streams, completers, `BlocListener`, `addPostFrameCallback`) forces the actual timing contract to be understood and expressed in code, resulting in genuinely more stable behavior across devices rather than code that coincidentally works on fast hardware.

**Effort**: Low. Each occurrence needs case-by-case evaluation and replacement with proper async coordination: streams for data flow, completers for one-shot async, `BlocListener` for state-driven side effects, or `WidgetsBinding.instance.addPostFrameCallback` for post-frame work.

**GitHub ticket**: [#3582](https://github.com/divinevideo/divine-mobile/issues/3582)

---

### Logging hygiene: unguarded prints and duplicate batchers
**Problem**: Production builds emit debug-level log output via bare `print()` calls, and two separate log-batching utilities implement the same concept with different APIs.

**Evidence**:
- `mobile/lib/services/video_loading_metrics.dart` lines 46–56, 184, 440: bare `print(message)` and `debugPrint(...)` without `kDebugMode` guards. Comment says "Use both UnifiedLogger AND print to ensure visibility" — debugging code that was not removed and writes video IDs and URLs to stdout in production. On iOS, visible via Console.app on any connected device.
- `mobile/lib/utils/log_batcher.dart` (204 lines): static class `LogBatcher` with a 5-second flush interval.
- `mobile/lib/utils/log_message_batcher.dart` (222 lines): singleton `LogMessageBatcher` with a 10-second interval and max-batch-size flush. Same concept, different API surface, both actively used.

**Done well**: `unified_logger` is used correctly in 250+ files across the codebase. The infrastructure is sound; the issue is 3 files that bypass it.

**Impact**: Low. No credentials leak, but unnecessary noise in production logs and duplicated maintenance for identical batching functionality.

**Effort**: Low. Wrap `print()` calls in `if (kDebugMode)` or remove them (rely on `UnifiedLogger`). Consolidate log batchers: pick one (the singleton version is more configurable), migrate callers, delete the other (~200 LOC removed).

**GitHub ticket**: [#3583](https://github.com/divinevideo/divine-mobile/issues/3583)

---

### Re-audit model serialization conventions
**Problem**: The reference audit found inconsistent model serialization conventions, but the specific `VideoEvent` / `json_serializable` evidence is now stale on current `main`.

**Reference-commit evidence**: At the reference commit, `json_serializable` was used only by `VideoEvent` (`@JsonSerializable(createFactory: false)` at `video_event.dart:19`, with `.g.dart` for `toJson` only), while `VideoStats`, `SocialCounts`, `UserProfile`, `ProfileSearchResult`, `HomeFeedResponse`, and other models used hand-rolled `fromJson`/`toJson`.

**Current `main` note**: This exact claim no longer holds. `VideoEvent` now uses hand-rolled `toJson`, and `mobile/packages/models/lib/src/video_event.dart` has no `@JsonSerializable` annotation or generated `.g.dart` part. Before turning this into implementation work, re-audit current model serialization patterns across `mobile/packages/models`, app-level models, and generator-backed state classes, then decide whether the project standard should be hand-rolled serializers, Freezed/json_serializable, or a narrower package-by-package convention.

**Impact**: Low.

**Effort**: Medium. Re-audit first, then standardize on one documented approach for each model surface. If adopting code generation, account for build-runner cost and generated-file maintenance. If keeping hand-rolled serializers, document the expected test coverage and update process when fields change.

**GitHub ticket**: [#3584](https://github.com/divinevideo/divine-mobile/issues/3584)

---

### Inconsistent equality implementations across models
**Problem**: Models use three different equality approaches: `Equatable` (9 models), hand-rolled `operator ==`/`hashCode` (20+ models), and no equality at all (several response models).

**Evidence**: `Equatable` used by 9 models (`NotificationModel`, `VideoCategory`, `UserList`, `DmMessage`, etc.). Hand-rolled `operator ==`/`hashCode` on 20+ models. No equality implementation at all on `HomeFeedResponse`, `VideoCommentsResponse`, `BlossomUploadResult`, `VideoComment`. Hand-rolled equality is error-prone when fields are added because forgetting to update `==` or `hashCode` causes subtle state bugs.

**Done well**: `NotificationModel`, `VideoCategory`, `UserList`, `DmMessage` and 5 other models use `Equatable` correctly, providing the standard for the rest of the package.

**Impact**: Medium. Models without equality break BLoC state comparison (a `BlocBuilder` won't skip rebuilds when state contains these models). Hand-rolled equality risks going stale when fields change.

**Effort**: Medium. Standardize on `Equatable` for all models in the `models` package.

**GitHub ticket**: [#3585](https://github.com/divinevideo/divine-mobile/issues/3585)

---

### Boilerplate duplication in FunnelcakeApiClient
**Problem**: Every method in `FunnelcakeApiClient` repeats the same try/catch/timeout/error-handling pattern (~15 lines per method, 24 methods).

**Evidence**: `mobile/packages/funnelcake_api_client/lib/src/funnelcake_api_client.dart` lines 144–1749: every method follows the identical pattern (check `isAvailable`, build URI, call `_get`/`_post`, decode JSON, catch `TimeoutException`, catch `FunnelcakeException`, catch generic). 24 methods with this duplication.

**Impact**: Medium. A change to error handling logic requires touching 24 methods; risk of inconsistency.

**Related**: See "Inconsistent error handling in notification methods" in [issues-error-handling.md](issues-error-handling.md). The notification methods deviate from the shared pattern. Extracting a `_request<T>` helper would likely resolve both issues.

**Effort**: Low. Extract a generic `_request<T>` helper that handles the try/catch boilerplate and accepts a response parser callback. Straightforward refactor within one file.

**GitHub ticket**: [#3586](https://github.com/divinevideo/divine-mobile/issues/3586)

---

### Widget helper method anti-pattern
**Problem**: 20+ files use `Widget _buildFoo()` methods instead of extracting to widget classes. Most affected: `share_video_menu.dart` (10 methods), `sounds_screen.dart` (9).

**Evidence**: 20+ screen and widget files use private methods returning `Widget` instead of separate widget classes. Most affected: `share_video_menu.dart` (10 `_build*` methods), `sounds_screen.dart` (9), `safety_settings_screen.dart` (7), `relay_diagnostic_screen.dart` (6), `explore_screen.dart` (5). Explicitly called out as an anti-pattern in the project's own `.claude/rules/code_style.md` and `.claude/rules/ui_theming.md`.

**Impact**: Medium. Prevents Flutter's diffing algorithm from optimizing rebuilds; makes individual components untestable in isolation; violates the project's own documented rules. Each `_build*` method lacks its own `BuildContext` and lifecycle.

**Effort**: Low. Extract each `_buildFoo()` into a private `_Foo` widget class. Safe, incremental refactor that can be done when touching these files for any reason. No functional change.

**GitHub ticket**: [#3587](https://github.com/divinevideo/divine-mobile/issues/3587)
