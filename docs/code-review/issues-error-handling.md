# Error Handling Issues

Issues related to silent failures, empty catch blocks, and user-facing error messages.

Note: The project has strong crash reporting infrastructure (Firebase Crashlytics + `unified_logger` in 250+ files) and well-typed custom exceptions across 7 packages. These issues cover the remaining gaps, from isolated oversights (issues 1–4) to broader patterns across BLoCs (issue 5) and services/repositories (issue 6).

---

### Empty catch blocks suppress errors silently
**Problem**: ~12 `catch (_) {}` or `catch (e) {}` blocks across app code and packages suppress errors with no logging or propagation.

**Evidence**: Empty catch blocks found in: `video_recorder_provider.dart` (file cleanup), `individual_video_providers.dart`, `app_providers.dart`, `video_publish_provider.dart`, `video_nostr_enrichment.dart`, `clip_manager_state.dart` (2 instances), `pooled_age_restricted_retry.dart` (2 instances), `nostr_app_sandbox_screen.dart`. In packages: `image_metadata_stripper/lib/src/image_metadata_stripper.dart`, `follow_repository/lib/src/follow_repository.dart` (2 instances), `nostr_sdk/lib/nip46/nostr_connect_session.dart`, `nostr_sdk/lib/relay/web_socket_connection_manager.dart`. Some are justifiable (file cleanup where failure is harmless), but others (particularly in `follow_repository` and `nostr_sdk` relay management) could mask real errors.

**Impact**: Low. Most are in non-critical paths (file cleanup, optional operations). However, the `follow_repository` and `nostr_sdk` relay connection instances could hide connectivity or data consistency issues that surface as confusing behavior rather than clear errors.

**Effort**: Low. Audit each instance: add `Log.warning()` where the error is recoverable but worth observing, or add a comment explaining why the no-op is intentional (per the project's error handling rules on documenting no-ops).

**GitHub ticket**: TBD

---

### Raw exception text shown to users
**Problem**: Users see raw `.toString()` exception output in error messages — either because l10n is bypassed entirely, or because l10n strings accept an `{error}` placeholder that receives raw exception text.

**Evidence**:

*No l10n at all (2 instances):*
- `mobile/lib/screens/key_import_screen.dart` line ~300: `Text('Error: $e')` — raw exception in a SnackBar. The same file correctly uses `context.l10n.keyManagementImportFailed(e)` on line ~289.
- `mobile/lib/mixins/async_value_ui_helpers_mixin.dart` line ~74: `Text('Error: $error')` in the default error widget, used by `explore_screen_router.dart`.

*L10n strings that pass raw exception text through (~26 ARB entries):*
These use `context.l10n` but the translated string is e.g. `"Error: {error}"` and callers pass `'$e'` (raw exception `.toString()`), so users still see unreadable internals like `"Error: NetworkException: Connection timed out"`. Examples from `app_en.arb`:
- `profileErrorPrefix` / `exploreErrorPrefix` / `keyImportError` / `profileError`: `"Error: {error}"`
- `webAuthUnexpectedError`: `"Unexpected error: {error}"`
- `soundsPreviewFailed` / `soundPreviewFailed`: `"Failed to play preview: {error}"`
- `shareMenuFailedToUpdateVideo`, `shareMenuFailedToReportAiContent`, `blossomFailedToSaveSettings`, `discoverListsFailedToUpdateSubscription`, `uploadRetryFailed`, `relayDiagnosticQueryFailed`, `relayDiagnosticConnectionRetryFailed`, `webAuthIntegrationFailed`, `profileSetupUploadFailedGeneric`, `profileSetupCameraAccessFailed`, `profileShareFailed`, `keyManagementImportFailed`, `keyManagementExportFailed`, `reportFailed`, `shareMenuFailedToReportContent`, `supportErrorOpeningPage`, `legalErrorOpeningPage`, `relaySettingsLastError`, `exploreErrorLoadingLists`

**Done well**: 1,251+ `context.l10n` usages across the codebase use static, user-friendly messages. The pattern works — these are the exceptions to it.

**Impact**: Medium. ~28 total instances across the app where users can see raw exception class names and internal messages. The relay diagnostic screen cases are arguably acceptable (developer-facing tool), but auth, share, upload, and explore paths are user-facing.

**Effort**: Medium. The 2 non-l10n cases are trivial one-line fixes. The ~26 ARB entries need a decision: either remove the `{error}` placeholder and show a generic user-friendly message, or map known exception types to specific l10n keys in the caller before passing to the l10n string. Recommend tackling by user-facing priority: auth (`webAuth*`), share (`shareMenu*`), upload (`uploadRetryFailed`), and explore (`explore*`) first.

**GitHub ticket**: TBD

---

### Inconsistent error handling in notification methods
**Problem**: `getNotifications` and `markNotificationsRead` silently suppress all errors and return empty/failure responses, while every other method throws typed exceptions.

**Evidence**: `mobile/packages/funnelcake_api_client/lib/src/funnelcake_api_client.dart` lines 1857–1873: `on Object { return const NotificationResponse(...); }`. Callers of notification methods cannot distinguish between "no notifications" and "network failure."

**Done well**: Every other method in the same file (e.g., `getVideosByAuthor`, lines 170–208) correctly throws typed `FunnelcakeApiException`, allowing callers to distinguish errors from empty results.

**Related**: See "Massive boilerplate duplication in FunnelcakeApiClient" in [issues-code-quality.md](issues-code-quality.md). The notification methods deviate from the shared pattern. Extracting a shared `_request<T>` helper would enforce consistent error handling across all methods, including these.

**Impact**: Medium. The caller has no way to show error UI or retry because the error is silently hidden.

**Effort**: Low. Make these methods throw like the rest, or document the intentional deviation with a clear reason.

**GitHub ticket**: TBD

---

### Error strings in BLoC state
**Problem**: 5 BLoC state classes store user-facing English strings in state fields instead of status enums, bypassing the l10n system.

**Evidence**: `InviteGateState` (`mobile/lib/blocs/invite_gate/invite_gate_state.dart` lines 15–16, 23–24): `String? inviteCodeError` and `String? generalError`. `ShareSheetBloc` line 350: `label: 'Link to post copied to clipboard'` (user-facing snackbar messages emitted through a String field). `SoundWaveformError(this.message)` emitted with `e.toString()`. `VideoEditorStickerError(this.message)` emitted with `e.toString()`. `GallerySaveResultError(this.message)` emitted with `e.toString()` and displayed directly in a snackbar at `library_screen.dart:292`. This is exactly the anti-pattern described in the state management rules: "State must NEVER contain error messages, error strings, or exception objects." The correct pattern is `addError(e, stackTrace)` with a status enum, as demonstrated by `VideoFeedBloc`'s `VideoFeedError` enum. The `ShareSheetBloc` case is particularly significant since share is a core user flow.

**Done well**: `HashtagSearchBloc`, `ClipsLibraryBloc`, and `VideoSearchBloc` use `addError(e, stackTrace)` with a status enum and no error strings in state, which is the correct pattern per project rules.

**Impact**: High. These strings are directly shown to users and bypass the l10n system entirely.

**Effort**: Medium. Replace String fields with enum/sealed-class status codes and map to `context.l10n` in the UI. The three sealed error states should drop the `message` field and use `addError()` + a status enum instead.

**GitHub ticket**: TBD

---

### BLoC event handlers missing `addError()` and try/catch

**Problem**: Of 104 async event handlers across 46 BLoC/Cubit classes, 64 don't fully follow the project's error handling rules. 54 handlers have try/catch but skip `addError(e, stackTrace)`, meaning errors aren't surfaced through BLoC's built-in error stream or `blocTest`'s `errors` parameter. Another 14 handlers have no try/catch at all, letting exceptions bubble up as unhandled.

**Evidence**: 14 handlers have no try/catch at all, e.g. `WelcomeBloc._onStarted` (~56), `ProfileEditorBloc._onUsernameChanged` (~118), `OtherProfileBloc._onBlockRequested` (~134), `AppUpdateBloc._onCheckRequested` (~24). The remaining 54 have try/catch but skip `addError()`, e.g. `CommentsBloc` (8 of ~12 handlers), `ShareSheetBloc` (all 4 handlers), `DivineAuthCubit` (4 handlers), `VideoInteractionsBloc` (3 handlers). Most `_onLoadMore` handlers across the codebase follow the same pattern: catch the error, silently reset `isLoadingMore: false`, and the user sees the spinner disappear with no failure feedback. Several of these also use `catch (e)` without capturing the stackTrace.

**Done well**: 40 handlers follow the full pattern correctly. Good examples: `ClipsLibraryBloc` (all 4 handlers), `VideoSearchBloc`, `NotificationFeedBloc` (5 handlers), `ConversationBloc`, `BackgroundPublishBloc`, `CategoriesBloc._onLoadRequested`/`_onCategorySelected`/`_onSortChanged`.

**Impact**: Medium. Without `addError()`, errors don't flow through BLoC's error stream, which limits future observability (e.g., if a `BlocObserver` or centralized error reporting is added later) and makes `blocTest`'s `errors` parameter unusable for those handlers. Handlers without try/catch risk unhandled exceptions that could leave BLoCs in stale states. Pagination failures are invisible to users.

**Effort**: Medium. Adding `addError(e, stackTrace)` to existing catch blocks is a one-line fix per handler, but 54 handlers across ~25 files need it. The 14 handlers missing try/catch entirely need fuller wrapping. Recommend tackling by priority: auth flow (`WelcomeBloc`, `DivineAuthCubit`) and core interactions (`CommentsBloc`, `VideoInteractionsBloc`, `ShareSheetBloc`) first.

**GitHub ticket**: TBD

---

### Services and repositories log errors but suppress them

**Problem**: ~170 catch blocks across services and repositories log errors (via `Log.error`, `Log.warning`, `developer.log`, or `print`) then return a value (`null`, `false`, `0`, `[]`, empty page) that callers can't distinguish from a legitimate "no data" result. Some of these are likely intentional but the method signatures don't document the contract. Callers have to guess whether `null` means "not found" or "crashed," and whether `false` means "validation rejected" or "network error."

**Evidence**: `LocalKeySigner` (`mobile/lib/services/local_key_signer.dart`): all 6 signing/encryption methods catch, `Log.error`, and return `null`. `AuthService` (`mobile/lib/services/auth_service.dart`) has ~41 instances, e.g. `hasSavedKeys()` (~684) returns `false` on storage error, `getPrivateKeyForSigning()` (~3153) returns `null`, `createAndSignEvent()` (~3298) returns `null`. `VideoEventPublisher._publishEventToNostr()` (~228) returns `false`, meaning the video is silently not propagated to relays. `BookmarkService`, `CuratedListService`, `MuteService`, `SocialService` all follow the same `return false` pattern across their write methods. In packages, `SecureKeyStorage` (~6 methods) and `FollowRepository` (~4 methods) return `false`/`null` on failures. Repository fallback cascades (e.g., `VideosRepository.searchVideos()`) catch at each phase (REST -> relay -> indexer) and return `[]` if all fail.

**Done well**: `FunnelcakeApiClient` (except notifications, see issue 3 above) throws typed `FunnelcakeApiException` for every method and documents it. `DmRepository.sendMessage()` propagates errors. These set a good precedent for what documented error contracts look like.

**Impact**: Medium-to-High depending on the method. Auth/signing/publish paths are high-risk. Camera and optional persistence paths are lower risk but still need documented contracts.

**Effort**: Medium. The work splits into two tracks: (a) for genuinely problematic methods (~20–30), choose a propagation strategy (throw, `Result<T>`, or redefine `false`), starting with `LocalKeySigner`, `AuthService` key methods, and `VideoEventPublisher`; (b) for intentionally-suppressing methods (~140+), add `///` documentation to the method signature explaining when `null`/`false`/`[]` is returned and why, per the project's error handling rules on documenting no-ops.

**GitHub ticket**: TBD
