# Profile banner image upload — implementation plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users upload a profile banner image from camera or gallery on the profile setup screen, alongside the existing color picker.

**Architecture:** Pure UI work in `mobile/lib/screens/profile_setup_screen.dart`. `ProfileEditorBloc.banner` is already a pass-through `String?`, so the new code just writes a Blossom CDN URL into the same field that the color picker writes a hex string into. Mutually exclusive: image clears color, color clears image. Reuses the existing `BlossomUploadService`, `ImagePicker`, `profileBackgroundColor` parser, and snackbar plumbing.

**Tech Stack:** Flutter, `flutter_bloc`, `flutter_riverpod`, `image_picker`, `blossom_upload_service` (existing), `BlossomUploadFailureReason` mapping (existing).

**Spec:** `mobile/docs/superpowers/specs/2026-05-09-profile-banner-image-upload-design.md`

---

## Context the implementer needs (read first)

- Repo workflow: `.claude/rules/agent_workflow.md`. Worktree is already created at `/Users/rabble/code/divine/divine-mobile/.worktrees/profile-banner-upload`, branch `feat/profile-banner-image-upload`. Work there. Do not branch a new worktree.
- All Flutter commands run from `mobile/` inside that worktree.
- Self-review checklist: `.claude/rules/self_review_checklist.md`.
- Style + patterns to mirror:
  - **Avatar upload (the model)**: `mobile/lib/screens/profile_setup_screen.dart` lines 1098–1370. Pick → upload → set URL field, snackbar UX, error mapping via `profileSetupUploadErrorMessage`.
  - **Color picker**: same file, around line 944, with `_selectedProfileColor` state at line 135 and pre-fill at line 192.
  - **Banner field write sites**: same file, ~line 1035–1037 and ~line 1072–1074. Hex format: `'0x${color.toARGB32().toRadixString(16).substring(2)}'`.
  - **Banner field read / parse**: `mobile/lib/utils/user_profile_utils.dart:24` `profileBackgroundColor` getter — already accepts `0x......`, `#......`, or returns `null` for URLs. Reuse it; do not write a new parser.
- l10n: `.claude/rules/localization.md`. ARB source of truth is `mobile/lib/l10n/app_en.arb`. Run `flutter gen-l10n` after editing it. ARB consistency test in `mobile/test/l10n/arb_consistency_test.dart` requires either translating to all locales or allowlisting.
- BLoC `ProfileEditorBloc`: `mobile/lib/blocs/profile_editor/profile_editor_bloc.dart:396`. Already accepts `banner` as `String?` and trims/nulls empty strings. No BLoC change.
- Test patterns: `.claude/rules/testing.md`. Private mocks per file. Always assert. l10n delegates on the test `MaterialApp`.

## File map

| File | Change |
|---|---|
| `mobile/lib/l10n/app_en.arb` | **Modify** — add 4 keys (button labels + success/generic-failure copy) |
| `mobile/lib/l10n/app_*.arb` (other locales) | **Modify or allowlist** — per ARB consistency test |
| `mobile/lib/l10n/generated/*` | **Modify** (auto-generated) — `flutter gen-l10n` output |
| `mobile/lib/screens/profile_setup_screen.dart` | **Modify** — add banner state + UI + pick/upload + save/pre-fill wiring + extracted shared helper |
| `mobile/lib/screens/profile_setup_screen_upload_helpers.dart` | **Create** — extracted private helpers for picker + upload, shared by avatar and banner. Same-file `part of` is overkill; extract a small library file with a typedef'd callback. (Implementer may inline back into `profile_setup_screen.dart` if the diff stays short — judgment call after refactor; default to extraction.) |
| `mobile/test/screens/profile_setup_screen_test.dart` | **Create** — widget tests for the banner block |

## Verification commands (run from `mobile/`)

- `flutter pub get` (if pubspec changes — none planned here, but if you add/remove imports nothing changes)
- `flutter gen-l10n`
- `dart format <changed files>`
- `flutter analyze lib test integration_test`
- `flutter test test/screens/profile_setup_screen_test.dart`
- `flutter test test/l10n/arb_consistency_test.dart`

---

## Chunk 1: ARB keys + l10n regeneration

### Task 1: Add new ARB keys for the banner upload UI

**Files:**
- Modify: `mobile/lib/l10n/app_en.arb`
- Modify (regenerate): `mobile/lib/l10n/generated/*.dart`

- [ ] **Step 1: Inspect the existing avatar-upload ARB keys to mirror their style**

Run from `mobile/`:
```bash
grep -nE 'profileSetupUpload|profileSetupAvatar|profileSetupPicture' lib/l10n/app_en.arb
```

You'll see the existing avatar keys (e.g. `profileSetupUploadSuccess`, `profileSetupGotItButton`, the failure-reason variants used by `profileSetupUploadErrorMessage`). New banner keys mirror the avatar tone exactly.

- [ ] **Step 2: Add the 4 new keys to `app_en.arb`**

Insert these entries near the existing `profileSetupUpload*` keys, in the same alphabetical neighborhood. Each value must follow the brand voice — short, plain, no exclamation marks, no emoji.

```json
"profileSetupBannerSectionTitle": "Banner",
"@profileSetupBannerSectionTitle": {
  "description": "Section header above the profile banner editing block on the profile setup screen."
},

"profileSetupBannerUploadButton": "Upload photo",
"@profileSetupBannerUploadButton": {
  "description": "Button that opens the camera/gallery picker for the profile banner image."
},

"profileSetupBannerClearButton": "Clear banner",
"@profileSetupBannerClearButton": {
  "description": "Button that clears whatever banner (image or color) the user has selected."
},

"profileSetupBannerUploadSuccess": "Banner updated",
"@profileSetupBannerUploadSuccess": {
  "description": "Snackbar shown after the banner image upload succeeds."
}
```

We deliberately do **not** add a new generic-failure key. The avatar's `profileSetupUploadErrorMessage(l10n, reason)` mapping is reused as-is — its copy is generic enough ("Upload failed", auth-failure variant, etc.) that it works for the banner too. Implementer: if you find the avatar's failure copy reads as obviously avatar-specific (e.g. mentions "profile picture"), add banner-specific failure keys mirroring the avatar set; otherwise reuse.

- [ ] **Step 3: Regenerate l10n**

Run from `mobile/`:
```bash
flutter gen-l10n
```

Expected: regenerates files under `mobile/lib/l10n/generated/`. No errors.

- [ ] **Step 4: Handle the ARB consistency test**

Run:
```bash
flutter test test/l10n/arb_consistency_test.dart
```

If the test fails because the new keys are missing in non-English ARB files, do one of the two things `.claude/rules/localization.md` allows:

  - **Translate**: add the keys to every `app_*.arb` file. Acceptable when the copy is short and translation is obvious.
  - **Allowlist**: add the keys to the allowlist in `mobile/test/l10n/arb_consistency_test.dart`. Acceptable as a deliberate "translate-later" gate.

For this PR, prefer the translate path for the four keys — they're trivial — unless `arb_consistency_test.dart` already documents an allowlist mechanism the rest of the repo uses for new English keys. Check the test file first; mirror what other recent PRs do.

- [ ] **Step 5: Re-run ARB consistency test, expect green**

```bash
flutter test test/l10n/arb_consistency_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/l10n/app_*.arb mobile/lib/l10n/generated test/l10n/arb_consistency_test.dart
git commit -m "$(cat <<'EOF'
feat(l10n): add profile banner upload strings

Adds the four ARB keys the new banner image upload UI on
profile_setup_screen will use. Mirrors the avatar upload key style.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Chunk 2: Widget tests scaffold (TDD red)

This chunk writes the failing tests before any production code. The next chunk turns them green.

### Task 2: Discover & set up test infrastructure for profile_setup_screen

**Files:**
- Create: `mobile/test/screens/profile_setup_screen_test.dart`

- [ ] **Step 1: Find an existing widget test that pumps a similar screen to model the harness on**

Run from `mobile/`:
```bash
grep -rln 'BlossomUploadService\|blossomUploadServiceProvider' test --include='*.dart' | head
grep -rln 'ProfileEditorBloc\|profileEditorBloc' test --include='*.dart' | head
```

Pick one with a similar shape (Riverpod overrides + BLoC mocking + l10n delegates) as your harness reference.

- [ ] **Step 2: Create the test file with the harness skeleton**

```dart
// mobile/test/screens/profile_setup_screen_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/profile_setup_screen.dart';
// Import the screen's view widget if it's exported separately;
// otherwise import what is exported. The implementer should adjust
// to whatever the file exposes.

class _MockBlossomUploadService extends Mock
    implements BlossomUploadService {}

class _MockProfileEditorBloc
    extends MockBloc<ProfileEditorEvent, ProfileEditorState>
    implements ProfileEditorBloc {}

// MyProfileBloc mock — needed to drive the pre-fill BlocListener.
// Mirror the existing pattern used by other profile_setup tests in
// neighbouring files; the exact import depends on what the screen
// reads via BlocListener.

void main() {
  group(ProfileSetupScreen, () {
    late _MockBlossomUploadService mockUploadService;
    late _MockProfileEditorBloc mockEditorBloc;

    setUp(() {
      mockUploadService = _MockBlossomUploadService();
      mockEditorBloc = _MockProfileEditorBloc();
      when(() => mockEditorBloc.state).thenReturn(
        const ProfileEditorState(),
      );
    });

    Future<void> pumpScreen(
      WidgetTester tester, {
      required ProviderContainer container,
    }) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider<ProfileEditorBloc>.value(
              value: mockEditorBloc,
              // Wrap with whatever other BlocProviders the screen
              // requires (MyProfileBloc, etc.). Look at the screen's
              // imports / context.read calls to enumerate them.
              child: const ProfileSetupScreen(),
            ),
          ),
        ),
      );
    }
  });
}
```

Implementer note: this skeleton is approximate. The exact imports + Bloc + Riverpod overrides depend on what `ProfileSetupScreen` reads. **Read the screen's `build()`, `initState()`, and `BlocListener` consumers** and mirror them. Do not guess.

- [ ] **Step 3: Run the empty file to confirm it compiles**

```bash
flutter test test/screens/profile_setup_screen_test.dart
```

Expected: 0 tests run, no compile errors.

- [ ] **Step 4: Commit**

```bash
git add test/screens/profile_setup_screen_test.dart
git commit -m "$(cat <<'EOF'
test(profile-setup): scaffold widget test harness

Sets up the Riverpod / Bloc / l10n harness for the upcoming banner
upload tests. No tests yet.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 3: Write the failing widget tests for the banner block

**Files:**
- Modify: `mobile/test/screens/profile_setup_screen_test.dart`

- [ ] **Step 1: Add a test for the pre-fill: hex banner shows color preview**

Inside `group(ProfileSetupScreen, () { ... })`:

```dart
group('banner pre-fill', () {
  testWidgets(
    'hex banner from MyProfileBloc renders color preview',
    (tester) async {
      // Arrange: drive MyProfileBloc to emit a profile whose `banner`
      // is "0x33ccbf". Use the bloc's MockBloc helpers (whenListen)
      // to control its emitted states.

      // Act: pumpScreen.

      // Assert: the banner color preview widget renders
      // (find by the public Key the implementation will expose, e.g.
      // ValueKey('profile_banner_color_preview')) and the image
      // preview is absent.
      expect(
        find.byKey(const ValueKey('profile_banner_color_preview')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('profile_banner_image_preview')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'URL banner from MyProfileBloc renders image preview',
    (tester) async {
      // Arrange: drive MyProfileBloc to emit a profile whose `banner`
      // is "https://cdn.example.com/banner.jpg".

      // Act + assert: image preview present, color preview absent.
      expect(
        find.byKey(const ValueKey('profile_banner_image_preview')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('profile_banner_color_preview')),
        findsNothing,
      );
    },
  );
});
```

- [ ] **Step 2: Add a test for save with image-uploaded banner**

```dart
group('banner save', () {
  testWidgets(
    'save dispatches ProfileEditorEdit.banner == uploaded URL when '
    'image was uploaded',
    (tester) async {
      // Arrange: pre-fill with no existing banner. Stub
      // BlossomUploadService.uploadImage to return success with
      // cdnUrl: "https://cdn.example.com/uploaded.jpg".
      // Use a fake image picker injection (see Task 5 for the
      // shared helper interface) — the file does not need to be
      // a real File on disk if the picker is mocked; otherwise
      // create a temp File via TestPath / Directory.systemTemp.

      // Act: tap the upload button -> pick gallery -> wait for upload
      // -> tap Save (or whatever triggers the SaveProfileRequested
      // event today; see lines ~1035 and ~1072).

      // Assert: verify the bloc received a ProfileEditorEdit (or
      // whatever the actual event class is — read it from
      // profile_editor_event.dart) with banner == cdnUrl.
      final captured = verify(
        () => mockEditorBloc.add(captureAny(that: isA<ProfileEditorEdit>())),
      ).captured;
      expect(captured, isNotEmpty);
      final event = captured.last as ProfileEditorEdit;
      expect(event.banner, equals('https://cdn.example.com/uploaded.jpg'));
    },
  );

  testWidgets(
    'save dispatches hex banner when color is selected',
    (tester) async {
      // Arrange + act: tap a color in the picker, then tap Save.
      // Assert: banner == "0xRRGGBB" matching the existing color
      // encoding. Pick a known color so the hex is predictable.
    },
  );
});
```

- [ ] **Step 3: Add tests for mutual exclusion**

```dart
group('banner mutual exclusion', () {
  testWidgets(
    'picking an image clears the selected color',
    (tester) async {
      // Arrange: pre-select a color (drive MyProfileBloc with hex
      // banner). Stub upload to succeed.
      // Act: pick image.
      // Assert: color preview disappears, image preview appears.
    },
  );

  testWidgets(
    'picking a color clears the uploaded image URL',
    (tester) async {
      // Arrange: pre-fill with URL banner.
      // Act: tap a color.
      // Assert: image preview disappears, color preview appears.
    },
  );
});
```

- [ ] **Step 4: Add a test for upload failure showing the snackbar**

```dart
group('banner upload errors', () {
  testWidgets(
    'shows banner-specific error snackbar when upload fails',
    (tester) async {
      // Arrange: stub BlossomUploadService.uploadImage to return
      // failure with a non-auth reason.
      // Act: pick image.
      // Assert: the error snackbar text equals the resolved l10n
      // string for `profileSetupUploadErrorMessage(l10n, reason)`
      // (or the banner-specific key if you added one in Task 1).
      // Resolve from a real BuildContext or via lookupAppLocalizations
      // per .claude/rules/localization.md.
    },
  );
});
```

- [ ] **Step 5: Run the file, expect failures**

```bash
flutter test test/screens/profile_setup_screen_test.dart
```

Expected: tests fail with "Found 0 widgets with key …" or similar — banner UI doesn't exist yet. Good.

- [ ] **Step 6: Commit**

```bash
git add test/screens/profile_setup_screen_test.dart
git commit -m "$(cat <<'EOF'
test(profile-setup): failing tests for banner upload

Asserts pre-fill, mutual exclusion with the color picker, save
payload, and upload-failure snackbar. Production code still missing
— tests are red on purpose (TDD).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Chunk 3: Production code — make the tests pass

### Task 4: Add banner state fields and pre-fill wiring

**Files:**
- Modify: `mobile/lib/screens/profile_setup_screen.dart`

- [ ] **Step 1: Add the three new state fields next to the existing avatar fields**

Around line 132–135, replace:

```dart
bool _isUploadingImage = false;
File? _selectedImage;
String? _uploadedImageUrl;
Color? _selectedProfileColor;
```

With:

```dart
bool _isUploadingImage = false;
File? _selectedImage;
String? _uploadedImageUrl;
Color? _selectedProfileColor;

bool _isUploadingBanner = false;
File? _selectedBannerImage;
String? _uploadedBannerUrl;
```

- [ ] **Step 2: Update the pre-fill block to populate `_uploadedBannerUrl` for URL banners**

In the `BlocListener<MyProfileBloc, MyProfileState>` listener around line 188–200, after the existing color pre-fill, add:

```dart
final bannerString = profile.banner;
if (profile.profileBackgroundColor == null &&
    bannerString != null &&
    bannerString.trim().isNotEmpty) {
  _uploadedBannerUrl = bannerString;
} else {
  _uploadedBannerUrl = null;
}
```

This is inside the existing `setState(() { ... })` block. Reuses `profileBackgroundColor` from `mobile/lib/utils/user_profile_utils.dart` — which is already imported (the existing line 192 calls it).

- [ ] **Step 3: Run the pre-fill tests**

```bash
flutter test test/screens/profile_setup_screen_test.dart -P --plain-name 'banner pre-fill'
```

Pre-fill tests should now pass (image preview test will still fail because the UI doesn't exist yet — that's fine for now, save it for Task 6).

Note: if the project's `flutter test` doesn't accept `-P --plain-name`, just run the whole file and grep the output for the pre-fill cases.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/profile_setup_screen.dart
git commit -m "$(cat <<'EOF'
feat(profile-setup): add banner upload state + pre-fill

Reads existing profile.banner: hex routes to the color picker (as
today), URL routes to the new uploaded-image preview state.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 5: Extract the shared pick-and-upload helper

The avatar's `_pickImage` → `_pickImageFromMobile` → `_uploadImage` (lines ~1098–1370) is about to have a near-duplicate for the banner. Extract a private helper now so the two paths can't drift.

**Files:**
- Create: `mobile/lib/screens/profile_setup_screen_upload_helpers.dart`
- Modify: `mobile/lib/screens/profile_setup_screen.dart` — refactor avatar to use it

- [ ] **Step 1: Create the helpers file**

```dart
// mobile/lib/screens/profile_setup_screen_upload_helpers.dart
//
// Shared pick + upload helpers used by both the avatar and the
// banner image flows on ProfileSetupScreen. Kept private to that
// screen — exported names start with $ProfileSetup to discourage
// reuse elsewhere; if you need this for another screen, generalise
// it into a proper widget instead of a free function.

import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:image_picker/image_picker.dart';

/// Result of a single pick+upload attempt.
sealed class ProfileImageUploadOutcome {
  const ProfileImageUploadOutcome();
}

class ProfileImageUploadCancelled extends ProfileImageUploadOutcome {
  const ProfileImageUploadCancelled();
}

class ProfileImageUploadSuccess extends ProfileImageUploadOutcome {
  const ProfileImageUploadSuccess(this.cdnUrl);
  final String cdnUrl;
}

class ProfileImageUploadFailure extends ProfileImageUploadOutcome {
  const ProfileImageUploadFailure({
    required this.reason,
    this.statusCode,
    this.errorMessage,
  });
  final BlossomUploadFailureReason? reason;
  final int? statusCode;
  final String? errorMessage;
}

/// Picks an image via [picker] from [source] (mobile path) and
/// uploads it via [uploadService] for [nostrPubkey]. Returns
/// [ProfileImageUploadCancelled] if the user backed out of the
/// picker.
///
/// Throws no exceptions itself. Any thrown exception from the
/// upload pipeline is caught and returned as a
/// [ProfileImageUploadFailure] with `reason: null` so the caller
/// surfaces the generic copy.
Future<ProfileImageUploadOutcome> pickAndUploadProfileImage({
  required ImagePicker picker,
  required ImageSource source,
  required BlossomUploadService uploadService,
  required String nostrPubkey,
  int maxWidth = 2048,
  int maxHeight = 2048,
  int imageQuality = 85,
}) async {
  // ... implementation: call picker.pickImage, build File, call
  // uploadService.uploadImage. Mirror the existing _uploadImage's
  // semantics from profile_setup_screen.dart lines 1286–1369.
}
```

Implementer: write the full implementation by literally moving the body of the existing `_pickImageFromMobile` + `_uploadImage` into this function, parameterising the `maxWidth`/`maxHeight` differences (avatar = 1024, banner = 2048) and dropping the `setState` calls (which stay at the call site).

- [ ] **Step 2: Refactor the avatar `_uploadImage` / `_pickImageFromMobile` to call the helper**

In `profile_setup_screen.dart`, replace the avatar's pick+upload internals so they now call `pickAndUploadProfileImage(...)` and handle the returned outcome with `setState` + snackbar logic. Keep `_pickImage(ImageSource)` as the external entry point (UI tap target) but have its body delegate.

Avatar-specific behavior to preserve at the call site:
- `_isUploadingImage = true / false`
- success: `_uploadedImageUrl = cdn`, `_pictureController.text = cdn`, `FocusScope.of(context).unfocus()`, success snackbar via `profileSetupUploadSuccess`
- failure: `_showUploadFailureSnackBar(l10n, reason)`

- [ ] **Step 3: Run the existing avatar code path manually-via-tests**

```bash
flutter test test/screens/profile_setup_screen_test.dart
```

Pre-fill tests still pass. The new banner tests still fail. The avatar refactor must not break any other test that touches this screen — find them:

```bash
flutter test --plain-name ProfileSetup
```

Anything that was passing before still passes.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/profile_setup_screen_upload_helpers.dart \
        lib/screens/profile_setup_screen.dart
git commit -m "$(cat <<'EOF'
refactor(profile-setup): extract shared pick+upload helper

Moves the picker + Blossom upload logic out of the avatar's
_pickImageFromMobile / _uploadImage into a free function so the
upcoming banner flow shares the same code path and they can't drift.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 6: Add the banner UI block + pick/upload + mutual exclusion

**Files:**
- Modify: `mobile/lib/screens/profile_setup_screen.dart`

- [ ] **Step 1: Add the banner UI block above the existing avatar/color section**

Find the section header for the avatar / color picker block. Insert the banner block immediately above it. Use a small private widget per `.claude/rules/code_style.md` (no methods returning `Widget`):

```dart
class _BannerEditingBlock extends StatelessWidget {
  const _BannerEditingBlock({
    required this.uploadedBannerUrl,
    required this.profileBannerUrl,
    required this.selectedColor,
    required this.isUploading,
    required this.onUploadFromGallery,
    required this.onUploadFromCamera,
    required this.onClear,
  });

  final String? uploadedBannerUrl;
  final String? profileBannerUrl; // pre-fill from Nostr if URL-shaped
  final Color? selectedColor;
  final bool isUploading;
  final VoidCallback onUploadFromGallery;
  final VoidCallback onUploadFromCamera;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final effectiveImageUrl = uploadedBannerUrl ?? profileBannerUrl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text(
          l10n.profileSetupBannerSectionTitle,
          style: VineTheme.titleMediumFont(),
        ),
        AspectRatio(
          aspectRatio: 3 / 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _BannerPreview(
              imageUrl: effectiveImageUrl,
              color: selectedColor,
            ),
          ),
        ),
        Row(
          children: [
            FilledButton(
              onPressed: isUploading ? null : onUploadFromGallery,
              child: Text(l10n.profileSetupBannerUploadButton),
            ),
            const SizedBox(width: 8),
            // Camera entry point — match how the avatar exposes both
            // (action sheet vs separate buttons). Inspect the avatar
            // block (~lines 484, 524) and mirror that interaction.
            TextButton(
              onPressed:
                  (effectiveImageUrl == null && selectedColor == null)
                      ? null
                      : onClear,
              child: Text(l10n.profileSetupBannerClearButton),
            ),
          ],
        ),
      ],
    );
  }
}

class _BannerPreview extends StatelessWidget {
  const _BannerPreview({this.imageUrl, this.color});

  final String? imageUrl;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null) {
      return VineCachedImage(
        key: const ValueKey('profile_banner_image_preview'),
        imageUrl: imageUrl!,
        fit: BoxFit.cover,
        // semanticLabel: l10n.profileSetupBannerSectionTitle ←
        // resolve at this layer so the screen-reader users get a
        // meaningful announcement; see .claude/rules/accessibility.md
      );
    }
    if (color != null) {
      return ColoredBox(
        key: const ValueKey('profile_banner_color_preview'),
        color: color!,
      );
    }
    return ColoredBox(
      key: const ValueKey('profile_banner_empty_preview'),
      color: VineTheme.cardBackground,
    );
  }
}
```

Notes:
- Use `VineCachedImage` rather than `Image.network` (`.claude/rules/ui_theming.md`).
- Use `VineTheme` colors and font helpers — no raw `TextStyle`, no raw `Colors.*`.
- The `ValueKey`s on the previews are the test hooks the failing tests in Task 3 look for.
- The "Upload photo" UX may need to mirror the avatar's action-sheet (camera vs gallery) — pick whichever pattern the avatar uses today and copy it. Don't invent a new bottom sheet.

- [ ] **Step 2: Wire the banner block into the screen's build tree**

Insert `_BannerEditingBlock` in the Column where the avatar/color section lives, above that section. Pass the new state and callbacks:

```dart
_BannerEditingBlock(
  uploadedBannerUrl: _uploadedBannerUrl,
  profileBannerUrl: null,
  // Note: pre-fill already routes URL-banners into _uploadedBannerUrl
  // in Task 4, so profileBannerUrl is always null here. Kept as a
  // parameter for clarity; remove if it stays dead.
  selectedColor: _selectedProfileColor,
  isUploading: _isUploadingBanner,
  onUploadFromGallery: () => _pickBannerImage(ImageSource.gallery),
  onUploadFromCamera: () => _pickBannerImage(ImageSource.camera),
  onClear: _clearBanner,
),
```

- [ ] **Step 3: Implement `_pickBannerImage` and `_clearBanner`**

```dart
Future<void> _pickBannerImage(ImageSource source) async {
  if (_isUploadingBanner) return;

  final l10n = context.l10n;
  final authService = ref.read(authServiceProvider);
  final pubkey = authService.currentPublicKeyHex;
  if (pubkey == null) {
    _showUploadFailureSnackBar(l10n, BlossomUploadFailureReason.auth);
    return;
  }

  setState(() => _isUploadingBanner = true);
  try {
    final outcome = await pickAndUploadProfileImage(
      picker: _picker,
      source: source,
      uploadService: ref.read(blossomUploadServiceProvider),
      nostrPubkey: pubkey,
    );
    if (!mounted) return;

    switch (outcome) {
      case ProfileImageUploadCancelled():
        // Nothing — user backed out of the picker.
      case ProfileImageUploadSuccess(:final cdnUrl):
        setState(() {
          _uploadedBannerUrl = cdnUrl;
          _selectedBannerImage = null;
          _selectedProfileColor = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.profileSetupBannerUploadSuccess),
            backgroundColor: VineTheme.success,
          ),
        );
      case ProfileImageUploadFailure(:final reason):
        _showUploadFailureSnackBar(l10n, reason);
    }
  } finally {
    if (mounted) {
      setState(() => _isUploadingBanner = false);
    }
  }
}

void _clearBanner() {
  setState(() {
    _uploadedBannerUrl = null;
    _selectedBannerImage = null;
    _selectedProfileColor = null;
  });
}
```

- [ ] **Step 4: Update the color-picker `onChanged` to clear the image side**

Around line 947 the existing color picker calls `setState(() { _selectedProfileColor = color; })`. Extend it:

```dart
setState(() {
  _selectedProfileColor = color;
  _uploadedBannerUrl = null;
  _selectedBannerImage = null;
});
```

This enforces mutual exclusion in the other direction.

- [ ] **Step 5: Update the two save sites to prefer the uploaded URL**

Around lines 1035–1037 and 1072–1074, replace:

```dart
banner: _selectedProfileColor != null
    ? '0x${_selectedProfileColor!.toARGB32().toRadixString(16).substring(2)}'
    : null,
```

with:

```dart
banner: _uploadedBannerUrl ??
    (_selectedProfileColor != null
        ? '0x${_selectedProfileColor!.toARGB32().toRadixString(16).substring(2)}'
        : null),
```

Apply this **at both call sites**. They are not refactored into a single helper here because the surrounding `ProfileEditorEdit(...)` (or whatever the event is named) is constructed differently at each — keep them in sync via the spec/test, not via further refactoring in this PR.

- [ ] **Step 6: Run the full test file, expect all green**

```bash
flutter test test/screens/profile_setup_screen_test.dart
```

Expected: every banner test from Task 3 now PASS.

- [ ] **Step 7: Run analyze + scoped tests**

```bash
flutter analyze lib test integration_test
flutter test test/screens/profile_setup_screen_test.dart
```

Expected: no analyzer warnings introduced; all banner tests green.

- [ ] **Step 8: Commit**

```bash
git add lib/screens/profile_setup_screen.dart
git commit -m "$(cat <<'EOF'
feat(profile-setup): banner image upload UI

Adds a 3:1 banner preview block above the avatar/color section with
camera+gallery upload via Blossom. Mutually exclusive with the
existing color picker — picking one clears the other. Save writes
the CDN URL into the same `banner` field on the kind 0 profile
event.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Chunk 4: Verification + PR

### Task 7: Full local verification

- [ ] **Step 1: Format**

```bash
dart format lib test
```

Expected: no changes (you formatted as you went).

- [ ] **Step 2: Analyze**

```bash
flutter analyze lib test integration_test
```

Expected: zero issues. If new analyzer warnings appear, fix them — do not silence with `// ignore:` per `.claude/rules/agent_workflow.md` §4.

- [ ] **Step 3: Run the affected test surface**

```bash
flutter test test/screens/profile_setup_screen_test.dart
flutter test test/l10n/arb_consistency_test.dart
flutter test --plain-name ProfileEditor
flutter test --plain-name ProfileSetup
```

Expected: all green. If any unrelated `ProfileSetup`/`ProfileEditor` test fails, **assume your change caused it** — re-read `.claude/rules/agent_workflow.md` §5 and trace the cause. Do not skip, do not blame flakiness.

- [ ] **Step 4: Confirm pre-commit hooks installed**

```bash
ls .git/hooks/pre-commit .git/hooks/pre-push 2>/dev/null || \
  (cd mobile && mise run setup_hooks)
```

If they were missing, install them, then run `git commit --amend --no-edit` is **not** what you want — instead just continue, the next commit will exercise them.

- [ ] **Step 5: Self-review against the checklist**

Open `.claude/rules/self_review_checklist.md` and walk through:

- "Before committing" section: format, analyze, scoped tests all green; no `print` / `developer.log` / TODO; no commented-out code from the refactor; commit messages explain the why.
- "While implementing" sections: no `Color(0x...)` literals in new code; no inline `TextStyle(...)`; banner preview uses `VineCachedImage` not `Image.network`; mutual-exclusion `setState` calls are correct; `context.mounted` guarded after every `await` in the new async paths.
- Accessibility: banner preview image has a `semanticLabel`; upload button has a tooltip or text label sufficient for screen readers; clear button has accessible labelling.

Fix anything that fails the walkthrough.

### Task 8: Rebase + open PR

- [ ] **Step 1: Rebase onto fresh `origin/main`**

```bash
git fetch origin
git rebase origin/main
```

Resolve any conflicts. Re-run analyze + scoped tests after rebase.

- [ ] **Step 2: Push**

```bash
git push -u origin feat/profile-banner-image-upload --force-with-lease
```

(`--force-with-lease` is required after rebase, never `--force`.)

- [ ] **Step 3: Open the PR via `gh`**

```bash
gh pr create --base main --title "feat(profile): upload a banner image from the profile setup screen" --body "$(cat <<'EOF'
## Summary

- Adds a 3:1 banner image preview + upload UI above the existing color picker on the profile setup screen.
- Reuses the existing `BlossomUploadService` (same code path as the avatar) — no schema, repository, or BLoC change.
- Image and color are mutually exclusive; selecting one clears the other.
- Pre-fills from any existing `profile.banner` set in another Nostr client.

## Why

`profile_setup_screen` already lets users edit a banner *color* and the rest of the app already *renders* banner images set in other Nostr clients — but divine-mobile users can't *upload* an image themselves and have to leave the app to update a banner.

## Test plan

- [ ] Camera path on iOS — picks, uploads, snackbar success, banner persists after Save.
- [ ] Gallery path on iOS — same.
- [ ] Camera + gallery on Android — same.
- [ ] Toggle from color → image → color and confirm the previews + Save payload track the active selection.
- [ ] Pre-existing Nostr-set banner image renders in the preview and is preserved on Save when untouched.
- [ ] `flutter test test/screens/profile_setup_screen_test.dart` passes.
- [ ] `flutter test test/l10n/arb_consistency_test.dart` passes.

## Spec

`mobile/docs/superpowers/specs/2026-05-09-profile-banner-image-upload-design.md`

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 4: Verify CI is green before requesting review**

```bash
gh pr view --json statusCheckRollup --jq '.statusCheckRollup[] | {name, conclusion}'
```

All required checks green: `build / build`, `Analyze`, `Tests`, `Format`, `Generated Files`, `Profile Repository CI` (if it runs). If any are red, fix and push again.

- [ ] **Step 5: Hand off**

Return the PR URL to the user.
