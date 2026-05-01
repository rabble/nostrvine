# Audio Upload And Sharing Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users import audio files into their sound library, use those files as video soundtracks, and optionally publish uploaded sounds as reusable Kind 1063 audio events.

**Architecture:** Keep published audio as `AudioEvent`, but add app-layer local import support around it. Local uploads are copied into app documents storage and represented as `AudioEvent` values with `file://` URLs until the user opts to share them; sharing uploads the audio to Blossom, publishes a Kind 1063 event, and stores the returned event on the video as an `["e", ..., "audio"]` tag. Rendering and preview use ProImageEditor `EditorAudio.file` for local files, preserving existing bundled and network paths.

**Tech Stack:** Flutter, Riverpod, `file_picker`, `pro_image_editor`, `pro_video_editor`, Blossom upload service, Nostr Kind 1063, existing `AudioEvent`, `VideoEditorProvider`, and `VideoEventPublisher`.

---

## Research Notes

- Existing sound reuse is built on `AudioEvent` Kind 1063, `SoundsRepository`, `soundByIdProvider`, `trendingSoundsProvider`, and `AudioSelectionBottomSheet`.
- `BlossomUploadService.uploadAudio()` already exists in `mobile/packages/blossom_upload_service/lib/src/blossom_upload_service.dart`.
- Video publish already adds a single selected sound reference from `DivineVideoDraft.selectedSound` via `VideoPublishService` and `VideoEventPublisher.publishVideoEvent`.
- The current editor preview path builds `AudioTrack.asset` or `AudioTrack.network` in `mobile/lib/widgets/video_editor/main_editor/video_editor_canvas.dart`; it needs a local-file branch.
- The current render path already calls `track.audio.safeFilePath()` in `mobile/lib/services/video_editor/video_editor_render_service.dart`, so it can render local audio once the `AudioTrack` is built with `EditorAudio.file`.
- `file_picker` is already in the workspace.

## File Map

- Create `mobile/lib/services/local_audio_library_service.dart`: copy imported audio files into documents storage, persist a manifest, delete local uploads, and emit `AudioEvent` values.
- Create `mobile/test/services/local_audio_library_service_test.dart`: hash, persistence, duplicate import, deletion, and file validation tests.
- Create `mobile/lib/providers/local_audio_library_provider.dart`: Riverpod controller around the local library service.
- Modify `mobile/lib/widgets/video_editor/audio_editor/audio_selection_bottom_sheet.dart`: add import action and include local uploads in the audio picker.
- Modify `mobile/test/widgets/video_editor/audio_editor/audio_selection_bottom_sheet_test.dart`: import button, imported sound display, and selected local sound result.
- Modify `mobile/lib/widgets/library/sounds_tab.dart` and/or `mobile/lib/screens/sounds_screen.dart`: show imported sounds in the sound library, with local-only affordance.
- Modify `mobile/lib/widgets/video_editor/main_editor/video_editor_canvas.dart`: convert `file://` audio events to `AudioTrack(audio: EditorAudio.file(...))`.
- Modify `mobile/lib/extensions/complete_parameters_extensions.dart`: keep audio event metadata parseable for local events.
- Modify `mobile/lib/models/divine_video_draft.dart` and `mobile/lib/models/video_editor/video_editor_provider_state.dart`: persist "share uploaded sound" intent for local selected sound.
- Modify `mobile/lib/providers/video_editor_provider.dart`: set/clear local sound share intent and include it in active drafts.
- Create `mobile/lib/services/shared_audio_publish_service.dart`: upload a local audio file to Blossom, publish Kind 1063, return the published `AudioEvent`.
- Create `mobile/test/services/shared_audio_publish_service_test.dart`: success, upload failure, signing failure, relay failure, and already-published input.
- Modify `mobile/lib/services/video_publish/video_publish_service.dart`: publish local uploaded sounds before publishing the video when the user opted in.
- Modify `mobile/lib/services/video_event_publisher.dart`: accept the resolved selected audio event reference rather than publishing local file paths.

## Chunk 1: Local Audio Library

### Task 1: Add A Persisted Local Audio Library Service

**Files:**
- Create: `mobile/lib/services/local_audio_library_service.dart`
- Test: `mobile/test/services/local_audio_library_service_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
test('imports audio into documents storage and returns a local AudioEvent', () async {
  final service = LocalAudioLibraryService(
    documentsDirectory: tempDir,
    clock: () => DateTime.fromMillisecondsSinceEpoch(1714600000000),
  );

  final event = await service.importAudioFile(
    sourcePath: sourceMp3.path,
    displayName: 'My Track',
    mimeType: 'audio/mpeg',
    duration: const Duration(seconds: 6),
  );

  expect(event.id, startsWith('local_audio_'));
  expect(event.title, 'My Track');
  expect(event.url, startsWith('file://'));
  expect(event.mimeType, 'audio/mpeg');
  expect(File(Uri.parse(event.url!).toFilePath()).existsSync(), isTrue);
  expect(await service.loadSounds(), [event]);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/local_audio_library_service_test.dart --plain-name "imports audio into documents storage"`

Expected: FAIL because `LocalAudioLibraryService` does not exist.

- [ ] **Step 3: Implement minimal service**

Implement a manifest file at `<documents>/audio_uploads/manifest.json`. Use `HashUtil.sha256File` for IDs and dedupe. Store only app-owned copied files, not original picker paths.

```dart
class LocalAudioLibraryService {
  LocalAudioLibraryService({
    required Directory documentsDirectory,
    DateTime Function()? clock,
  }) : _documentsDirectory = documentsDirectory,
       _clock = clock ?? DateTime.now;

  final Directory _documentsDirectory;
  final DateTime Function() _clock;

  Future<AudioEvent> importAudioFile({
    required String sourcePath,
    required String displayName,
    required String mimeType,
    required Duration duration,
  }) async {
    final source = File(sourcePath);
    if (!source.existsSync()) {
      throw const LocalAudioImportException('Audio file not found');
    }
    final hash = await HashUtil.sha256File(source);
    final ext = p.extension(source.path).isEmpty ? '.m4a' : p.extension(source.path);
    final audioDir = Directory(p.join(_documentsDirectory.path, 'audio_uploads'));
    await audioDir.create(recursive: true);
    final copied = File(p.join(audioDir.path, '${hash.hash}$ext'));
    if (!copied.existsSync()) {
      await source.copy(copied.path);
    }
    final event = AudioEvent(
      id: 'local_audio_${hash.hash}',
      pubkey: 'local',
      createdAt: _clock().millisecondsSinceEpoch ~/ 1000,
      url: copied.uri.toString(),
      mimeType: mimeType,
      sha256: hash.hash,
      fileSize: hash.size,
      duration: duration.inMilliseconds / 1000,
      title: displayName,
      source: 'Uploaded',
    );
    await _upsertManifestEvent(event);
    return event;
  }
}
```

- [ ] **Step 4: Add validation tests**

Cover unsupported extensions, empty files, files over the agreed size limit, duplicate imports, and manifest corruption fallback.

- [ ] **Step 5: Run tests**

Run: `flutter test test/services/local_audio_library_service_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/services/local_audio_library_service.dart mobile/test/services/local_audio_library_service_test.dart
git commit -m "feat(audio): add local audio library service"
```

### Task 2: Add Riverpod Access To Local Audio

**Files:**
- Create: `mobile/lib/providers/local_audio_library_provider.dart`
- Modify: `mobile/lib/providers/sounds_providers.dart`
- Test: `mobile/test/providers/local_audio_library_provider_test.dart`

- [ ] **Step 1: Write failing provider tests**

```dart
test('localUploadedSoundsProvider loads persisted imports', () async {
  final container = ProviderContainer(overrides: [
    localAudioLibraryServiceProvider.overrideWithValue(fakeService),
  ]);
  addTearDown(container.dispose);

  expect(
    await container.read(localUploadedSoundsProvider.future),
    [localAudioEvent],
  );
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/providers/local_audio_library_provider_test.dart`

Expected: FAIL because providers do not exist.

- [ ] **Step 3: Implement providers**

Use generated Riverpod if the file uses `@riverpod`; otherwise use manual providers to avoid unnecessary generated code. If using `@riverpod`, run build runner and commit generated output.

```dart
final localAudioLibraryServiceProvider = Provider<LocalAudioLibraryService>((ref) {
  throw UnimplementedError('override in app bootstrap after documents path is available');
});

final localUploadedSoundsProvider = FutureProvider<List<AudioEvent>>((ref) async {
  return ref.watch(localAudioLibraryServiceProvider).loadSounds();
});
```

- [ ] **Step 4: Wire app bootstrap**

Create the real service after documents directory is known. If no existing documents provider exists, add a small `FutureProvider<Directory>` and override it in tests.

- [ ] **Step 5: Run tests**

Run: `flutter test test/providers/local_audio_library_provider_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/providers/local_audio_library_provider.dart mobile/lib/providers/sounds_providers.dart mobile/test/providers/local_audio_library_provider_test.dart
git commit -m "feat(audio): expose local uploaded sounds"
```

## Chunk 2: Import UI And Playback

### Task 3: Add Upload UI To Audio Selection

**Files:**
- Modify: `mobile/lib/widgets/video_editor/audio_editor/audio_selection_bottom_sheet.dart`
- Modify: `mobile/lib/l10n/app_en.arb` and generated l10n files if this repo requires generated localization outputs
- Test: `mobile/test/widgets/video_editor/audio_editor/audio_selection_bottom_sheet_test.dart`

- [ ] **Step 1: Write failing widget test**

```dart
testWidgets('shows upload action and returns imported audio', (tester) async {
  final service = FakeLocalAudioLibraryService(imported: localAudioEvent);
  await tester.pumpWidget(buildWidget(overrides: [
    localAudioLibraryServiceProvider.overrideWithValue(service),
    localUploadedSoundsProvider.overrideWith((_) async => []),
  ]));

  await tester.tap(find.text('Upload'));
  await tester.pumpAndSettle();

  expect(service.importCalled, isTrue);
  expect(find.text('My Track'), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/video_editor/audio_editor/audio_selection_bottom_sheet_test.dart --plain-name "shows upload action"`

Expected: FAIL because the upload action is not rendered.

- [ ] **Step 3: Implement picker action**

Add a compact upload button in the selection sheet header or first row. Use `FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['mp3', 'm4a', 'aac', 'wav'])`. The picker result flows through `LocalAudioLibraryService.importAudioFile()`, invalidates `localUploadedSoundsProvider`, and selects the imported event.

- [ ] **Step 4: Include local sounds in lists**

Render local uploads before community sounds, with source text "Uploaded". Keep bundled and community tabs intact.

- [ ] **Step 5: Run tests**

Run: `flutter test test/widgets/video_editor/audio_editor/audio_selection_bottom_sheet_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/widgets/video_editor/audio_editor/audio_selection_bottom_sheet.dart mobile/test/widgets/video_editor/audio_editor/audio_selection_bottom_sheet_test.dart mobile/lib/l10n
git commit -m "feat(audio): let users import audio files"
```

### Task 4: Support Local Audio In Preview And Render

**Files:**
- Modify: `mobile/lib/widgets/video_editor/main_editor/video_editor_canvas.dart:523-541`
- Modify: `mobile/lib/services/video_editor/video_editor_render_service.dart:741-759`
- Test: `mobile/test/widgets/video_editor/main_editor/video_editor_canvas_test.dart`
- Test: `mobile/test/services/video_editor/video_editor_render_service_test.dart`

- [ ] **Step 1: Extract track building helper and write failing unit test**

```dart
test('builds file audio track for local uploaded AudioEvent', () async {
  final event = AudioEvent(
    id: 'local_audio_hash',
    pubkey: 'local',
    createdAt: 1,
    url: File('/tmp/imported.m4a').uri.toString(),
    duration: 6,
    title: 'Imported',
  );

  final track = await buildEditorAudioTrack(
    sound: event,
    startTime: Duration.zero,
    endTime: const Duration(seconds: 6),
    volume: 1,
  );

  expect(track.audio.hasFile, isTrue);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/video_editor/main_editor/video_editor_canvas_test.dart --plain-name "builds file audio track"`

Expected: FAIL because local-file URLs fall into the network branch today.

- [ ] **Step 3: Implement local file branch**

```dart
if (sound.url!.startsWith('file://')) {
  track = AudioTrack(
    id: sound.id,
    title: sound.title ?? context.l10n.videoEditorAudioUntitledSound,
    subtitle: sound.source ?? '',
    duration: Duration(milliseconds: ((sound.duration ?? 0) * 1000).round()),
    audio: EditorAudio.file(File(Uri.parse(sound.url!).toFilePath())),
    volume: customVolume,
    startTime: item.startTime,
    endTime: item.endTime,
    audioStartTime: sound.startOffset,
  );
}
```

- [ ] **Step 4: Keep render path covered**

Assert that `VideoEditorRenderService` receives a `VideoAudioTrack.path` from `track.audio.safeFilePath()` for `EditorAudio.file`. No network fetch should happen for local uploads.

- [ ] **Step 5: Run tests**

Run: `flutter test test/widgets/video_editor/main_editor/video_editor_canvas_test.dart test/services/video_editor/video_editor_render_service_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/widgets/video_editor/main_editor/video_editor_canvas.dart mobile/lib/services/video_editor/video_editor_render_service.dart mobile/test/widgets/video_editor/main_editor/video_editor_canvas_test.dart mobile/test/services/video_editor/video_editor_render_service_test.dart
git commit -m "feat(audio): render local uploaded audio"
```

## Chunk 3: Library Surface And Draft State

### Task 5: Show Uploaded Sounds In The Library

**Files:**
- Modify: `mobile/lib/widgets/library/sounds_tab.dart`
- Modify: `mobile/lib/screens/sounds_screen.dart`
- Test: `mobile/test/widgets/library/sounds_tab_test.dart`
- Test: `mobile/test/screens/sounds_screen_test.dart`

- [ ] **Step 1: Write failing tests**

Assert that local uploads render in the library and that tapping one opens the detail/use flow or selects it when the screen has a callback.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/library/sounds_tab_test.dart test/screens/sounds_screen_test.dart --plain-name "uploaded"`

Expected: FAIL because local uploads are not included.

- [ ] **Step 3: Merge local sounds into UI data**

Read `localUploadedSoundsProvider` and prepend those events to sound lists. Do not publish or query Nostr for `local_audio_` IDs. In `soundByIdProvider`, resolve `local_audio_` from the local library before falling through to relays.

- [ ] **Step 4: Run tests**

Run: `flutter test test/widgets/library/sounds_tab_test.dart test/screens/sounds_screen_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/widgets/library/sounds_tab.dart mobile/lib/screens/sounds_screen.dart mobile/lib/providers/sounds_providers.dart mobile/test
git commit -m "feat(audio): show uploaded sounds in library"
```

### Task 6: Persist Share Intent For Uploaded Sounds

**Files:**
- Modify: `mobile/lib/models/video_editor/video_editor_provider_state.dart`
- Modify: `mobile/lib/models/divine_video_draft.dart`
- Modify: `mobile/lib/providers/video_editor_provider.dart`
- Test: `mobile/test/models/divine_video_draft_test.dart`
- Test: `mobile/test/providers/video_editor_provider_test.dart`

- [ ] **Step 1: Write failing model tests**

```dart
test('draft persists shareUploadedSound', () {
  final draft = DivineVideoDraft.create(
    clips: [],
    title: '',
    description: '',
    hashtags: {},
    selectedApproach: 'test',
    shareUploadedSound: true,
  );

  expect(DivineVideoDraft.fromJson(draft.toJson(), tempDir.path).shareUploadedSound, isTrue);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/models/divine_video_draft_test.dart --plain-name "shareUploadedSound"`

Expected: FAIL because the field does not exist.

- [ ] **Step 3: Implement state**

Add `shareUploadedSound` to editor state and draft JSON. Only surface the toggle when `selectedSound.url` is a `file://` URL. Clear the flag when selected sound is cleared or changed to a non-local sound.

- [ ] **Step 4: Run tests**

Run: `flutter test test/models/divine_video_draft_test.dart test/providers/video_editor_provider_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/models/video_editor/video_editor_provider_state.dart mobile/lib/models/divine_video_draft.dart mobile/lib/providers/video_editor_provider.dart mobile/test
git commit -m "feat(audio): persist uploaded sound sharing intent"
```

## Chunk 4: Publish Shared Uploaded Audio

### Task 7: Publish A Local Uploaded Sound As Kind 1063

**Files:**
- Create: `mobile/lib/services/shared_audio_publish_service.dart`
- Test: `mobile/test/services/shared_audio_publish_service_test.dart`

- [ ] **Step 1: Write failing service tests**

```dart
test('uploads local audio and publishes Kind 1063', () async {
  final service = SharedAudioPublishService(
    blossomUploadService: blossom,
    authService: auth,
    nostrClient: nostr,
  );

  final event = await service.publishLocalUploadedSound(
    localSound: localAudioEvent,
    sourceVideoReference: '34236:$pubkey:$dTag',
    sourceVideoRelay: 'wss://relay.divine.video',
  );

  expect(event.id, signedEvent.id);
  verify(() => blossom.uploadAudio(audioFile: any(named: 'audioFile'), mimeType: 'audio/mpeg')).called(1);
  verify(() => auth.createAndSignEvent(kind: audioEventKind, content: '', tags: any(named: 'tags'))).called(1);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/shared_audio_publish_service_test.dart`

Expected: FAIL because the service does not exist.

- [ ] **Step 3: Implement service**

The service should reject non-local sounds, upload the local file with `uploadAudio`, build an `AudioEvent` with the Blossom URL/hash/size/duration/title, sign a Kind 1063 event, publish it, and return the published `AudioEvent`.

- [ ] **Step 4: Add failure tests**

Cover missing file, upload failure, no URL returned, signing failure, relay publish failure, and non-local input. These should not publish a video-level `e` tag.

- [ ] **Step 5: Run tests**

Run: `flutter test test/services/shared_audio_publish_service_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/services/shared_audio_publish_service.dart mobile/test/services/shared_audio_publish_service_test.dart
git commit -m "feat(audio): publish uploaded sounds"
```

### Task 8: Attach Shared Uploaded Audio To Video Publish

**Files:**
- Modify: `mobile/lib/services/video_publish/video_publish_service.dart`
- Modify: `mobile/lib/services/video_event_publisher.dart`
- Test: `mobile/test/services/video_publish/video_publish_service_test.dart`
- Test: `mobile/test/services/video_event_publisher_test.dart`

- [ ] **Step 1: Write failing publish tests**

Assert that a draft with `selectedSound.url == file://...` and `shareUploadedSound == true` publishes the uploaded sound first and passes the published event ID to `VideoEventPublisher.publishVideoEvent`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/video_publish/video_publish_service_test.dart --plain-name "shared uploaded sound"`

Expected: FAIL because local uploaded sounds are not resolved before video publish.

- [ ] **Step 3: Implement publish ordering**

In `VideoPublishService.publishDraft`, before calling `videoEventPublisher.publishVideoEvent`, resolve:

```dart
final selectedSound = draft.selectedSound;
AudioEvent? publishableSound = selectedSound;
if (draft.shareUploadedSound && selectedSound?.url?.startsWith('file://') == true) {
  publishableSound = await sharedAudioPublishService.publishLocalUploadedSound(
    localSound: selectedSound!,
    sourceVideoReference: '${NIP71VideoKinds.getPreferredAddressableKind()}:$pubkey:${pendingUpload.videoId}',
    sourceVideoRelay: 'wss://relay.divine.video',
  );
}
```

Then pass `publishableSound?.id` and relay to the video publisher. Never pass `local_audio_` IDs into a Nostr video event.

- [ ] **Step 4: Update video publisher guardrails**

Add an assertion or validation in `VideoEventPublisher` that skips selected audio references starting with `local_audio_` or `file://` and logs an error. This prevents leaking local-only data if a caller forgets to resolve it.

- [ ] **Step 5: Run tests**

Run: `flutter test test/services/video_publish/video_publish_service_test.dart test/services/video_event_publisher_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/services/video_publish/video_publish_service.dart mobile/lib/services/video_event_publisher.dart mobile/test/services
git commit -m "feat(audio): attach shared uploaded sounds to videos"
```

## Chunk 5: End-To-End Verification

### Task 9: Broaden Tests And Manual Checks

**Files:**
- Modify as needed based on test failures only.

- [ ] **Step 1: Run focused tests**

```bash
cd mobile
flutter test test/services/local_audio_library_service_test.dart
flutter test test/widgets/video_editor/audio_editor/audio_selection_bottom_sheet_test.dart
flutter test test/widgets/video_editor/main_editor/video_editor_canvas_test.dart
flutter test test/services/shared_audio_publish_service_test.dart
flutter test test/services/video_publish/video_publish_service_test.dart
```

Expected: PASS.

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze`

Expected: PASS, or only pre-existing warnings documented in the PR body.

- [ ] **Step 3: Run generated code if needed**

Run: `dart run build_runner build --delete-conflicting-outputs` if any `@riverpod`, `freezed`, JSON, Drift, or mock generator inputs changed.

Expected: generated files are updated and committed.

- [ ] **Step 4: Manual happy path**

On a device or simulator:
1. Open the recorder.
2. Tap the audio chip.
3. Tap Upload.
4. Pick an `.m4a` or `.mp3`.
5. Confirm it appears in the picker and library.
6. Use it in a recording.
7. Render and preview the video.
8. Publish once with sharing disabled and confirm no audio `e` tag is published.
9. Publish once with sharing enabled and confirm the Kind 1063 audio event is published before the video and the video has `["e", <audio-event-id>, <relay>, "audio"]`.

- [ ] **Step 5: Final commit**

```bash
git status --short
git commit --allow-empty -m "test(audio): verify uploaded sound flow"
```

Only use the empty commit if all prior chunks were already committed and this step records verification notes in the PR body.

## Current Bug Fix Already Applied In This Branch

The immediate "Use this sound" bug was caused by sound detail and sound browser screens writing only to `selectedSoundProvider`, while the recorder, editor, draft, and publish paths read `videoEditorProvider.selectedSound`. The fix in this branch updates both entry points to also call `videoEditorProvider.notifier.selectSound(sound)` and mute original audio by default, matching the recorder audio chip behavior.

Targeted tests:

```bash
cd mobile
flutter test test/screens/sound_detail_screen_test.dart --plain-name "tapping Use Sound selects sound for recording"
flutter test test/screens/sounds_screen_test.dart --plain-name "tapping sound without callback selects it for recording"
```
