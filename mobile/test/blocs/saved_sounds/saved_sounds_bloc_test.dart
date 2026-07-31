// ABOUTME: Tests the BLoC owning device-local saved sound library state.
// ABOUTME: Covers durable saves, optional enrichment, edits, search, and removal.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/saved_sounds/saved_sound_media_probe.dart';
import 'package:openvine/blocs/saved_sounds/saved_sounds_bloc.dart';
import 'package:openvine/models/saved_sound.dart';
import 'package:openvine/services/saved_sounds_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ControlledProbe implements SavedSoundMediaProbe {
  final calls = <AudioEvent>[];
  Completer<SavedSoundMediaResult?>? completer;
  SavedSoundMediaResult? result;

  @override
  Future<SavedSoundMediaResult?> probe(AudioEvent sound) {
    calls.add(sound);
    final controlled = completer;
    return controlled?.future ?? Future.value(result);
  }
}

AudioEvent _sound({
  String id = 'sound-1',
  String title = 'Rain Guitar',
  List<String> tags = const ['field recording'],
}) => AudioEvent(
  id: id,
  pubkey: 'creator',
  createdAt: 1,
  title: title,
  url: 'https://example.com/$id.m4a',
  externalSource: AudioExternalSource(
    provider: 'freesound',
    providerSoundId: id,
    providerName: 'Freesound',
    license: const AudioLicenseMetadata(
      type: 'cc0',
      name: 'CC0',
      url: 'https://creativecommons.org/publicdomain/zero/1.0/',
      allowsCommercialUse: true,
      allowsDerivatives: true,
      requiresAttribution: false,
    ),
    catalogTags: tags,
  ),
);

Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  late SavedSoundsService service;
  late _ControlledProbe probe;
  late SavedSoundsBloc bloc;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    service = SavedSoundsService(await SharedPreferences.getInstance());
    probe = _ControlledProbe();
    bloc = SavedSoundsBloc(
      service: service,
      mediaProbe: probe,
      now: () => DateTime.utc(2026, 7, 31),
    );
  });

  tearDown(() => bloc.close());

  test('loads persisted records', () async {
    await service.saveSavedSound(
      SavedSound.fromLegacy(_sound(id: 'existing')),
    );

    bloc.add(const SavedSoundsLoadRequested());
    await _settle();

    expect(bloc.state.sounds.single.id, 'existing');
  });

  test(
    'durably saves basic context and catalog tags before probe finishes',
    () async {
      probe.completer = Completer<SavedSoundMediaResult?>();
      const context = SavedSoundSourceContext(
        creatorName: 'Alice',
        description: 'A rainy loop',
      );

      final result = await bloc.saveSound(_sound(), sourceContext: context);

      expect(result, SavedSoundSaveResult.saved);
      expect(bloc.state.sounds.single.savedAt, DateTime.utc(2026, 7, 31));
      expect(bloc.state.sounds.single.sourceContext, context);
      expect(bloc.state.sounds.single.catalogTags, ['field recording']);
      expect(service.loadSavedSounds(), bloc.state.sounds);
      expect(probe.completer!.isCompleted, isFalse);
    },
  );

  test(
    'duplicate save reports alreadySaved and does not probe again',
    () async {
      await bloc.saveSound(_sound());
      await _settle();
      final result = await bloc.saveSound(_sound());

      expect(result, SavedSoundSaveResult.alreadySaved);
      expect(probe.calls, hasLength(1));
    },
  );

  test(
    'successful probe replaces duration and waveform on the same full ID',
    () async {
      probe.completer = Completer<SavedSoundMediaResult?>();
      await bloc.saveSound(_sound());

      probe.completer!.complete(
        const SavedSoundMediaResult(
          durationSeconds: 4.5,
          waveformSamples: [0.1, 0.8],
        ),
      );
      await _settle();

      expect(bloc.state.sounds.single.id, 'sound-1');
      expect(bloc.state.sounds.single.audio.duration, 4.5);
      expect(bloc.state.sounds.single.waveformSamples, [0.1, 0.8]);
    },
  );

  test(
    'failed optional probe leaves the saved record without an error',
    () async {
      probe.result = null;

      expect(await bloc.saveSound(_sound()), SavedSoundSaveResult.saved);
      await _settle();

      expect(bloc.state.sounds.single.id, 'sound-1');
      expect(bloc.state.unsavedSoundIds, isEmpty);
    },
  );

  test('autosaves normalized personal details', () async {
    await bloc.saveSound(_sound());
    bloc.add(
      const SavedSoundDetailsChanged(
        soundId: 'sound-1',
        label: '  Warm up  ',
        hashtags: ['#Practice', 'practice', ' Guitar '],
      ),
    );
    await _settle();

    final saved = service.loadSavedSounds().single;
    expect(saved.personalLabel, 'Warm up');
    expect(saved.personalHashtags, ['practice', 'guitar']);
  });

  test('query and selected hashtag filter private and source fields', () async {
    await service.saveSavedSound(
      SavedSound(
        audio: _sound(),
        personalLabel: 'Morning idea',
        personalHashtags: const ['practice'],
        catalogTags: const ['field recording'],
        waveformSamples: const [],
        sourceContext: const SavedSoundSourceContext(
          creatorName: 'Alice',
          description: 'Rain outside',
          transcript: 'soft guitar notes',
        ),
      ),
    );
    bloc.add(const SavedSoundsLoadRequested());
    await _settle();

    for (final query in [
      'morning',
      'rain guitar',
      'alice',
      'outside',
      'soft guitar',
      'practice',
      'field recording',
    ]) {
      bloc.add(SavedSoundsQueryChanged(query));
      await _settle();
      expect(bloc.state.visibleSounds, hasLength(1), reason: query);
    }
    bloc.add(const SavedSoundsHashtagSelected('missing'));
    await _settle();
    expect(bloc.state.visibleSounds, isEmpty);
    bloc.add(const SavedSoundsHashtagSelected('practice'));
    await _settle();
    expect(bloc.state.visibleSounds, hasLength(1));
  });

  test('removes a saved sound', () async {
    await bloc.saveSound(_sound());

    bloc.add(const SavedSoundRemoveRequested('sound-1'));
    await _settle();

    expect(bloc.state.sounds, isEmpty);
    expect(service.loadSavedSounds(), isEmpty);
  });
}
