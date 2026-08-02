# divine-mobile Codebase Audit

Status: Historical
Validated against: `mobile/` as of 2026-06-12. Line numbers and "still
present" claims have drifted — re-verify any finding against current
`origin/main` before acting on it.

Six findings from this audit have shipped and are closed: SEC-02 (#5055),
COR-03 (#5056), COR-05 (#5057), COR-04 (#5059), COR-12 (#5060), and
COR-11 (#5080). Everything else in the table below is unverified since
the audit date.

**Date:** 2026-06-12 · **Scope:** `mobile/` app (~1,190 Dart files in `lib/`, ~243k non-generated lines) + 50 workspace packages · **Method:** read-only analysis; every finding cites code that was actually read. Headline criticals were independently double-verified.

## Executive summary

The codebase is in *managed* drift: four CI ratchets freeze the debt (skipped tests, UI→service imports, untested services, `Future.delayed` in tests) and the new BLoC/package architecture is being built correctly — no package cycles, no BLoC-to-BLoC coupling. The legacy core has not shrunk: `lib/services/` is a 59,655-line shadow layer the documented architecture says shouldn't exist, with three god objects (`video_event_service` 5,813 lines, `auth_service` 5,260, `upload_manager` 2,802) that 95 UI files reach into directly. The most dangerous single fact: **relay events are never signature-verified on the live ingestion path** — the app's entire trust model assumes honest relays. The most dangerous *systemic* bug: `NostrClient.subscribe` never closes relay REQs or stream controllers on cancel, leaking subscriptions on every feed refresh/pagination and silently breaking re-subscription. One verified path can write a raw **nsec into logs that get uploaded with bug reports**. Performance-wise, event ingestion is super-linear (3 O(n) scans + full re-sort per event, eager re-filtering per notification) on the main isolate during scroll. The test suite is a partial safety net: auth is well covered, upload moderately, but **the exact behaviors a `video_event_service` refactor would break (dedup, pagination, subscription lifecycle) are all skipped**, and the e2e suite never runs automatically. Refactoring must start by resurrecting that net.

---

## Findings table

Severity = production blast radius. Effort: S < ½ day, M = days, L = weeks/epic. Paths relative to `mobile/` unless noted.

### Correctness

| ID | Sev | Location | Description | Effort |
|----|-----|----------|-------------|--------|
| COR-01 | critical | `packages/nostr_client/lib/src/nostr_client.dart:667` (+ call sites `lib/services/video_event_service.dart:4743,1704,3473,3621,3766`) | Cancelling a feed subscription never closes the relay REQ or the broadcast StreamController — systemic leak on every refresh/pagination/timeout | M |
| COR-02 | critical | `packages/nostr_client/lib/src/nostr_client.dart:655-658` | Filter-hash dedup returns the stale stream and silently drops `onEose`; identical re-subscribe sends no new REQ → stuck spinners / false "feed exhausted" | M |
| COR-03 | high | `lib/services/video_event_publisher.dart:416,1260-1264` | Video publish marked `published` on WebSocket send, not relay `OK`; policy-rejected videos silently lost while shown as published | S |
| COR-04 | high | `lib/services/video_event_service.dart:1627→1955` | Check-then-act race in `subscribeToVideoFeed` across two awaits; concurrent calls double-subscribe and orphan the first REQ | S |
| COR-05 | high | `lib/services/auth_service.dart:578-637` | Background RPC upgrade unconditionally reinstates `_keycastSigner`/`_currentIdentity` after the await — resurrects the previous account's signer after sign-out/switch | S |
| COR-06 | medium | `lib/blocs/video_feed/video_feed_bloc.dart:66-74,688-722` | Source-change/refresh handlers run `concurrent` with no post-await source check; rapid source switching can render the wrong feed | S |
| COR-07 | medium | `lib/blocs/video_feed/video_feed_bloc.dart:402` | `until = oldestCreatedAt - 1` permanently skips same-second videos; id-dedup at :419 already makes the `-1` unnecessary | S |
| COR-08 | medium | `packages/nostr_sdk/lib/relay/relay.dart:76-88`, `relay_base.dart:153-156` | `onConnected` iterates `pendingMessages` while failed sends append → ConcurrentModificationError swallowed, queued publishes wiped on reconnect | S |
| COR-09 | medium | `packages/nostr_sdk/lib/relay/relay_pool.dart:392-404` | `onEose` waits for EOSE from *every* relay; one dead relay suppresses EOSE for the whole subscription (30s timeout backstop only) | S |
| COR-10 | medium | `lib/services/auth_service.dart:3604-3611,3773-3779` | `catch (_) {}` around OAuth logout / `KeycastSession.clear()` during destructive sign-out — tokens can survive "remove keys" silently | S |
| COR-11 | medium | `lib/services/video_event_service.dart:4048-4080` | Online-retry `Timer.periodic` never cancelled once attempts exhausted; retry hardcodes `discovery`, so other feeds never recover | S |
| COR-12 | medium | `lib/services/upload_manager.dart:2679-2725` | `_startProcessingPoll` timer is anonymous and survives `dispose()` — fires against a disposed manager for up to 5 min | S |
| COR-13 | medium | `lib/services/video_event_service.dart:1940-1951` | `onDone` cleanup removes `_activeSubscriptions[type]` without checking it still points at this subscription — can delete a newer subscription's tracking | S |
| COR-14 | low | `lib/services/video_event_service.dart:5323-5368` | Search timeout returns partial results but leaks the search subscription and relay REQ | S |
| COR-15 | low | `packages/nostr_sdk/lib/relay/relay_isolate_worker.dart:84-90,126-140` | Unguarded `jsonDecode` in isolate WS listener; `_closeWS` nulls its *parameter*, not the field (not on hot path today — app uses `RelayBase`) | S |
| COR-16 | low | `lib/services/upload_manager.dart:1631-1632` | `resumeInterruptedUpload` fire-and-forgets the Hive status persist before starting the upload | S |

### Security

| ID | Sev | Location | Description | Effort |
|----|-----|----------|-------------|--------|
| SEC-01 | critical | `packages/nostr_sdk/lib/relay/relay_pool.dart:305` | Relay event signatures never verified on live ingestion (`eventSignCheck` defaults false and is never enabled; `EventSignChecker` has zero production callers) — any relay/MITM can forge events from any pubkey, including kind-5 deletions acted on at `nostr_client.dart:164` | M |
| SEC-02 | high | `lib/blocs/email_verification/email_verification_cubit.dart:297` | Logs `verifier=$_pendingVerifier` in full; in BYOK flow the verifier embeds the raw **nsec** (`keycast_flutter/lib/src/oauth/pkce.dart:9`); the unified-log ring buffer is uploaded by bug reports (`bug_report_service.dart:168-186`). Line 286 already redacts the same field — :297 was missed | S |
| SEC-03 | high | `lib/services/nostr_app_bridge_service.dart:369-386`, `nostr_app_bridge_policy.dart:126-130` | WebView nip44 decrypt/encrypt consent is gated on the *remote* directory manifest (`prompt_required_for`); only `signEvent` is code-forced to prompt — a compromised directory entry gets a silent decryption oracle | S |
| SEC-04 | medium | `packages/funnelcake_api_client/lib/...:1628`, `packages/db_client/.../nostr_events_dao.dart:268` | REST-fetched and Drift-cached events are also never signature-verified; forged higher-`created_at` replaceable events can overwrite real ones (compounds SEC-01; `api.divine.video` is CDN-cached) | M |
| SEC-05 | medium | `packages/nostr_sdk/lib/relay/relay_pool.dart:275,411-413,490,542-544` | Bare index/cast on relay-controlled JSON outside try/catch — malformed frames crash (remote DoS vector) | S |
| SEC-06 | medium | `lib/services/zendesk_support_service.dart:781,1020`, `zendesk_config.dart:26` | Agent-API token path bakes a tickets-read/write token into the binary if `ZENDESK_API_TOKEN` is ever defined at build. **Verified: codemagic.yaml does NOT inject it today** — latent, but the dangerous fallback should go | S |
| SEC-07 | medium | `lib/providers/auth_providers.dart:65-71`, `packages/keycast_flutter/.../secure_storage.dart:13` | App-wide secure-storage instances lack hardened options (iOS defaults to `whenUnlocked`, no Android `encryptedSharedPreferences`) while the key manager itself is hardened — inconsistent; these back keycast tokens and the transient BYOK verifier+nsec | S |
| SEC-08 | low | `lib/screens/apps/nostr_app_sandbox_screen.dart:631-633,734-741` | Manifest-supplied `autoLoginScript` injected raw; `_escapeJs` doesn't neutralize `</script>` in the HTML-injection path | S |
| SEC-09 | low | `lib/screens/apps/nostr_app_sandbox_screen.dart:293-303,448-458` | Main-frame attestation is iOS-only; Android falls back to a same-origin-readable DOM nonce for bridge isolation | M |
| SEC-10 | low | `mobile/overrides/`, `pubspec.yaml:122-125,317-320` | Vendored `cryptography_flutter-2.3.2` (fork of unmaintained upstream, security-sensitive) and `app_device_integrity` get no upstream fixes; rationale undocumented in-tree | S |
| SEC-11 | low | `packages/db_client/lib/src/database/app_database.dart:582-585` | Identifier interpolation into `PRAGMA`/`ALTER TABLE` — constants today, injectable if ever fed dynamic input | S |

Verified clean: no committed secrets or `.env`; transport security properly locked down on iOS/Android; nsec never crosses the JS bridge; primary key storage (memory-wiped containers + Keychain/Keystore) is sound; NIP-59 DMs *do* verify signatures.

### Dead code & duplication

| ID | Sev | Location | Description | Effort |
|----|-----|----------|-------------|--------|
| DED-01 | medium | ~55 files across `lib/` | ~7,000+ verifiably dead lines: services (`identity_manager_service.dart` 296, `share_service.dart` 206), `screens/web_auth_screen.dart` (561), 13 dead widgets, dead providers orphaned by BLoC migration (`providers/video_feed_provider.dart`), dev scripts inside `lib/scripts/` | M |
| DED-02 | medium | `lib/widgets/share_video_menu.dart` (1,606 lines) | Superseded by `blocs/share_sheet/`; only an 8-line `showEditDialogForVideo` (line 1480) is still referenced | S |
| DED-03 | medium | `lib/services/feature_flag_service.dart` (403 lines) | Dead duplicate — all consumers import `lib/features/feature_flags/services/feature_flag_service.dart` | S |
| DED-04 | medium | 34 files (largest: `screens/sounds_screen.dart` 707, `widgets/hashtag_search_view.dart` 231) | Imported ONLY by their own tests — dead code kept green at CI cost; delete file + test together | M |
| DED-05 | medium | `mobile/deploy*.sh`, `fix_video_feed_items.sh` (7 tracked scripts, 915 lines) | All reference the pre-rebrand OpenVine/Cloudflare stack; none referenced by CI; last touched 2025-09 | S |
| DED-06 | low | `lib/features/feature_flags/services/build_configuration.dart:13-31` | 5 flags (`FF_NEW_CAMERA_UI`, `FF_ENHANCED_ANALYTICS`, `FF_NEW_PROFILE_LAYOUT`, `FF_ROUTER_DRIVEN_HOME`, `FF_CLASSICS_HASHTAGS`) defined, never checked anywhere | S |
| DED-07 | medium | `lib/router/app_shell.dart:205,209,216,221` | Four `TODO(#3339)` transitional blocks reference a **closed** issue — violates the repo's own transitional-code rule | S |
| DED-08 | medium | `lib/services/notification_service.dart` vs `notification_service_enhanced.dart` | Not duplicates (local-push vs Nostr-social) but the naming implies supersession; both live — rename, don't delete | S |
| DED-09 | medium | `lib/blocs/profile_liked_videos/` vs `profile_reposted_videos/` (+ `profile_saved_videos`) | ~74% byte-identical after name normalization (335/453 lines) — extract a shared paged ids→videos base | M |
| DED-10 | low | `.claude/rules/state_management.md` | Cites canonical `_PooledVideoFeedItem` sites that no longer exist (already refactored) — doc drift | S |
| DED-11 | low | `wingspan/` (agent session artifacts), `website/` (deployable CF worker, zero CI), untracked root debris (`pr4904-console.log`, `explore-layout.png`, `path/`) | Repo hygiene; debris is untracked (local rm only); `website/` needs an owner | S |

### Architecture drift

| ID | Sev | Location | Description | Effort |
|----|-----|----------|-------------|--------|
| ARC-01 | high | `lib/services/` (170 files, **59,655 lines**) | Shadow layer the documented architecture doesn't have; ratchet scripts treat it as a containment zone; epics #4337/#4338 already name the demolition | L |
| ARC-02 | high | `lib/services/video_event_service.dart` (5,813 lines, 126 methods) | ≥7 responsibilities: subscriptions, pagination, in-memory cache, moderation policy (setter-injected), repost resolution, profile hydration, frame-scheduled notification fan-out | L |
| ARC-03 | high | `lib/services/auth_service.dart` (5,260 lines, 96 methods) | ≥8 responsibilities incl. three remote-signer protocols (bunker :2786, Amber :2310, NIP-07 :2391) — extract those first, they're self-contained state machines | L |
| ARC-04 | high | `lib/services/upload_manager.dart` (2,802 lines) | Queue + transport + error taxonomy + **user-facing strings** (`getUserFriendlyErrorMessage` :1406 violates l10n layering) | M |
| ARC-05 | high | `scripts/baseline/ui_service_imports.txt` (95 files) | 95 UI files import services directly, concentrated on hot paths (feed, explore, profile, video editor); ratchet prevents growth, nothing drives shrinkage | L |
| ARC-06 | medium | `lib/services/video_event_service.dart:348-476` | Setter-injected repositories (`setBlocklistRepository` etc.) — filtering silently no-ops until wired; same race class as the documented #3503 cold-start bug | M |
| ARC-07 | medium | `lib/main.dart` (2,485 lines) | DI wiring (16 inline `registerService` blocks :504-757), notification deep-link routing (:374-471 — belongs in `router/`), 4 trailing widget classes; mechanical moves available | M |
| ARC-08 | medium | `lib/services/curated_list_service.dart` (1,738 lines) | Repository + client + publisher + local store in one ChangeNotifier; a `curated_list_repository` package already exists to migrate into | M |
| ARC-09 | medium | `lib/services/zendesk_support_service.dart` (1,168 lines) | All-static class with static state + test hooks — the exact singleton-to-DI shape epic #4338-C2 targets | M |
| ARC-10 | medium | `packages/curation_repository/pubspec.yaml`, `src/curation_repository.dart:9` | Repository→repository dependency on `likes_repository` (rules forbid); graph is otherwise a clean DAG | S |
| ARC-11 | low | `packages/unified_logger/pubspec.yaml` | Leaf logging package depends on `models` — inverts direction, couples every consumer's rebuilds to the domain models | S |
| ARC-12 | low | `packages/content_blocklist_repository/.../blocklist_change.dart:4`, `packages/dm_repository/.../dm_repository.dart:19` | Repositories import `flutter/foundation.dart` (`@immutable` → use `meta`; `compute()` → inject an isolate runner) | S |
| ARC-13 | low | `lib/providers/relay_discovery_provider.dart`, `lib/router/providers/redirect_provider.dart` | Import `package:riverpod/src/...` internals — break on any Riverpod patch release | S |
| ARC-14 | medium | `lib/screens/explore_screen.dart:241,877,1005,1041`; `lib/widgets/classic_vines_tab.dart:318`; `lib/widgets/new_videos_tab.dart:85` | Business logic in widgets: filtering in `build`, UI reaching *through* a notifier to a service, direct singleton fetch from a screen, platform-policy filtering in UI | S each |

Positive: no BLoC-to-BLoC deps, no package cycles, package barrels respected, ChangeNotifier ratchet currently tight (15/15).

### Performance

| ID | Sev | Location | Description | Effort |
|----|-----|----------|-------------|--------|
| PRF-01 | high | `lib/services/video_event_service.dart:2204-2210,4218-4220,4279-4281` | Three O(n) linear id scans with per-element `toLowerCase()` allocation per ingested event → O(n²) per burst on the main isolate; a Set fast path already exists at :2126 | M |
| PRF-02 | high | `lib/services/video_event_service.dart:4444`, `packages/models/lib/src/video_event.dart:1074-1077` | Full-list re-sort on *every* insert, with engagement score recomputed inside the comparator (never cached) → O(n² log n) per burst | M |
| PRF-03 | high | `lib/providers/video_events_providers.dart:374-414` | Per-notification full-list filtering (two `.where` passes + label resolution + `copyWith` per video) runs *before* the 500 ms debounce — only the emission is debounced | S |
| PRF-04 | high | `lib/screens/explore_screen.dart:1235-1238`, `lib/providers/route_feed_providers.dart:76` | `filterVideoList` (multi-pass + observer side effect) called directly in `build()` | S |
| PRF-05 | high | `lib/widgets/video_feed_item/feed_videos.dart:707-722` | `_FeedItemOverlayActions` fully reconstructed 30–60×/s during scroll inside `ValueListenableBuilder` — only opacity should update | M |
| PRF-06 | high | `lib/services/video_event_service.dart:4288-4291` | Per-video `_fetchProfileIfMissing` N+1 (~300 round-trips per 500-video burst); `ProfileRepository.fetchBatchProfiles` (:1313) already exists, and a like-count batcher to mirror lives at :4489-4522 | M |
| PRF-07 | medium | `lib/widgets/user_profile_tile.dart:66`, `lib/screens/comments/widgets/comment_item.dart:285`, `lib/widgets/video_feed_item/collaborator_avatar_row.dart:219` | N+1 per-tile profile watches in follower lists, comments, collaborator stacks — no batching, no `.select()` | M |
| PRF-08 | medium | `lib/services/video_event_service.dart:163-164,189`, `packages/profile_repository/lib/src/profile_repository.dart:91-103` | Unbounded session growth: hashtag/author buckets and `_replaceableVideoEvents` retain full `VideoEvent`s with no eviction (event lists are capped at 500; these aren't); profile-repo sets grow forever | M |
| PRF-09 | medium | `lib/services/video_event_service.dart:2254-2301,4358-4386`, `packages/unified_logger/.../unified_logger.dart:196-198` | Eager log-string interpolation per event (tag formatting, joins) paid even when the level is filtered — no lazy overload | S |
| PRF-10 | medium | `lib/widgets/user_avatar.dart:147`, `lib/widgets/video_thumbnail_widget.dart` | No `memCacheWidth/Height` on avatars/grid thumbnails — full-res decode for 40–48 px circles (~16× memory per avatar) | S |
| PRF-11 | low | `video_event_service.dart:3823-3871,817-826,4603`; `packages/infinite_video_feed/.../infinite_video_feed.dart:904-926` | Misc: hashtag query rescans all lists; fresh `List.unmodifiable` wrapper per access defeats `identical()` checks; stale guard-sets on player retry | S |

Positive: the video player pool itself is solid — bounded 3-controller window, subscriptions/timers properly cancelled, bounded prefetch concurrency.

### Dependency health

| ID | Sev | Location | Description | Effort |
|----|-----|----------|-------------|--------|
| DEP-01 | medium | `pubspec.yaml:294` | `sqlcipher_flutter_libs 0.6.8` — upstream's latest is literally `0.7.0+eol`; the at-rest-encryption native lib has no future; needs a successor plan | M |
| DEP-02 | medium | `pubspec.yaml:355`; 11 importing files incl. `test/flutter_test_config.dart` | `golden_toolkit` is discontinued upstream; `alchemist` already added but migration barely started (1 file) | M |
| DEP-03 | medium | `pubspec.yaml:122-125` | `c2pa_flutter` git dep pinned to `ref: 0.0.3` — a mutable tag, not a SHA; used in 5+ production files | S |
| DEP-04 | low | `mobile/overrides/cryptography_flutter-2.3.2/` | Vendored crypto fork with no in-tree rationale doc (see also SEC-10) | S |
| DEP-05 | low | `packages/nostr_sdk/lib/utils/sqlite_util.dart` | Fifth storage backend (`sqflite`) carried for one util while drift/sqlite3 are first-class — drop it | M |
| DEP-06 | low | `pubspec.yaml` (various) | ~55 direct deps behind latest (`flutter_secure_storage` 9→10, `go_router` 16→17, `device_info_plus` 10→13 *and* override-pinned) — routine drift, batch upgrade | M |
| DEP-07 | low | `pubspec.yaml:338-340` | `build_runner <2.11.0` pin, properly tracked as `TODO(#3142)` — re-test per release | S |

### Test suite

| ID | Sev | Location | Description | Effort |
|----|-----|----------|-------------|--------|
| TST-01 | high | `scripts/baseline/skip_tests.txt:67-76` | `video_event_service`'s dedup, pagination, replaceable-event, and subscription-lifecycle tests are ALL skipped or commented out — exactly what a VES refactor would break has no net | M |
| TST-02 | high | `.github/workflows/mobile_service_integration_tests.yaml:3-4` | Entire `integration_test/` e2e suite runs only on manual `workflow_dispatch`; no schedule, no PR trigger — zero automatic end-to-end backstop | S |
| TST-03 | medium | `scripts/baseline/skip_tests.txt` (84 files, 156 skips) | Skip debt frozen and ratcheted (good) but large; `skipped_tests_report.md` is stale (claims ~300 — improved since) | L |
| TST-04 | medium | `scripts/baseline/future_delayed_tests.txt` (40 files) | Wall-clock waits in tests, incl. shared helpers (`test/helpers/test_helpers.dart`, `test/mocks/mock_*`) whose timing debt infects every consumer — migrate shared mocks first | M |
| TST-05 | medium | `scripts/baseline/skip_tests.txt:24-35` | 12 router/navigation test files skip-dead — navigation regressions uncaught | M |
| TST-06 | medium | `mobile_ci.yaml:143` | 17 `integration`-tagged files under `test/` are excluded from PR runs and run nowhere | S |
| TST-07 | low | `test/vgv_tag_baseline.txt` | Current VGV opt-out count (57) is below baseline (61) — lower the baseline to lock in progress | S |

**Trustworthiness verdict:** `auth_service` has a genuinely strong net (16 scenario files, high assertion density); `upload_manager` moderate (8 files); `video_event_service` is the danger zone — its active tests cover peripheral behavior while core behaviors are skip-dead. Refactor auth/upload behind existing nets; **gate any VES/subscription work on resurrecting TST-01 first**.

---

## Critical & high findings — failure modes and fix approach

**COR-01/COR-02 — NostrClient subscription contract (critical).** Shared root cause: the app layer treats `StreamSubscription.cancel()` as tearing down the relay subscription, but `NostrClient.subscribe` creates a broadcast controller with no `onCancel` and an unbounded `_subscriptionStreams` map. Every replaced/timed-out feed subscription leaves a live relay-side REQ (relays cap concurrent REQs → feeds eventually stop receiving data) and a leaked controller; the dedup path then returns the stale stream and drops `onEose`, so identical re-subscribes (pull-to-refresh, repeated load-more) silently do nothing. **Fix:** one change in `NostrClient.subscribe` — add `onCancel` (last-listener) that sends CLOSE, closes the controller, and removes it from the map; make dedup either chain `onEose` callbacks or refuse dedup when `onEose` is provided. This single contract fix also resolves COR-13/COR-14's leak halves. Gate on TST-01 test resurrection.

**SEC-01 — No signature verification on relay ingestion (critical).** `relay_pool.dart:305` constructs events from relay JSON and delivers them with no `isValid`/`isSigned` check; the verification machinery exists (`EventSignChecker`, isolate worker path) but is dormant. Any relay the app connects to — including *discovered* relays — or a WS MITM can forge events attributed to any pubkey: profile impersonation, forged videos, forged kind-5 deletions that delete local data. **DECIDED (2026-07-28, user):** no proactive/bulk verification — CPU + battery cost not justified. Verify **lazily at point of use, DMs only**: check a signature once, when the user taps to view the message. Do NOT verify other nostr event kinds (feeds, profiles, videos, deletions stay unverified — accepted risk under the trusted-relay model). Remaining design work: how a failed DM check renders (flag vs hide). The dormant isolate checker can be reused per-event for this.

**SEC-02 — nsec in uploaded logs (high).** Verified chain: BYOK export → `generateVerifier(nsec:)` embeds the raw key in the PKCE verifier → edge-case error log prints `verifier=$_pendingVerifier` in full → unified-log ring buffer → bug-report upload to Blossom. **Fix:** one line — redact :297 the same way :286 already does. Ship immediately.

**COR-03 — Publish success without relay OK (high).** `publishEvent` resolves when the WS frame is sent; the divine relay rejects policy-violating video events (e.g. missing thumbnail) via `OK false`, but the upload is already marked `published` and injected into the local cache — the user's video is gone while the app says it's live. **Fix:** switch the video-publish path to the existing `publishEventAwaitOk`, mapping rejection into the retry/failed flow.

**COR-04 — subscribeToVideoFeed race (high).** Duplicate-check and registration are separated by two awaits; the retry timer and reconnection logic can race a user-triggered subscribe, double-subscribing and orphaning a REQ. **Fix:** claim the subscription slot synchronously before the first await.

**COR-05 — Stale signer resurrection (high).** `_upgradeDivineRpcInBackground` runs unawaited with up to a 10 s window and unconditionally reinstates the signer/identity it captured — after sign-out or account switch this is signing-as-the-wrong-identity. **Fix:** capture an auth generation/pubkey before the await; bail if it changed.

**SEC-03 — Manifest-gated decryption oracle (high).** Only `signEvent` is code-forced to prompt; `nip44.decrypt` prompts only if the remote directory manifest says so. **Fix:** code-enforce consent for decrypt/encrypt regardless of manifest — treat decryption as privileged as signing.

**ARC-01..05 — God objects + 95-file UI bypass (high).** Not a single failure mode but the bug nursery: setter-injected deps that silently no-op (ARC-06 — same class as shipped bug #3503), mixed UI strings in transport code, and a 95-call-site blast radius for any service change. **Fix approach:** incremental carve-outs along existing seams (signer protocols out of auth_service; filtering policy out of VES into the existing blocklist/filter layer; error-string mapper out of upload_manager), burning down the UI-import baseline by cluster, not by file. Aligns with existing epics #4337/#4338/#4339.

**PRF-01..06 — Super-linear ingestion + render hot path (high).** Per relay event during a burst: 3 linear id scans with string allocation → full O(n log n) re-sort with uncached scores → `notifyListeners` → eager O(n) re-filter with per-video label resolution in every listening provider → per-frame overlay reconstruction during scroll. All on the main isolate while the user scrolls. **Fix:** id→index map + cached engagement score + batch-deferred sort; move filtering inside the debounce; rebuild only opacity in the scroll listener; batch profile fetches via the existing `fetchBatchProfiles`, mirroring the in-file like-count batcher.

**TST-01/TST-02 — Missing net where it's needed most (high).** The skipped VES tests cover exactly dedup/pagination/subscription lifecycle — the behaviors COR-01/02/04 and PRF-01/02 fixes will touch. e2e runs only manually. **Fix:** resurrect or rewrite those suites against the current API and add a nightly schedule for the service e2e workflow *before* touching VES.

---

## Proposed refactor sequence

Each batch is independently shippable; tests pass after each; earlier batches de-risk later ones. Slots into existing epics #4337 (skip debt), #4338 (Track D / singleton-to-DI), #4339 (oversized-file split).

**Batch 0 — Build the safety net (do first; blocks 2, 4, 5).**
Resurrect/rewrite VES dedup, pagination, replaceable-event, and subscription-lifecycle tests (TST-01); add `schedule:` nightly trigger to the service e2e workflow (TST-02); un-tag or relocate the 17 orphaned `integration`-tagged tests (TST-06); lower the VGV baseline to 57 (TST-07); regenerate `skipped_tests_report.md`. No production code changes.

**Batch 1 — Surgical correctness & security fixes (small diffs, independent of all refactors).**
SEC-02 (one-line redaction — ship same day), COR-03 (awaitOk), COR-04 (synchronous claim), COR-05 (generation guard), SEC-03 (code-enforced decrypt prompt), COR-06 (restartable + source guard), COR-07 (drop `-1`), COR-10 (stop swallowing sign-out failures), COR-11/COR-12 (timer lifecycle), COR-08 (copy-then-iterate), SEC-05 (guard relay JSON parse), DED-07 (resolve closed-issue TODOs). Each is an isolated PR with a targeted test.

**Batch 2 — Fix the NostrClient subscription contract (gated on Batch 0).**
COR-01 + COR-02 in `NostrClient.subscribe` (onCancel → CLOSE + close + evict; onEose-aware dedup), then sweep the VES call sites that work around the broken contract (COR-13, COR-14, COR-09 quorum-EOSE). Highest-leverage single change in the audit; one package, one behavior contract, verified by the resurrected lifecycle tests.

**Batch 3 — Signature verification (needs the trust-model decision below).**
SEC-01 at the relay_pool ingestion boundary using the dormant isolate checker; SEC-04 at the funnelcake and Drift-cache boundaries. Shippable behind a flag with telemetry on verification failures first, then enforced.

**Batch 4 — Dead-code sweep (fully independent; do anytime; shrinks later batches).**
DED-01/02/03/04 deletions (~7k lines + 34 test-only files), DED-05 script removal, DED-06 flag removal, DED-08 renames, DED-10 doc fix. Mechanical, reviewable in clusters, zero behavior change. Reduces the surface Batches 5–6 must reason about.

**Batch 5 — Hot-path performance (gated on Batch 0; mostly inside VES without splitting it).**
PRF-01/02 (id map + cached score + deferred sort), PRF-03/04 (filter inside debounce; lift out of build), PRF-05 (opacity-only rebuild), PRF-06/07 (batch profile fetches), PRF-09 (lazy logging), PRF-10 (memCache sizes), PRF-08 (bucket eviction). Each measurable; profile before/after per the repo's own performance rule.

**Batch 6 — God-object carve-outs (last; gated on Batches 0, 2, 5 stabilizing behavior).**
ARC-04 first (smallest: error-string mapper to UI, then transport/queue split), ARC-03 signer-protocol extraction, ARC-02 filtering-policy extraction into the existing blocklist layer + constructor injection (kills ARC-06), ARC-07 mechanical main.dart moves, ARC-08 migration into the existing `curated_list_repository` package, ARC-09 static→DI. Burn the ARC-05 baseline down by cluster as each seam moves. Each extraction ships with tests per repo rule.

**Batch 7 — Dependency hygiene (independent, low urgency).**
DEP-03 (pin c2pa to SHA + consider mirroring), DEP-02 (finish alchemist migration, unblock by replacing `flutter_test_config.dart` usage), SEC-07 (align secure-storage options), DEP-05 (drop sqflite), SEC-06 (remove agent-token fallback), DEP-04/SEC-10 (document vendoring rationale), DEP-06 batch upgrades, DEP-01 successor plan for SQLCipher.

---

## What I was unsure about — needs human input before touching

1. ~~**Relay trust model (gates Batch 3).**~~ **RESOLVED 2026-07-28:** no proactive signature verification (battery/CPU). Verify lazily, once, at DM view time — DMs only, never other event kinds. Batch 3 rescope: lazy DM-only verification instead of ingestion-time checks.
2. **EOSE semantics (COR-09).** If production configs are effectively single-relay (relay.divine.video), all-relay EOSE may be acceptable as-is — is multi-relay actually used by real users?
3. **Pagination `-1` (COR-07).** Was `until - 1` added to work around a specific relay quirk (duplicate floods from a non-conforming relay)? Git history may explain; I didn't find a justification in code.
4. **`website/` and `wingspan/`.** Who owns the apps-directory worker under `website/` (zero CI, last touched 2026-04)? Is `wingspan/` (committed agent-planning artifacts) intentional documentation or accidental commits?
5. **Deploy scripts (DED-05).** All seven look stale/pre-rebrand, but `deploy_android.sh` (2025-10) may still be used manually — confirm before deleting.
6. **Feature flags (DED-06).** Are the 5 unchecked `FF_*` flags reserved for planned work or abandoned?
7. **Zendesk agent-token path (SEC-06).** Codemagic doesn't inject `ZENDESK_API_TOKEN`; are there *other* build pipelines (local release builds, Shorebird patches) that might?
8. **34 test-only files (DED-04).** Some may be staged for in-flight features rather than dead — needs a quick owner pass over the list before bulk deletion.
9. **Epic sequencing.** Batches 2/5/6 overlap epics #4338/#4339 — the owners of those epics should reconcile this sequence with their plans rather than running both in parallel.
10. **`notification_service` naming (DED-08).** Rename is safe but churns ~dozens of imports — worth bundling with a planned notifications change rather than standalone.
