# App Update Prompt

Nudge users running outdated versions to upgrade, with escalating urgency and one-tap deep-links to the right install source.

## Problem

Users stay on old versions for months (e.g. 1.0.4 build 200 spotted in Discord). They miss fixes, hit bugs we've already solved, and we have no way to tell them a new version exists.

## Design Decisions

| Decision | Choice | Why |
|----------|--------|-----|
| Version source | GitHub Releases API | Already the source of truth, zero maintenance |
| Minimum version | Tag convention in release body, parsed when present | Ready when we need it, zero cost until then |
| Store-native checking | Yes, alongside GitHub | Covers App Store / Play Store users natively |
| Blocking gate | Never | User's app, user's choice. Escalate, don't block. |
| Check frequency | Once per 24 hours on launch | Don't slow startup, don't spam the API |

## Version Source

### GitHub Releases API

On app launch (max once per 24h), fetch the latest release from the GitHub API. The repo owner and name are extracted into named constants (`AppVersionConstants.repoOwner`, `AppVersionConstants.repoName`), not hardcoded in the URL:

```
GET https://api.github.com/repos/{owner}/{repo}/releases/latest
```

Response gives us:

```json
{
  "tag_name": "1.0.8",
  "published_at": "2026-04-02T02:04:42Z",
  "html_url": "https://github.com/divinevideo/divine-mobile/releases/tag/1.0.8",
  "body": "# 1.0.8 — More you, less friction ..."
}
```

- `tag_name` -> latest version
- `published_at` -> release date (drives escalation timing)
- `html_url` -> release notes link
- `body` -> parsed for optional `<!-- minimum_version: X.Y.Z -->` tag

### Minimum Version (Tag Convention)

When we need to set a version floor (e.g. security fix), add an HTML comment to the release body:

```markdown
<!-- minimum_version: 1.0.6 -->
```

The client parses this with a simple regex. If absent, no minimum is enforced. This is invisible to readers on the GitHub releases page.

### Store-Native Checking

For users who installed via App Store or Play Store, also use platform-native update APIs as a secondary signal:

- **iOS**: `SKStoreProductViewController` or App Store lookup API
- **Android**: Google Play In-App Updates API (`com.google.android.play.core`)

Store-native takes priority when available because it enables in-place updates. GitHub API is the fallback for sideloads and Zapstore.

**Conflict resolution**: If the store-native API reports a different latest version than GitHub (e.g. due to App Store review delays or staged rollouts), use the **lower** of the two as the "latest." This avoids nudging users to update to a version that isn't available to them yet on their install source.

### Caching

- Cache the GitHub response in SharedPreferences with a 24h TTL
- On network failure, use cached data (or skip the check silently)
- Never block app startup waiting for the check — fire-and-forget, show nudge when result arrives

## Install Source Detection

Detect once on first launch, cache in SharedPreferences.

| Platform | Source | Detection | Upgrade URL |
|----------|--------|-----------|-------------|
| Android | Play Store | `installerPackageName == "com.android.vending"` | Play Store deep-link |
| Android | Zapstore | `installerPackageName == "com.zapstore.app"` | Zapstore deep-link |
| Android | Sideload | Fallback (any other installer or null) | GitHub releases page |
| iOS | App Store | Not TestFlight (no sandbox receipt) | App Store deep-link |
| iOS | TestFlight | Sandbox receipt environment | TestFlight deep-link |

The install source enum: `playStore`, `appStore`, `testFlight`, `zapstore`, `sideload`.

## Escalation Ladder

All nudges are **always dismissible**. Never blocking. The clock starts from `published_at` of the latest release, not from when the user last opened the app.

### Level 1: Gentle

**Trigger**: New version exists, < 2 weeks since `published_at`.

**UX**: Small dismissible banner at the bottom of the home feed.

**Copy**: "A fresh update just dropped. Check it out ->"

**Repeat**: Once per new version. If dismissed, gone until next release.

### Level 2: Moderate

**Trigger**: New version exists, >= 2 weeks since `published_at`.

**UX**: Dialog on app launch with a brief summary of what's new.

**Copy**: "There's been an update since you last checked -- new stuff's waiting for you." + first 2-3 bullet points from release notes.

**Repeat**: Every 3 days after dismissal. When a NEW version is released while the user is in the moderate tier for an older version, the cooldown resets and the nudge reappears immediately for the new version.

### Level 3: Urgent

**Trigger**: User's version is below `minimum_version` (when set in release body).

**UX**: Dialog on every app launch. Stronger copy, still dismissible.

**Copy**: "You're missing important fixes. Update to keep things running smooth."

**Repeat**: Every launch. Always dismissible.

### Dismissal Tracking

Store in SharedPreferences:
- `update_dismissed_version`: version string of last dismissed nudge
- `update_dismissed_at`: timestamp of last dismissal
- `update_last_checked`: timestamp of last GitHub API fetch

## Architecture

Standard layered pattern:

```
UI (banner / dialog) -> AppUpdateBloc -> AppUpdateRepository -> AppVersionClient
```

### AppVersionClient (Data Layer)

- Fetches GitHub Releases API (with 24h cache)
- Parses `tag_name`, `published_at`, `body` (for minimum_version tag)
- Returns raw `AppVersionInfo` model
- Lives in a new package: `packages/app_version_client/`

### AppUpdateRepository (Repository Layer)

- Compares current app version (from `package_info_plus`) against latest
- Detects install source via platform channels
- Determines escalation level based on `published_at` age and `minimum_version`
- Resolves the correct download URL for the detected install source
- Lives in a new package: `packages/app_update_repository/`

### AppUpdateBloc (Business Logic Layer)

- State has two axes: `AppUpdateStatus` (initial/checking/resolved/error) and `UpdateUrgency` (none/gentle/moderate/urgent)
- Events: `CheckForUpdate`, `DismissUpdate`
- Handles dismissal by persisting to SharedPreferences and re-emitting with `urgency: none`
- Checks dismissal cooldowns (once per version for gentle, 3-day cooldown for moderate)
- Provided inside the authenticated shell (below the auth gate). Triggered by a `BlocListener` on the auth BLoC that dispatches `CheckForUpdate` when the user is authenticated.
- Lives in: `lib/app_update/bloc/`

### UI (Presentation Layer)

- **Banner widget**: Slim bar at bottom of home feed, tappable, dismiss with X
- **Dialog widget**: Centered dialog with release highlights, "Update" and "Not now" buttons
- Both use `VineTheme` and follow dark-mode-only constraint
- "Update" button calls `launchUrl()` with the resolved download URL
- Lives in: `lib/app_update/view/`

## Data Flow

```
App Launch
  -> AppUpdateBloc receives CheckForUpdate event
  -> Repository fetches version info (cached if < 24h)
  -> Repository compares versions, checks install source
  -> Repository returns UpdateStatus (none / gentle / moderate / urgent)
  -> Bloc checks dismissal state from SharedPreferences
  -> Bloc emits final state to UI
  -> UI shows banner, dialog, or nothing
```

## Models

```dart
/// Raw response from GitHub Releases API
class AppVersionInfo extends Equatable {
  final String latestVersion;
  final DateTime publishedAt;
  final String releaseNotesUrl;
  final String? minimumVersion;  // parsed from <!-- minimum_version: X.Y.Z -->
  final List<String> releaseHighlights; // parsed section headers from body (e.g. "Resumable uploads", "Double-tap to like")
}

/// Install source enum
enum InstallSource { playStore, appStore, testFlight, zapstore, sideload }

/// Escalation level
enum UpdateUrgency { none, gentle, moderate, urgent }

/// BLoC lifecycle status
enum AppUpdateStatus { initial, checking, resolved, error }

/// Final state exposed to UI
class AppUpdateState extends Equatable {
  final AppUpdateStatus status;
  final UpdateUrgency urgency;
  final String? latestVersion;
  final String? downloadUrl;
  final List<String> releaseHighlights;
}
```

**Release highlights parsing**: The client extracts bold list items (`**text**`) from the release body's top-level bullet points. These are short feature names already written in brand voice (e.g. "Resumable uploads", "Double-tap to like"). No Markdown truncation needed — we pick discrete items, not a raw substring.

**Dismissal handling**: When the BLoC processes a `DismissUpdate` event, it persists the dismissal to SharedPreferences and re-emits state with `urgency: UpdateUrgency.none`. No `dismissed` boolean in state — the BLoC resolves dismissal internally before emitting.

## Edge Cases

- **No network on launch**: Skip silently. Check again next launch.
- **GitHub API rate limit** (60 req/hr unauthenticated): 24h cache makes this a non-issue for normal use.
- **User on latest version**: Bloc emits `none`, UI shows nothing.
- **Pre-release / draft releases**: GitHub `/releases/latest` ignores these by default.
- **Version parsing**: Compare using semantic versioning (major.minor.patch). Build number is secondary.
- **First install**: Don't show any nudge on first launch — detected by absence of `update_last_checked` key in SharedPreferences (set after the first successful check).

## Testing Strategy

- **AppVersionClient**:
  - Parse valid GitHub response with all fields
  - Parse response with `<!-- minimum_version: X.Y.Z -->` present and absent
  - Handle malformed JSON, network errors, non-200 status codes
  - Cache TTL: return cached data within 24h, re-fetch after
  - Extract release highlights from varied Markdown body formats
- **AppUpdateRepository**:
  - Version comparison: same version, newer available, user ahead (pre-release build), malformed version strings
  - Escalation: < 2 weeks = gentle, >= 2 weeks = moderate, below minimum = urgent
  - Install source detection per platform (mock platform channels)
  - Download URL resolution for each install source
  - Store-native vs GitHub conflict resolution (lower version wins)
- **AppUpdateBloc**:
  - blocTest for each escalation level emission
  - Dismissal: gentle dismissed = urgency none until next version
  - Dismissal: moderate dismissed = urgency none, reappears after 3 days
  - Dismissal: new version released resets cooldown
  - First install: no nudge when `update_last_checked` absent
  - Error state on fetch failure with no cache
- **UI**:
  - Banner renders for gentle state, hidden for none
  - Dialog renders for moderate and urgent states
  - Dismiss button emits DismissUpdate event
  - Update button calls launchUrl with correct download URL
  - No UI rendered for initial/checking/error states

All copy strings extracted to l10n-ready constants (English only for v1, structured for future localization).

## Out of Scope (v1)

- Showing full changelog in-app (just link to GitHub release page)
- Auto-downloading APKs for sideload users
- Push notifications about updates
- A/B testing nudge copy
- Analytics on update conversion rates (good for v2)
- Localization of nudge copy (structured for it, English only for now)
