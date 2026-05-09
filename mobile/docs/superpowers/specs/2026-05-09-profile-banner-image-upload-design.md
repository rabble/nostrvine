# Profile banner image upload

**Date**: 2026-05-09
**Status**: Approved, ready for implementation plan
**Owner**: rabble

## Problem

divine-mobile renders the `banner` field from a Nostr `kind 0` profile metadata
event whenever it is set, including when it was set by another Nostr client.
But divine-mobile itself does not let users **upload** a banner image — the
existing "banner" UI on `profile_setup_screen.dart` is a color picker that
writes a hex string (e.g. `0x33ccbf`) into the same `banner` field.

Result: users see a banner image on their own profile that they originally set
in another Nostr app, and there is no way to change it from divine-mobile.
They have to leave the app to update it.

## Goal

Let a user pick an image from their camera or photo library, upload it to
Blossom, and publish it as their `kind 0` `banner` URL — using the same upload
infrastructure that already handles the avatar.

## Non-goals

- Cropping, aspect-ratio enforcement, filters, or any image editing. Display
  uses `BoxFit.cover` and tolerates arbitrary aspect ratios.
- Tap-to-edit affordance on the user's own profile-page banner. Editing stays
  on `profile_setup_screen.dart` for now (separate discoverability PR later).
- Refactoring the avatar path. Avatar continues to use square `pickImage`
  with `maxWidth/maxHeight` as today.
- Deprecating the divine-mobile-only "hex color in `banner` field" convention.
  Other Nostr clients render those hex strings as broken image URLs — worth a
  separate cleanup, not this PR.
- Changes to `BlossomUploadService`, the funnelcake API, or any server-side
  code. The upload service is reused unchanged.

## Architecture

`ProfileEditorBloc.banner` is already a pass-through `String?` — see
`lib/blocs/profile_editor/profile_editor_bloc.dart:396`:

```dart
final banner = (event.banner?.trim().isEmpty ?? true) ? null : event.banner;
```

So no BLoC, repository, or client change is required. The new code writes a
CDN URL into the same field that the color picker writes a hex string into.

The new banner-image upload is **mutually exclusive** with the existing color
picker. Picking an image clears the selected color; picking a color clears
the uploaded image URL.

The work is contained to `mobile/lib/screens/profile_setup_screen.dart` plus
its test file plus l10n keys.

## Components

### State on `_ProfileSetupScreenState`

```dart
File? _selectedBannerImage;
String? _uploadedBannerUrl;
bool _isUploadingBanner = false;
```

Mirrors the existing `_selectedImage` / `_uploadedImageUrl` / `_isUploadingImage`
fields used by the avatar (~line 134).

### UI

A new banner block above the existing avatar / color picker section:

- **Preview** — 3:1 aspect ratio box (matches the display-side framing on
  the profile page), `BoxFit.cover`. Resolution priority:
  1. `_uploadedBannerUrl` (just uploaded this session)
  2. existing `profile.banner` if URL-shaped (pre-fill from Nostr)
  3. solid `_selectedProfileColor` (existing color path)
  4. neutral placeholder
- **"Upload photo" button** — opens an action sheet (Camera / Gallery)
  matching the avatar's pattern (~line 484, 524).
- **"Clear" button** — only enabled when something is set. Clears whichever
  of `{_selectedBannerImage, _uploadedBannerUrl, _selectedProfileColor}`
  is active.

### Pick + upload flow

`_pickBannerImage(ImageSource source)` mirrors `_pickImageFromMobile`
exactly (~line 1262):

```dart
final image = await _picker.pickImage(
  source: source,
  maxWidth: 2048,
  maxHeight: 2048,
  imageQuality: 85,
  requestFullMetadata: false,
);
```

No cropping. On non-null pick → set `_selectedBannerImage` → immediately
call `_uploadBannerImage()`.

`_uploadBannerImage()` is a near-copy of `_uploadImage()` (~line 1286):

- same `blossomUploadServiceProvider`
- same `authService.currentPublicKeyHex` null-check, same auth-failure
  classification
- same error mapping via `profileSetupUploadErrorMessage`
- same snackbar UX and copy structure (with new banner-specific l10n keys —
  see Localization)
- on success: `setState(() { _uploadedBannerUrl = result.cdnUrl; _selectedProfileColor = null; })`

### Mutual exclusion

Color picker `onChanged` clears `_selectedBannerImage` and
`_uploadedBannerUrl` so the two cannot coexist.

### Save handlers

The two existing save sites (~line 1035 and ~line 1072) construct the
`banner` field. Change to:

```dart
banner: _uploadedBannerUrl ??
    (_selectedProfileColor != null
        ? _hexFromColor(_selectedProfileColor!)
        : null),
```

Use the existing color-encoding helper — do not invent a new one.

### Pre-fill

In the existing block where `_pictureController.text = profile.picture ?? ''`
runs (~line 191), also read `profile.banner`:

- if it parses as `0x......` hex → set `_selectedProfileColor` (existing path)
- else if non-empty → treat as image URL, set `_uploadedBannerUrl`
- else → leave both null

The pre-fill heuristic depends on the exact hex format the existing color
picker writes. Implementation step will grep the encoder to confirm before
writing the parser.

### Refactor (in scope)

The avatar's `_pickImage` / `_pickImageFromMobile` / `_uploadImage` and the
new banner equivalents will share most of their logic. Extract a private
helper in the same file that takes the image source, max dimensions, and
success/failure callbacks, so the two paths cannot drift. Small, contained,
included in the same PR per the no-tech-debt rule
(`rules/agent_workflow.md` §4).

## Data flow

```
User taps "Upload photo"
  → ImagePicker (camera or gallery)
  → File on disk
  → BlossomUploadService.uploadImage
  → CDN URL
  → setState (_uploadedBannerUrl, clear _selectedProfileColor)
  → preview re-renders
User taps "Save"
  → ProfileEditorBloc.add(ProfileEditorEdit(banner: cdnUrl, …))
  → existing publish path emits kind 0
```

## Localization

New ARB keys in `mobile/lib/l10n/app_en.arb`:

- `profileSetupBannerSectionTitle` — section header above the banner block
- `profileSetupBannerUploadButton` — "Upload photo"
- `profileSetupBannerClearButton` — "Clear banner"
- `profileSetupBannerUploadSuccess` — success snackbar
- `profileSetupBannerUploadGenericError` — generic failure copy

Reuse `profileSetupUploadErrorMessage` plumbing for the failure-reason →
copy mapping, with new banner-specific message keys parallel to the existing
avatar ones.

`flutter gen-l10n` from `mobile/`. Commit the regenerated files.

## Testing

Extend `mobile/test/screens/profile_setup_screen_test.dart`:

- Pre-fill: hex-shaped `profile.banner` → color preview rendered, image
  preview hidden.
- Pre-fill: URL-shaped `profile.banner` → image preview rendered, color
  preview hidden.
- Picking an image (mocked picker) clears `_selectedProfileColor` in the
  rendered preview.
- Picking a color clears `_uploadedBannerUrl` in the rendered preview.
- Successful upload (mocked `BlossomUploadService` returns `cdnUrl`)
  results in `ProfileEditorEdit.banner == cdnUrl` on save.
- Color selected on save → `ProfileEditorEdit.banner` is the hex string.
- Mocked upload failure → banner-specific error snackbar shown.

Mocks: `_MockBlossomUploadService`, plus the existing image_picker test
harness pattern this file already uses for the avatar. l10n delegates on
the test `MaterialApp` per `rules/testing.md`.

## Risks

- **Pre-fill heuristic** assumes the existing color picker writes hex with a
  `0x` prefix. If the format differs, pre-fill will mis-route. Mitigation:
  grep the encoder during implementation, write the parser to match exactly,
  add a pre-fill round-trip test.
- **Large images**: `image_picker`'s `maxWidth/maxHeight: 2048` caps decoded
  size. Blossom upload size limits should be unchanged from avatar
  behavior — confirm during implementation.
- **Display drift across surfaces**: any place in the app that renders a
  banner today continues to read `profile.banner` and pass it to an image
  widget. URLs work end-to-end already (they're how non-divine clients
  populate the field). No display-side changes.

## Verification

From `mobile/`:

```
dart format <changed files>
flutter analyze lib test integration_test
flutter test test/screens/profile_setup_screen_test.dart
flutter gen-l10n
flutter test test/l10n/arb_consistency_test.dart
```

Manual:

- Camera path on iOS device.
- Gallery path on iOS device.
- Camera + gallery on Android device.
- Switch from color → image → color and confirm previews and Save payload.
- Verify a pre-existing Nostr-set banner image renders in the preview and
  is preserved on Save when untouched.

## Out of scope follow-ups

- Tap-to-edit affordance on the user's own profile-page banner.
- Deprecate the hex-color-in-`banner` convention.
- Refactor avatar to share a common picker/upload helper with banner if the
  in-scope refactor here ends up not covering the avatar side.
