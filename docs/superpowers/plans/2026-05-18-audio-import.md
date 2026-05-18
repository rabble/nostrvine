# Audio Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users import an audio file, use it as the editor sound, and publish that sound as a Blossom-backed Kind 1063 event before the video event references it.

**Architecture:** Keep imported audio as a normal `AudioEvent` with a `local_import_` id and a local file path in `url`. A small import service owns file copying and MIME/title/duration metadata. Existing editor, render, and publish flows learn how to treat local imported audio as a file source, then `VideoEventPublisher` uploads/signs/publishes it before creating the final video event.

**Tech Stack:** Flutter/Dart, Riverpod compatibility path, `file_picker`, `path_provider`, `pro_video_editor`, `AudioPlaybackService`, `BlossomUploadService`, Nostr Kind 1063 via existing `AuthService` and relay publish path.

---

## File Structure

- Modify: `mobile/packages/models/lib/src/audio_event.dart`
  - Add `localImportMarker`, `isLocalImport`, `localFilePath`, and `AudioEvent.fromLocalImport`.
- Test: `mobile/packages/models/test/src/audio_event_test.dart`
  - Cover local import construction, JSON round trip, and file path getter.
- Create: `mobile/lib/services/local_audio_import_service.dart`
  - Copy picked audio into app-owned draft audio storage and return a local `AudioEvent`.
- Test: `mobile/test/services/local_audio_import_service_test.dart`
  - Cover copy success, unsupported extension, and missing file.
- Modify: `mobile/lib/widgets/video_editor/audio_editor/audio_selection_bottom_sheet.dart`
  - Add import button, file picker call, local preview via `loadAudioFromFile`, and duration resolution via `EditorVideo.file`.
- Modify: `mobile/lib/providers/video_editor_provider.dart`
  - Render selected local imports with `EditorAudio.file`.
- Modify: `mobile/lib/widgets/video_editor/main_editor/video_editor_canvas.dart`
  - Preview selected local imports with `AudioTrack.file`.
- Modify: `mobile/lib/services/video_event_publisher.dart`
  - Accept a full selected `AudioEvent`, publish local imports as Kind 1063, and block video publishing if that audio publish fails.
- Modify: `mobile/lib/services/video_publish/video_publish_service.dart`
  - Pass `draft.selectedSound` into `VideoEventPublisher`.
- Test: `mobile/test/services/video_event_publisher_test.dart`
  - Cover local import upload, Kind 1063 publish, My Sounds save, video audio `e` tag, and failure blocking.
- Modify: `mobile/lib/l10n/app_en.arb` and generated l10n files only if the UI needs new visible copy.

## Task 0: Worktree And Baseline

**Files:**
- No source edits.

- [ ] **Step 1: Confirm worktree state**

Run:

```bash
git status --short
git branch --show-current
```

Expected: clean status, branch `feat/audio-import`.

- [ ] **Step 2: Resolve dependencies**

Run from `mobile/`:

```bash
flutter pub get
```

Expected: dependencies resolve without changes unless `pubspec.lock` genuinely needs an update.

- [ ] **Step 3: Run focused baseline tests**

Run from `mobile/`:

```bash
flutter test test/widgets/video_editor/audio_editor/audio_selection_bottom_sheet_test.dart test/services/video_event_publisher_test.dart
```

Expected: existing tests pass before feature edits.

## Task 1: Local Import Model And Service

**Files:**
- Modify: `mobile/packages/models/lib/src/audio_event.dart`
- Test: `mobile/packages/models/test/src/audio_event_test.dart`
- Create: `mobile/lib/services/local_audio_import_service.dart`
- Test: `mobile/test/services/local_audio_import_service_test.dart`

- [ ] **Step 1: Write failing model tests**

Add tests near the other `AudioEvent` constructor/JSON coverage:

```dart
test('fromLocalImport creates draft-local audio event', () {
  final event = AudioEvent.fromLocalImport(
    id: 'local_import_1700000000000',
    filePath: '/tmp/divine-audio/snare.mp3',
    createdAt: 1700000000,
    title: 'snare',
    mimeType: 'audio/mpeg',
    duration: 2.5,
  );

  expect(event.id, equals('local_import_1700000000000'));
  expect(event.pubkey, equals(AudioEvent.localImportMarker));
  expect(event.url, equals('/tmp/divine-audio/snare.mp3'));
  expect(event.localFilePath, equals('/tmp/divine-audio/snare.mp3'));
  expect(event.isLocalImport, isTrue);
  expect(event.mimeType, equals('audio/mpeg'));
  expect(event.title, equals('snare'));
  expect(event.source, equals('Imported audio'));
});

test('local import survives json round trip', () {
  final original = AudioEvent.fromLocalImport(
    id: 'local_import_1700000000000',
    filePath: '/tmp/divine-audio/kick.wav',
    createdAt: 1700000000,
    title: 'kick',
    mimeType: 'audio/wav',
    duration: 1.25,
  );

  final restored = AudioEvent.fromJson(original.toJson());

  expect(restored.isLocalImport, isTrue);
  expect(restored.localFilePath, equals('/tmp/divine-audio/kick.wav'));
  expect(restored.title, equals('kick'));
  expect(restored.duration, equals(1.25));
});
```

- [ ] **Step 2: Run model tests and confirm RED**

Run from `mobile/packages/models/`:

```bash
flutter test test/src/audio_event_test.dart --plain-name "fromLocalImport creates draft-local audio event"
```

Expected: fail because `AudioEvent.fromLocalImport` and local import getters do not exist.

- [ ] **Step 3: Implement `AudioEvent` local import helpers**

Add to `AudioEvent`:

```dart
factory AudioEvent.fromLocalImport({
  required String id,
  required String filePath,
  required int createdAt,
  required String title,
  required String mimeType,
  double? duration,
}) {
  return AudioEvent(
    id: id,
    pubkey: localImportMarker,
    createdAt: createdAt,
    url: filePath,
    mimeType: mimeType,
    duration: duration,
    title: title,
    source: 'Imported audio',
  );
}

static const localImportMarker = 'local_import';

bool get isLocalImport => id.startsWith('${localImportMarker}_');

String? get localFilePath {
  if (!isLocalImport || url == null || url!.isEmpty) return null;
  return url;
}
```

- [ ] **Step 4: Run model tests and confirm GREEN**

Run from `mobile/packages/models/`:

```bash
flutter test test/src/audio_event_test.dart --plain-name "local import"
```

Expected: the two new tests pass.

- [ ] **Step 5: Write failing import service tests**

Create `mobile/test/services/local_audio_import_service_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/local_audio_import_service.dart';

void main() {
  group(LocalAudioImportService, () {
    late Directory tempDir;
    late Directory sourceDir;
    late Directory storageDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('audio_import_test_');
      sourceDir = Directory('${tempDir.path}/source')..createSync();
      storageDir = Directory('${tempDir.path}/storage')..createSync();
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('copies picked audio into draft storage and returns local AudioEvent', () async {
      final source = File('${sourceDir.path}/My Sound.MP3');
      await source.writeAsBytes([1, 2, 3, 4]);
      final service = LocalAudioImportService(
        storageRootProvider: () async => storageDir,
        durationResolver: (_) async => const Duration(milliseconds: 2500),
        clock: () => DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );

      final event = await service.importAudioFile(
        sourcePath: source.path,
        draftId: 'draft_123',
        displayName: 'My Sound.MP3',
      );

      expect(event.id, equals('local_import_1700000000000'));
      expect(event.title, equals('My Sound'));
      expect(event.mimeType, equals('audio/mpeg'));
      expect(event.duration, equals(2.5));
      expect(event.localFilePath, isNot(equals(source.path)));
      expect(event.localFilePath, contains('/draft_123/'));
      expect(await File(event.localFilePath!).readAsBytes(), equals([1, 2, 3, 4]));
    });

    test('rejects unsupported audio extensions without copying', () async {
      final source = File('${sourceDir.path}/notes.txt');
      await source.writeAsString('not audio');
      final service = LocalAudioImportService(
        storageRootProvider: () async => storageDir,
      );

      await expectLater(
        service.importAudioFile(
          sourcePath: source.path,
          draftId: 'draft_123',
          displayName: 'notes.txt',
        ),
        throwsA(isA<LocalAudioImportException>()),
      );

      expect(storageDir.listSync(recursive: true), isEmpty);
    });

    test('rejects missing source files', () async {
      final service = LocalAudioImportService(
        storageRootProvider: () async => storageDir,
      );

      await expectLater(
        service.importAudioFile(
          sourcePath: '${sourceDir.path}/missing.mp3',
          draftId: 'draft_123',
          displayName: 'missing.mp3',
        ),
        throwsA(isA<LocalAudioImportException>()),
      );
    });
  });
}
```

- [ ] **Step 6: Run import service tests and confirm RED**

Run from `mobile/`:

```bash
flutter test test/services/local_audio_import_service_test.dart
```

Expected: fail because `LocalAudioImportService` does not exist.

- [ ] **Step 7: Implement local import service**

Create `mobile/lib/services/local_audio_import_service.dart`:

```dart
import 'dart:io';

import 'package:models/models.dart' show AudioEvent;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

typedef AudioImportStorageRootProvider = Future<Directory> Function();
typedef AudioImportDurationResolver = Future<Duration?> Function(File file);
typedef AudioImportClock = DateTime Function();

class LocalAudioImportException implements Exception {
  const LocalAudioImportException(this.message);
  final String message;

  @override
  String toString() => message;
}

class LocalAudioImportService {
  LocalAudioImportService({
    AudioImportStorageRootProvider? storageRootProvider,
    AudioImportDurationResolver? durationResolver,
    AudioImportClock? clock,
  }) : _storageRootProvider = storageRootProvider ?? _defaultStorageRoot,
       _durationResolver = durationResolver ?? _defaultDurationResolver,
       _clock = clock ?? DateTime.now;

  final AudioImportStorageRootProvider _storageRootProvider;
  final AudioImportDurationResolver _durationResolver;
  final AudioImportClock _clock;

  Future<AudioEvent> importAudioFile({
    required String sourcePath,
    required String draftId,
    required String displayName,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const LocalAudioImportException('Audio file could not be opened.');
    }

    final extension = path.extension(displayName).toLowerCase();
    final mimeType = _mimeTypeForExtension(extension);
    if (mimeType == null) {
      throw const LocalAudioImportException('That audio file type is not supported.');
    }

    final now = _clock();
    final fileName = _safeFileName(
      '${now.millisecondsSinceEpoch}_${path.basename(displayName)}',
    );
    final root = await _storageRootProvider();
    final draftDir = Directory(path.join(root.path, draftId));
    await draftDir.create(recursive: true);
    final copied = await source.copy(path.join(draftDir.path, fileName));
    final duration = await _durationResolver(copied);

    return AudioEvent.fromLocalImport(
      id: 'local_import_${now.millisecondsSinceEpoch}',
      filePath: copied.path,
      createdAt: now.millisecondsSinceEpoch ~/ 1000,
      title: _titleFromDisplayName(displayName),
      mimeType: mimeType,
      duration: duration == null ? null : duration.inMilliseconds / 1000,
    );
  }

  static Future<Directory> _defaultStorageRoot() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory(path.join(docs.path, 'draft_audio_imports'));
  }

  static Future<Duration?> _defaultDurationResolver(File file) async {
    final metadata = await ProVideoEditor.instance.getMetadata(
      EditorVideo.file(file),
    );
    return metadata.duration;
  }

  static String? _mimeTypeForExtension(String extension) => switch (extension) {
    '.aac' => 'audio/aac',
    '.m4a' => 'audio/mp4',
    '.mp3' => 'audio/mpeg',
    '.wav' => 'audio/wav',
    '.weba' => 'audio/webm',
    '.webm' => 'audio/webm',
    _ => null,
  };

  static String _titleFromDisplayName(String displayName) {
    final withoutExtension = path.basenameWithoutExtension(displayName).trim();
    return withoutExtension.isEmpty ? 'Imported audio' : withoutExtension;
  }

  static String _safeFileName(String input) {
    return input.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  }
}
```

- [ ] **Step 8: Run import service tests and confirm GREEN**

Run from `mobile/`:

```bash
flutter test test/services/local_audio_import_service_test.dart
```

Expected: all local import service tests pass.

- [ ] **Step 9: Commit model and service**

Run:

```bash
git add mobile/packages/models/lib/src/audio_event.dart mobile/packages/models/test/src/audio_event_test.dart mobile/lib/services/local_audio_import_service.dart mobile/test/services/local_audio_import_service_test.dart
git commit -m "feat(audio): add local audio import service"
```

## Task 2: Picker, Preview, And Render File Handling

**Files:**
- Modify: `mobile/lib/widgets/video_editor/audio_editor/audio_selection_bottom_sheet.dart`
- Modify: `mobile/lib/providers/video_editor_provider.dart`
- Modify: `mobile/lib/widgets/video_editor/main_editor/video_editor_canvas.dart`
- Test: `mobile/test/widgets/video_editor/audio_editor/audio_selection_bottom_sheet_test.dart`
- Test: `mobile/test/providers/video_editor_provider_test.dart`

- [ ] **Step 1: Write failing picker test for import action**

Add constructor injection to the test harness only after the test is written. The expected widget behavior is:

```dart
testWidgets('shows import action in the audio picker', (tester) async {
  await tester.pumpWidget(
    buildWidget(trendingSoundsAsync: const AsyncValue.data([])),
  );
  await tester.pumpAndSettle();

  expect(find.text('Import audio'), findsOneWidget);
  expect(find.byIcon(Icons.upload_file), findsOneWidget);
});
```

- [ ] **Step 2: Run picker test and confirm RED**

Run from `mobile/`:

```bash
flutter test test/widgets/video_editor/audio_editor/audio_selection_bottom_sheet_test.dart --plain-name "shows import action"
```

Expected: fail because no import action exists.

- [ ] **Step 3: Add import action and handler**

In `audio_selection_bottom_sheet.dart`, import `file_picker`, `local_audio_import_service.dart`, and `video_editor_provider.dart`. Add optional constructor parameters for tests:

```dart
const AudioSelectionBottomSheet({
  required this.scrollController,
  this.localAudioImportService,
  this.pickAudioFile,
  super.key,
});

final LocalAudioImportService? localAudioImportService;
final Future<FilePickerResult?> Function()? pickAudioFile;
```

Add a handler:

```dart
Future<void> _importAudio() async {
  final picker = widget.pickAudioFile ?? () {
    return FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['aac', 'm4a', 'mp3', 'wav', 'weba', 'webm'],
      allowMultiple: false,
    );
  };

  try {
    final result = await picker();
    final file = result?.files.singleOrNull;
    final filePath = file?.path;
    if (file == null || filePath == null || filePath.isEmpty) return;

    final imported = await (widget.localAudioImportService ?? LocalAudioImportService())
        .importAudioFile(
          sourcePath: filePath,
          draftId: ref.read(videoEditorProvider.notifier).draftId,
          displayName: file.name,
        );

    if (!mounted) return;
    setState(() => _selectedItem = imported);
    await _togglePlayPause(enforcePlay: true);
  } on LocalAudioImportException catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.message)),
    );
  }
}
```

Render an import row above the sound list:

```dart
SliverToBoxAdapter(
  child: ListTile(
    leading: const Icon(Icons.upload_file, color: VineTheme.whiteText),
    title: const Text('Import audio'),
    subtitle: const Text('Use a file from this device'),
    onTap: onImportAudio,
  ),
),
```

- [ ] **Step 4: Teach picker preview and duration resolution about files**

Change `_togglePlayPause`:

```dart
final loadedDuration = sound.isLocalImport && sound.localFilePath != null
    ? await _audioService.loadAudioFromFile(sound.localFilePath!)
    : await _audioService.loadAudio(sound.url!);
```

Change `_resolveDurationSecs`:

```dart
final localPath = sound.localFilePath;
final metadata = await ProVideoEditor.instance.getMetadata(
  localPath != null
      ? EditorVideo.file(File(localPath))
      : EditorVideo.autoSource(assetPath: assetPath, networkUrl: url),
);
```

- [ ] **Step 5: Run picker test and confirm GREEN**

Run from `mobile/`:

```bash
flutter test test/widgets/video_editor/audio_editor/audio_selection_bottom_sheet_test.dart --plain-name "shows import action"
```

Expected: import action test passes.

- [ ] **Step 6: Write failing render mapping test**

Add or extend provider/render tests so a selected local import produces `EditorAudio.file` instead of `EditorAudio.network`. The assertion should inspect `CompleteParameters.audioTracks` after invoking the same render-parameter path used by `renderVideo`.

Expected test shape:

```dart
test('selected local import is rendered as file audio', () {
  final sound = AudioEvent.fromLocalImport(
    id: 'local_import_1700000000000',
    filePath: '/tmp/imported/snare.mp3',
    createdAt: 1700000000,
    title: 'snare',
    mimeType: 'audio/mpeg',
    duration: 2,
  );

  final params = buildRenderParametersForTest(selectedSound: sound);

  expect(params!.audioTracks.single.audio, isA<EditorAudio>());
  expect(params.audioTracks.single.audio.safeFilePath(), completion('/tmp/imported/snare.mp3'));
});
```

- [ ] **Step 7: Implement selected local render handling**

In `_buildRenderParameters`, change selected sound audio selection:

```dart
audio: soundTrack.isBundled
    ? EditorAudio.asset(soundTrack.assetPath!)
    : soundTrack.isLocalImport && soundTrack.localFilePath != null
    ? EditorAudio.file(File(soundTrack.localFilePath!))
    : EditorAudio.network(soundTrack.url!),
```

- [ ] **Step 8: Implement timeline preview file handling**

In `VideoEditorCanvas._syncAudioTracks`, change non-bundled handling:

```dart
} else if (sound.isLocalImport && sound.localFilePath != null) {
  track = AudioTrack.file(
    sound.localFilePath!,
    volume: customVolume,
    videoStartTime: item.startTime,
    videoEndTime: item.endTime,
    trackStart: sound.startOffset,
  );
} else {
  track = AudioTrack.network(
    sound.url!,
    volume: customVolume,
    videoStartTime: item.startTime,
    videoEndTime: item.endTime,
    trackStart: sound.startOffset,
  );
}
```

- [ ] **Step 9: Run focused UI/render tests**

Run from `mobile/`:

```bash
flutter test test/widgets/video_editor/audio_editor/audio_selection_bottom_sheet_test.dart test/providers/video_editor_provider_test.dart
```

Expected: all focused tests pass.

- [ ] **Step 10: Commit picker and render handling**

Run:

```bash
git add mobile/lib/widgets/video_editor/audio_editor/audio_selection_bottom_sheet.dart mobile/lib/providers/video_editor_provider.dart mobile/lib/widgets/video_editor/main_editor/video_editor_canvas.dart mobile/test/widgets/video_editor/audio_editor/audio_selection_bottom_sheet_test.dart mobile/test/providers/video_editor_provider_test.dart
git commit -m "feat(audio): import audio from picker"
```

## Task 3: Publish Imported Audio Before Video

**Files:**
- Modify: `mobile/lib/services/video_event_publisher.dart`
- Modify: `mobile/lib/services/video_publish/video_publish_service.dart`
- Test: `mobile/test/services/video_event_publisher_test.dart`
- Test: `mobile/test/services/video_publish/video_publish_service_test.dart`

- [ ] **Step 1: Write failing publisher success test**

Add a test near selected audio reference coverage:

```dart
test('publishes local imported audio before video and tags video event', () async {
  final audioFile = File('${Directory.systemTemp.path}/imported_audio.mp3');
  await audioFile.writeAsBytes([1, 2, 3]);
  addTearDown(() {
    if (audioFile.existsSync()) audioFile.deleteSync();
  });

  final localAudio = AudioEvent.fromLocalImport(
    id: 'local_import_1700000000000',
    filePath: audioFile.path,
    createdAt: 1700000000,
    title: 'imported_audio',
    mimeType: 'audio/mpeg',
    duration: 3,
  );

  when(
    () => mockBlossomUploadService.uploadAudio(
      audioFile: any(named: 'audioFile'),
      mimeType: 'audio/mpeg',
      onProgress: any(named: 'onProgress'),
    ),
  ).thenAnswer(
    (_) async => const BlossomUploadResult(
      success: true,
      url: 'https://cdn.example/audiohash',
      fallbackUrl: 'https://cdn.example/audiohash',
      videoId: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    ),
  );

  final result = await publisher.publishVideoEvent(
    upload: completedUpload,
    selectedAudio: localAudio,
  );

  expect(result, isTrue);
  final audioEvent = signedEvents.singleWhere((event) => event.kind == audioEventKind);
  expect(audioEvent.tags, contains(['url', 'https://cdn.example/audiohash']));
  expect(audioEvent.tags, contains(['m', 'audio/mpeg']));
  expect(audioEvent.tags, contains(['x', 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa']));
  expect(audioEvent.tags, contains(['size', '3']));
  expect(audioEvent.tags, contains(['title', 'imported_audio']));

  final videoEvent = signedEvents.singleWhere((event) => event.kind != audioEventKind);
  expect(videoEvent.tags, contains(['e', audioEvent.id, 'wss://relay.divine.video', 'audio']));
});
```

- [ ] **Step 2: Run publisher success test and confirm RED**

Run from `mobile/`:

```bash
flutter test test/services/video_event_publisher_test.dart --plain-name "publishes local imported audio"
```

Expected: fail because `publishVideoEvent` does not accept `selectedAudio`.

- [ ] **Step 3: Write failing publisher failure test**

Add:

```dart
test('blocks video publish when local imported audio cannot be published', () async {
  final audioFile = File('${Directory.systemTemp.path}/missing_imported_audio.mp3');
  final localAudio = AudioEvent.fromLocalImport(
    id: 'local_import_1700000000000',
    filePath: audioFile.path,
    createdAt: 1700000000,
    title: 'missing',
    mimeType: 'audio/mpeg',
  );

  final result = await publisher.publishVideoEvent(
    upload: completedUpload,
    selectedAudio: localAudio,
  );

  expect(result, isFalse);
  expect(signedEvents.where((event) => event.kind != audioEventKind), isEmpty);
});
```

- [ ] **Step 4: Extend publisher API**

Add optional `AudioEvent? selectedAudio` to `publishVideoEvent` and `publishDirectUpload`, and pass it through:

```dart
Future<bool> publishVideoEvent({
  required PendingUpload upload,
  AudioEvent? selectedAudio,
  String? selectedAudioEventId,
  String? selectedAudioRelay,
  ...
}) async {
  return publishDirectUpload(
    updatedUpload,
    selectedAudio: selectedAudio,
    selectedAudioEventId: selectedAudioEventId,
    selectedAudioRelay: selectedAudioRelay,
    ...
  );
}
```

- [ ] **Step 5: Implement imported audio publish helper**

Add a private helper to `VideoEventPublisher`:

```dart
Future<String?> _publishImportedAudioEvent({
  required AudioEvent audio,
  required String videoDTag,
  required String pubkey,
  required String relayHint,
}) async {
  final filePath = audio.localFilePath;
  final blossomService = _blossomUploadService;
  if (filePath == null || blossomService == null) return null;

  final audioFile = File(filePath);
  if (!await audioFile.exists()) return null;

  final uploadResult = await blossomService.uploadAudio(
    audioFile: audioFile,
    mimeType: audio.mimeType ?? 'audio/mpeg',
  );
  final audioUrl = uploadResult.fallbackUrl ?? uploadResult.url;
  if (!uploadResult.success || audioUrl == null || uploadResult.videoId == null) {
    return null;
  }

  final sourceVideoReference =
      '${NIP71VideoKinds.getPreferredAddressableKind()}:$pubkey:$videoDTag';
  final publishedAudio = AudioEvent(
    id: '',
    pubkey: pubkey,
    createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    url: audioUrl,
    mimeType: audio.mimeType ?? 'audio/mpeg',
    sha256: uploadResult.videoId,
    fileSize: await audioFile.length(),
    duration: audio.duration,
    title: audio.title,
    source: audio.source,
    sourceVideoReference: sourceVideoReference,
    sourceVideoRelay: relayHint,
  );

  final signedAudioEvent = await _authService?.createAndSignEvent(
    kind: audioEventKind,
    content: '',
    tags: publishedAudio.toTags(),
  );
  if (signedAudioEvent == null) return null;

  final published = await _publishEventToNostr(signedAudioEvent);
  if (!published) return null;

  try {
    await _savedSoundsService?.saveSound(AudioEvent.fromNostrEvent(signedAudioEvent));
  } catch (e) {
    Log.warning(
      'Failed to save imported audio event to My Sounds: $e',
      name: 'VideoEventPublisher',
      category: LogCategory.video,
    );
  }

  return signedAudioEvent.id;
}
```

- [ ] **Step 6: Use imported audio helper before selected audio tag handling**

In `publishDirectUpload`, before existing selected audio id validation:

```dart
String? selectedAudioReferenceId = selectedAudioEventId;
String? selectedAudioReferenceRelay = selectedAudioRelay;

if (selectedAudio?.isLocalImport == true) {
  final userPubkey = _authService?.currentPublicKeyHex;
  final relayHint = _nostrService.connectedRelays.isNotEmpty
      ? _nostrService.connectedRelays.first
      : 'wss://relay.divine.video';
  if (userPubkey == null) return false;

  selectedAudioReferenceId = await _publishImportedAudioEvent(
    audio: selectedAudio!,
    videoDTag: dTag,
    pubkey: userPubkey,
    relayHint: relayHint,
  );
  selectedAudioReferenceRelay = relayHint;
  if (selectedAudioReferenceId == null) return false;
}
```

Then keep the existing valid event id check using `selectedAudioReferenceId` and `selectedAudioReferenceRelay`.

- [ ] **Step 7: Pass selected sound from publish service**

In `video_publish_service.dart`:

```dart
final published = await videoEventPublisher.publishVideoEvent(
  upload: pendingUpload,
  ...
  selectedAudio: draft.selectedSound,
  selectedAudioEventId: draft.selectedSound?.id,
  selectedAudioRelay: draft.selectedSound?.sourceVideoRelay,
  ...
);
```

- [ ] **Step 8: Run publisher tests and confirm GREEN**

Run from `mobile/`:

```bash
flutter test test/services/video_event_publisher_test.dart --plain-name "local imported audio"
flutter test test/services/video_publish/video_publish_service_test.dart --plain-name "selectedAudio"
```

Expected: local import publish tests pass and publish service mocks expect `selectedAudio: draft.selectedSound`.

- [ ] **Step 9: Commit publish path**

Run:

```bash
git add mobile/lib/services/video_event_publisher.dart mobile/lib/services/video_publish/video_publish_service.dart mobile/test/services/video_event_publisher_test.dart mobile/test/services/video_publish/video_publish_service_test.dart
git commit -m "feat(audio): publish imported audio before video"
```

## Task 4: Final Verification And PR Prep

**Files:**
- Potentially modify generated l10n files if `app_en.arb` changed.

- [ ] **Step 1: Run generated l10n if copy changed**

If `mobile/lib/l10n/app_en.arb` changed, run from `mobile/`:

```bash
flutter gen-l10n
flutter test test/l10n/arb_consistency_test.dart
```

Expected: generated localization files match ARB keys and consistency test passes.

- [ ] **Step 2: Run package tests touched by model changes**

Run from `mobile/packages/models/`:

```bash
flutter test
```

Expected: all `models` package tests pass.

- [ ] **Step 3: Run focused app tests**

Run from `mobile/`:

```bash
flutter test test/services/local_audio_import_service_test.dart test/widgets/video_editor/audio_editor/audio_selection_bottom_sheet_test.dart test/providers/video_editor_provider_test.dart test/services/video_event_publisher_test.dart test/services/video_publish/video_publish_service_test.dart
```

Expected: all focused app tests pass.

- [ ] **Step 4: Run analyzer**

Run from `mobile/`:

```bash
flutter analyze
```

Expected: no analyzer errors.

- [ ] **Step 5: Review diff**

Run:

```bash
git diff --stat origin/main...HEAD
git diff --check
git status --short
```

Expected: no whitespace errors; only planned files changed.

- [ ] **Step 6: Commit remaining verification/doc updates**

If final edits remain:

```bash
git add <only-files-changed-for-audio-import>
git commit -m "test(audio): cover imported audio flow"
```

- [ ] **Step 7: Rebase and push**

Run:

```bash
git fetch origin
git rebase origin/main
git push -u origin feat/audio-import --force-with-lease
```

Expected: branch pushes cleanly.

- [ ] **Step 8: Open PR**

Run:

```bash
gh pr create \
  --base main \
  --head feat/audio-import \
  --title "feat(audio): import audio for videos" \
  --body "Adds local audio file import for the video editor, publishes imported sounds as Blossom-backed Kind 1063 events before the video event, and tags videos with the published audio event."
```

Expected: PR targets `main` with a Conventional Commit title.

## Self-Review

- Spec coverage: import-only flow is covered by Tasks 1 and 2; local preview/render are covered by Task 2; publish-to-Blossom/Kind 1063/video `e` tag are covered by Task 3; draft-owned storage is covered by the `draftId` storage path in Task 1; recording, metadata editing, background upload, and cross-draft sharing stay out of scope.
- Placeholder scan: plan has no deferred behavior placeholders.
- Type consistency: the same `AudioEvent.fromLocalImport`, `isLocalImport`, and `localFilePath` API is used across model, picker, render, and publish tasks.
