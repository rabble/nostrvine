# Code Simplicity Issues

Issues related to duplication, oversized files, unused code, and unnecessary complexity.

> **Oversized-file status — August 2026.** This document started as the April
> #3530 audit baseline. The oversized-file section below now reflects current
> `origin/main` and the live #4339 maintainability inventory. Other historical
> sections retain their April audit context unless explicitly annotated.

Note: Newer features like `features/feature_flags/` demonstrate clean
co-location, and the BLoC migration has produced focused classes. These issues
cover legacy complexity and newer growth pressure: 58 non-generated Dart files
under `mobile/lib` are currently over 800 lines, led by
`video_event_service.dart` at 6,619 lines.

---

### Oversized files (58 files over 800 lines)
**Problem**: Oversized files remain a visible maintainability backlog. The
broad file-size ratchet for #4339 is intentionally advisory rather than a
blocking CI failure. The refreshed advisory baseline in
`mobile/scripts/baseline/file_sizes.txt` now records the current 58-file
inventory so future warnings mean a PR added or grew an oversized file after
this snapshot.

**Evidence**: Current largest files over 800 lines, excluding generated/l10n:
`video_event_service.dart` (6,619), `auth_service.dart` (4,769),
`video_editor_canvas.dart` (3,343), `main.dart` (3,075),
`video_event_publisher.dart` (2,316), `upload_manager.dart` (2,310),
`video_recorder_bloc.dart` (2,295), `clip_editor_bloc.dart` (1,854),
`curated_list_service.dart` (1,834), `video_editor_provider.dart` (1,566),
`creator_analytics_screen.dart` (1,498), `feed_videos.dart` (1,412),
`video_editor_render_service.dart` (1,405), `sound_detail_screen.dart`
(1,386), and `profile_editor_bloc.dart` (1,383).

Focused, already-shrunk wins are no longer in the inventory:
`app_providers.dart` and `app_router.dart` are no longer oversized, and
`video_feed_page.dart` is below the 800-line threshold. To refresh these
figures, run `UPDATE_BASELINE=1 bash mobile/scripts/check_file_size_ceiling.sh`
from the repo root, then re-derive this evidence list from
`mobile/scripts/baseline/file_sizes.txt`. The largest current growth cluster is
video editor/recorder code: canvas, recorder bloc, clip editor bloc, editor
provider, render service, timeline strip, timeline widget, and editor scaffold.

**Impact**: High. These files are hard to test, review, and modify; they create
merge-conflict pressure when multiple engineers touch the same surface; and
large UI/BLoC/service files make architectural boundaries harder to see. The
advisory baseline keeps that pressure visible without blocking unrelated PRs.

**Effort**: High. Each oversized file requires a domain-specific decomposition
strategy. Priority targets are the video-editor cluster
([#6933](https://github.com/divinevideo/divine-mobile/issues/6933)),
`video_event_service`, `auth_service`, `main.dart`, and `upload_manager`
([#6935](https://github.com/divinevideo/divine-mobile/issues/6935)).
Remaining production `Future.delayed` paydown is tracked separately in
[#6934](https://github.com/divinevideo/divine-mobile/issues/6934), with the
existing production timing ratchet staying hard-gated.

**GitHub ticket**: [#3594](https://github.com/divinevideo/divine-mobile/issues/3594)
— closed 2026-05-13; superseded by epic
[#4339](https://github.com/divinevideo/divine-mobile/issues/4339) Wave 2/4
([#3337](https://github.com/divinevideo/divine-mobile/issues/3337),
[#3334](https://github.com/divinevideo/divine-mobile/issues/3334),
[#4506](https://github.com/divinevideo/divine-mobile/issues/4506),
[#4507](https://github.com/divinevideo/divine-mobile/issues/4507),
[#4508](https://github.com/divinevideo/divine-mobile/issues/4508),
[#4511](https://github.com/divinevideo/divine-mobile/issues/4511)–[#4516](https://github.com/divinevideo/divine-mobile/issues/4516)).

---

### `main.dart` is an oversized entry point with 7+ responsibilities
**Problem**: `main.dart` bundles startup orchestration, service initialization, deep link handling, provider wiring, logging configuration, and UI widgets into a single file. Each concern is tightly coupled to the rest, making the startup sequence hard to understand, test, or modify independently.

**Evidence**: `mobile/lib/main.dart` is currently 3,075 lines with 138 imports
and contains:
1. **Firebase background message handler** (~50 lines): top-level isolate function for push notifications
2. **Startup coordinator setup** (~250 lines): phased initialization with timing instrumentation
3. **`_startOpenVineApp()`** (~600 lines): bindings, crash reporting, video cache config, window manager, DNS overrides, logging config, error zone setup, `debugPrint` override
4. **Service initialization functions** (~150 lines): 8 separate `_initialize*` functions for core services, audio session, media playback, Hive, video cache manifest, seed data preload, seed media preload, Zendesk
5. **`DivineApp` widget** (~700 lines): deep link handling, deferred startup, background services, `MultiRepositoryProvider` with 20+ providers, router config, back navigation
6. **`_UploadFailureListener` widget** (~60 lines): upload failure bottom sheet
7. **`_CrashProbeHotspot` widget** (~30 lines): hidden dev tool

The `DivineApp.build()` method alone is ~400 lines deep with nested `MultiRepositoryProvider`, `MultiBlocProvider`, and `BlocListener` wrappers.

**Impact**: Medium. Any change to startup, deep linking, provider wiring, or logging requires editing the same file. The 138 imports create a dependency fan-in that makes `main.dart` a merge conflict hotspot. The startup sequence is hard to test because initialization functions depend on global singletons and side effects.

**Effort**: Medium. Extract incrementally: (1) move `_UploadFailureListener` and `_CrashProbeHotspot` to their own files, (2) extract the startup/initialization functions into a dedicated `startup/` module, (3) extract the `MultiRepositoryProvider`/`MultiBlocProvider` wiring into a dedicated provider setup widget, (4) extract deep link handling into its own service (partially exists in `deep_link_service.dart` already).

**GitHub ticket**: [#3595](https://github.com/divinevideo/divine-mobile/issues/3595) — closed 2026-05-13; superseded by [#3337](https://github.com/divinevideo/divine-mobile/issues/3337).

---

### Dual notification implementation
**Problem**: Old `NotificationsScreen` (765 lines, marked TODO-remove) coexists with new BLoC-based `lib/notifications/`. Both run simultaneously.

**Evidence**: Old: `screens/notifications_screen.dart` (765 lines, `// TODO(notifications-refactor): Remove after migration is verified`). Old provider: `providers/relay_notifications_provider.dart` (also marked TODO-remove). New: `lib/notifications/` feature (BLoC-based, correct architecture). The old screen is still wired into `screens/inbox/inbox_view.dart:93` as `const NotificationsScreen()`. The relay notifications provider is still referenced from `app_shell.dart` for unread badge count. Both systems run simultaneously.

**Done well**: The new `lib/notifications/` feature demonstrates the correct BLoC-based architecture. The replacement is built; it just needs to fully replace the old implementation.

**Impact**: Medium. Two notification systems running simultaneously; confusion about which is canonical; ~1,500 LOC of dual-system code in total (old screen + provider + wiring).

**Effort**: Low. Verify the new `lib/notifications/` BLoC system covers all functionality, update `inbox_view.dart` to use the new notifications page, delete old screen and provider. Estimated ~1,000 LOC net deletion after wiring updates.

**GitHub ticket**: [#3596](https://github.com/divinevideo/divine-mobile/issues/3596) — closed 2026-05-12; work landed.

---

### Duplicate `VideoFeedState` name collision
**Problem**: One Freezed sealed class in `state/video_feed_state.dart`, one Equatable class in `blocs/video_feed/video_feed_state.dart`. Same name, different types.

**Evidence**: `mobile/lib/state/video_feed_state.dart`: Freezed sealed class used by Riverpod providers. `mobile/lib/blocs/video_feed/video_feed_state.dart`: Equatable class used by `VideoFeedBloc`. Two classes called `VideoFeedState` with different structures and different base classes. Dart avoids conflicts only because they're in different import paths, but any new engineer will find both and be unsure which to use.

**Impact**: Low. Cognitive tax for contributors; risk of importing the wrong class; impediment to eventual consolidation of the video feed state management.

**Effort**: Low. Rename the BLoC-internal one to `VideoFeedBlocState` (it's a `part of` the bloc, only one file needs changing). ~5 minutes.

**GitHub ticket**: [#3597](https://github.com/divinevideo/divine-mobile/issues/3597)
— closed 2026-05-18; work landed.

---

### Content moderation: 8 services for one concern
**Problem**: 8 intertwined services called independently at every filter point instead of composed into a pipeline.

**Evidence**: 8 files, 2,458 LOC total: `content_moderation_service.dart` (705), `content_filter_service.dart` (281), `content_blocklist_service.dart` (713), `moderation_label_service.dart` (631), `blocklist_content_filter.dart` (15, a single function wrapping `ContentBlocklistService.shouldFilterFromFeeds` to match a typedef — adds no logic), `nsfw_content_filter.dart` (113), `divine_host_filter_service.dart`, `video_moderation_status_service.dart` (278). `VideoEventService` imports all of them and calls them in sequence at every filter point. No single place to understand the full moderation pipeline.

**Impact**: Medium. Callers must coordinate 6+ service calls independently at every filter point; no single place to understand the moderation pipeline; `VideoEventService` couples to all 8 services. The 15-line wrapper function adds no logic.

**Effort**: Medium. Introduce a `ModerationPipeline` that composes `ContentBlocklistService`, `NsfwContentFilter`, `ModerationLabelService`, and `DivineHostFilterService` into a single `shouldFilter(VideoEvent) → ModerationDecision` call. `ContentFilterService` already partially does this; expand it. Inline the 15-line wrapper.

**GitHub ticket**: [#3598](https://github.com/divinevideo/divine-mobile/issues/3598) — closed 2026-05-13; work landed.

---

### Non-app code ships in production `lib/`
**Problem**: Debug screen, operational scripts (`lib/scripts/`), and test infrastructure (`lib/nostr/transport/`) compiled into every build with no production call sites.

**Evidence**: Debug screen: `lib/screens/debug_video_test.dart` (~120 lines, `ConsumerStatefulWidget`, not wired to any route, only referenced by its own file). Scripts: `lib/scripts/` (3 files, ~300 lines: `bulk_thumbnail_generator.dart`, `debugprint_to_unified_logger_migration.dart`, `migrate_logging.dart`; developer tools importing `openvine/services/` and `openvine/constants/`). Test infra: `lib/nostr/transport/` (3 files, ~100 lines: `in_memory_transport.dart`, `nostr_fixture_pump.dart`, `nostr_transport.dart`; relay simulation utilities with zero production call sites, tested in `test/nostr/transport/`). All compiled into every production build.

**Impact**: Low. Increases binary size; debug/test code in production bundle is a code hygiene issue; `lib/scripts/` imports heavy service dependencies unnecessarily.

**Effort**: Low. Move debug screen behind `DeveloperOptionsScreen` or delete; move scripts to `mobile/tools/` (already exists); move transport utilities to `test/helpers/nostr/`. ~520 LOC relocated or removed.

**GitHub ticket**: [#3599](https://github.com/divinevideo/divine-mobile/issues/3599)

---

### `DivineTheme` shadows `VineTheme`
**Problem**: `lib/theme/app_theme.dart` defines `DivineTheme` used in only 3 places (all in `notification_list_item.dart`). The canonical design system is `VineTheme` in `divine_ui`.

**Evidence**: `mobile/lib/theme/app_theme.dart` defines `DivineTheme` with purple-tinted colors. Only used in 3 places (all in `notification_list_item.dart`). Canonical design system is `VineTheme` in `mobile/packages/divine_ui/lib/src/theme/vine_theme.dart` (601 lines). `DivineTheme` appears to be an earlier design iteration that was not removed after `VineTheme` became the standard.

**Impact**: Low. Only 3 references; creates confusion about which theme system to use; diverges from the project's `VineTheme`-first rule.

**Effort**: Low. Add a notification accent color to `VineTheme`, update `notification_list_item.dart` to use it, delete `lib/theme/app_theme.dart`. ~30 lines removed.

**GitHub ticket**: [#3600](https://github.com/divinevideo/divine-mobile/issues/3600)
— closed 2026-08-06; work landed.
