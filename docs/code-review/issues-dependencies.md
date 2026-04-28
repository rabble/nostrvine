# Dependency Issues

Issues related to dependency hygiene, version currency, vendored overrides, and storage layer consolidation.

Note: The project has 44 packages across `mobile/packages/`. These issues cover version drift across 12 packages (including security-sensitive ones like `flutter_secure_storage`), vendored overrides and git-pinned dependencies with no removal plan, dual storage backends (Hive + Drift), and no automated dependency monitoring.

---

### `nostr_sdk` ownership: decide whether to keep in-repo, extract, or contribute upstream
**Problem**: `nostr_sdk` was forked and brought into the monorepo. It now lives as an in-repo package with no decision on its long-term home. As the package stabilizes, this decision becomes more relevant.

**Evidence**: `nostr_sdk` has zero path dependencies on other monorepo packages; its `pubspec.yaml` only depends on pub.dev packages (bip340, cryptography, dio, etc.). 17 monorepo packages depend on it (comments_repository, db_client, dm_repository, follow_repository, models, nostr_client, profile_repository, videos_repository, etc.). Commit history shows stabilization: Q4 2025 had 14 commits, 2026 YTD has 25, almost entirely fixes (relay performance, WebSocket guards, timestamp normalization), not new features. The package already has a pub.dev-ready `pubspec.yaml` with topics and description.

**Options**:
1. **Keep in-repo**: simplest, no migration cost. Downside: harder for external developers to contribute to or consume the SDK independently.
2. **Extract to the GitHub org as a standalone repo**: enables independent versioning, dedicated issue tracking, and potential reuse by other Nostr apps in the org. Can be consumed via git dependency or published to pub.dev. Downside: 17 in-repo consumers need to switch from `path:` to a versioned dependency; coordination overhead for cross-repo changes.
3. **Contribute back to the original upstream repo**: returns improvements to the community and reduces long-term maintenance burden. Downside: upstream may have diverged; requires alignment on API direction; less control over release cadence.

**Impact**: Low (no urgency). The package works fine in-repo. This is a strategic decision about long-term maintainability and community contribution.

**Effort**: Low to decide, Medium–High to execute option 2 or 3.

**GitHub ticket**: TBD

---

### Unused dependencies in root pubspec
**Problem**: `file_picker` and `cupertino_icons` are declared in the root `pubspec.yaml` but have zero imports in `lib/`.

**Evidence**: `file_picker` has 0 imports across the codebase, likely from a feature that was since removed. `cupertino_icons` has 0 imports; the project uses `DivineIcon` from `divine_ui` for all iconography. Both add to resolution time and attack surface without providing value.

**Impact**: Low. Unused dependencies increase `pub get` resolution time, inflate the dependency graph, and carry transitive dependencies that may introduce security advisories for code that is never executed.

**Effort**: Low. Remove both entries from `pubspec.yaml` and run `flutter pub get` to verify nothing breaks.

**GitHub ticket**: TBD

---

### Misplaced root-level dependencies
**Problem**: `convert` and `http_parser` are declared in the root `pubspec.yaml` but only used inside packages that already declare them independently.

**Evidence**: `convert` is used only in `nostr_sdk` and `funnelcake_api_client`, both of which declare it in their own `pubspec.yaml`. `http_parser` is used only in `funnelcake_api_client`, which also declares it independently. The root declaration is redundant and misleading, implying the app layer depends on these packages directly.

**Impact**: Low. Misleading dependency graph.

**Effort**: Low. Remove both from root `pubspec.yaml`, verify package-level declarations are sufficient.

**GitHub ticket**: TBD

---

### Vendored overrides with no upstream plan
**Problem**: `cryptography_flutter` (vendored at v2.3.2, latest is v2.3.4) and `app_device_integrity` (v1.1.0, uses outdated `flutter_lints` v2) are vendored in `overrides/` with no TODO or tracking issue for removal.

**Evidence**: `overrides/cryptography_flutter/` vendors v2.3.2 with modified SDK constraints; the latest on pub.dev is v2.3.4. `overrides/app_device_integrity/` vendors v1.1.0 with its own `analysis_options.yaml` that uses `flutter_lints: ^2.0.0` (4 major versions behind the current v6.0.0). Neither override directory contains a README, TODO comment, or linked GitHub issue explaining why the override exists or when it should be removed.

**Done well**: The `divine_video_player` migration (PR #3242) shows the team tracks and executes on dependency replacement.

**Impact**: Medium. Vendored code does not receive upstream security patches or bug fixes. The `flutter_lints` v2 usage in `app_device_integrity` means its analysis options are 4 major versions behind, missing years of updated lint rules. Without a removal plan, overrides become permanent forks.

**Effort**: Medium. Investigate whether upstream versions now fix the original issues; if so, remove the overrides and use the published packages. If not, add README files documenting the reason and a tracking issue for removal.

**GitHub ticket**: TBD

---

### Git-pinned dependencies with no removal plan
**Problem**: `c2pa_flutter` (git ref `0.0.3`) and `media_kit_video` (fork with "temporary" comment) are pinned to git refs with no tracking issue for migration back to pub.

**Evidence**: `c2pa_flutter` is pinned to git ref `0.0.3` in `pubspec.yaml` and is not available on pub.dev. `media_kit_video` uses a fork with a comment indicating it is temporary, but no GitHub issue tracks when to switch back to the upstream package. Git-pinned dependencies bypass pub.dev's security scanning and version constraint resolution.

**Impact**: Medium. Git-pinned deps are invisible to `flutter pub outdated`, cannot be audited by pub.dev's security tooling, and silently pin transitive dependencies. If the fork repo is deleted or force-pushed, builds break without warning.

**Effort**: Low. For `c2pa_flutter`, check if a pub.dev release now exists; for `media_kit_video`, create a tracking issue and verify the upstream fix status. Both need TODO comments at minimum.

**GitHub ticket**: TBD

---

### `device_info_plus` overridden 3 major versions behind
**Problem**: `device_info_plus` is pinned to v10.1.2 via a dependency override while the latest is v13.1.0.

**Evidence**: `pubspec.yaml` contains a `dependency_overrides` entry pinning `device_info_plus` to `10.1.2`. The latest stable release is `13.1.0`, three major versions ahead. The override was likely added to resolve a transitive version conflict, but it now prevents the package (and its platform-specific implementations) from receiving bug fixes and security patches.

**Impact**: Medium. Three major versions behind means missing platform compatibility fixes (especially for new iOS/Android versions), potential deprecation of APIs the app relies on, and increasing migration difficulty the longer the pin stays.

**Effort**: Medium. Remove the override, resolve any version conflicts surfaced by `flutter pub get`, and test on both iOS and Android. Major version bumps may include breaking API changes.

**GitHub ticket**: TBD

---

### Firebase suite behind latest
**Problem**: 5 Firebase packages have minor version bumps available.

**Evidence**: `firebase_core`, `firebase_analytics`, `firebase_crashlytics`, `firebase_messaging`, and `firebase_performance` all have newer minor or patch versions available. While not major version bumps, Firebase packages are tightly coupled, and updating one often requires updating the suite together.

**Impact**: Low. Minor versions typically contain bug fixes and performance improvements; falling behind makes future upgrades harder as changes accumulate.

**Effort**: Low. Bump all 5 Firebase packages together, run `flutter pub get`, and verify the app builds and Firebase features work on both platforms.

**GitHub ticket**: TBD

---

### `flutter_local_notifications` 2 major versions behind (19→21)
**Problem**: `flutter_local_notifications` is pinned to v19 while v21 is available, two major versions behind.

**Evidence**: `flutter pub outdated` shows v21 available. Two major version jumps mean two rounds of breaking API changes to address.

**Impact**: Medium. Missing platform fixes for newer iOS/Android notification APIs; two majors of accumulated breaking changes increases migration complexity.

**Effort**: Medium. Read changelogs for v20 and v21, update call sites, test notification delivery on both platforms.

**GitHub ticket**: TBD

---

### `flutter_secure_storage` 1 major version behind (9→10)
**Problem**: `flutter_secure_storage` is on v9 while v10 is available.

**Evidence**: `flutter pub outdated` shows v10 available. This package handles credential and token storage, which is security-sensitive code.

**Impact**: Medium. Security-sensitive package missing latest patches and platform keychain/keystore improvements.

**Effort**: Medium. Read v10 changelog, update call sites, verify secure storage read/write on both platforms. Prioritize due to security sensitivity.

**GitHub ticket**: TBD

---

### `go_router` 1 major version behind (16→17)
**Problem**: `go_router` is on v16 while v17 is available.

**Evidence**: `flutter pub outdated` shows v17 available. `go_router` is used app-wide via `app_router.dart` (1,117 lines) with 60+ route definitions.

**Impact**: Medium. App-wide routing package; breaking changes may affect navigation across the entire app.

**Effort**: High. Read v17 changelog, update route definitions and navigation call sites across the app, test deep linking and back navigation. Large blast radius due to app-wide usage.

**GitHub ticket**: TBD

---

### `google_fonts` 2 major versions behind (6→8)
**Problem**: `google_fonts` is on v6 while v8 is available.

**Evidence**: `flutter pub outdated` shows v8 available. Two major version jumps.

**Impact**: Low. Typography package; unlikely to affect core functionality but may include font rendering improvements.

**Effort**: Low. Read changelogs for v7 and v8, update any changed APIs. Likely a contained change.

**GitHub ticket**: TBD

---

### `share_plus` 1 major version behind (12→13)
**Problem**: `share_plus` is on v12 while v13 is available.

**Evidence**: `flutter pub outdated` shows v13 available.

**Impact**: Low. Sharing functionality; breaking changes likely limited to share API call sites.

**Effort**: Low. Read v13 changelog, update share call sites, test share flows on both platforms.

**GitHub ticket**: TBD

---

### `app_links` 1 major version behind (6→7)
**Problem**: `app_links` is on v6 while v7 is available.

**Evidence**: `flutter pub outdated` shows v7 available. Handles deep link and universal link routing.

**Impact**: Medium. Deep linking is user-facing; broken links silently fail.

**Effort**: Medium. Read v7 changelog, update initialization and listener code, test deep link handling on both platforms.

**GitHub ticket**: TBD

---

### `flutter_web_auth_2` 1 major version behind (4→5)
**Problem**: `flutter_web_auth_2` is on v4 while v5 is available.

**Evidence**: `flutter pub outdated` shows v5 available. Used for OAuth/web authentication flows.

**Impact**: Medium. Authentication package; breaking changes could affect login flows.

**Effort**: Medium. Read v5 changelog, update auth call sites, test all OAuth flows on both platforms.

**GitHub ticket**: TBD

---

### No automated dependency update tooling
**Problem**: No Dependabot or CI job monitors dependency freshness. Updates rely entirely on manual checks.

**Evidence**: No `.github/dependabot.yml` configuration exists. No CI workflow runs `flutter pub outdated` or alerts on available updates. Dependency updates happen only when a developer manually checks or when a build breaks due to a transitive conflict.

**Impact**: Medium. Without automated monitoring, dependencies drift silently. Security advisories on transitive dependencies go unnoticed until they cause build failures or are discovered in manual audits (like this one).

**Effort**: Low. Add a Dependabot configuration for the root `pubspec.yaml` and key packages. Alternatively, add a scheduled CI job that runs `flutter pub outdated` and posts results to a Slack channel or creates an issue.

**GitHub ticket**: TBD

---

### Migrate Hive CE usage to Drift
**Problem**: The app uses both Hive CE and Drift for local persistence. Hive should be consolidated into Drift, the primary storage layer.

**Evidence**: 12 files in `lib/` import Hive for simple caching (notification preferences, hashtag cache, personal event cache, upload state). Drift is the primary database layer via `db_client` with 15 tables and 68 imports. Some data is duplicated; Drift already has `PendingUploads` and `Notifications` tables that overlap with Hive usage. All Hive use cases fit naturally into Drift tables.

**Done well**: `db_client` with 15 tables and 68 imports is the mature, well-established primary storage layer, and the migration target is ready.

**Impact**: Medium. Two storage systems means two sets of migration code, two initialization paths, two failure modes. Developers must know which system owns which data. Risk of data inconsistency between the two stores.

**Effort**: High. Requires migrating all 12 Hive usage sites to Drift, writing data migration logic for existing user data, and removing the Hive dependency. Best done incrementally per feature.

**GitHub ticket**: TBD


---

### Migrate to `divine_video_player`: replace `media_kit` fork with native platform APIs
**Problem**: Video playback currently uses a forked `media_kit` (wrapping libmpv/ffmpeg). While the team controls the fork, the underlying stack adds bundle size (ffmpeg) and introduces an abstraction layer between the app and the native platform players. Work is already underway (PR #3242) to replace it with `divine_video_player`, which uses platform APIs directly (ExoPlayer on Android, AVPlayer on iOS/macOS).

**Evidence**: `divine_video_player` already exists in `mobile/packages/divine_video_player/` (~1,000 lines of Dart, plus native platform code). `pooled_video_player` (current player, 21 Dart files) wraps the `media_kit` fork. PR #3242 integrates `divine_video_player` into the feed behind an experimental feature flag. The new player resolves several concrete issues: HLS support on Android, smoother swiping (no thumbnail fallback), higher preload limits, smaller bundle size (no ffmpeg), and hot restart stability.

**Trade-off**: Maintaining a custom video player built on native APIs is a significant long-term commitment: platform API changes, codec edge cases, and device-specific bugs become the team's responsibility. However, video playback is the core of diVine. Using native APIs directly removes the libmpv/ffmpeg layer, reduces bundle size, and gives the team a simpler stack to reason about and debug.

**Impact**: High. Directly affects the core user experience (feed scrolling, playback quality, format support).

**Effort**: High. The player package exists and is being integrated. Remaining work: complete feed integration, migrate all other playback surfaces (explore, profile, video detail, editor preview), remove `media_kit`/`pooled_video_player`, and establish test coverage for the new package.

**GitHub ticket**: TBD (relates to #2732)

---

### Bundled Google Fonts missing OFL license files and `LicenseRegistry` registration
**Problem**: Five font files bundled in `mobile/google_fonts/` have no accompanying OFL license text, and no `LicenseRegistry.addLicense` call registers them in the app.

**Evidence**: `mobile/google_fonts/` contains `BricolageGrotesque-Bold.ttf`, `BricolageGrotesque-ExtraBold.ttf`, `Inter-Regular.ttf`, `Inter-Medium.ttf`, `Inter-SemiBold.ttf`, all OFL-1.1 licensed. No `OFL.txt` or `LICENSE` file accompanies them. Zero matches for `LicenseRegistry` in `mobile/lib/`. The OFL requires that the license text be included with any distribution of the font software. The `google_fonts` package documentation explicitly requires developers to register font licenses before publishing.

**Impact**: Low. OFL is permissive and permits commercial use, but distributing fonts without the accompanying license text is technically a violation.

**Effort**: Low. Add OFL.txt files alongside the `.ttf` files and add a `LicenseRegistry.addLicense` call in `main.dart` that registers the OFL text for each font family. ~30 minutes of work.

---

### Inconsistent HTTP client libraries across packages
**Problem**: `funnelcake_api_client`, `invite_api_client`, and `app_version_client` use `package:http`, while `blossom_upload_service` uses `package:dio`. Dio is the more robust choice for the app's needs (interceptors, upload progress, streaming, retry).

**Evidence**: `mobile/packages/funnelcake_api_client/pubspec.yaml` line 12: `http: ^1.4.0`. `mobile/packages/blossom_upload_service/pubspec.yaml` line 10: `dio: ^5.7.0`. Two different HTTP libraries mean two different error handling patterns, two different interceptor mechanisms, and two different mock strategies in tests.

**Done well**: `blossom_upload_service` uses Dio with upload progress tracking and streaming, the more robust HTTP client for the app's needs.

**Impact**: Medium. Team context-switches between two HTTP abstractions; shared concerns (auth headers, timeouts, retry) are duplicated rather than centralized.

**Effort**: High. Standardizing on Dio across all API client packages is a large migration. A smaller improvement: extract shared auth/header logic into a common utility rather than duplicating it across clients.

**GitHub ticket**: TBD
