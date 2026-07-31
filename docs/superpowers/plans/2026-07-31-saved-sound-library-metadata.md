# Saved Sound Library Metadata Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every device-local saved sound recognizable and organizable through retained source context, passive transcript capture, a compact waveform, a private label, and private hashtags, without publishing or syncing anything.

**Architecture:** Persist a versioned `SavedSound` wrapper around `AudioEvent`. Replace the saved-sounds Riverpod notifier with one app-scoped `SavedSoundsBloc`, keyed to the current account storage bucket. Capture only source data already in memory, save the basic record before optional media probing, and treat absent transcript/waveform data as normal.

**Tech Stack:** Flutter, Dart, `flutter_bloc`, `bloc_concurrency`, Riverpod only for dependency construction, `SharedPreferences`, existing `ProVideoEditor`, existing `SubtitleService`, existing `divine_ui`.

---

## Decision record

These decisions are constraints for implementation, not optional suggestions.

| Decision | Why this is the simplest correct choice |
|---|---|
| Keep the existing per-account `SharedPreferences` key and add a versioned payload on that key. | It survives normal upgrades, preserves account isolation, and avoids dual writes or a second migration lifecycle. |
| Wrap `AudioEvent` in an app-local `SavedSound`. | Personal metadata is library state, not Nostr audio metadata. This prevents private labels and hashtags from accidentally entering publish paths. |
| Use one app-scoped `SavedSoundsBloc`. | The library, sound-detail routes, and audio picker all consume the same state. One keyed BLoC avoids duplicate caches and obeys the requested state-management direction. |
| Keep `savedSoundsServiceProvider` only as a Riverpod dependency bridge. | Auth and `SharedPreferences` already live in Riverpod. Reusing that construction avoids an unrelated auth migration while keeping all feature state in BLoC. |
| Save the basic record before probing duration/waveform. | A decoder or network failure must never lose the user's save. The record is useful with only its audio and personal metadata. |
| Capture transcript only from `VideoEvent.textTrackContent`. | The captions are already present, so parsing is cheap. No fetch, generation, retry, polling, or user-visible transcript error is introduced. |
| Run at most one optional media probe per newly saved or legacy incomplete sound. | This preserves existing duration backfill and adds the requested waveform without creating a general enrichment system. |
| Store at most 96 normalized mono waveform samples. | That is enough for a small card, keeps JSON small, and avoids persisting raw stereo decoder output. |
| Treat personal hashtags as normalized strings. | Trimming, removing `#`, case-insensitive dedupe, and a single active filter deliver organization without inventing categories or taxonomies. |
| Keep explicit library saves separate from draft-local imports. | Importing into an edit should not silently change the user's reusable library. The existing Library “Add audio” path saves and then reveals the same details editor. |
| Use rich cards in one vertical list. | It gives enough room for context and avoids the horizontal scrolling behavior the user rejected. |
| Store proxy tags in `AudioExternalSource` as read-only catalog tags. | The proxy already returns them. Retaining them needs no backend API or cross-device write behavior. |

## File map

### Create

- `mobile/lib/models/saved_sound.dart`
- `mobile/lib/blocs/saved_sounds/saved_sounds_bloc.dart`
- `mobile/lib/blocs/saved_sounds/saved_sounds_event.dart`
- `mobile/lib/blocs/saved_sounds/saved_sounds_state.dart`
- `mobile/lib/blocs/saved_sounds/saved_sound_media_probe.dart`
- `mobile/lib/blocs/saved_sounds/saved_sounds_scope.dart`
- `mobile/lib/services/saved_sound_context_builder.dart`
- `mobile/lib/widgets/library/saved_sound_card.dart`
- `mobile/lib/widgets/library/saved_sound_details_editor.dart`
- `mobile/test/models/saved_sound_test.dart`
- `mobile/test/blocs/saved_sounds/saved_sounds_bloc_test.dart`
- `mobile/test/blocs/saved_sounds/saved_sound_media_probe_test.dart`
- `mobile/test/blocs/saved_sounds/saved_sounds_scope_test.dart`
- `mobile/test/services/saved_sound_context_builder_test.dart`
- `mobile/test/widgets/library/saved_sound_card_test.dart`
- `mobile/test/widgets/library/saved_sound_details_editor_test.dart`

### Modify

- `mobile/packages/models/lib/src/audio_event.dart`
- `mobile/packages/models/test/src/audio_event_test.dart`
- `mobile/packages/sounds_repository/lib/src/sound_library_api_client.dart`
- `mobile/packages/sounds_repository/test/src/sound_library_api_client_test.dart`
- `mobile/lib/services/saved_sounds_service.dart`
- `mobile/test/services/saved_sounds_service_test.dart`
- `mobile/lib/providers/saved_sounds_provider.dart`
- `mobile/lib/main.dart`
- `mobile/lib/screens/sound_detail_screen.dart`
- `mobile/test/screens/sound_detail_screen_test.dart`
- `mobile/lib/widgets/library/sounds_tab.dart`
- `mobile/test/widgets/library/sounds_tab_test.dart`
- `mobile/lib/widgets/video_editor/audio_editor/audio_selection_bottom_sheet.dart`
- `mobile/test/widgets/video_editor/audio_editor/audio_selection_bottom_sheet_test.dart`
- `mobile/lib/widgets/video_feed_item/audio_attribution_row.dart`
- `mobile/lib/widgets/video_feed_item/metadata/metadata_sounds_section.dart`
- their existing mirrored widget tests
- `mobile/lib/l10n/app_en.arb`
- every other `mobile/lib/l10n/app_*.arb`, or the approved untranslated-debt list
- generated localization files

### Remove

- `mobile/test/providers/saved_sounds_provider_test.dart`
- the `savedSoundsProvider` notifier and `SavedSoundsNotifier` from `mobile/lib/providers/saved_sounds_provider.dart`

Do not remove `savedSoundsServiceProvider`; publishing currently consumes the persistence dependency and does not need saved-sound UI state.

## Task 1: Add the local saved-sound value model

**Files:**

- Create: `mobile/lib/models/saved_sound.dart`
- Test: `mobile/test/models/saved_sound_test.dart`

- [ ] Write failing tests for:

  - full JSON round trip;
  - a source-less/music-only record;
  - nullable `savedAt` for legacy data;
  - normalized personal hashtags;
  - unknown JSON fields being ignored;
  - full Nostr IDs remaining unchanged.

- [ ] Run the test and confirm it fails because the model does not exist:

```bash
cd mobile
flutter test test/models/saved_sound_test.dart
```

- [ ] Implement immutable manual-JSON models with no generator:

```dart
@immutable
class SavedSoundLibraryPayload {
  const SavedSoundLibraryPayload({
    required this.schemaVersion,
    required this.sounds,
  });

  static const currentSchemaVersion = 1;

  final int schemaVersion;
  final List<SavedSound> sounds;
}

@immutable
class SavedSound {
  const SavedSound({
    required this.audio,
    required this.personalHashtags,
    required this.catalogTags,
    required this.waveformSamples,
    this.savedAt,
    this.personalLabel,
    this.sourceContext,
  });

  final AudioEvent audio;
  final DateTime? savedAt;
  final String? personalLabel;
  final List<String> personalHashtags;
  final SavedSoundSourceContext? sourceContext;
  final List<String> catalogTags;
  final List<double> waveformSamples;

  String get id => audio.id;
}

@immutable
class SavedSoundSourceContext {
  const SavedSoundSourceContext({
    this.videoEventId,
    this.creatorPubkey,
    this.creatorName,
    this.title,
    this.description,
    this.thumbnailUrl,
    this.transcript,
  });

  final String? videoEventId;
  final String? creatorPubkey;
  final String? creatorName;
  final String? title;
  final String? description;
  final String? thumbnailUrl;
  final String? transcript;
}
```

- [ ] Add pure helpers:

```dart
List<String> normalizeSavedSoundHashtags(Iterable<String> values) {
  final seen = <String>{};
  return [
    for (final raw in values)
      if (raw.trim().replaceFirst(RegExp(r'^#+'), '').trim().isNotEmpty)
        if (seen.add(
          raw
              .trim()
              .replaceFirst(RegExp(r'^#+'), '')
              .trim()
              .toLowerCase(),
        ))
          raw
              .trim()
              .replaceFirst(RegExp(r'^#+'), '')
              .trim()
              .toLowerCase(),
  ];
}
```

`copyWith` must support explicitly clearing `personalLabel`; use a private
sentinel rather than `value ?? oldValue`.

- [ ] Run the focused test and formatting:

```bash
cd mobile
dart format lib/models/saved_sound.dart test/models/saved_sound_test.dart
flutter test test/models/saved_sound_test.dart
```

- [ ] Commit:

```bash
git add mobile/lib/models/saved_sound.dart mobile/test/models/saved_sound_test.dart
git commit -m "feat(sounds): add saved sound metadata model"
```

## Task 2: Retain catalog tags from `divine-sound-proxy`

**Files:**

- Modify: `mobile/packages/models/lib/src/audio_event.dart`
- Modify: `mobile/packages/models/test/src/audio_event_test.dart`
- Modify: `mobile/packages/sounds_repository/lib/src/sound_library_api_client.dart`
- Modify: `mobile/packages/sounds_repository/test/src/sound_library_api_client_test.dart`

- [ ] Add failing model tests proving `AudioExternalSource.catalogTags` survives `AudioEvent.toJson()` and `AudioEvent.fromJson()`.

- [ ] Add a failing client test with a proxy row containing:

```json
{"tags":["field recording","birds","birds"]}
```

Assert the mapped event contains `["field recording", "birds"]`.

- [ ] Run the two focused package tests and confirm the new assertions fail:

```bash
cd mobile/packages/models
flutter test test/src/audio_event_test.dart
cd ../sounds_repository
flutter test test/src/sound_library_api_client_test.dart
```

- [ ] Add the field with an empty default so old drafts and cached sounds still decode:

```dart
const AudioExternalSource({
  required this.provider,
  required this.providerSoundId,
  required this.providerName,
  required this.license,
  this.catalogTags = const [],
  // existing optional fields
});

final List<String> catalogTags;
```

Serialize `catalogTags` and parse only strings, trimmed and deduplicated. In
`_soundFromJson`, map `json['tags']` into that field. Do not add a proxy write
endpoint.

- [ ] Re-run both tests:

```bash
cd mobile/packages/models
flutter test test/src/audio_event_test.dart
cd ../sounds_repository
flutter test test/src/sound_library_api_client_test.dart
```

- [ ] Commit:

```bash
git add mobile/packages/models/lib/src/audio_event.dart mobile/packages/models/test/src/audio_event_test.dart mobile/packages/sounds_repository/lib/src/sound_library_api_client.dart mobile/packages/sounds_repository/test/src/sound_library_api_client_test.dart
git commit -m "feat(sounds): retain proxy catalog tags"
```

## Task 3: Migrate persistence to a versioned payload

**Files:**

- Modify: `mobile/lib/services/saved_sounds_service.dart`
- Modify: `mobile/test/services/saved_sounds_service_test.dart`

- [ ] Change service tests first so the public contract is `List<SavedSound>`.

- [ ] Add failing tests for:

  - reading the old bare `List<AudioEvent>` as records with empty metadata and `savedAt == null`;
  - writing `{schemaVersion: 1, sounds: [...]}` after the next save or edit;
  - preserving order and full IDs during migration;
  - skipping one corrupt record without dropping valid neighbors;
  - replacing metadata by full sound ID without duplicating;
  - `setString` returning `false` causing the mutation to throw and not report success;
  - signed-in and anonymous bucket isolation;
  - the existing device-wide consent migration still filtering `video_*` records.

- [ ] Run and confirm failure:

```bash
cd mobile
flutter test test/services/saved_sounds_service_test.dart
```

- [ ] Change the service API:

```dart
List<SavedSound> loadSounds();

Future<SavedSoundSaveResult> saveSound(SavedSound sound);

Future<void> replaceSound(SavedSound sound);

Future<void> removeSound(String soundId);

Future<void> replaceAll(List<SavedSound> sounds);
```

- [ ] Implement a tolerant reader:

```dart
final decoded = jsonDecode(raw);
final entries = switch (decoded) {
  List<dynamic> legacy => legacy.map(
      (json) => SavedSound.fromLegacy(
        AudioEvent.fromJson(Map<String, dynamic>.from(json as Map)),
      ),
    ),
  Map<String, dynamic> payload => (payload['sounds'] as List<dynamic>).map(
      (json) => SavedSound.fromJson(
        Map<String, dynamic>.from(json as Map),
      ),
    ),
  _ => const Iterable<SavedSound>.empty(),
};
```

Keep the per-entry `try/catch`; do not let one malformed entry erase the
bucket.

- [ ] Make writes explicit about failure:

```dart
final written = await _preferences.setString(storageKey, encoded);
if (!written) {
  throw StateError('Failed to persist saved sounds');
}
```

The legacy device-wide migration must continue checking its own write before
removing the legacy key.

- [ ] Run focused tests:

```bash
cd mobile
dart format lib/services/saved_sounds_service.dart test/services/saved_sounds_service_test.dart
flutter test test/services/saved_sounds_service_test.dart
```

- [ ] Commit:

```bash
git add mobile/lib/services/saved_sounds_service.dart mobile/test/services/saved_sounds_service_test.dart
git commit -m "feat(sounds): version saved sound persistence"
```

## Task 4: Capture source context and passive transcripts

**Files:**

- Create: `mobile/lib/services/saved_sound_context_builder.dart`
- Create: `mobile/test/services/saved_sound_context_builder_test.dart`

This is a new file under `mobile/lib/services`, so its same-named test is
mandatory.

- [ ] Write failing tests for:

  - title, description, thumbnail, creator pubkey/name, and full event ID;
  - embedded VTT cues becoming readable transcript text;
  - adjacent duplicate cue text being emitted once;
  - null/empty/malformed `textTrackContent` producing `transcript == null`;
  - no network or transcription collaborator existing in the API.

- [ ] Run and confirm failure:

```bash
cd mobile
flutter test test/services/saved_sound_context_builder_test.dart
```

- [ ] Implement a synchronous builder around the existing parser:

```dart
class SavedSoundContextBuilder {
  const SavedSoundContextBuilder();

  SavedSoundSourceContext fromVideo(
    VideoEvent video, {
    String? creatorName,
  }) {
    return SavedSoundSourceContext(
      videoEventId: video.id,
      creatorPubkey: video.pubkey,
      creatorName: creatorName,
      title: video.displayTitle,
      description: _nonBlank(video.content),
      thumbnailUrl: video.effectiveThumbnailUrl,
      transcript: _transcript(video.textTrackContent),
    );
  }

  String? _transcript(String? vtt) {
    if (vtt == null || vtt.trim().isEmpty) return null;
    final lines = <String>[];
    for (final cue in SubtitleService.parseVtt(vtt)) {
      final text = cue.text.trim();
      if (text.isNotEmpty && (lines.isEmpty || lines.last != text)) {
        lines.add(text);
      }
    }
    return lines.isEmpty ? null : lines.join(' ');
  }
}
```

Use the existing `VideoEvent.effectiveThumbnailUrl`; do not add another
thumbnail-resolution abstraction.

- [ ] Run the service test and the service-floor guard:

```bash
cd mobile
flutter test test/services/saved_sound_context_builder_test.dart
UPDATE_BASELINE=1 bash scripts/check_untested_services_floor.sh
git diff -- scripts/baseline/untested_services.txt
```

The baseline should not grow. If the new tested service does not change it,
do not stage it.

- [ ] Commit:

```bash
git add mobile/lib/services/saved_sound_context_builder.dart mobile/test/services/saved_sound_context_builder_test.dart
git commit -m "feat(sounds): snapshot source context on save"
```

## Task 5: Add the optional duration/waveform media probe

**Files:**

- Create: `mobile/lib/blocs/saved_sounds/saved_sound_media_probe.dart`
- Create: `mobile/test/blocs/saved_sounds/saved_sound_media_probe_test.dart`

- [ ] Write failing tests for:

  - asset, file, and network `AudioEvent.resolvedSource` mapping;
  - combining stereo amplitudes into one non-negative channel;
  - downsampling to at most 96 samples;
  - preserving duration returned with waveform data;
  - waveform failure falling back to metadata duration;
  - complete failure returning no enrichment and not throwing.

- [ ] Run and confirm failure:

```bash
cd mobile
flutter test test/blocs/saved_sounds/saved_sound_media_probe_test.dart
```

- [ ] Define an injectable boundary:

```dart
abstract interface class SavedSoundMediaProbe {
  Future<SavedSoundMediaResult?> probe(AudioEvent sound);
}

@immutable
class SavedSoundMediaResult {
  const SavedSoundMediaResult({
    required this.waveformSamples,
    this.durationSeconds,
  });

  final double? durationSeconds;
  final List<double> waveformSamples;
}
```

The production implementation uses `ProVideoEditor.getWaveform` once. Convert
left/right `Float32List` values into at most 96 mono samples by averaging the
absolute peak in each evenly sized bucket. If waveform extraction fails, call
the existing metadata API only when duration is missing.

- [ ] Do not log the sound URL, transcript, label, hashtags, or truncated ID.
If a diagnostic is retained, use the full sound ID and a generic failure.

- [ ] Run focused tests:

```bash
cd mobile
dart format lib/blocs/saved_sounds/saved_sound_media_probe.dart test/blocs/saved_sounds/saved_sound_media_probe_test.dart
flutter test test/blocs/saved_sounds/saved_sound_media_probe_test.dart
```

- [ ] Commit:

```bash
git add mobile/lib/blocs/saved_sounds/saved_sound_media_probe.dart mobile/test/blocs/saved_sounds/saved_sound_media_probe_test.dart
git commit -m "feat(sounds): probe compact saved waveforms"
```

## Task 6: Replace saved-sound state with BLoC

**Files:**

- Create: `mobile/lib/blocs/saved_sounds/saved_sounds_bloc.dart`
- Create: `mobile/lib/blocs/saved_sounds/saved_sounds_event.dart`
- Create: `mobile/lib/blocs/saved_sounds/saved_sounds_state.dart`
- Create: `mobile/test/blocs/saved_sounds/saved_sounds_bloc_test.dart`
- Modify: `mobile/lib/providers/saved_sounds_provider.dart`
- Remove: `mobile/test/providers/saved_sounds_provider_test.dart`

- [ ] Write failing BLoC tests for:

  - initial load;
  - newest-first save with synchronous source context and proxy tags;
  - duplicate save returning `alreadySaved`;
  - basic save completing before a controlled media-probe completer finishes;
  - successful probe replacing the same full ID with duration/waveform;
  - failed probe leaving no error state;
  - autosaving label and normalized hashtags;
  - edit failure retaining optimistic typed values and marking only that record
    as unsaved;
  - removal;
  - query matching label, title, creator, description, transcript, personal
    hashtags, and catalog tags;
  - one selected hashtag filter and clear.

- [ ] Run and confirm failure:

```bash
cd mobile
flutter test test/blocs/saved_sounds/saved_sounds_bloc_test.dart
```

- [ ] Use event-driven state:

```dart
sealed class SavedSoundsEvent extends Equatable {
  const SavedSoundsEvent();
}

final class SavedSoundsLoadRequested extends SavedSoundsEvent {
  const SavedSoundsLoadRequested();
}

final class SavedSoundSaveRequested extends SavedSoundsEvent {
  const SavedSoundSaveRequested({
    required this.sound,
    required this.completer,
    this.sourceContext,
  });

  final AudioEvent sound;
  final SavedSoundSourceContext? sourceContext;
  final Completer<SavedSoundSaveResult> completer;
}

final class SavedSoundDetailsChanged extends SavedSoundsEvent {
  const SavedSoundDetailsChanged({
    required this.soundId,
    required this.label,
    required this.hashtags,
  });

  final String soundId;
  final String? label;
  final List<String> hashtags;
}
```

Also add remove, query-change, hashtag-select, and private probe-completed
events.

- [ ] Keep a convenience method for callers that need save completion:

```dart
Future<SavedSoundSaveResult> saveSound(
  AudioEvent sound, {
  SavedSoundSourceContext? sourceContext,
}) {
  final completer = Completer<SavedSoundSaveResult>();
  add(
    SavedSoundSaveRequested(
      sound: sound,
      sourceContext: sourceContext,
      completer: completer,
    ),
  );
  return completer.future;
}
```

- [ ] Construct the record before any `await`:

```dart
final record = SavedSound(
  audio: event.sound,
  savedAt: _now().toUtc(),
  personalHashtags: const [],
  catalogTags: event.sound.externalSource?.catalogTags ?? const [],
  waveformSamples: const [],
  sourceContext: event.sourceContext,
);
final result = await _service.saveSound(record);
```

Inject `DateTime Function()` into the BLoC constructor, defaulting to
`DateTime.now`, so ordering tests do not wait on the wall clock.

After that durable write completes, emit the loaded bucket and launch the
probe. The BLoC owns one immutable service/account bucket for its lifetime.
After every `await`, check `emit.isDone` before emitting; when the keyed scope
closes account A's BLoC, its captured write may finish only in A's bucket and
can never update account B's BLoC state.

- [ ] Use `sequential()` for write events so debounced edits remain ordered.
Query and filter events are synchronous and need no concurrency transformer.

- [ ] State owns filtering:

```dart
List<SavedSound> get visibleSounds => sounds.where((sound) {
  final matchesTag = selectedHashtag == null ||
      sound.personalHashtags.contains(selectedHashtag);
  return matchesTag && sound.matchesQuery(query);
}).toList(growable: false);
```

- [ ] Reduce `mobile/lib/providers/saved_sounds_provider.dart` to
`savedSoundsServiceProvider` only. Do not migrate unrelated auth providers.

- [ ] Run tests:

```bash
cd mobile
dart format lib/blocs/saved_sounds test/blocs/saved_sounds lib/providers/saved_sounds_provider.dart
flutter test test/blocs/saved_sounds/saved_sounds_bloc_test.dart
```

- [ ] Commit:

```bash
git add mobile/lib/blocs/saved_sounds mobile/test/blocs/saved_sounds mobile/lib/providers/saved_sounds_provider.dart
git rm mobile/test/providers/saved_sounds_provider_test.dart
git commit -m "refactor(sounds): manage saved library with bloc"
```

## Task 7: Provide the account-keyed BLoC app-wide

**Files:**

- Create: `mobile/lib/blocs/saved_sounds/saved_sounds_scope.dart`
- Create: `mobile/test/blocs/saved_sounds/saved_sounds_scope_test.dart`
- Modify: `mobile/lib/main.dart`

- [ ] Write a failing widget test that rebuilds the scope with storage key A
and then B, asserting the A BLoC closes and B loads only B's records.

- [ ] Run and confirm failure:

```bash
cd mobile
flutter test test/blocs/saved_sounds/saved_sounds_scope_test.dart
```

- [ ] Implement a small bridge:

```dart
class SavedSoundsScope extends StatelessWidget {
  const SavedSoundsScope({
    required this.service,
    required this.child,
    super.key,
  });

  final SavedSoundsService service;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SavedSoundsBloc>(
      key: ValueKey(service.storageKey),
      lazy: false,
      create: (_) => SavedSoundsBloc(
        service: service,
        mediaProbe: ProVideoEditorSavedSoundMediaProbe(),
      )..add(const SavedSoundsLoadRequested()),
      child: child,
    );
  }
}
```

- [ ] In `mobile/lib/main.dart`, watch `savedSoundsServiceProvider` alongside
the existing app dependencies and wrap the existing repository/BLoC tree with
`SavedSoundsScope`. Do not duplicate it inside `LibraryScreen`; route and modal
descendants must share the same instance.

- [ ] Run the scope test and targeted analyze:

```bash
cd mobile
flutter test test/blocs/saved_sounds/saved_sounds_scope_test.dart
flutter analyze lib/blocs/saved_sounds lib/main.dart
```

- [ ] Commit:

```bash
git add mobile/lib/blocs/saved_sounds/saved_sounds_scope.dart mobile/test/blocs/saved_sounds/saved_sounds_scope_test.dart mobile/lib/main.dart
git commit -m "feat(sounds): scope saved library bloc by account"
```

## Task 8: Capture source context at the real navigation/save boundaries

**Files:**

- Modify: `mobile/lib/widgets/video_feed_item/audio_attribution_row.dart`
- Modify: `mobile/test/widgets/audio_attribution_row_test.dart`
- Modify: `mobile/lib/widgets/video_feed_item/metadata/metadata_sounds_section.dart`
- Modify: `mobile/test/widgets/metadata_sounds_section_test.dart`
- Modify: `mobile/lib/screens/sound_detail_screen.dart`
- Modify: `mobile/test/screens/sound_detail_screen_test.dart`

- [ ] Add failing navigation tests asserting route extras include both:

```dart
<String, dynamic>{
  'sound': audio,
  'sourceVideo': video,
}
```

where the current widget already holds the source `VideoEvent`.

- [ ] Add failing sound-detail tests asserting:

  - save calls the global `SavedSoundsBloc`;
  - source context is built synchronously when `sourceVideo` exists;
  - absent `sourceVideo` still saves normally;
  - save publishes no Nostr event;
  - after a new save, the personal-details editor becomes visible.

- [ ] Run the smallest mirrored tests found by `rg` plus:

```bash
cd mobile
flutter test test/screens/sound_detail_screen_test.dart
```

- [ ] Pass the source video from feed attribution and metadata sound rows.
Keep deep-link loader behavior unchanged: if it has only an `AudioEvent`, save
without source context rather than adding a new fetch pipeline.

- [ ] Replace notifier calls with:

```dart
final result = await context.read<SavedSoundsBloc>().saveSound(
  widget.sound,
  sourceContext: widget.sourceVideo == null
      ? null
      : const SavedSoundContextBuilder().fromVideo(widget.sourceVideo!),
);
```

Do not generate a transcript and do not display a missing-transcript warning.

- [ ] Run tests and format:

```bash
cd mobile
dart format lib/screens/sound_detail_screen.dart lib/widgets/video_feed_item/audio_attribution_row.dart lib/widgets/video_feed_item/metadata/metadata_sounds_section.dart
flutter test test/screens/sound_detail_screen_test.dart
```

- [ ] Commit:

```bash
git add mobile/lib/screens/sound_detail_screen.dart mobile/test/screens/sound_detail_screen_test.dart mobile/lib/widgets/video_feed_item/audio_attribution_row.dart mobile/test/widgets/audio_attribution_row_test.dart mobile/lib/widgets/video_feed_item/metadata/metadata_sounds_section.dart mobile/test/widgets/metadata_sounds_section_test.dart
git commit -m "feat(sounds): retain source post context"
```

Before committing, inspect the staged paths with `git status --short`.

## Task 9: Add the reusable autosaving details editor

**Files:**

- Create: `mobile/lib/widgets/library/saved_sound_details_editor.dart`
- Create: `mobile/test/widgets/library/saved_sound_details_editor_test.dart`
- Modify: `mobile/lib/screens/sound_detail_screen.dart`
- Modify: `mobile/test/screens/sound_detail_screen_test.dart`

- [ ] Write failing widget tests for:

  - initial label and hashtags;
  - label changes dispatching one edit after a 350 ms debounce;
  - Enter/comma/space committing a hashtag;
  - leading `#`, case-insensitive duplicates, and blanks being normalized;
  - removing a hashtag;
  - disposal cancelling the timer;
  - a failed persistence state keeping typed content visible with a concise
    retry affordance.

- [ ] Run and confirm failure:

```bash
cd mobile
flutter test test/widgets/library/saved_sound_details_editor_test.dart
```

- [ ] Build the editor from existing `divine_ui` input/button components. It
must dispatch `SavedSoundDetailsChanged` after 350 ms of inactivity and on
focus loss. There is no Save button because the user chose autosave.

- [ ] Render it in `SoundDetailScreen` immediately after a successful new save,
and when editing an already-saved record. Do not gate the original save on
editor completion.

- [ ] Add localized copy for “Your label”, “Add hashtags”, “Saved on this
device”, and the concise retry message. Follow the localization task below
before considering this task complete.

- [ ] Run tests:

```bash
cd mobile
dart format lib/widgets/library/saved_sound_details_editor.dart test/widgets/library/saved_sound_details_editor_test.dart
flutter test test/widgets/library/saved_sound_details_editor_test.dart test/screens/sound_detail_screen_test.dart
```

- [ ] Commit:

```bash
git add mobile/lib/widgets/library/saved_sound_details_editor.dart mobile/test/widgets/library/saved_sound_details_editor_test.dart mobile/lib/screens/sound_detail_screen.dart mobile/test/screens/sound_detail_screen_test.dart
git commit -m "feat(sounds): autosave personal sound details"
```

## Task 10: Build rich vertical cards

**Files:**

- Create: `mobile/lib/widgets/library/saved_sound_card.dart`
- Create: `mobile/test/widgets/library/saved_sound_card_test.dart`

- [ ] Write failing widget tests for:

  - thumbnail, personal label, source title, creator, description;
  - transcript excerpt only when present;
  - waveform only when samples are present;
  - personal hashtags and read-only catalog tags;
  - music-only/source-less fallback with no transcript error;
  - thumbnail failure fallback;
  - semantic label containing display title and duration;
  - preview, edit, and remove callbacks remaining distinct.

- [ ] Run and confirm failure:

```bash
cd mobile
flutter test test/widgets/library/saved_sound_card_test.dart
```

- [ ] Build a small widget-class tree, not widget-returning helper methods.
Use:

  - `VineCachedImage` for thumbnail;
  - `VineTheme` typography/colors;
  - `DivineIconButton` for actions;
  - `StereoWaveformPainter` with `Float32List.fromList(samples)` and equal
    active/inactive non-progress colors, or a smaller shared sanctioned painter
    if the existing API cannot render a static waveform cleanly;
  - `Wrap` for tags so no horizontal scroller is introduced.

- [ ] Keep hierarchy deterministic:

  1. personal label;
  2. source title;
  3. audio title fallback;
  4. localized “Saved sound”.

- [ ] Run the card test and design-system guards:

```bash
cd mobile
flutter test test/widgets/library/saved_sound_card_test.dart
bash scripts/check_raw_textstyle_ceiling.sh
bash scripts/check_raw_colors_ceiling.sh
bash scripts/check_material_button_ceiling.sh
bash scripts/check_raw_dialog_ceiling.sh
```

- [ ] Commit:

```bash
git add mobile/lib/widgets/library/saved_sound_card.dart mobile/test/widgets/library/saved_sound_card_test.dart
git commit -m "feat(sounds): add rich saved sound cards"
```

## Task 11: Convert the Sounds tab and audio picker to BLoC records

**Files:**

- Modify: `mobile/lib/widgets/library/sounds_tab.dart`
- Modify: `mobile/test/widgets/library/sounds_tab_test.dart`
- Modify: `mobile/lib/widgets/video_editor/audio_editor/audio_selection_bottom_sheet.dart`
- Modify: `mobile/test/widgets/video_editor/audio_editor/audio_selection_bottom_sheet_test.dart`

- [ ] Rewrite tests first to provide `SavedSoundsBloc` and assert:

  - cards come from `state.visibleSounds`;
  - search dispatches `SavedSoundsQueryChanged`;
  - tapping a personal hashtag applies and clears one filter;
  - catalog tags are searchable but do not appear as personal filter choices;
  - edit expands the shared editor in the vertical flow;
  - remove dispatches the full ID;
  - Library “Add audio” durably saves first and then reveals the editor;
  - the audio picker displays/selects `record.audio`;
  - draft-local import alone still does not add to the saved library.

- [ ] Run and confirm failure:

```bash
cd mobile
flutter test test/widgets/library/sounds_tab_test.dart test/widgets/video_editor/audio_editor/audio_selection_bottom_sheet_test.dart
```

- [ ] Convert `SoundsTab` from watching `savedSoundsProvider` to:

```dart
BlocBuilder<SavedSoundsBloc, SavedSoundsState>(
  builder: (context, state) {
    return SavedSoundsList(
      sounds: state.visibleSounds,
      selectedHashtag: state.selectedHashtag,
    );
  },
)
```

The widget may remain a `ConsumerStatefulWidget` because audio playback and
the existing picker dependency still use Riverpod; saved-sound state must not.

- [ ] Replace `SoundTile` only in the saved library with `SavedSoundCard`.
Do not redesign shared sound search rows.

- [ ] In the audio picker, map:

```dart
final savedSounds = context
    .watch<SavedSoundsBloc>()
    .state
    .sounds
    .map((record) => record.audio)
    .toList(growable: false);
```

- [ ] Run tests:

```bash
cd mobile
dart format lib/widgets/library/sounds_tab.dart lib/widgets/video_editor/audio_editor/audio_selection_bottom_sheet.dart
flutter test test/widgets/library/sounds_tab_test.dart test/widgets/video_editor/audio_editor/audio_selection_bottom_sheet_test.dart
```

- [ ] Commit:

```bash
git add mobile/lib/widgets/library/sounds_tab.dart mobile/test/widgets/library/sounds_tab_test.dart mobile/lib/widgets/video_editor/audio_editor/audio_selection_bottom_sheet.dart mobile/test/widgets/video_editor/audio_editor/audio_selection_bottom_sheet_test.dart
git commit -m "feat(sounds): browse and organize saved sounds"
```

## Task 12: Localize and verify the finished feature

**Files:**

- Modify: `mobile/lib/l10n/app_en.arb`
- Modify: every other `mobile/lib/l10n/app_*.arb`, or
  `mobile/test/l10n/arb_consistency_test.dart`
- Modify: generated localization outputs
- Update intentional goldens only if the existing golden harness covers these
  screens

- [ ] Add final user-facing strings. Prefer direct copy:

  - `Your label`
  - `Add hashtags`
  - `Saved on this device`
  - `Couldn’t save those details. Tap to retry.`
  - `Saved sound`
  - `Clear hashtag filter`

- [ ] Mirror keys into every locale. If translations are intentionally
deferred, add only those exact keys to `_knownUntranslatedDebt`; do not leave
locale files structurally inconsistent.

- [ ] Generate localizations and run consistency:

```bash
cd mobile
flutter gen-l10n
flutter test test/l10n/arb_consistency_test.dart
```

- [ ] Run all focused tests:

```bash
cd mobile
flutter test test/models/saved_sound_test.dart
flutter test test/services/saved_sounds_service_test.dart test/services/saved_sound_context_builder_test.dart
flutter test test/blocs/saved_sounds
flutter test test/widgets/library/saved_sound_card_test.dart test/widgets/library/saved_sound_details_editor_test.dart test/widgets/library/sounds_tab_test.dart
flutter test test/screens/sound_detail_screen_test.dart test/widgets/video_editor/audio_editor/audio_selection_bottom_sheet_test.dart
```

- [ ] Run package tests required by touched packages:

```bash
cd mobile/packages/models
flutter test test/src/audio_event_test.dart
cd ../sounds_repository
flutter test test/src/sound_library_api_client_test.dart
```

- [ ] Run static and repository guards:

```bash
cd mobile
flutter analyze
bash scripts/check_untested_services_floor.sh
bash scripts/check_raw_textstyle_ceiling.sh
bash scripts/check_raw_colors_ceiling.sh
bash scripts/check_material_button_ceiling.sh
bash scripts/check_raw_dialog_ceiling.sh
bash scripts/check_test_unit_structure.sh
```

- [ ] Run visual verification:

```bash
cd mobile
scripts/golden.sh verify
```

If a golden changes intentionally, inspect the rendered image before updating
and commit only the relevant result.

- [ ] Prove local-only behavior with a final diff search:

```bash
git diff origin/main...HEAD -- mobile | rg -n "publish|Event\\(|sendEvent|relay|analytics"
```

Any match must be an unchanged context line, a test assertion proving no
publish, or an existing import. The implementation must not add a saved-sound
Nostr event, proxy mutation, or analytics payload containing personal data.

- [ ] Review the complete diff and status:

```bash
git diff --check
git status --short
git diff --stat origin/main...HEAD
git diff origin/main...HEAD
```

- [ ] Commit localization/generated/golden changes:

```bash
git add mobile/lib/l10n mobile/test/l10n mobile/test/goldens
git commit -m "test(sounds): verify saved library metadata"
```

Stage only paths that actually changed.

## Task 13: Rebase and prepare the pull request

- [ ] Confirm every intended change is committed and the worktree is clean:

```bash
git status --short
```

- [ ] Fetch and rebase on fresh `origin/main`:

```bash
git fetch origin
git rebase origin/main
```

- [ ] Re-run the focused tests and `flutter analyze` after the rebase.

- [ ] Push with lease:

```bash
git push --force-with-lease -u origin feat/sound-library-metadata
```

- [ ] Open one PR targeting `main` with a semantic title:

```bash
gh pr create --base main --title "feat(sounds): make saved sounds recognizable" --body $'## Summary\n- migrate the device-local saved-sound library to versioned metadata records\n- manage saved sounds with an account-keyed BLoC\n- retain available source context, transcripts, compact waveforms, and proxy tags\n- autosave private labels and hashtags without publishing or syncing them\n\n## Verification\n- focused model, service, BLoC, widget, and package tests\n- localization consistency and golden verification\n- flutter analyze and repository guards'
```

The PR body must separately call out:

  - device-local/versioned persistence and legacy migration;
  - BLoC state ownership;
  - retained proxy/source metadata;
  - passive transcript and best-effort waveform behavior;
  - private autosaved label/hashtags;
  - tests and no-publish guarantee.

- [ ] Follow `/Users/rabble/code/divine/divine-context/PR_REVIEW.md` and
`/Users/rabble/code/divine/divine-context/PR_REVIEW_TEAMS.md` before requesting
review. If those files cannot be trusted because the context checkout is dirty
or stale, leave the PR open and report that review automation is blocked.

## Definition of done

- Existing saved sounds survive the upgrade and remain account-separated.
- A save is durable before optional waveform work starts.
- No Nostr event, proxy write, sync record, or personal-data analytics event is
created by saving or editing library metadata.
- Source thumbnail/title/description/creator and proxy tags are retained when
already available.
- Embedded captions become a passive transcript snapshot; music/no-caption
sounds show no transcript section and no error.
- Personal labels and hashtags autosave locally and remain editable.
- Search covers all retained metadata; personal hashtags provide tappable
filters.
- Rich cards are a vertical list and include optional thumbnail/waveform.
- Saved-sound state is owned by BLoC and switches cleanly with accounts.
- Focused tests, package tests, localization consistency, goldens, guards, and
`flutter analyze` pass.
- The branch is rebased, committed, pushed, and opened as one PR to `main`.
