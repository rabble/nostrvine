# Code Review: Issue Tracker

Working document. GitHub issues will be created once the list is finalized.

**Reference commit:** [`4f2834ddb`](https://github.com/divinevideo/divine-mobile/commit/4f2834ddb529487020333feea8e269c6fa19bfbc): `feat(feed): move captions control into more info (#3105)` (2026-04-16)

> **Note:** All file paths, line numbers, and code snippets in the issue files below were captured at the reference commit. Since `main` continues to evolve, some references may be outdated — files may have moved, lines shifted, or code changed. When acting on an issue, verify against the current state of the codebase.

## Summary

The codebase has strong foundations: a well-established BLoC pattern (42 directories, 61 test files), VGV CI infrastructure across 33 packages, consistent `VineTheme` adoption in 194 files, and solid security primitives for key storage. Repository packages like `videos_repository` and `comments_repository` demonstrate the target architecture cleanly.

The central finding is **incomplete migrations and inconsistent application of established rules**. The target architecture (BLoC-first, layered, co-located features) is well-documented and working where adopted, with an ongoing migration underway. However, 140 services bypass the layer model and three state management patterns still coexist. The same inconsistency shows up in error handling (~170 catch blocks with undocumented contracts), testing (223 skipped tests, non-functional golden suite), localization (hardcoded English strings alongside 1,251+ `context.l10n` usages), and accessibility (core screens invisible to screen readers despite semantic infrastructure in the video feed).

## Recommendations

The 91 findings consolidate into **7 strategic initiatives**, ordered by return on investment. Each bundles related issues into a coherent workstream the team can plan efforts around, rather than triaging 91 individual tickets.

**How to read this section**: Within each initiative, items are listed in priority order. Every item links to its detailed finding (with full evidence, code references, and positive examples) in the issue files.

---

### 1. Immediate Fixes (11 issues)

High-impact, low-effort items that each ship as a self-contained PR. No architectural decisions required.

| # | Action | Source |
|:-:|--------|--------|
| 1 | **Re-enable R8 minification** — `isMinifyEnabled = true` for 30–50% APK size reduction | [Performance](issues-performance.md) |
| 2 | **Fix private key escape** — move `createAnonymousAccountFromPrivateKeyHex` inside `withPrivateKey` callback | [Security](issues-security.md) |
| 3 | **Add CI workflows for 7 packages** — copy existing VGV reusable template | [CI/CD](issues-ci-cd.md) |
| 4 | **Add `analysis_options.yaml` to 3 packages** — `follow_repository`, `keycast_flutter`, `nostr_apps` | [Tooling](issues-tooling.md) |
| 5 | **Replace 5 `Image.network` with `VineCachedImage`** — adds disk caching, placeholders, retry | [UI/UX](issues-ui-ux.md) |
| 6 | **Fix `context.watch` → `context.select`** — 3 documented cases causing unnecessary rebuilds | [Performance](issues-performance.md) |
| 7 | **Extract `_request<T>` helper in `FunnelcakeApiClient`** — eliminate 24-method boilerplate duplication (also fixes notification error suppression) | [Code Quality](issues-code-quality.md) |
| 8 | **Defer startup cleanup to background isolate** — 4 delete queries currently blocking cold start | [Performance](issues-performance.md) |
| 9 | **Remove unused root dependencies** — `file_picker`, `cupertino_icons` (zero imports) | [Dependencies](issues-dependencies.md) |
| 10 | **Remove misplaced root dependencies** — `convert`, `http_parser` (already declared in consuming packages) | [Dependencies](issues-dependencies.md) |
| 11 | **Add OFL license files** for 5 bundled Google Fonts + `LicenseRegistry` registration | [Dependencies](issues-dependencies.md) |

---

### 2. Security Hardening (2 remaining issues)

The most urgent key escape fix is in [Immediate Fixes](#1-immediate-fixes-11-issues). These 2 close the remaining gaps in key management and logging.

| # | Action | Source |
|:-:|--------|--------|
| 1 | **Redesign `getPrivateKeyForSigning`** — accept a signing callback instead of returning the raw key as `String` | [Security](issues-security.md) |
| 2 | **Add pre-capture log filter** — scrub hex-format private keys before writing to the 50K-entry ring buffer | [Security](issues-security.md) |

---

### 3. Video Feed Performance (5 issues)

All 7 performance findings cluster around the video feed. These 5 cover the network layer, rendering, scroll, and build-method hot paths.

| # | Action | Source |
|:-:|--------|--------|
| 1 | **Wire `GET /api/videos/{id}/stats`** — replace 3 relay round-trips per video with 1 API call | [Performance](issues-performance.md) |
| 2 | **Fix video feed rendering inefficiencies** — O(n²) dedup, O(n) per-item lookup, map/filter rebuilt every render, controller leak on web | [Performance](issues-performance.md) |
| 3 | **Move profile grid de-duplication out of `build()`** — DateTime parsing, Set checks, and cache warmup currently run on every rebuild | [Performance](issues-performance.md) |
| 4 | **Adopt optimistic updates as the default pattern** — update UI immediately, publish to relay in background (proven in `CommentsBloc`) | [Architecture](issues-architecture.md) |
| 5 | **Cancel orphaned `Future.delayed` in `VideoFeedItem`** — 2 uncancellable futures outlive widget on fast scroll | [Performance](issues-performance.md) |

---

### 4. Architecture, Simplicity & Code Quality (35 issues)

**This is the central finding.** The target architecture (`UI → BLoC → Repository → Client`) is well-established and proven where adopted. The gap is incomplete migration and inconsistent application: 140 services bypass the layer model, three state management patterns coexist, and code quality patterns (error handling, equality, serialization) vary by file age.

Tackle in phases, each phase unlocks the next:

#### Phase A — Layer Completion (10 issues)

The structural foundation everything else builds on. The services directory and data source strategy are the highest-priority items.

| # | Action | Source |
|:-:|--------|--------|
| 1 | **Classify and migrate `services/` directory** — 140 files mixing repositories, clients, and utilities in one flat directory | [Architecture](issues-architecture.md) |
| 2 | **Stop UI from bypassing BLoC** — 40+ screens/widgets import services directly; 13 screens filter/sort inside `build()` | [Architecture](issues-architecture.md) |
| 3 | **Complete state management migration** — 176 Riverpod + 49 ChangeNotifier files coexist with 125 BLoC files; ChangeNotifier not tracked in plan | [Architecture](issues-architecture.md) |
| 4 | **Document data source strategy** — define when to use each of the 4 read patterns; wire 5 unwired Funnelcake endpoints | [Architecture](issues-architecture.md) |
| 5 | **Extract repository from `VideoEvent` model** — 1,502 lines with embedded URL scoring, selection logic, and 46 `developer.log` calls | [Architecture](issues-architecture.md) |
| 6 | **Migrate database to proper schema versioning** — stuck at v1 with 330+ lines of ad-hoc SQL on every startup | [Architecture](issues-architecture.md) |
| 7 | **Adopt co-located feature structure** — only 3 of 40+ features use the desired `features/` pattern | [Architecture](issues-architecture.md) |
| 8 | **Convert 13+ singleton services to constructor injection** — `factory => _instance` singletons wrapped in providers but untestable | [Architecture](issues-architecture.md) |
| 9 | **Design unified caching architecture** — 13 independent caches across 4 storage backends, no shared strategy | [Architecture](issues-architecture.md) |
| 10 | **Extract analytics package with `BlocObserver`** — 9 services, 2,629 LOC, no unified schema; UI calls analytics directly | [Architecture](issues-architecture.md) |

#### Phase B — Error Handling Contracts (5 issues)

Once layer boundaries are clearer, standardize how errors flow through them.

| # | Action | Source |
|:-:|--------|--------|
| 1 | **Add `addError(e, stackTrace)` to 54 BLoC catch blocks** — unlocks observability, fixes `blocTest`'s `errors` parameter | [Error Handling](issues-error-handling.md) |
| 2 | **Remove error strings from 5 BLoC state classes** — replace `String? errorMessage` with status enum + `addError()` | [Error Handling](issues-error-handling.md) |
| 3 | **Document contracts for ~170 suppressed catch blocks** — callers can't distinguish "no data" from "crashed" | [Error Handling](issues-error-handling.md) |
| 4 | **Replace raw exception text in ~28 user-facing messages** — users see `.toString()` output | [Error Handling](issues-error-handling.md) |
| 5 | **Audit ~12 empty catch blocks** — add logging or document the intentional no-op | [Error Handling](issues-error-handling.md) |

#### Phase C — Code Simplification (7 issues)

Break up the largest files and remove duplication. Each is independent and can be done when the file is next touched.

| # | Action | Source |
|:-:|--------|--------|
| 1 | **Break up oversized files** — 30+ files over 800 lines; led by `video_event_service` (5,652), `auth_service` (4,223), `share_video_menu` (2,864) | [Simplicity](issues-simplicity.md) |
| 2 | **Refactor `main.dart`** — 1,801 lines, 84 imports, 7+ responsibilities | [Simplicity](issues-simplicity.md) |
| 3 | **Delete dual notification system** — new BLoC version is ready; ~1,500 LOC removed | [Simplicity](issues-simplicity.md) |
| 4 | **Consolidate 8 content moderation services** into a single `ModerationPipeline` | [Simplicity](issues-simplicity.md) |
| 5 | **Rename `VideoFeedState` collision** — BLoC variant → `VideoFeedBlocState` | [Simplicity](issues-simplicity.md) |
| 6 | **Delete `DivineTheme`** — 3 references; migrate to `VineTheme` | [Simplicity](issues-simplicity.md) |
| 7 | **Move non-app code out of `lib/`** — debug screen, scripts, transport stubs (~520 LOC) | [Simplicity](issues-simplicity.md) |

#### Phase D — Code Patterns & Tooling (13 issues)

Standardize patterns so new code doesn't recreate old inconsistencies.

| # | Action | Source |
|:-:|--------|--------|
| 1 | **Re-enable 38 suppressed lint rules (phased)** — type-safety rules (`invalid_assignment`, `return_of_invalid_type`) mask real bugs | [Tooling](issues-tooling.md) |
| 2 | **Extract `_buildFoo()` methods to widget classes** — 20+ files with the helper method anti-pattern | [Code Quality](issues-code-quality.md) |
| 3 | **Standardize model equality on `Equatable`** — 9 models use Equatable, 20+ use hand-rolled `==`, several have none | [Code Quality](issues-code-quality.md) |
| 4 | **Standardize serialization approach** — `json_serializable` on one model, hand-rolled everywhere else | [Code Quality](issues-code-quality.md) |
| 5 | **Remove 22 `Future.delayed` calls in app code** — each is a potential indicator of an underlying race condition or coordination bug masked by "wait a bit"; replace with explicit async coordination | [Code Quality](issues-code-quality.md) |
| 6 | **Consolidate duplicate log batchers** — two utilities, same concept, different APIs | [Code Quality](issues-code-quality.md) |
| 7 | **Migrate GoRouter to `@TypedGoRoute`** — 1,117-line procedural router vs project's own type-safe routing rules | [Navigation](issues-navigation.md) |
| 8 | **Add deep link parameter validation** — no format checking on video IDs, npub, or hashtags | [Navigation](issues-navigation.md) |
| 9 | **Add READMEs to all packages** — using the existing 15-line template | [Documentation](issues-documentation.md) |
| 10 | **Make architecture docs discoverable by contributors** — link from `CONTRIBUTING.md` or create contributor-facing `docs/ARCHITECTURE.md` | [Documentation](issues-documentation.md) |
| 11 | **Migrate 56 files from raw `TextStyle` to `VineTheme` font methods** | [UI/UX](issues-ui-ux.md) |
| 12 | **Replace 7 files using raw `Colors.*`** with `VineTheme` tokens | [UI/UX](issues-ui-ux.md) |
| 13 | **Fix 4 screens with missing error state branches** | [UI/UX](issues-ui-ux.md) |

---

### 5. Test & CI Recovery (11 issues)

BLoC testing is strong (42 directories, 61 test files). The gaps are below and around the BLoC layer: 50+ untested services, 264 flaky `Future.delayed` calls, 223 skipped tests with no owner, a non-functional golden suite, and no coverage enforcement for the main app.

| # | Action | Source |
|:-:|--------|--------|
| 1 | **Add coverage enforcement to mobile CI** — 8 shards run tests but never pass `--coverage` or check a threshold | [CI/CD](issues-ci-cd.md) |
| 2 | **Raise package coverage thresholds** — range from 20% to 100%; set each to current actual, then increase incrementally | [CI/CD](issues-ci-cd.md) |
| 3 | **Write tests for 50+ untested services** — includes safety-critical `content_moderation`, `mute`, `bookmark`. Best paired with the service-to-package extraction in [Initiative 4A](#phase-a--layer-completion-10-issues): adding tests as each service is extracted into a package | [Testing](issues-testing.md) |
| 4 | **Replace 264 `Future.delayed` calls with `fakeAsync`** — single largest source of test flakiness, known 6+ months | [Testing](issues-testing.md) |
| 5 | **Triage 223 skipped tests** — assign owners, link to issues, restore or delete; ~14,000 lines of skipped coverage | [Testing](issues-testing.md) |
| 6 | **Re-enable golden test suite** — infrastructure is ready (Alchemist, golden_toolkit, CI config); root-cause the rendering mismatch | [Testing](issues-testing.md) |
| 7 | **Consolidate test file organization** — 9 root-level files; 114 files split across 44 sources (worst: `video_event_service` at 25 test files) | [Testing](issues-testing.md) |
| 8 | **Migrate 39 screen tests to `createTestApp` helper** — existing helper already includes l10n delegates | [Testing](issues-testing.md) |
| 9 | **Add `group()` structure to 25 test files** | [Testing](issues-testing.md) |
| 10 | **Delete 13 empty test files** | [Testing](issues-testing.md) |
| 11 | **Expand integration test coverage** — major flows (feed scroll, search, follow/unfollow, upload) untested despite mature Patrol infrastructure | [Testing](issues-testing.md) |

---

### 6. Accessibility & Localization (10 issues)

| # | Action | Source |
|:-:|--------|--------|
| 1 | **Add semantic labels to core navigation** — bottom nav, explore grid, notifications are invisible to screen readers | [UI/UX](issues-ui-ux.md) |
| 2 | **Add `SemanticsService.announce` for async operations** — zero announcements for uploads, deletes, follows, errors | [UI/UX](issues-ui-ux.md) |
| 3 | **Fix touch targets below 48dp** — `VideoFollowButton` is 20×20dp (critical engagement action) | [UI/UX](issues-ui-ux.md) |
| 4 | **Wire 15+ hardcoded English strings to `context.l10n`** — many already have unused ARB keys defined | [UI/UX](issues-ui-ux.md) |
| 5 | **Add ICU plural syntax** to 22 ARB keys + replace 11 inline Dart ternaries — Arabic, Polish, Romanian broken | [UI/UX](issues-ui-ux.md) |
| 6 | **Audit `onSurfaceMuted` WCAG contrast** — ~4.0:1 ratio, below 4.5:1 AA threshold; affects 738 usages across 194 files | [UI/UX](issues-ui-ux.md) |
| 7 | **Add `disableAnimations` checks** — zero of 55+ animations respect reduced-motion preference | [UI/UX](issues-ui-ux.md) |
| 8 | **Clean up 94 orphaned ARB keys** — defined but unused; wasted translation effort across 14 languages | [UI/UX](issues-ui-ux.md) |
| 9 | **Add `ExcludeSemantics` / `MergeSemantics`** — zero uses; decorative elements clutter semantics tree | [UI/UX](issues-ui-ux.md) |
| 10 | **Add 3 missing ARB keys** to 14 non-English files | [UI/UX](issues-ui-ux.md) |

---

### 7. Dependency Hygiene (16 issues)

12 packages are 1–3 major versions behind, 2 vendored overrides and 2 git-pinned dependencies have no removal plan, and no automated tooling monitors freshness. The highest-impact dependency migration (`divine_video_player` replacing `media_kit`) is already underway.

| # | Action | Source |
|:-:|--------|--------|
| 1 | **Set up automated dependency monitoring** — add Dependabot or scheduled `flutter pub outdated` CI job | [Dependencies](issues-dependencies.md) |
| 2 | **Update `flutter_secure_storage` (v9→v10)** — security-sensitive, priority upgrade | [Dependencies](issues-dependencies.md) |
| 3 | **Update `flutter_local_notifications` (v19→v21)** — 2 majors behind | [Dependencies](issues-dependencies.md) |
| 4 | **Remove `device_info_plus` override** — pinned 3 majors behind (v10→v13) | [Dependencies](issues-dependencies.md) |
| 5 | **Update `app_links` (v6→v7)** — deep link handling | [Dependencies](issues-dependencies.md) |
| 6 | **Update `flutter_web_auth_2` (v4→v5)** — OAuth flows | [Dependencies](issues-dependencies.md) |
| 7 | **Document or remove vendored overrides** — `cryptography_flutter`, `app_device_integrity` (no README or tracking issue) | [Dependencies](issues-dependencies.md) |
| 8 | **Add tracking issues for git-pinned deps** — `c2pa_flutter`, `media_kit_video` fork | [Dependencies](issues-dependencies.md) |
| 9 | **Complete `divine_video_player` migration** — replace `media_kit` fork, remove ffmpeg (PR #3242 underway) | [Dependencies](issues-dependencies.md) |
| 10 | **Migrate Hive CE to Drift** — 12 files use both storage systems with data overlap risk | [Dependencies](issues-dependencies.md) |
| 11 | **Decide `nostr_sdk` ownership** — keep in-repo, extract to org, or contribute upstream | [Dependencies](issues-dependencies.md) |
| 12 | **Update `go_router` (v16→v17)** — app-wide routing, large blast radius | [Dependencies](issues-dependencies.md) |
| 13 | **Standardize HTTP client library** — `package:http` in 3 clients vs `package:dio` in 1 | [Dependencies](issues-dependencies.md) |
| 14 | **Bump Firebase suite** — 5 packages with minor updates available | [Dependencies](issues-dependencies.md) |
| 15 | **Update `google_fonts` (v6→v8)** | [Dependencies](issues-dependencies.md) |
| 16 | **Update `share_plus` (v12→v13)** | [Dependencies](issues-dependencies.md) |

---

## Issue Files

| Theme | File | Issues |
|-------|------|--------|
| Architecture | [issues-architecture.md](issues-architecture.md) | 11 |
| Testing | [issues-testing.md](issues-testing.md) | 9 |
| Code Simplicity | [issues-simplicity.md](issues-simplicity.md) | 7 |
| UI/UX, Localization & Accessibility | [issues-ui-ux.md](issues-ui-ux.md) | 14 |
| Documentation | [issues-documentation.md](issues-documentation.md) | 2 |
| Error Handling | [issues-error-handling.md](issues-error-handling.md) | 6 |
| Code Quality | [issues-code-quality.md](issues-code-quality.md) | 6 |
| Navigation | [issues-navigation.md](issues-navigation.md) | 2 |
| Tooling & CI | [issues-tooling.md](issues-tooling.md) | 2 |
| CI/CD | [issues-ci-cd.md](issues-ci-cd.md) | 3 |
| Dependencies & Licenses | [issues-dependencies.md](issues-dependencies.md) | 19 |
| Security | [issues-security.md](issues-security.md) | 3 |
| Performance | [issues-performance.md](issues-performance.md) | 7 |

**Total: 91 issues**
