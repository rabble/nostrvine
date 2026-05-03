# Camera "Upload" mode explainer

**Date:** 2026-05-04
**Status:** Approved for implementation

## Problem

Users arriving from TikTok / Instagram / similar apps reach for a "post
from camera roll" affordance on the recorder screen. Divine doesn't
support uploads — every video is recorded in-app so we can carry
camera-to-user verification and stay free of AI slop.

Today there is no surface that explains this. Users scroll the mode
wheel, find only `Capture` and `Classic`, and either churn or assume
the feature is missing rather than intentional. We're missing the
educational moment with the audience most likely to convert on the
brand promise.

## Goal

Add a third mode `Upload` to the camera mode-switcher whose entire
content is an in-screen explainer. Selecting `Upload` does **not**
open a picker. The panel explains why Divine doesn't accept uploads
(verification, no AI slop) and links out to
`https://divine.video/proofmode` for users who want to read more.

C2PA-aware verified import is explicitly **out of scope**. This is the
educational placeholder that lives where users would otherwise expect
an uploader. When real verified import ships, it replaces this
panel's body without needing to relocate the entry point.

## Non-goals

- No photo / video picker integration (no `image_picker`, no
  `file_picker`, no new permissions).
- No client-side AI-content detection or C2PA signature inspection.
- No changes to `divine.video/proofmode`. The page already exists; we
  link to it as-is.
- No localization of `divine.video/proofmode`'s body — the URL is the
  same in every locale.
- No drive-by l10n for the existing `Capture` / `Classic` mode labels;
  flagged as a follow-up if we want all three labels translated.

## Design

### 1. Enum: add `upload`

`mobile/lib/models/video_recorder/video_recorder_mode.dart`

Add `upload` as a third case alongside `capture` and `classic`. Update
each existing `switch` in this file to return safe values for the new
case:

| Property              | Value for `upload`                       |
|-----------------------|------------------------------------------|
| `label`               | `'Upload'` (will be l10n-keyed)          |
| `hasRecordingLimit`   | `false`                                  |
| `hasVideoEditor`      | `false`                                  |
| `supportGridLines`    | `false`                                  |
| `defaultAspectRatio`  | `.vertical` (unused — no preview)        |

Dart's exhaustive `switch` checking will flag every other call site
that switches on `VideoRecorderMode`. Each gets a sensible upload-mode
arm — typically the same arm `classic` uses, since neither one
involves the in-app editor. The compiler errors are the work list.

### 2. New stack widget

`mobile/lib/widgets/video_recorder/modes/upload/video_recorder_upload_stack.dart`

Mirrors the file shape of `video_recorder_capture_stack.dart` and
`video_recorder_classic_stack.dart`. Body is a static, scrollable
explainer panel — no camera preview, no record button, no top bar.

Layout (top to bottom inside the recorder area):

- Title (large, brand-voiced)
- Two short body paragraphs
- Outbound "Learn more" link row with a chevron and an external-link
  icon affordance
- The mode-switcher wheel remains visible at the bottom (owned by the
  screen, not the stack), so the user can swipe back to a recording
  mode without reading the panel.

Uses `VineTheme` colors / fonts and the existing `divine_ui`
components. No raw `TextStyle` or `Color(0x...)` literals. No
hardcoded English strings — every visible string comes from
`context.l10n`.

### 3. Camera lifecycle on mode switch

`mobile/lib/screens/video_recorder_screen.dart`

When the active mode becomes `upload`, the screen must release the
camera the same way the existing background lifecycle hook does (see
the `WidgetsBindingObserver` path that handles
`AppLifecycleState.paused`). When the user swipes back to a recording
mode, re-initialize the camera the same way the screen does today on
foreground.

Goal: no camera indicator LED while sitting on the explainer, no
wasted resources, no audio focus held.

### 4. "Learn more" link

Single constant in
`mobile/lib/widgets/video_recorder/modes/upload/upload_explainer_constants.dart`:

```dart
const proofmodeLearnMoreUrl = 'https://divine.video/proofmode';
```

Tapping the link uses the existing `url_launcher` dependency with
`LaunchMode.externalApplication`. The URL is the same in every
locale (the marketing page handles its own localization).

### 5. Copy (English source)

These ARB keys go in `mobile/lib/l10n/app_en.arb`. Other locales
follow the existing translation workflow — out of scope for this PR
beyond English.

Copy is adapted from the existing support-team reply when users
ask why uploads aren't allowed, so the in-app explainer says what
the team already says in writing — same hedges, same humility, same
"camera-direct" framing. Notably:

- "better guarantee" not "guarantee" — we don't claim perfect
  verification (C2PA is future).
- "as much as we can" — honest about not being airtight.
- Avoids the brand-guideline phrase "AI slop" in favour of
  "synthetic content"; the support reply uses the latter and this
  surface should match.

| ARB key                          | Value                                                                                                                                                                          |
|----------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `videoRecorderUploadTitle`       | `Why no upload?`                                                                                                                                                               |
| `videoRecorderUploadBody`        | `What you see on Divine is human-made: raw and captured in the moment. Unlike platforms that allow highly produced or AI-generated uploads, we prioritize the authenticity of the camera-direct experience.` |
| `videoRecorderUploadBodyDetail`  | `By keeping creation inside the app, we can better guarantee content is real and unedited — and keep the community free of synthetic content as much as we can.`               |
| `videoRecorderUploadBodyCta`     | `Switch to Capture or Classic to roll something real.`                                                                                                                         |
| `videoRecorderUploadLearnMore`   | `Learn how verification works`                                                                                                                                                 |

There is no `videoRecorderUploadModeLabel` key — the mode tab label
stays hardcoded `'Upload'` to match the existing hardcoded `'Capture'`
and `'Classic'` in `VideoRecorderMode.label`. Migrating all three is
a follow-up issue.

### 6. Mode-switcher wheel

`VideoRecorderModeSelectorWheel` already iterates
`VideoRecorderMode.values`, so it picks up `upload` automatically.
No changes to this widget. The pill width is computed from the
selected label's text width via `TextPainter`, so a longer label will
naturally widen the pill.

### 7. Bottom bar

The existing record button and classic-mode action rows live inside
the per-mode stacks (`video_recorder_capture_stack.dart`,
`video_recorder_classic_stack.dart`). The new stack omits them, so
nothing else needs to gate on `mode == upload`.

## Tests

- **Widget test** for `VideoRecorderUploadStack`:
  - Renders the title, both body paragraphs, and the learn-more link
    using `lookupAppLocalizations(const Locale('en'))` for assertions
    (per `rules/testing.md` — never assert hardcoded English).
  - Tapping the learn-more link calls the URL launcher with
    `proofmodeLearnMoreUrl` and `LaunchMode.externalApplication`.
    Mock `url_launcher` per project pattern.
  - `MaterialApp` includes
    `localizationsDelegates: AppLocalizations.localizationsDelegates`
    and `supportedLocales: AppLocalizations.supportedLocales`.

- **Widget test** for the recorder screen mode swap:
  - Switching the mode wheel to `upload` shows the upload stack and
    hides the camera preview / record button.
  - Switching back to `capture` re-shows the camera preview.

- **Enum coverage**: ensure each `switch` arm on
  `VideoRecorderMode.upload` is exercised — direct unit assertions on
  the four enum getters.

- **Integration tests** under `integration_test/video_recorder/`:
  audit only — most should be unaffected. Any test that asserts the
  exact set of mode labels gets a one-line update.

## Risks & open issues

1. **`divine.video/proofmode` content drift.** The link is hardcoded
   in app code; if the marketing page is renamed, the app keeps
   pointing at a 404 until a new release. Mitigation: keep the URL in
   one constant so renames are a one-line PR; the website team owns
   redirects.

2. **Bait-and-switch perception.** Some users will read the `Upload`
   tab as deceptive ("I tapped upload and got a lecture"). Copy
   leads with the *why* before any refusal language to disarm this,
   but it's a UX risk worth watching in feedback after launch.

3. **Camera-release race.** If the user rapidly swipes between modes,
   the camera may be in the middle of releasing when re-init is
   requested. The existing `AppLifecycleState` handling in the
   recorder screen already handles this case; we reuse it rather
   than inventing a new path.

4. **Apple review framing.** The `Upload` tab does not request
   `NSPhotoLibraryUsageDescription` (no picker), so no Info.plist
   change is required. If a reviewer asks "where does upload go?",
   the explainer panel is the answer.

## Implementation order

1. Add `upload` to the enum and fix the resulting compiler errors
   across the codebase (one commit per logical site, or a single
   mechanical commit if the touched sites are all `switch` arms).
2. Add ARB keys + run `flutter gen-l10n`.
3. Build the explainer stack widget + URL constant.
4. Wire camera-release on entering `upload` mode in the recorder
   screen.
5. Tests.
6. Manual QA on iOS + Android: swipe to Upload, verify no LED, tap
   learn-more, swipe back, record.
