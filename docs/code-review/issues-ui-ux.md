# UI/UX Issues

Issues related to theme consistency, localization, accessibility, loading/error states, and UI patterns.

Note: `VineTheme` is adopted across 194 files, 1,251+ `context.l10n` usages support 15 languages, and 54 of 58 BLoC-backed screens handle error states. These issues cover the gaps: hardcoded English strings (many with unused ARB keys already defined), missing ICU plural syntax, accessibility gaps (unlabeled elements, undersized touch targets, no screen reader announcements or reduced-motion support), WCAG contrast issues, and inconsistent `VineTheme` font method adoption.

## Localization

---

### Hardcoded English strings in 15+ widget and screen files
**Problem**: 15 files use literal English strings in `Text()` instead of `context.l10n.xxx`, plus 27 hardcoded `hintText`, `tooltip`, and `semanticLabel` values across ~20 additional files.

**Evidence**: Examples: `explore_screen.dart:1214`: `Text('No videos available')`. `category_gallery_screen.dart:209`: `const Text('Retry')`. `profile_setup_screen.dart:1723`: `Text("Support request sent! We'll get back to you soon.")`. `camera_fab.dart:40`: `Text('You must be 16 or older to create content')`. `content_warning.dart:148`: `const Text('View Anyway')`. `metadata_expanded_sheet.dart:145`: `Text('Captions')`. Many of these have corresponding ARB keys that were created but never wired up (see orphaned keys finding below). With 15 supported languages, every hardcoded string is a broken experience for non-English users.

**Done well**: `settings_screen.dart` uses 37+ `context.l10n` calls with no hardcoded English. `user_not_available_screen.dart` is fully localized.

**Impact**: High. These strings will not change for any non-English locale.

**Effort**: Medium. Most already have ARB keys defined. For those that do, it is a find-and-replace to `context.l10n.keyName`. For those that lack ARB keys, new keys must be added first.

**GitHub ticket**: TBD

---

### 94 orphaned ARB keys (defined but unused in code)
**Problem**: 94 keys in `app_en.arb` have no reference in any non-generated Dart file. These were created to support l10n but never wired up to widgets.

**Evidence**: Major categories: `profileSetup*` (22 keys), `auth*` (17 keys), `metadata*` (14 keys), plus scattered `category*`, `locale*`, `router*` keys. Several have exact matches to hardcoded strings in code, e.g. `profileSetupBioHint: "Tell people about yourself..."` exists in ARB while `profile_setup_screen.dart:676` uses `hintText: 'Tell people about yourself...'`. Similarly `invitesTitle`/`cameraAgeRestriction` have matching hardcoded strings. The 94 keys represent wasted translation effort across 14 languages.

**Impact**: Medium. Wasted translation effort and the underlying hardcoded strings remain broken for non-English users.

**Effort**: Low. For the ~30+ keys with matching hardcoded strings, the fix is replacing the string with `context.l10n.keyName`. The rest should be audited to determine if they are truly dead.

**GitHub ticket**: TBD

---

### Missing ICU plural syntax (22 ARB keys + 11 inline Dart ternaries)
**Problem**: 22 ARB keys use `{count}` parameters with quantity nouns but lack ICU plural syntax. Additionally, 11 widget files use inline Dart ternary logic for English-only pluralization.

**Evidence**: ARB examples: `relaySettingsConnectedToRelays: "Connected to {count} relay(s)!"` uses literal "(s)" instead of ICU plural. `analyticsViewsCount: "{count} views"` should be `{count, plural, =1{view} other{views}}`. Dart inline examples: `list_card.dart:67`: `'${length == 1 ? 'person' : 'people'}'`. `comments_screen.dart:63`: `'$count ${count == 1 ? 'Comment' : 'Comments'}'`. Languages like Arabic (6 plural forms), Polish (4 forms), and Romanian (3 forms), all supported by the app, cannot be served by simple ternary checks.

**Impact**: High. Arabic, Polish, Romanian, and other supported languages with complex plural rules will show grammatically incorrect strings.

**Effort**: Medium. For the 22 ARB keys, convert to ICU `{count, plural, =1{...} other{...}}` syntax. For the 11 inline Dart occurrences, create new ARB keys with ICU plural syntax and replace the inline logic.

**GitHub ticket**: TBD

---

### 3 recently added keys missing from all non-English ARB files
**Problem**: `feedFollowingEmpty`, `feedForYouEmpty`, `feedLatestEmpty` exist in `app_en.arb` but are missing from all 14 non-English ARB files.

**Evidence**: EN has 1,402 keys. All other languages (AR, DE, ES, FR, ID, IT, JA, KO, NL, PL, PT, RO, SV, TR) have 1,399 keys each. The generated code falls back to English for these keys.

**Impact**: Low. Only 3 keys, limited to empty-state messages.

**Effort**: Low. Add the 3 keys to all 14 ARB files with translated values.

**GitHub ticket**: TBD

---

### Interactive elements without semantic labels
**Problem**: Multiple high-traffic interactive elements use bare `GestureDetector` or `InkWell` with no `Semantics` wrapper, `tooltip`, or `label`, making them invisible to screen readers.

**Evidence**: Key instances: `VineBottomNav._buildTabButton` (lines 110–127) has `Semantics(identifier:)` but no `label:` or `button: true`, making the 4 main navigation tabs invisible to screen readers. `VideoExploreTile` (line 42) wraps content in `GestureDetector` with no semantics, the primary discovery surface. `ProfileHeaderWidget._UniqueIdentifier` (lines 702–719) has a copy-link `GestureDetector` wrapping an SVG icon with no label. `VideoOverlayActions` content warning badge (line 1439) and ProofMode badge (line 1457) are tappable `GestureDetector`s with no semantic annotation. `ShareVideoMenu` close `IconButton` (line 161) has no `tooltip`, plus 4+ other `GestureDetector`/`InkWell` instances lacking labels. `GlobalUploadIndicator` (line 69) tappable progress indicator with no label. `NotificationListItem` (line 29) uses `InkWell(onTap:)` with no semantic description.

**Done well**: `user_avatar.dart` wraps in `Semantics(label: ..., button: true)` correctly. `video_action_button.dart` has a comprehensive `Semantics` wrapper with label, identifier, and button semantics.

**Impact**: High. Bottom navigation (used on every screen), explore grid (primary discovery), and notifications (key engagement) are all affected. Screen reader users cannot identify or navigate between core app surfaces.

**Effort**: Medium. Add `Semantics(label: ..., button: true)` wrappers or `tooltip` to each instance. The bottom nav fix is highest priority.

**GitHub ticket**: TBD

---

### Zero uses of `ExcludeSemantics` and `MergeSemantics`
**Problem**: No decorative elements are excluded from the semantics tree, and no related elements are merged. This adds unnecessary noise to the screen reader experience.

**Evidence**: Zero matches for `ExcludeSemantics` or `MergeSemantics` across the entire `mobile/lib/` directory. Decorative gradients (e.g., video overlay at `video_feed_item.dart` lines 1406–1429), background images, dividers, and icons used alongside text all add noise to the semantics tree. Semantics usage is concentrated in the video feed overlay (87 files with `Semantics()`), but screens like settings, inbox, auth, and notifications have zero or minimal semantic annotations.

**Examples needing `ExcludeSemantics`** (decorative icons next to text — the icon is redundant with the adjacent label):

- `audio_attribution_row.dart`: The music note icon and caret-right icon next to `"$soundName · $creatorName"` are purely visual.
- `video_feed_item.dart` content warning badge: A `warning_amber_rounded` icon next to the warning label text.

**Examples needing `MergeSemantics`** (related widgets that form one logical unit):

- `collaborator_avatar_row.dart`: The people icon, stacked avatars, and collaborator count label form a single concept ("3 collaborators") but are read as separate nodes.
- `video_feed_item.dart` author row: The avatar, display name, NIP-05 badge, and loop count form one unit ("Author: displayName, verified, 5 loops") but are read individually.

**Impact**: Medium. Screen readers traverse every decorative element, making navigation slow and confusing.

**Effort**: High. Requires a systematic pass through all screens to identify decorative vs. meaningful content.

**GitHub ticket**: TBD

---

### Touch targets below 48x48dp minimum
**Problem**: Several interactive elements have touch targets smaller than the 48x48dp accessibility minimum.

**Evidence**: `VideoFollowButton` (`video_follow_button.dart` line 173): 20x20dp container, far below minimum. This is a critical engagement action overlaid on the avatar. `MoreActionButton` (`more_action_button.dart` line 37): 40x40dp container, below minimum. The Semantics wrapper does not add padding.

**Impact**: High (follow button) / Medium (more button). Users with motor impairments struggle to tap undersized targets. The 20x20dp follow button is challenging even for typical users.

**Effort**: Medium. The follow button needs design coordination (keep visual at 20px but wrap in a transparent 48x48 hit area). The more button is a simple size increase.

**GitHub ticket**: TBD

---

### `onSurfaceMuted` color fails WCAG AA contrast for normal text
**Problem**: `VineTheme.onSurfaceMuted` is `Color(0x80FFFFFF)` (white at 50% opacity), which on black renders as ~#808080 with a contrast ratio of ~4.0:1, below the 4.5:1 WCAG AA threshold for normal text.

**Evidence**: `mobile/packages/divine_ui/lib/src/theme/vine_theme.dart` line 276: `static const Color onSurfaceMuted = Color(0x80FFFFFF);`. This color appears in 738+ occurrences across 194 files, frequently for body text, labels, and subtitles. On non-pure-black surfaces (e.g., `cardBackground`), the contrast would be even lower.

**Done well**: `VineTheme` itself is well-structured with consistent adoption across 194 files. The issue is one specific token value, not the theme architecture.

**Impact**: Medium. Affects readability for users with low vision across a very large surface area (194 files).

**Effort**: Low to define a higher-contrast variant, High to audit all 738 usages and determine which should use it.

**GitHub ticket**: TBD

---

### Zero uses of `SemanticsService.announce`
**Problem**: No async operations announce changes to screen readers. Uploads, deletes, errors, bookmark additions, and follow/unfollow actions all complete silently.

**Evidence**: Zero matches for `SemanticsService.announce` across the entire `mobile/lib/` directory. Screen reader users have no feedback when: video upload completes or fails, content is bookmarked or added to a list, follow/unfollow actions succeed, comments are posted or deleted, or error states change.

**Impact**: High. Screen reader users have no feedback for any async operation outcome.

**Effort**: Medium. Add `SemanticsService.announce()` calls after key async operations. Focus first on upload complete/fail, delete, and follow/unfollow.

**GitHub ticket**: TBD

---

### Zero checks for reduced motion / `disableAnimations`
**Problem**: None of the 55+ animation usages check `MediaQuery.of(context).disableAnimations` to respect the user's reduced-motion preference.

**Evidence**: Zero matches for `disableAnimations` across the entire `mobile/lib/` directory. The app uses `AnimatedOpacity` extensively (video overlay fade at `video_feed_item.dart` lines 1469 and 1695, pause button fade at line 1160), `FadeTransition`, `ScaleTransition`, and custom animations in the video recorder, editor, and feed.

**Impact**: Medium. Users with vestibular disorders or epilepsy risk still see all animations, including content warning-gated content that may have flashing lights.

**Effort**: Medium. Create a shared utility `bool shouldAnimate(BuildContext context)` and thread it through animation durations. For critical ones (video overlay, editor), set `duration: Duration.zero` when reduced motion is active.

**GitHub ticket**: TBD

---

### Raw `TextStyle` constructors instead of `VineTheme` font methods
**Problem**: 56 screen files use raw `TextStyle(fontSize: ..., fontWeight: ...)` constructors instead of `VineTheme` font methods (`titleMediumFont()`, `bodyMediumFont()`, etc.).

**Evidence**: 56 files in `mobile/lib/screens/` contain raw `TextStyle(` constructors alongside 109 files that use `VineTheme.` correctly, roughly a 50/50 split. Examples: `app_detail_screen.dart` has 4+ raw `TextStyle` constructors with inline `fontSize` and `fontWeight`; `content_preferences_screen.dart` lines 48–59 use `TextStyle(fontSize: 16)` instead of `VineTheme.bodyLargeFont()`; `invites_screen.dart` line 84 uses `TextStyle(fontSize: 16, color: VineTheme.secondaryText)` mixing raw and themed styling. The project's own `ui_theming.md` rule states: "Use `VineTheme` font methods instead of raw `TextStyle` constructors."

**Done well**: 109 files use `VineTheme.` font methods correctly. `user_not_available_screen.dart` demonstrates consistent usage throughout.

**Impact**: Medium. Design system drift: if font family, weight, or line height values change in `VineTheme`, the 56 files with raw `TextStyle` won't pick up the update. Creates visual inconsistency as the design system evolves.

**Effort**: Medium. Mechanical replacement in 56 files, but each occurrence needs mapping to the correct `VineTheme` method. Can be done opportunistically when touching these screens.

**GitHub ticket**: TBD

---

### Raw `Colors.` usage in screen files
**Problem**: 7 screen files use `Colors.white`, `Colors.black`, or other Material `Colors.*` constants instead of `VineTheme` color tokens.

**Evidence**: Files using raw `Colors.` in `mobile/lib/screens/`: `invite_gate_screen.dart` (`Colors.white`, `Colors.black`), `category_gallery_screen.dart`, `new_message_sheet.dart`, `trending_hashtags_section.dart`, `feature_request_dialog.dart`, `bug_report_dialog.dart`, `video_text_editor_screen.dart`. Additional occurrences in `mobile/lib/widgets/`: `video_action_button.dart` and others. The project rule states: "Use `VineTheme` and shared components from `divine_ui` before adding one-off styling or raw `Colors.*`."

**Done well**: The vast majority of the codebase uses `VineTheme` color tokens; the 7 affected files are a small minority.

**Impact**: Low. Divine is dark-mode only, so `Colors.white`/`Colors.black` may coincidentally match the theme. However, if the design system palette shifts (e.g., off-white text, dark gray backgrounds), these hardcoded values won't follow.

**Effort**: Low. Replace each `Colors.*` reference with the corresponding `VineTheme` token. Small, isolated changes.

**GitHub ticket**: TBD

---

### `Image.network` used without caching
**Problem**: 5 files use raw `Image.network` instead of `VineCachedImage` or `CachedNetworkImage`.

**Evidence**: `widgets/blurhash_display.dart` (lines 93, 102) uses `Image.network` as a fallback when blurhash decoding fails; this is the most impactful instance since blurhash is used on every video thumbnail. `screens/feed/video_feed_page.dart` uses `Image.network` for an app icon. `screens/feed/pooled_fullscreen_video_feed_screen.dart` uses it for thumbnails. `screens/apps/apps_directory_screen.dart` uses it for app icons. `widgets/video_thumbnail_widget.dart` has a debug-mode toggle for `Image.network`. The project's `performance.md` rule states: "Always use the project's `VineCachedImage` wrapper."

**Done well**: 12 files correctly use `VineCachedImage` with caching, placeholders, and retry logic.

**Impact**: Medium. `Image.network` has no disk caching, no placeholder, and no retry logic. The `blurhash_display.dart` fallback is especially impactful since it fires on every failed blurhash decode, potentially re-downloading thumbnails that would otherwise be cached.

**Effort**: Low. Replace each `Image.network` call with `VineCachedImage`. The `blurhash_display.dart` case may need a `VineCachedImage` with an `errorWidget` fallback to avoid infinite retry loops.

**GitHub ticket**: TBD

---

### Screens with missing or incomplete error states
**Problem**: 4 screens using BLoC state do not handle the failure/error branch, silently showing loading or stale content when async operations fail.

**Evidence**: `screens/search_results/widgets/video_search_view.dart` handles loading and success but has no error/failure branch; if the search request fails, the UI stays in the loading state indefinitely. `screens/apps/apps_permissions_screen.dart` treats any non-`loaded` status as loading, lumping error states into the loading spinner. `screens/apps/app_detail_screen.dart` has a `NotFound` state but no general failure state for network errors. `screens/content_filters_screen.dart` performs async content label operations with no visible error feedback.

**Done well**: 54 of 58 screens handle error states correctly with status enums or sealed class branches.

**Impact**: Low. Limited to 4 screens out of 58 using BLoC state builders. However, users on those screens get stuck on a spinner or see stale content when the network is unreliable, with no way to retry.

**Effort**: Low. Add a failure/error branch to each screen's `BlocBuilder` or switch expression. The BLoCs already emit failure states; the UI just doesn't render them.

**GitHub ticket**: TBD
