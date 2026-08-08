# Content Language Discovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give non-English users a feed in their own language, by replacing the current fake language signal (the poster's phone locale) with a real detected one, and feeding that into the recommender.

**Architecture:** Five phases across three repos, each phase shipping as its own PR against its repo's `main`. Phases 1–2 fix the client so the self-reported signal stops lying. Phase 3 makes the existing ASR services report the language they detect instead of echoing the caller's hint. Phase 4 adds a `detected_language` column to funnelcake fed by text detection at ingest plus the ASR signal. Phase 5 feeds language into Gorse and honors the `preferred_languages` param the client already sends. UI is a gated decision (see "Phase 6 Gate"), deliberately not built here.

**Tech Stack:** Flutter/Dart (divine-mobile), Rust + ClickHouse (divine-funnelcake), Rust + Python/FastAPI/NeMo (divine-blossom), Gorse recommender.

## Background: why this plan exists

Measured on 2026-08-06 against `https://api.divine.video/api/videos`, sample of 3000 recent videos:

```
language field    en 92.4% | (empty) 2.2% | fr 1.2% | ja 0.9% | es 0.7%
                  ru/it/de 0.4% ea | nb/pl 0.3% | tr/pt 0.2% | ar 0.1% | nl/uk/ro <0.1%
```

The field is not the video's language. It is `LanguagePreferenceService.contentLanguage` — a single global per-user setting that silently defaults to `PlatformDispatcher.instance.locale.languageCode` and is stamped onto every video that user ever publishes. Observed mislabels in the non-English rows:

```
pt | "Cleaning up the Chileans"     pt | "English tutorial"
de | "ho ho ho green giant"         ja | "#Vine"
```

Usable prose per video for text-based detection (title + `summary` tag, with hashtags/@mentions/URLs stripped), same 2000-video sample:

```
10+ words 31.6%  |  4-9 words 36.1%  |  1-3 words 23.1%  |  0 words 9.1%
```

Existing ASR coverage: `text_track_content` is populated on **1.2%** of videos.

Three verified facts that shape the phases:

1. Gorse never sees language. `gorse_item_for_event` (divine-funnelcake `crates/relay/src/relay.rs:300-368`) sets `categories` = hashtags and `labels` = orientation + hashtags + Vine-archive percentile labels. Gorse user labels (`relay.rs:2590-2619`) are `has_profile`, `has_bio`, `has_picture`, `domain:<nip05>`. No language on either side.
2. The client already sends `preferred_languages` and `viewer_country` (divine-mobile `funnelcake_api_client.dart:170-187`); grepping all of divine-funnelcake for either string returns zero hits. `RecommendationQuery` (`crates/api/src/recommendations.rs:81-89`) has no language field.
3. Both ASR backends can detect language but neither reports it. divine-blossom `cloud-run-asr-parakeet` runs `nvidia/parakeet-tdt-0.6b-v3` (the multilingual checkpoint) and `_hypothesis_to_result` (`app/transcribe.py:107`) echoes the caller's `language` hint straight back. The Google STT v2 path already extracts the real detected code into `SttResult.language` (`cloud-run-transcoder/src/transcription_google_stt_v2.rs:561-564`) but nothing consumes it.

## Global Constraints

- Every phase is a separate PR targeting its repo's `main`. Never stack PRs across phases.
- Each repo's PR follows that repo's `AGENTS.md`. For divine-mobile: worktree from `origin/main`, Conventional Commit PR title, `flutter analyze lib test integration_test` + scoped tests green before push, never `--no-verify`.
- ISO-639-1 two-letter lowercase is the canonical language representation everywhere in this plan. BCP-47 tags from ASR (`en-US`, `pt-BR`) are truncated at the first `-` and lowercased at the boundary where they enter our storage.
- Never truncate Nostr IDs in code, logs, tests, or debug output.
- The self-reported NIP-32 `l`/ISO-639-1 tag is **never** overwritten or deleted. Detection is stored alongside it in a new column, never in place of it.
- No new dialogs or bottom sheets in divine-mobile; the composer change in Phase 2 reuses the existing full-screen selection pattern from `content_preferences_screen.dart`.
- Do not add a `// TODO` without a tracking issue link.

---

## Phase 1 — divine-mobile: stop manufacturing a language claim

**Repo:** `divine-mobile`. **Branch:** `fix/language-self-report-honesty`. **One PR.**

Two bugs, same file family, same PR because they share the `FeedViewerPreferenceHints` seam.

**Bug A:** `LanguagePreferenceService.contentLanguage` (`mobile/lib/services/language_preference_service.dart:29-30`) falls back to the OS locale when the user never chose. `video_publish_service.dart:390` passes that value to the publisher, which stamps `['l', language, 'ISO-639-1']` (`video_event_publisher.dart:1343-1347`). Result: we cannot distinguish "this creator declared English" from "their phone happens to be English." An absent tag is strictly more useful than a fabricated one.

**Bug B:** `readFeedViewerPreferenceHints` (`mobile/lib/providers/feed_viewer_preference_hints.dart:64-75`) resolves `viewerCountry` through a geo lookup with a 250 ms timeout that yields `null` on timeout. That value is folded into the popular-feed disk cache key via `_popularPreferenceCacheSuffix` (`mobile/packages/videos_repository/lib/src/videos_repository.dart:146-161`, used at lines 950, 1112, 2613). On a slow network the key flips between `:country=` and `:country=US`, so the cache misses exactly when the network is worst.

**Files:**
- Modify: `mobile/lib/services/language_preference_service.dart:22-30`
- Modify: `mobile/lib/services/video_publish/video_publish_service.dart:390`
- Modify: `mobile/packages/videos_repository/lib/src/videos_repository.dart:146-161`
- Test: `mobile/test/services/language_preference_service_test.dart`
- Test: `mobile/test/services/video_publish/video_publish_service_test.dart`
- Test: `mobile/packages/videos_repository/test/src/videos_repository_test.dart`

**Interfaces:**
- Produces: `LanguagePreferenceService.declaredContentLanguage` → `String?`, returning the user's explicit choice or `null` when unset. `contentLanguage` → `String` keeps its current OS-locale-fallback behaviour and stays the value used for *viewer-side* hints (asking for content in a language is fine to infer from the phone; *claiming* content is in a language is not).
- Produces: `_popularPreferenceCacheSuffix` no longer accepts `viewerCountry`; signature becomes `_popularPreferenceCacheSuffix({List<String> preferredLanguages = const []})`.

- [x] **Step 1: Write the failing test for the declared-vs-inferred split**

In `mobile/test/services/language_preference_service_test.dart`, inside the existing top-level `group`:

```dart
group('declaredContentLanguage', () {
  test('is null when the user never chose a language', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final service = LanguagePreferenceService();
    await service.initialize();

    expect(service.declaredContentLanguage, isNull);
    expect(service.contentLanguage, isNotEmpty);
  });

  test('is the explicit choice once the user sets one', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final service = LanguagePreferenceService();
    await service.initialize();
    await service.setContentLanguage('pt');

    expect(service.declaredContentLanguage, equals('pt'));
  });

  test('returns to null after the choice is cleared', () async {
    SharedPreferences.setMockInitialValues(
      <String, Object>{LanguagePreferenceService.prefsKey: 'pt'},
    );
    final service = LanguagePreferenceService();
    await service.initialize();
    await service.clearContentLanguage();

    expect(service.declaredContentLanguage, isNull);
  });
});
```

- [x] **Step 2: Run it and confirm it fails**

```bash
cd mobile && flutter test test/services/language_preference_service_test.dart
```

Expected: FAIL, `The getter 'declaredContentLanguage' isn't defined for the class 'LanguagePreferenceService'`.

- [x] **Step 3: Add the getter**

In `mobile/lib/services/language_preference_service.dart`, directly above the existing `contentLanguage` getter:

```dart
  /// The language the user explicitly chose, or `null` if they never chose.
  ///
  /// Unlike [contentLanguage] this never falls back to the OS locale. Use it
  /// when *claiming* what language a piece of content is in — a phone set to
  /// German is not evidence that the video is German.
  String? get declaredContentLanguage => _customLanguage;
```

- [x] **Step 4: Run it and confirm it passes**

```bash
cd mobile && flutter test test/services/language_preference_service_test.dart
```

Expected: PASS.

- [x] **Step 5: Write the failing test for publish-time behaviour**

In `mobile/test/services/video_publish/video_publish_service_test.dart`, add to the group that already exercises publish argument forwarding:

The file's `setUp` (`:142`) builds a shared `service` **without** a `languagePreferenceService`, so these tests construct their own instance with the same mocks. Add a new `group` inside `group('VideoPublishService', ...)`:

```dart
group('content language self-labelling', () {
  VideoPublishService buildServiceWithLanguage(
    LanguagePreferenceService languageService,
  ) => VideoPublishService(
    uploadManager: mockUploadManager,
    authService: mockAuthService,
    videoEventPublisher: mockVideoEventPublisher,
    blossomService: mockBlossomService,
    draftService: mockDraftService,
    collaboratorInviteService: mockCollaboratorInviteService,
    mentionResolutionService: mockMentionResolutionService,
    performanceMonitor: fakePerformanceMonitor,
    languagePreferenceService: languageService,
    onProgressChanged:
        ({required double progress, required String draftId}) {},
  );

  test('omits the language tag when the user never declared one', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final languageService = LanguagePreferenceService();
    await languageService.initialize();

    await buildServiceWithLanguage(
      languageService,
    ).publishVideo(draft: _createTestDraft());

    final captured = verify(
      () => _verifyPublishVideoEvent(
        mockVideoEventPublisher,
        language: captureAny(named: 'language'),
        textTrackRefs: any(named: 'textTrackRefs'),
        textTrackLang: any(named: 'textTrackLang'),
      ),
    ).captured;
    expect(captured.single, isNull);
  });

  test('sends the declared language when the user chose one', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final languageService = LanguagePreferenceService();
    await languageService.initialize();
    await languageService.setContentLanguage('pt');

    await buildServiceWithLanguage(
      languageService,
    ).publishVideo(draft: _createTestDraft());

    final captured = verify(
      () => _verifyPublishVideoEvent(
        mockVideoEventPublisher,
        language: captureAny(named: 'language'),
        textTrackRefs: any(named: 'textTrackRefs'),
        textTrackLang: any(named: 'textTrackLang'),
      ),
    ).captured;
    expect(captured.single, equals('pt'));
  });
});
```

**`publishVideoEvent` takes ~20 named parameters.** `verify` requires *every* one to be matched by an `any(named:)` / `captureAny(named:)` matcher, so route these tests through the existing `_verifyPublishVideoEvent` helper. Extend that helper with an optional `language` matcher and keep the other existing capture parameters unchanged.

Set up the mocks these tests need the same way the neighbouring tests do (`mockAuthService.isAuthenticated` → true, etc.) — copy the arrangement from a passing publish test rather than guessing.

- [x] **Step 6: Run it and confirm the first test fails**

```bash
cd mobile && flutter test test/services/video_publish/video_publish_service_test.dart
```

Expected: FAIL on "omits the language tag" — actual is the OS locale (`'en'` in CI), expected `null`.

- [x] **Step 7: Switch the publish call site to the declared value**

`mobile/lib/services/video_publish/video_publish_service.dart:390`:

```dart
          language: languagePreferenceService?.declaredContentLanguage,
```

`video_event_publisher.dart:1344` already guards `if (language != null && language.isNotEmpty)`, so a null value correctly emits no `L`/`l` tag pair. No change needed there.

- [x] **Step 8: Run both suites and confirm they pass**

```bash
cd mobile && flutter test test/services/video_publish/ test/services/language_preference_service_test.dart
```

Expected: PASS.

- [x] **Step 9: Write the failing test for the cache-key bug**

In `mobile/packages/videos_repository/test/src/videos_repository_test.dart`, inside the existing `getPopularVideosPage` group:

```dart
test('reuses the cached page when only the country hint changes', () async {
  // The country hint comes from a 250ms-timeout geo lookup that yields
  // null on a slow network. If it forked the cache key, this second call
  // would miss the cache and hit the API again.
  when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
  when(
    () => mockFunnelcakeClient.getV2PopularVideos(
      variant: any(named: 'variant'),
      limit: any(named: 'limit'),
      before: any(named: 'before'),
      preferredLanguages: any(named: 'preferredLanguages'),
      viewerCountry: any(named: 'viewerCountry'),
    ),
  ).thenAnswer((_) async => [
        _createVideoStats(
          id: 'native-1',
          pubkey: 'pubkey-1',
          dTag: 'native-dtag-1',
          videoUrl: 'https://example.com/native-1.mp4',
        ),
      ]);

  final feedCache = InMemoryFeedCache();
  final repositoryWithCache = VideosRepository(
    nostrClient: mockNostrClient,
    funnelcakeApiClient: mockFunnelcakeClient,
    inMemoryFeedCache: feedCache,
  );

  final first = await repositoryWithCache.getPopularVideosPage(
    variant: PopularVideosVariant.native,
    preferredLanguages: const ['pt'],
  );
  final second = await repositoryWithCache.getPopularVideosPage(
    variant: PopularVideosVariant.native,
    preferredLanguages: const ['pt'],
    viewerCountry: 'BR',
  );

  expect(
    second.videos.map((video) => video.id),
    equals(first.videos.map((video) => video.id)),
  );
  verify(
    () => mockFunnelcakeClient.getV2PopularVideosPage(
      variant: PopularVideosVariant.native,
      limit: 25,
      preferredLanguages: const ['pt'],
      viewerCountry: any(named: 'viewerCountry'),
    ),
  ).called(1);
});
```

- [x] **Step 10: Run it and confirm it fails**

```bash
cd mobile/packages/videos_repository && flutter test test/src/videos_repository_test.dart
```

Expected: FAIL because the second call hits `getV2PopularVideosPage` again when `viewerCountry` is still part of the in-memory cache key.

- [x] **Step 11: Drop the country from the cache key**

In `mobile/packages/videos_repository/lib/src/videos_repository.dart`, replace lines 146-161 with:

```dart
/// Cache-key suffix for the popular feed's viewer preferences.
///
/// Deliberately excludes the viewer country: it is resolved through a geo
/// lookup with a short timeout that yields null when the network is slow, so
/// including it made the key flip between two values and miss the cache
/// exactly when the network was worst.
String _popularPreferenceCacheSuffix({
  List<String> preferredLanguages = const [],
}) {
  final languages = preferredLanguages
      .map((language) => language.trim())
      .where((language) => language.isNotEmpty)
      .join(',');

  return languages.isEmpty ? '' : ':lang=$languages';
}
```

Then update the three call sites (lines ~950, ~1112, ~2613) to stop passing `viewerCountry:`. Leave the `viewerCountry` *parameter* on the public repository and API-client methods — it still goes out on the wire and Phase 5 will start honoring it server-side. Do not add a visible test seam for the private suffix helper; the behavior test above proves the call-site cache key stays stable when only the country hint changes.

- [x] **Step 12: Run the package suite with coverage**

```bash
cd mobile/packages/videos_repository && flutter test --coverage
```

Expected: PASS, coverage still satisfies the package's `min_coverage`.

- [x] **Step 13: Analyze and format**

```bash
cd mobile && dart format lib/services/language_preference_service.dart lib/services/video_publish/video_publish_service.dart packages/videos_repository/lib/src/videos_repository.dart && flutter analyze lib test integration_test
```

Expected: no issues.

- [x] **Step 14: Commit and open the PR**

```bash
git add mobile/lib/services/language_preference_service.dart \
        mobile/lib/services/video_publish/video_publish_service.dart \
        mobile/packages/videos_repository/lib/src/videos_repository.dart \
        mobile/test/services/language_preference_service_test.dart \
        mobile/test/services/video_publish/video_publish_service_test.dart \
        mobile/packages/videos_repository/test/src/videos_repository_test.dart
git commit -m "fix(publish): only self-label language when the user declared one

The NIP-32 l/ISO-639-1 tag was being stamped from the OS locale whenever
the user had not chosen a content language, so 92% of the catalog claims
'en' regardless of what language the video is actually in. Publish now
sends only an explicit choice, and the popular-feed cache key no longer
forks on the flaky geo country hint."
gh pr create --base main --title "fix(publish): only self-label language when the user declared one"
```

**Exit criteria:** New uploads from users who never touched the setting carry no `l`/ISO-639-1 tag. Watch the `(empty)` share of `language` in the sample query climb over the following weeks — that rise is the measurement working, not a regression.

---

## Phase 2 — divine-mobile: per-video language in the composer

**Repo:** `divine-mobile`. **Branch:** `feat/composer-video-language`. **One PR.** Depends on Phase 1 shipping first (it consumes `declaredContentLanguage`).

Today one global setting labels every video a creator ever posts, so a bilingual creator is guaranteed wrong on half their output. Add a per-video override on the publish draft, defaulting to the account-level declared value (which may be null).

**Files:**
- Modify: `mobile/lib/models/divine_video_draft.dart` (field list at `:47`, declarations at `:283`, `copyWith` at `:397`)
- Modify: `mobile/lib/services/video_publish/video_publish_service.dart:390`
- Create: `mobile/lib/screens/video_publish/video_language_screen.dart`
- Modify: `mobile/lib/router/app_router.dart` (register the new route beside the existing publish-flow routes)
- Modify: `mobile/lib/l10n/app_en.arb` plus every other `mobile/lib/l10n/app_*.arb`
- Test: `mobile/test/services/video_publish/video_publish_service_test.dart`
- Test: `mobile/test/screens/video_publish/video_language_screen_test.dart`

**Interfaces:**
- Consumes: `LanguagePreferenceService.declaredContentLanguage` → `String?` from Phase 1.
- Produces: `draft.language` → `String?` on the publish draft model, defaulting to `null`.
- Produces: `VideoLanguageScreen`, a full-screen selector over `LanguagePreferenceService.supportedLanguages` with an explicit "Not specified" option that sets `null`.

- [ ] **Step 1: Write the failing test for draft precedence**

In `mobile/test/services/video_publish/video_publish_service_test.dart`:

```dart
test('per-video language overrides the account default', () async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final languageService = LanguagePreferenceService();
  await languageService.initialize();
  await languageService.setContentLanguage('en');

  final service = buildServiceUnderTest(
    languagePreferenceService: languageService,
  );
  await service.publish(draft: buildDraft(language: 'ja'));

  expect(capturedPublishCall.language, equals('ja'));
});

test('falls back to the account default when the draft omits a language',
    () async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final languageService = LanguagePreferenceService();
  await languageService.initialize();
  await languageService.setContentLanguage('en');

  final service = buildServiceUnderTest(
    languagePreferenceService: languageService,
  );
  await service.publish(draft: buildDraft());

  expect(capturedPublishCall.language, equals('en'));
});
```

- [ ] **Step 2: Run it and confirm it fails**

```bash
cd mobile && flutter test test/services/video_publish/video_publish_service_test.dart
```

Expected: FAIL, `buildDraft` has no named parameter `language`.

- [ ] **Step 3: Add the field to the draft model and thread it through**

In `mobile/lib/models/divine_video_draft.dart`: add `this.language,` to the constructor beside `this.contentWarning` (`:47`), `final String? language;` beside `final String? contentWarning;` (`:283`), and handle it in `copyWith` (`:397`) plus `props` and any `fromJson`/`toJson` — the draft is persisted, so check for a `*.g.dart` beside it. Then at `video_publish_service.dart:390`:

```dart
          language: draft.language ??
              languagePreferenceService?.declaredContentLanguage,
```

- [ ] **Step 4: Regenerate if the draft model is generator-backed**

```bash
cd mobile && dart run build_runner build --delete-conflicting-outputs && git status --short
```

Stage any regenerated `*.g.dart` / `*.freezed.dart`.

- [ ] **Step 5: Run the suite and confirm it passes**

```bash
cd mobile && flutter test test/services/video_publish/
```

Expected: PASS.

- [ ] **Step 6: Add the ARB keys**

In `mobile/lib/l10n/app_en.arb`:

```json
"videoPublishLanguageTitle": "Video language",
"@videoPublishLanguageTitle": {
  "description": "Screen title for choosing what language a single video is in."
},
"videoPublishLanguageUnspecified": "Not specified",
"@videoPublishLanguageUnspecified": {
  "description": "Option meaning the creator declines to declare a language for this video."
},
"videoPublishLanguageSubtitle": "Helps people who speak your language find this video."
```

Mirror all three keys into every other `mobile/lib/l10n/app_*.arb`, or add them to `_knownUntranslatedDebt` in `mobile/test/l10n/arb_consistency_test.dart` if translation is deferred.

- [ ] **Step 7: Regenerate l10n and verify consistency**

```bash
cd mobile && flutter gen-l10n && flutter test test/l10n/arb_consistency_test.dart
```

Expected: PASS.

- [ ] **Step 8: Write the failing widget test**

Create `mobile/test/screens/video_publish/video_language_screen_test.dart`:

```dart
void main() {
  group(VideoLanguageScreen, () {
    testWidgets('returns the selected language code', (tester) async {
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: VideoLanguageScreen(
            initialLanguage: null,
            onSelected: (code) => selected = code,
          ),
        ),
      );

      await tester.tap(find.text('Japanese'));
      await tester.pumpAndSettle();

      expect(selected, equals('ja'));
    });

    testWidgets('returns null for the unspecified option', (tester) async {
      var called = false;
      String? selected = 'ja';
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: VideoLanguageScreen(
            initialLanguage: 'ja',
            onSelected: (code) {
              called = true;
              selected = code;
            },
          ),
        ),
      );

      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.tap(find.text(l10n.videoPublishLanguageUnspecified));
      await tester.pumpAndSettle();

      expect(called, isTrue);
      expect(selected, isNull);
    });
  });
}
```

- [ ] **Step 9: Run it and confirm it fails**

```bash
cd mobile && flutter test test/screens/video_publish/video_language_screen_test.dart
```

Expected: FAIL, `VideoLanguageScreen` is not defined.

- [ ] **Step 10: Build the screen**

Create `mobile/lib/screens/video_publish/video_language_screen.dart`. Model it directly on the language list already in `mobile/lib/screens/settings/content_preferences_screen.dart:180-210` — same `LanguagePreferenceService.supportedLanguages` source, same `ListTile` shape, same `DivineIcon`/`VineTheme` usage. Requirements:

- Full-screen `Scaffold`, not a sheet or dialog.
- First row is the "Not specified" option, calling `onSelected(null)`.
- Remaining rows are `supportedLanguages` entries sorted by display name, calling `onSelected(code)`.
- A trailing check on the row matching `initialLanguage` (or on "Not specified" when it is null).
- Split into small private widget classes (`_UnspecifiedTile`, `_LanguageTile`) — no methods returning `Widget`.
- All copy from `context.l10n`.

- [ ] **Step 11: Run it and confirm it passes**

```bash
cd mobile && flutter test test/screens/video_publish/video_language_screen_test.dart
```

Expected: PASS.

- [ ] **Step 12: Wire the route and the composer entry point**

Register the screen in `mobile/lib/router/app_router.dart` following the existing publish-flow route patterns, and add a row in the publish/compose screen — beside the existing content-warning row — that shows the current draft language (or the "Not specified" label) and pushes the new route, writing the result back onto the draft.

- [ ] **Step 13: Analyze, format, run the affected suites**

```bash
cd mobile && dart format $(git diff --name-only --diff-filter=ACM | grep '\.dart$') \
  && flutter analyze lib test integration_test \
  && flutter test test/screens/video_publish/ test/services/video_publish/ test/l10n/arb_consistency_test.dart
```

Expected: no analyzer issues, all tests PASS.

- [ ] **Step 14: Commit and open the PR**

```bash
git add -A mobile/lib mobile/test
git commit -m "feat(publish): let creators set the language per video

The account-level content language labelled every video a creator ever
posted, which is wrong for anyone who posts in more than one language.
Drafts now carry an optional language that falls back to the account
default."
gh pr create --base main --title "feat(publish): let creators set the language per video"
```

Attach a screen recording of the new selector to the PR (repo requires it for UI changes).

**Exit criteria:** A creator can label two videos in two languages in one session.

---

## Phase 3 — divine-blossom: report the language ASR actually detected

**Repo:** `divine-blossom`. **Branch:** `feat/asr-detected-language`. **One PR.** Independent of Phases 1–2.

`nvidia/parakeet-tdt-0.6b-v3` is the multilingual checkpoint, and the Google STT v2 path already parses the real detected code into `SttResult.language`. Both then discard it in favour of the caller's hint. This phase surfaces detection on both paths so Phase 4 has an audio-derived signal to consume.

**Files:**
- Modify: `cloud-run-asr-parakeet/app/transcribe.py:81-104` and `:107-157`
- Modify: `cloud-run-asr-parakeet/app/main.py:60-81`
- Modify: `cloud-run-transcoder/src/transcription_google_stt_v2.rs` (the caller that builds the VTT from `SttResult`)
- Test: `cloud-run-asr-parakeet/tests/test_transcribe_mapping.py`

**Interfaces:**
- Produces: the `/v1/transcribe` JSON response gains `detected_language` (ISO-639-1, lowercase, or `null`), *alongside* the existing `language` field which keeps echoing the request hint so existing callers are untouched.

- [ ] **Step 1: Write the failing test**

In `cloud-run-asr-parakeet/tests/test_transcribe_mapping.py`:

```python
def test_result_reports_model_detected_language_over_hint():
    hyp = _FakeHypothesis(text="bonjour tout le monde", langs=["fr"])
    result = _hypothesis_to_result(hyp, language="en-US")

    assert result.detected_language == "fr"
    assert result.language == "en-US"


def test_detected_language_is_none_when_model_reports_nothing():
    hyp = _FakeHypothesis(text="hello", langs=None)
    result = _hypothesis_to_result(hyp, language="en-US")

    assert result.detected_language is None
```

Add a `_FakeHypothesis` alongside the file's existing fakes carrying `text`, `timestamp`, and `langs` attributes.

- [ ] **Step 2: Run it and confirm it fails**

```bash
cd cloud-run-asr-parakeet && python -m pytest tests/test_transcribe_mapping.py -v
```

Expected: FAIL, `TranscriptionResult` has no attribute `detected_language`.

- [ ] **Step 3: Confirm what the checkpoint actually exposes before implementing**

The NeMo hypothesis attribute carrying detected language differs between checkpoints. Run the model once and inspect:

```bash
cd cloud-run-asr-parakeet && python -c "
from app.transcribe import Transcriber
t = Transcriber()
hyp = t._model.transcribe(['../small_test.mp4'], timestamps=True)[0]
print([a for a in dir(hyp) if not a.startswith('_')])
print(getattr(hyp, 'langs', None), getattr(hyp, 'lang', None))
"
```

Use whatever attribute is actually present in Step 4. If the checkpoint exposes none, implement `detected_language` as always-`None` on the Parakeet path, note it in the PR description, and let Phase 4 lean on the Google STT path plus text detection.

- [ ] **Step 4: Implement**

Add `detected_language: Optional[str]` to `TranscriptionResult` (`transcribe.py:40-45`) and include it in the dict at `:45`. In `_hypothesis_to_result`, read the attribute confirmed in Step 3, normalize it (`str(value).strip().split("-")[0].lower() or None`), and pass it through. Expose it in the `/v1/transcribe` response in `main.py`.

- [ ] **Step 5: Run it and confirm it passes**

```bash
cd cloud-run-asr-parakeet && python -m pytest tests/ -v
```

Expected: PASS.

- [ ] **Step 6: Propagate the Google STT detected code**

`SttResult.language` (`transcription_google_stt_v2.rs:117-121`) already holds the detected `languageCode` from the response. Find its consumer and carry it to the transcoder's output metadata under the same `detected_language` name, normalized to ISO-639-1 the same way (`split('-').next()`, lowercased). Add a unit test in the same file's existing `mod tests` asserting `pt-BR` normalizes to `pt`.

- [ ] **Step 7: Run the Rust tests**

```bash
cd cloud-run-transcoder && cargo test transcription_google_stt_v2
```

Expected: PASS.

- [ ] **Step 8: Commit and open the PR**

```bash
git add cloud-run-asr-parakeet cloud-run-transcoder
git commit -m "feat(asr): report the language the model detected

Both transcription paths echoed the caller's language hint back as the
result language. Parakeet v3 is the multilingual checkpoint and Google
STT v2 already returns a detected languageCode; surface both as
detected_language so ingest can use a real signal."
gh pr create --base main --title "feat(asr): report the language the model detected"
```

**Exit criteria:** `POST /v1/transcribe` on a French clip with `?language=en-US` returns `detected_language: "fr"`.

**Scope honesty — what this phase does NOT do.** Phase 3 makes the ASR services *capable* of reporting language. It does not make them *run* on the catalog. Transcription happens today only when a creator opens the captions editor, which is why `text_track_content` is populated on 1.2% of videos. Turning ASR into a real language signal requires running transcription at ingest on every upload — a separate, larger piece of work with its own GPU cost, queue, backpressure, and cost-per-minute analysis that this plan does not scope.

So Phase 4 lands with **text detection only**, and its `source = 'asr'` enum value stays unused. That is deliberate: the schema is ready for the ASR path so adopting it later is an insert, not a migration. Decide on ASR-at-ingest after Phase 4 reports actual text-detection coverage — if text alone clears the Phase 6 gate, the GPU spend may not be worth it.

---

## Phase 4 — divine-funnelcake: a real `detected_language` column

**Repo:** `divine-funnelcake`. **Branch:** `feat/detected-language`. **One PR.** Depends on Phase 3 only for the ASR half; the text-detection half can land without it.

**Architecture note — read this before writing any SQL.** The existing `language` column is *not* written by Rust. The entire videos read model is a projection computed in ClickHouse over the raw events table's `tags` array; `language` is derived by `arrayElement(arrayFilter(t -> t[1] = 'l' AND t[3] = 'ISO-639-1', tags), 1)[2]` at `000097_videos_latest_read_model.up.sql:165`. ClickHouse cannot run language detection, so `detected_language` **cannot** be another derived column.

Instead follow the side-table pattern the repo already uses for enrichment that automation produces outside the MV — `nostr.category_overrides` (`000200`) is the model to copy, and `enrich_with_labels(storage, &mut videos)` (`crates/api/src/handlers.rs:1114`, called from ~15 read paths) is the query-time read pattern to extend. A `ReplacingMergeTree` keyed on `event_id`, written by a Rust worker, read at enrichment time.

**Files:**
- Create: `database/migrations/000201_video_detected_language.up.sql` and `.down.sql`
- Create: `crates/relay/src/language.rs`
- Modify: `crates/relay/src/lib.rs` (register the module)
- Modify: `crates/relay/src/relay.rs` (spawn detection alongside the existing `submit_gorse_user_enrichment` fire-and-forget pattern at `:2572`)
- Modify: `crates/api/src/handlers.rs:1114` (`enrich_with_labels`)
- Create: `bin/backfill_detected_language.rs`
- Modify: `Cargo.toml` (workspace dep `whatlang = "0.16"`)

**Interfaces:**
- Produces: `detect_language(title: &str, summary: &str) -> Option<(String, f64)>` in `crates/relay/src/language.rs`, returning a lowercase ISO-639-1 code and a 0.0–1.0 confidence, or `None` when there is not enough prose to judge.
- Produces: table `nostr.video_detected_language` with columns `event_id FixedString(64)`, `language LowCardinality(String)`, `confidence Float32`, `source Enum8('text' = 1, 'asr' = 2)`, `version DateTime64(3)`.
- Produces: `detected_language: Option<String>` and `detected_language_confidence: Option<f32>` on the video response type that `enrich_with_labels` populates.

**FixedString(64) landmine:** `event_id` is `FixedString(64)` to match `category_overrides.target_event_id`. Inserting into a `FixedString(N)` column from a Rust `String` **silently corrupts the data with no error** — the string carries a length prefix, the column expects exactly N raw bytes. Use `[u8; 64]` with `#[serde(with = "BigArray")]` from `serde-big-array` on any Row struct that writes this column, and `CAST(event_id AS String)` when selecting it back.

- [ ] **Step 1: Write the failing detector tests**

Create `crates/relay/src/language.rs` containing only a `mod tests`:

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn detects_language_from_prose() {
        let (lang, confidence) = detect_language(
            "Como fazer pão de queijo",
            "Uma receita simples que aprendi com a minha avó em Minas Gerais",
        )
        .expect("should detect");
        assert_eq!(lang, "pt");
        assert!(confidence > 0.5);
    }

    #[test]
    fn returns_none_when_there_is_too_little_prose() {
        assert!(detect_language("Loop", "").is_none());
        assert!(detect_language("", "").is_none());
        assert!(detect_language("Car", "").is_none());
    }

    #[test]
    fn ignores_hashtags_mentions_and_urls() {
        // Only #LNICNews and a URL: no prose, so no verdict.
        assert!(detect_language(
            "#LNICNews",
            "#DivineUniverSity @someone https://divine.video/x"
        )
        .is_none());
    }

    #[test]
    fn does_not_guess_from_a_proper_noun_alone() {
        assert!(detect_language("Biebs !", "").is_none());
    }
}
```

- [ ] **Step 2: Run and confirm it fails to compile**

```bash
cargo test -p funnelcake-relay language::
```

Expected: FAIL, `cannot find function detect_language`.

- [ ] **Step 3: Implement the detector**

Add `whatlang = "0.16"` to the workspace `Cargo.toml` and the relay crate's deps. In `crates/relay/src/language.rs`, above the tests:

```rust
use whatlang::{detect, Lang};

/// Minimum prose words before we are willing to guess a language.
///
/// Measured on 2000 production videos: 31.6% have 10+ prose words, 36.1%
/// have 4-9, and the rest have too little to judge. Four is the floor where
/// whatlang stops coin-flipping on short English/Dutch/German fragments.
const MIN_PROSE_WORDS: usize = 4;

/// Minimum whatlang confidence we will store.
const MIN_CONFIDENCE: f64 = 0.5;

/// Detects the language of a video from its title and summary.
///
/// Hashtags, @mentions, and URLs are stripped first: they are overwhelmingly
/// English or proper nouns regardless of what language the video is in.
/// Returns `None` when there is not enough prose to judge — an absent verdict
/// is more useful downstream than a coin flip.
pub fn detect_language(title: &str, summary: &str) -> Option<(String, f64)> {
    let combined = format!("{title} {summary}");
    let prose: Vec<&str> = combined
        .split_whitespace()
        .filter(|token| {
            !token.starts_with('#')
                && !token.starts_with('@')
                && !token.starts_with("http://")
                && !token.starts_with("https://")
                && token.chars().any(char::is_alphabetic)
        })
        .collect();

    if prose.len() < MIN_PROSE_WORDS {
        return None;
    }

    let info = detect(&prose.join(" "))?;
    if !info.is_reliable() || info.confidence() < MIN_CONFIDENCE {
        return None;
    }

    Some((iso639_1(info.lang())?.to_string(), info.confidence()))
}

/// Maps a whatlang `Lang` to its ISO-639-1 two-letter code.
fn iso639_1(lang: Lang) -> Option<&'static str> {
    let code = lang.code(); // whatlang returns ISO-639-3
    Some(match code {
        "eng" => "en", "spa" => "es", "por" => "pt", "fra" => "fr",
        "deu" => "de", "ita" => "it", "nld" => "nl", "rus" => "ru",
        "ukr" => "uk", "pol" => "pl", "tur" => "tr", "ara" => "ar",
        "jpn" => "ja", "kor" => "ko", "cmn" => "zh", "hin" => "hi",
        "ind" => "id", "vie" => "vi", "tha" => "th", "swe" => "sv",
        "ron" => "ro", "bul" => "bg", "urd" => "ur", "amh" => "am",
        _ => return None,
    })
}
```

Register the module in `crates/relay/src/lib.rs` with `mod language;`.

- [ ] **Step 4: Run and confirm the tests pass**

```bash
cargo test -p funnelcake-relay language::
```

Expected: PASS. If `does_not_guess_from_a_proper_noun_alone` fails, the word floor is doing its job and the assertion is right — do not weaken the test to match the implementation.

- [ ] **Step 5: Write the migration**

Create `database/migrations/000201_video_detected_language.up.sql`. Read `000200_category_overrides.up.sql` end to end first and match its conventions exactly — schema prefix (`nostr.`), `IF NOT EXISTS`, engine choice, and its comment style explaining *why* the engine was chosen.

```sql
-- Migration 000201: Automation-detected content language.
--
-- The existing videos_latest.language column is derived in SQL from the
-- NIP-32 l/ISO-639-1 tag, which the mobile client stamped from the poster's
-- OS locale. It reports the publisher's phone setting, not the language of
-- the video, so it cannot drive discovery.
--
-- Detection needs a real language classifier, which ClickHouse cannot run,
-- so this cannot be another derived column on the read model. It is a side
-- table written by the relay and read at enrichment time, following the same
-- shape as category_overrides (000200).
--
-- ReplacingMergeTree(version): re-detection must overwrite, never accumulate.
-- A later ASR-sourced verdict replaces an earlier text-sourced one for the
-- same event.

CREATE TABLE IF NOT EXISTS nostr.video_detected_language (
    event_id FixedString(64),
    -- ISO-639-1, lowercase. Never the self-reported tag.
    language LowCardinality(String),
    -- 0.0-1.0 from the classifier. Rows below the write threshold are not
    -- inserted at all, so this is always >= the threshold in force when the
    -- row was written.
    confidence Float32,
    -- text = title/summary classification, asr = transcript-derived.
    -- ASR outranks text: the ordering is enforced by the writer, not here.
    source Enum8('text' = 1, 'asr' = 2),
    version DateTime64(3)
) ENGINE = ReplacingMergeTree(version)
ORDER BY event_id;
```

Write the matching `.down.sql` with `DROP TABLE IF EXISTS nostr.video_detected_language;`.

**ClickHouse Cloud constraint:** never put multiple table renames in one statement — the shared engine rejects it with "Database X is Shared, it does not support renaming of multiple tables in single query." One statement per table.

- [ ] **Step 6: Apply the migration locally and confirm it round-trips**

```bash
docker compose -f docker-compose.test.local.yml up -d
# apply via the repo's migration runner, then:
docker compose -f docker-compose.test.local.yml exec clickhouse \
  clickhouse-client -q "DESCRIBE nostr.video_detected_language"
```

Expected: five columns as declared. Then apply the `.down.sql` and confirm the table is gone.

- [ ] **Step 7: Detect on ingest**

In `crates/relay/src/relay.rs`, add `submit_language_detection(&self, event: &RelayEvent)` modelled directly on `submit_gorse_user_enrichment` at `:2572` — same `tokio::spawn`, same `.instrument(parent_span)`, same fire-and-forget error handling (`debug!` on failure, never fail the ingest). Call it from the same place `submit_gorse_user_enrichment` is called (`:2013`), gated on the event being a video or audio kind.

Inside: pull the `title` and `summary` tag values off the event, call `language::detect_language(title, summary)`, and on `Some((lang, confidence))` insert one row with `source = 'text'` and `version = now64(3)`. On `None`, **write nothing** — an absent row is the signal for "undetected," and writing an empty-language row would make the read path unable to distinguish "not yet processed" from "processed, no verdict." Never fall back to the self-reported tag.

Use `[u8; 64]` with `#[serde(with = "BigArray")]` for the `event_id` field on the insert Row struct — see the FixedString landmine above.

- [ ] **Step 8: Add an ingest-level test**

Add to the relay crate's existing ingest test module, mirroring the fixture style of neighbouring tests in that file:

```rust
#[tokio::test]
async fn ingest_writes_detected_language_for_prose_titled_video() {
    let harness = ingest_harness().await;
    harness
        .ingest(video_event_with_text(
            "Como fazer pão de queijo",
            "Uma receita simples que aprendi com a minha avó em Minas Gerais",
        ))
        .await;

    let row = harness.detected_language_for(&harness.last_event_id()).await;
    assert_eq!(row.map(|r| r.language), Some("pt".to_string()));
}

#[tokio::test]
async fn ingest_writes_no_row_when_there_is_too_little_prose() {
    let harness = ingest_harness().await;
    harness.ingest(video_event_with_text("Loop", "")).await;

    assert!(harness
        .detected_language_for(&harness.last_event_id())
        .await
        .is_none());
}
```

- [ ] **Step 9: Run the crate suite**

```bash
cargo test -p funnelcake-relay && cargo clippy -p funnelcake-relay -- -D warnings
```

Expected: PASS, no clippy warnings.

- [ ] **Step 10: Read it back through `enrich_with_labels`**

Extend `enrich_with_labels` (`crates/api/src/handlers.rs:1114`) to also fetch `video_detected_language` rows for the batch of event ids it is already enriching, and populate `detected_language` / `detected_language_confidence` on each video. One batched query for the whole slice — do not query per video.

Use `FINAL` when selecting from the `ReplacingMergeTree` so a re-detected event does not return two rows, and `CAST(event_id AS String)` in the SELECT — reading a `FixedString(64)` into a Rust `String` without the cast produces "string is not valid utf8."

This is deliberately *not* a change to the read-model structs in `crates/clickhouse/src/queries.rs`. Those three structs deserialize **positionally**, and adding a field without adding the column at the same position in every feeding SELECT causes a runtime deserialize failure rather than a compile error (see the explicit warnings in `crates/clickhouse/src/client.rs` at lines 1764, 1825, 15805). Going through the existing enrichment seam avoids touching them at all.

- [ ] **Step 11: Add an API-level test and run the workspace suite**

Add a test in `crates/api/src/tests.rs` asserting a video with a `video_detected_language` row comes back with `detected_language` populated, and one without comes back `None`.

```bash
cargo test --workspace && cargo clippy --workspace -- -D warnings
```

Expected: PASS.

- [ ] **Step 12: Backfill**

Create `bin/backfill_detected_language.rs`. Check `bin/janitor.rs` first — if it already has a batching/checkpointing harness, extend that instead of writing a second one. The backfill walks existing videos in `event_id` order with a resumable checkpoint, runs `detect_language` over each title/summary, and batch-inserts rows for the hits.

Run against staging first. Report in the PR description: total videos scanned, share with a verdict at confidence ≥ 0.5, and the per-language histogram.

- [ ] **Step 13: Sanity-check the backfill output before trusting it**

Spot-check 20 rows per detected language against the actual titles:

```bash
clickhouse-client -q "
SELECT d.language, d.confidence, v.title
FROM nostr.video_detected_language FINAL AS d
JOIN nostr.videos_latest AS v ON CAST(d.event_id AS String) = v.id
WHERE d.language != 'en'
ORDER BY rand() LIMIT 60
FORMAT Vertical"
```

If the non-English verdicts look like the mislabels in this plan's Background section, the floor is too low — raise `MIN_PROSE_WORDS` to 6, re-run, and re-check. Do not lower `MIN_CONFIDENCE` to get more coverage; coverage bought with wrong labels is what this whole plan exists to undo.

- [ ] **Step 13: Commit and open the PR**

```bash
git add database/migrations crates bin Cargo.toml Cargo.lock
git commit -m "feat(ingest): detect content language from title and summary

The existing language column is the poster's phone locale, not the
video's language - 92.4% of the catalog claims 'en' and the non-en rows
are visibly mislabelled. Add a separate detected_language column fed by
text detection at ingest, with a 4-prose-word floor and a confidence
threshold so we store no verdict rather than a coin flip."
gh pr create --base main --title "feat(ingest): detect content language from title and summary"
```

**Exit criteria:** Report actual coverage from the backfill — what share of the catalog has a `detected_language` with confidence ≥ 0.5, broken down by language. This number is the input to the Phase 6 gate.

---

## Phase 5 — divine-funnelcake: feed language to Gorse and honor the client's hint

**Repo:** `divine-funnelcake`. **Branch:** `feat/language-aware-recommendations`. **One PR.** Depends on Phase 4.

**Files:**
- Modify: `crates/relay/src/relay.rs:300-368` (`gorse_item_for_event`)
- Modify: `crates/api/src/recommendations.rs:81-113` (`RecommendationQuery`)
- Modify: `crates/api/src/handlers.rs` (the recommendations route's query extractor)
- Modify: `crates/api/src/openapi.rs`

**Interfaces:**
- Consumes: `detected_language` / `detected_language_confidence` from Phase 4.
- Produces: `RecommendationQuery.preferred_languages: Vec<String>` and `RecommendationQuery.viewer_country: Option<String>`, parsed from the comma-separated `preferred_languages` and `viewer_country` query params the client has been sending since before this plan.

- [ ] **Step 1: Write the failing Gorse-label test**

In the existing `mod tests` in `crates/relay/src/relay.rs`, beside the other `gorse_item_for_event` tests:

```rust
#[test]
fn gorse_item_carries_detected_language_label() {
    let event = video_event_with_text(
        "Como fazer pão de queijo",
        "Uma receita simples que aprendi com a minha avó em Minas Gerais",
    );
    let item = gorse_item_for_event(&event).expect("video event yields an item");
    assert!(item.labels.contains(&"lang:pt".to_string()));
}

#[test]
fn gorse_item_omits_language_label_when_undetected() {
    let event = video_event_with_text("Loop", "");
    let item = gorse_item_for_event(&event).expect("video event yields an item");
    assert!(!item.labels.iter().any(|l| l.starts_with("lang:")));
}

#[test]
fn gorse_item_ignores_the_self_reported_language_tag() {
    // Self-reports 'de' (poster's phone locale) but the prose is Portuguese.
    let mut event = video_event_with_text(
        "Como fazer pão de queijo",
        "Uma receita simples que aprendi com a minha avó em Minas Gerais",
    );
    event.tags.push(vec!["l".into(), "de".into(), "ISO-639-1".into()]);
    let item = gorse_item_for_event(&event).expect("video event yields an item");

    assert!(item.labels.contains(&"lang:pt".to_string()));
    assert!(!item.labels.contains(&"lang:de".to_string()));
}
```

Reuse the `video_event_with_text` fixture added in Phase 4 Step 8.

- [ ] **Step 2: Run and confirm it fails**

```bash
cargo test -p funnelcake-relay gorse_item_carries_detected_language
```

Expected: FAIL, label not present.

- [ ] **Step 3: Add the label**

In `gorse_item_for_event`, after the `labels` vec is built (`relay.rs:324-325`), call `language::detect_language` directly on the event's `title` and `summary` tags and push `format!("lang:{code}")` on `Some`.

**Call the detector directly here — do not read the `video_detected_language` table.** Detection is written by a `tokio::spawn`ed task (Phase 4 Step 7) that races Gorse item construction, so the row may not exist yet when this runs. `detect_language` is a pure in-memory function over data already on the event, so calling it twice is cheaper than coordinating the two paths, and it makes the label deterministic per event rather than dependent on task scheduling.

Use the detected value only — never the self-reported `l`/ISO-639-1 tag.

- [ ] **Step 4: Run and confirm it passes**

```bash
cargo test -p funnelcake-relay gorse_item
```

Expected: PASS.

- [ ] **Step 5: Write the failing query-parsing test**

In `crates/api/src/tests.rs`:

```rust
#[test]
fn recommendation_query_parses_preferred_languages() {
    let q = RecommendationQuery::from_params(
        Some(50), None, None, None, None, None,
        Some("pt,en"), None,
        ResolvedContentSafety::default(),
    );
    assert_eq!(q.preferred_languages, vec!["pt".to_string(), "en".to_string()]);
}

#[test]
fn recommendation_query_ignores_blank_language_entries() {
    let q = RecommendationQuery::from_params(
        Some(50), None, None, None, None, None,
        Some("pt, ,,en "), None,
        ResolvedContentSafety::default(),
    );
    assert_eq!(q.preferred_languages, vec!["pt".to_string(), "en".to_string()]);
}
```

- [ ] **Step 6: Run and confirm it fails**

```bash
cargo test -p funnelcake-api recommendation_query_parses
```

Expected: FAIL, `from_params` takes 7 arguments.

- [ ] **Step 7: Extend `RecommendationQuery`**

Add `pub preferred_languages: Vec<String>` and `pub viewer_country: Option<String>` to the struct and to `from_params`, splitting on `,`, trimming, lowercasing, dropping empties. Update every existing `from_params` call site (grep it) and the route's query extractor so the params are actually read off the wire. Document both in `crates/api/src/openapi.rs`.

- [ ] **Step 8: Run and confirm it passes**

```bash
cargo test -p funnelcake-api recommendation_query
```

Expected: PASS.

- [ ] **Step 9: Apply the preference as a soft boost, not a hard filter**

Feed `preferred_languages` into the Gorse call as a label preference, and in the fallback path rank matching-language items above non-matching ones. **Do not filter.** At the coverage levels Phase 4 will report, a hard filter empties the feed for anyone outside the top few languages — and a video with no detected language must never be excluded, since "undetected" is the majority case for short-caption content.

Add a test asserting that a request with `preferred_languages=pt` still returns items whose `detected_language` is empty.

- [ ] **Step 10: Run the workspace suite**

```bash
cargo test --workspace && cargo clippy --workspace -- -D warnings
```

Expected: PASS.

- [ ] **Step 11: Commit and open the PR**

```bash
git add crates
git commit -m "feat(recommendations): make language a ranking signal

Gorse had no language input at all, and the preferred_languages param
the mobile client has been sending was silently dropped. Add a lang:xx
item label from the detected column and honor the client's hint as a
soft boost - never a filter, since undetected is the majority case."
gh pr create --base main --title "feat(recommendations): make language a ranking signal"
```

**Exit criteria:** A staging account with `preferred_languages=pt` sees measurably more Portuguese content in For You, and its feed is not shorter than an equivalent `en` account's.

---

## Phase 6 Gate — decide on UI, do not pre-build it

Deliberately not a task list. Build UI only once Phase 4's backfill reports **≥ 5% of the catalog with confident detection in at least one non-English language**, and Phase 5 shows the soft boost moving watch-time for those users.

Below that bar, ship nothing visible: a language tab that opens onto four videos reads as "this app has nothing for me," which is worse than no tab. At the 1.2%-French level measured today, a per-language tab is an empty room.

When the bar is met, the first UI to try is a **language filter on the existing New/Popular tabs**, not a new tab. A filter degrades gracefully as the corpus fills in; a dedicated tab in `ExploreTabsState.tabNames` (`mobile/lib/blocs/explore_tabs/explore_tabs_state.dart:52-60`) commits us to having enough content to fill it on day one.

Re-run the measurement in this plan's Background section to check the gate:

```bash
python3 - <<'EOF'
import json,urllib.request,collections
langs=collections.Counter(); tot=0
for off in range(0,3000,100):
    d=json.load(urllib.request.urlopen(
        f"https://api.divine.video/api/videos?limit=100&offset={off}&nsfw=show",timeout=25))
    items=d['data'] if isinstance(d,dict) and 'data' in d else d
    if not items: break
    for i in items:
        tot+=1
        langs[i.get('detected_language') or '(none)']+=1
print(tot, langs.most_common(25))
EOF
```

---

## Risks

- **Phase 4 backfill cost.** Re-detecting the whole catalog is a full table scan plus a write. Batch it and run off-peak; the janitor bin is the right home if it already has a batching harness.
- **whatlang on short text.** The `MIN_PROSE_WORDS = 4` floor is set from the measured distribution, not from theory. If the backfill shows implausible detections (e.g. a spike in Dutch, whatlang's classic false positive for short English), raise the floor to 6 and re-run rather than lowering the confidence threshold.
- **Positional deserialization in ClickHouse.** Phase 4 Step 10 is the highest-risk step in the plan; the failure mode is a runtime error in production, not a compile error. Grep every SELECT feeding the three structs.
- **Phase 1 shifts a metric.** The `(empty)` share of `language` will climb after Phase 1 ships. That is the intended effect. Tell whoever watches that dashboard before it lands.
