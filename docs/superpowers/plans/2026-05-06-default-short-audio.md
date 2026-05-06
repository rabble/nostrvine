# Default Short Audio Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the audio from `https://www.youtube.com/shorts/kcEM8xNVyiU` as a bundled default sound in the mobile sound picker.

**Architecture:** The app already loads bundled default sounds from `mobile/assets/sounds/sounds_manifest.json` through `SoundLibraryService`. This change adds one audio file and one manifest entry, with a focused manifest regression test.

**Tech Stack:** Flutter, Dart, `flutter_test`, bundled Flutter assets, `yt-dlp` or equivalent downloader, `ffmpeg`/`ffprobe` for audio extraction and duration.

---

## Chunk 1: Bundled Sound Asset

### Task 1: Manifest Guard Test

**Files:**
- Modify: `mobile/test/services/sound_library_service_test.dart`
- Read: `mobile/assets/sounds/sounds_manifest.json`

- [ ] **Step 1: Write the failing test**

Add a test to `mobile/test/services/sound_library_service_test.dart`:

```dart
test('real manifest includes the bundled public domain short audio', () async {
  final manifestFile = File('assets/sounds/sounds_manifest.json');
  final sounds = SoundLibraryService.parseManifest(
    await manifestFile.readAsString(),
  );

  final sound = sounds.singleWhere((s) => s.id == 'new_zealand_state_highway_73');

  expect(sound.title, equals('New Zealand Road State Highway 73'));
  expect(
    sound.assetPath,
    equals('assets/sounds/new-zealand-state-highway-73.mp3'),
  );
  expect(sound.duration.inMilliseconds, greaterThan(0));
  expect(sound.license, equals('Public Domain'));
  expect(
    sound.sourceUrl,
    equals('https://www.youtube.com/shorts/kcEM8xNVyiU'),
  );
  expect(sound.tags, containsAll(<String>['default', 'short']));
});
```

- [ ] **Step 2: Run test to verify it fails**

Run from `mobile/`:

```bash
flutter test test/services/sound_library_service_test.dart --plain-name "real manifest includes the bundled public domain short audio"
```

Expected: FAIL because the manifest does not contain `new_zealand_state_highway_73`.

### Task 2: Extract and Add Asset

**Files:**
- Create: `mobile/assets/sounds/new-zealand-state-highway-73.mp3`

- [ ] **Step 1: Extract audio**

Use a downloader/extractor such as `yt-dlp` with `ffmpeg` available:

```bash
yt-dlp -x --audio-format mp3 --audio-quality 0 \
  -o 'mobile/assets/sounds/new-zealand-state-highway-73.%(ext)s' \
  'https://www.youtube.com/shorts/kcEM8xNVyiU'
```

- [ ] **Step 2: Measure duration**

Run:

```bash
ffprobe -v error -show_entries format=duration \
  -of default=noprint_wrappers=1:nokey=1 \
  mobile/assets/sounds/new-zealand-state-highway-73.mp3
```

Use the rounded millisecond duration in the manifest.

### Task 3: Add Manifest Entry

**Files:**
- Modify: `mobile/assets/sounds/sounds_manifest.json`

- [ ] **Step 1: Add the sound metadata**

Insert one entry in the `sounds` array:

```json
{
  "id": "new_zealand_state_highway_73",
  "title": "New Zealand Road State Highway 73",
  "assetPath": "assets/sounds/new-zealand-state-highway-73.mp3",
  "durationMs": 9334,
  "tags": ["default", "short", "road", "new zealand", "travel"],
  "license": "Public Domain",
  "sourceUrl": "https://www.youtube.com/shorts/kcEM8xNVyiU"
}
```

- [ ] **Step 2: Run focused test to verify it passes**

Run from `mobile/`:

```bash
flutter test test/services/sound_library_service_test.dart --plain-name "real manifest includes the bundled public domain short audio"
```

Expected: PASS.

### Task 4: Broaden Verification and Commit

**Files:**
- Modified/created files from Tasks 1-3

- [ ] **Step 1: Run service tests**

Run from `mobile/`:

```bash
flutter test test/services/sound_library_service_test.dart
```

Expected: PASS.

- [ ] **Step 2: Run analyze**

Run from `mobile/`:

```bash
flutter analyze lib test
```

Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/specs/2026-05-06-default-short-audio-design.md \
  docs/superpowers/plans/2026-05-06-default-short-audio.md \
  mobile/test/services/sound_library_service_test.dart \
  mobile/assets/sounds/sounds_manifest.json \
  mobile/assets/sounds/new-zealand-state-highway-73.mp3
git commit -m "feat(audio): add bundled short default sound"
```
