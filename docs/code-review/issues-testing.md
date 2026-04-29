# Testing Issues

Issues related to test coverage gaps, test quality, flakiness, and CI enforcement.

Note: BLoC testing is well-covered (42 directories, 61 test files). These issues cover the gaps below that: 50+ untested services (including safety-critical ones like `content_moderation_service`), 264 `Future.delayed` calls causing flakiness, 223 skipped tests with no owner, a non-functional golden suite, narrow integration test coverage, and test files that don't mirror `lib/`.

---

### 50+ services have no test file
**Problem**: High-impact untested services include `bookmark_service.dart` (951 lines), `content_moderation_service.dart` (705 lines), `mute_service.dart` (628 lines).

**Evidence**: Key untested services by line count: `bookmark_service.dart` (951), `bug_report_service.dart` (947), `content_moderation_service.dart` (705), `mute_service.dart` (628), `social_service.dart` (542), `native_proofmode_service.dart` (525), `startup_performance_service.dart` (462), `personal_event_cache_service.dart` (412), `circuit_breaker_service.dart` (344), `nip05_verification_service.dart` (337), `video_visibility_manager.dart` (278), `error_analytics_tracker.dart` (276). Additionally, 18 of 33 top-level screen files have no tests (including `explore_screen.dart`, `other_profile_screen.dart`, `relay_settings_screen.dart`, `notification_settings_screen.dart`). BLoCs are well-covered (42 BLoC dirs, 61 test files), but the untested services those BLoCs depend on are a testing blind spot.

**Impact**: High. Services are the densest concentration of business logic; `content_moderation_service` and `mute_service` are user-safety-critical with zero tests. BLoCs depend on untested services, so BLoC tests have a blind spot in the layer below them.

**Effort**: High. Writing tests for 50+ services requires mocking dependencies and understanding internal logic. Priority: P0 for safety-critical (`bookmark`, `mute`, `content_moderation`), P1 for business logic (`social`, `circuit_breaker`, `personal_event_cache`), P2 for observability (`analytics`, `metrics`).

**Related**: This work pairs naturally with the `services/` directory migration in [issues-architecture.md](issues-architecture.md). As each service is extracted into a dedicated package (repository most likely), tests should be added as part of the same PR.

**GitHub ticket**: [#3608](https://github.com/divinevideo/divine-mobile/issues/3608)

---

### `Future.delayed` used without `fakeAsync` in 51 test files
**Problem**: 264 occurrences of `Future.delayed` performing real wall-clock waits instead of using `fakeAsync` with `elapse()` for deterministic time control. Largest source of test flakiness, known for 6+ months.

**Evidence**: 264 total occurrences across 51 files. Most affected: `startup_diagnostics_test.dart` (24 occurrences), `curated_list_service_stream_test.dart` (20), `event_handlers_simple_test.dart` (15), `content_blocklist_service_test.dart` (14), `startup_coordinator_test.dart` (13). Documented in `test/TEST_QUALITY_AUDIT.md` (generated 2025-10-20) as a CRITICAL finding with file-by-file call counts. The issue has been known for 6+ months with no resolution. `Future.delayed` itself is fine inside `fakeAsync`; the problem is using it outside `fakeAsync`, which causes real waits whose timing varies between environments.

**Impact**: High. The single largest source of test flakiness; real-time waits behave differently across CI runners and local machines, causing tests to pass locally but fail in CI or vice versa. Also slows down test execution unnecessarily.

**Effort**: Medium. Each occurrence needs either wrapping in `fakeAsync` with `elapse()` to control time deterministically, or replacement with `Completer`, stream listeners, or `pumpAndSettle` where the delay was masking an async coordination problem. `await Future<void>.delayed(Duration.zero)` is acceptable for single event-loop cycling. Mechanical but tedious across 51 files and 264 call sites.

**GitHub ticket**: [#3609](https://github.com/divinevideo/divine-mobile/issues/3609)

---

### 223 skipped tests with no owner
**Problem**: 223 test cases skipped with `skip: true`, no reason string, no linked issue, and `TODO(any)` as assignee.

**Evidence**: 223 tests with `skip: true` and generic `TODO(any): Fix and re-enable` with no accompanying reason string, no linked GitHub issue, no owner. 123 of 797 test files (15.4%) have at least one skip. ~14,000 lines of test code across skipped service tests not currently providing coverage (`curated_list_service`: 3,862 lines, `video_event_service`: 3,513 lines, `video_event_publisher`: 2,649 lines, `upload_manager`: 2,439 lines).

**Impact**: Medium. Skipped tests consume parse/import overhead while providing no safety guarantee; `TODO(any)` means no owner and no resolution path. The ~14,000 lines of skipped service test code represent significant past investment that is not currently providing coverage.

**Effort**: Medium. Triage each skip: restore, update, or delete. Assigning owners and linking to GitHub issues is the critical missing step. Re-enabling the ~14,000 lines of skipped service tests is the highest-value target.

**GitHub ticket**: [#3610](https://github.com/divinevideo/divine-mobile/issues/3610)

---

### 13 fully commented-out test files
**Problem**: 13 test files have empty `void main() {}` bodies with all test logic commented out. They provide no coverage while consuming maintenance overhead.

**Evidence**: Notable examples: `test/providers/home_feed_refresh_on_follow_test.dart` (4 tests), `test/providers/profile_feed_pagination_test.dart` (6 cursor pagination tests), `test/integration/video_loading_flow_test.dart` (5 tests), plus 4 partially commented-out files. These files still import dependencies, are picked up by the test runner, and appear in test counts, appearing in test counts without contributing coverage.

**Impact**: Low. No functional harm, but unused files add noise to the test tree, inflate test file counts, and slow down static analysis.

**Effort**: Low. For each file, check git blame to determine if the code under test still exists. If yes, restore the tests. If not, delete the file. Can be done in a single PR.

**GitHub ticket**: [#3611](https://github.com/divinevideo/divine-mobile/issues/3611)

---

### Golden test suite is non-functional
**Problem**: All 12 `testGoldens` calls are skipped. 84 golden images committed with no test enforcing them. The `golden` tag is not registered.

**Evidence**: Only 3 golden test files exist (covering `UploadProgressIndicator`, `UserAvatar`, `VideoThumbnail`). All 12 `testGoldens` calls carry `skip: true` with a TODO comment "Fails on CI." 84 golden PNG images are committed to the repo with no active test enforcing them. The `golden` tag is not registered in `dart_test.yaml` (only `integration` is registered), making tag-based golden test selection impossible. No `TestTag.golden` constant class exists. The infrastructure is extensive: `golden_toolkit`, Alchemist (`^0.12.1`), `GoldenTestHelper`, `golden_test_devices.dart`, and a `flutter_test_config.dart` that already calls `loadAppFonts()` and configures `AlchemistConfig` with `CiGoldensConfig`. Despite all this wiring, the tests remain skipped.

**Impact**: Medium. Zero visual regression coverage despite significant infrastructure investment (Alchemist, golden_toolkit, helper classes, CI config all in place); committed golden images create false confidence about visual coverage; the CI rendering failure that caused the skips was never root-caused.

**Effort**: Medium. The infrastructure is already in place. The remaining work is: root-cause the CI rendering mismatch (Alchemist and `loadAppFonts()` are already configured, so the issue may be a golden image regeneration or platform-specific rendering delta), register the `golden` tag in `dart_test.yaml`, create `TestTag.golden` constant, un-skip and regenerate goldens, and add a dedicated golden CI job with `--update-goldens` available as a manual trigger.

**GitHub ticket**: [#3612](https://github.com/divinevideo/divine-mobile/issues/3612)

---

### Widget tests missing localization delegates
**Problem**: 39 screen test files do not include `AppLocalizations.localizationsDelegates`. Will silently fail as more widgets adopt `context.l10n`.

**Evidence**: 39 screen test files do not include `AppLocalizations.localizationsDelegates` and `supportedLocales` in their `MaterialApp` test wrapper. Tests that do pump `MaterialApp` generally include the delegates, so the pattern is established but inconsistently applied. As more widgets adopt `context.l10n`, these tests will silently fail to render localized text or crash with a missing delegate error.

**Done well**: The shared `createTestApp()` helper in `widget_test_helper.dart` already includes delegates correctly; the 39 tests just need to adopt it.

**Impact**: Low. Currently works because many widgets haven't adopted `context.l10n` yet, but becomes a growing problem with each l10n adoption. Silent failures make debugging harder.

**Effort**: Low. Migrate the 39 test files to use the existing `createTestApp()` helper, or add delegates directly to their `MaterialApp` wrappers. One-time fix that prevents all future occurrences.

**GitHub ticket**: [#3613](https://github.com/divinevideo/divine-mobile/issues/3613)

---

### Test file organization does not mirror `lib/`
**Problem**: The test tree deviates from the expected 1:1 `lib/` mirror in two ways: files in the wrong location, and single source files split across multiple test files.

**Evidence**:
- **9 test files at `test/` root** instead of in subdirectories: `hashtag_display_test.dart`, `hashtag_functionality_test.dart`, `hashtag_sorting_test.dart`, `main_keyboard_error_handler_test.dart`, `main_video_cache_startup_test.dart`, `profile_fetching_test.dart`, `revine_fix_test.dart`, `revine_profile_display_test.dart`, `video_visibility_manager_test.dart`. These appear to be one-off debug or bug-reproduction tests that were never reorganized.
- **114 test files split across 44 source files** instead of 1:1 mapping. Worst offenders: `video_event_service.dart` (25 test files across 3 directories), `upload_manager.dart` (9 test files), `curated_list_service.dart` (8 test files), `notification_service.dart` (7 test files). Common splitting patterns: feature-based (`_adult_filter_test`, `_deduplication_test`), operation-based (`_crud_test`, `_stream_test`), scope-based (`_unit_test`, `_simple_test`).

**Impact**: Medium. Split and misplaced test files make it harder to find the test for a given source file, scatter related setup across files (duplicating mocks), inflate file counts, and make it unclear whether a source file has full coverage.

**Effort**: Medium. Move root-level files into correct subdirectories. Consolidate split test files into single `<source>_test.dart` files using `group()` blocks. The `video_event_service` (25 files) and `upload_manager` (9 files) are the largest consolidation efforts; smaller splits are mechanical merges.

**GitHub ticket**: [#3614](https://github.com/divinevideo/divine-mobile/issues/3614)

---

### 25 test files with no `group()` organization
**Problem**: Flat lists of `testWidgets` calls with no grouping make test output harder to parse and failures harder to locate.

**Evidence**: 25 test files contain only top-level `testWidgets` or `test` calls with no `group()` structure. VGV testing standards recommend grouping by: "renders" / "navigation" / "interactions" for widget tests, by event name for BLoC tests, and by method name for repositories and clients. Without groups, test runner output is a flat list of descriptions with no hierarchy.

**Done well**: `hashtag_search_bloc_test.dart` groups by event type. `time_formatter_test.dart` groups by method name with edge cases.

**Impact**: Low. No functional impact on test correctness, but reduces readability of test output, makes it harder to run a subset of tests within a file, and makes test files harder to navigate.

**Effort**: Low. Wrap existing tests in appropriate `group()` calls. Mechanical change with no logic modifications.

**GitHub ticket**: [#3615](https://github.com/divinevideo/divine-mobile/issues/3615)

---

### Integration test coverage concentrated on onboarding; major runtime flows untested
**Problem**: 27 integration tests exist but coverage is concentrated on auth and camera flows. Major user-facing flows (feed scrolling, search/explore, social graph, comments, zaps, notifications, profile editing, upload, mute/block, bookmarks) have no integration test.

**Evidence**: The 27 tests in `mobile/integration_test/` (~6,148 lines) break down as: auth (9 files), video recorder (6), E2E (3), clip editor (2), privacy (2), content reporting (2), lifecycle/perf (2), secure storage (1). Infrastructure is mature: Patrol framework, 10 helper files (~1,469 lines) covering relay publishing, DB queries, HTTP helpers, navigation automation, and mock Nostr client, plus a full Docker stack (`local_stack/`) with 15 services (keycast, FunnelCake relay, Blossom, MinIO, invite). The investment in test infrastructure is already made; the gap is in breadth of flow coverage beyond onboarding and camera.

**Impact**: Medium. Regressions in high-traffic runtime flows (feed, social interactions, discovery) are caught manually or by users, not by automated tests.

**Effort**: High. Each new flow needs Docker stack interaction and potentially new test helpers. Priority: feed scroll/pagination (highest traffic), upload E2E (revenue-critical), follow/unfollow (social core).

**GitHub ticket**: [#3616](https://github.com/divinevideo/divine-mobile/issues/3616)
