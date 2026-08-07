// ABOUTME: Tests fail-closed consent verification for legacy Kind 1063 audio.
// ABOUTME: Ensures only unambiguous matching source-video evidence permits reuse.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/exceptions/video_exceptions.dart';
import 'package:openvine/services/audio_reuse_consent_resolver.dart';
import 'package:sounds_repository/sounds_repository.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockSoundsRepository extends Mock implements SoundsRepository {}

class _MockVideosRepository extends Mock implements VideosRepository {}

const _pubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

/// A real Kind 1063 id: the lookup only matches a 32-byte-hex event id.
const _audioEventId =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

AudioEvent _sound({
  bool allowsReuse = false,
  bool hasExplicitReuseConsent = false,
  String? sourceVideoReference = '34236:$_pubkey:source-video',
  String id = _audioEventId,
}) {
  return AudioEvent(
    id: id,
    pubkey: _pubkey,
    createdAt: 100,
    sourceVideoReference: sourceVideoReference,
    allowsReuse: allowsReuse,
    hasExplicitReuseConsent: hasExplicitReuseConsent,
  );
}

VideoEvent _video({
  String id = 'video-event',
  String vineId = 'source-video',
  int createdAt = 101,
  bool allowsReuse = true,
}) {
  return VideoEvent(
    id: id,
    pubkey: _pubkey,
    createdAt: createdAt,
    content: '',
    timestamp: DateTime.fromMillisecondsSinceEpoch(
      createdAt * 1000,
      isUtc: true,
    ),
    vineId: vineId,
    addressableDTag: vineId,
    rawTags: allowsReuse
        ? const {'allow_audio_reuse': 'true'}
        : const {'allow_audio_reuse': 'false'},
  );
}

void main() {
  late _MockSoundsRepository soundsRepository;
  late _MockVideosRepository videosRepository;
  late AudioReuseConsentResolver resolver;

  setUp(() {
    soundsRepository = _MockSoundsRepository();
    videosRepository = _MockVideosRepository();
    resolver = AudioReuseConsentResolver(
      soundsRepository: soundsRepository,
      videosRepository: videosRepository,
    );
  });

  /// Stubs the sound lookup with [ids], and whether the relays answered.
  void stubLookup(List<String> ids, {bool answered = true}) {
    when(
      () => soundsRepository.fetchVideosUsingSoundDetailed(_audioEventId),
    ).thenAnswer((_) async => (ids: ids, answered: answered));
  }

  test('accepts explicit true without a legacy lookup', () async {
    expect(await resolver.verify(_sound(allowsReuse: true)), isTrue);
    verifyNever(() => soundsRepository.fetchVideosUsingSoundDetailed(any()));
  });

  test('honors explicit false without a legacy lookup', () async {
    expect(
      await resolver.verify(_sound(hasExplicitReuseConsent: true)),
      isFalse,
    );
    verifyNever(() => soundsRepository.fetchVideosUsingSoundDetailed(any()));
  });

  test('uses newest matching source video for a legacy event', () async {
    stubLookup(['later', 'earliest', 'wrong']);
    when(
      () => videosRepository.getVideosByIds([
        'later',
        'earliest',
        'wrong',
      ], hydrateBulkStats: false),
    ).thenAnswer(
      (_) async => [
        _video(id: 'later', createdAt: 120),
        _video(id: 'earliest', createdAt: 110, allowsReuse: false),
        _video(id: 'wrong', vineId: 'other-video', createdAt: 105),
      ],
    );

    expect(await resolver.verify(_sound()), isTrue);
  });

  test('honours a revocation on the newest revision', () async {
    stubLookup(['revoked', 'original']);
    when(
      () => videosRepository.getVideosByIds([
        'revoked',
        'original',
      ], hydrateBulkStats: false),
    ).thenAnswer(
      (_) async => [
        _video(id: 'revoked', createdAt: 120, allowsReuse: false),
        _video(id: 'original', createdAt: 110),
      ],
    );

    expect(await resolver.verify(_sound()), isFalse);
  });

  test('fails closed on ambiguous newest source events', () async {
    stubLookup(['first', 'second']);
    when(
      () => videosRepository.getVideosByIds([
        'first',
        'second',
      ], hydrateBulkStats: false),
    ).thenAnswer(
      (_) async => [
        _video(id: 'first', createdAt: 110),
        _video(id: 'second', createdAt: 110),
      ],
    );

    expect(await resolver.verify(_sound()), isFalse);
  });

  test('answers false on missing, mismatched, or old evidence', () async {
    expect(await resolver.verify(_sound(sourceVideoReference: null)), isFalse);

    stubLookup(['candidate']);
    when(
      () => videosRepository.getVideosByIds([
        'candidate',
      ], hydrateBulkStats: false),
    ).thenAnswer((_) async => [_video(vineId: 'other-video', createdAt: 99)]);
    expect(await resolver.verify(_sound()), isFalse);
  });

  // A relay that never answered is not a creator who said no. Reporting the
  // transport failure as `false` would tell the user to swap a sound that may
  // well be cleared, so the caller gets the exception and decides.
  //
  // This is the shape the transport actually produces: `queryEvents` drops the
  // `timedOut`/`noRelays` flags and the SDK catches the `TimeoutException`, so
  // an offline lookup arrives as an ordinary empty list, never as a throw.
  test('rejects an empty answer the relays never gave', () async {
    stubLookup([], answered: false);

    expect(
      resolver.verify(_sound()),
      throwsA(isA<AudioReuseConsentUnavailableException>()),
    );
    verifyNever(
      () => videosRepository.getVideosByIds(
        any(),
        hydrateBulkStats: any(named: 'hydrateBulkStats'),
      ),
    );
  });

  // A cached hit is real evidence even when the relays stayed silent.
  test('uses a cached answer the relays did not confirm', () async {
    stubLookup(['granting'], answered: false);
    when(
      () => videosRepository.getVideosByIds([
        'granting',
      ], hydrateBulkStats: false),
    ).thenAnswer((_) async => [_video(id: 'granting', createdAt: 120)]);

    expect(await resolver.verify(_sound()), isTrue);
  });

  // The relays just named these videos, so fetching none of them is the same
  // silence one layer down — `getVideosByIds` swallows an offline relay into
  // an empty list too.
  test('rejects named videos that could not be fetched', () async {
    stubLookup(['granting']);
    when(
      () => videosRepository.getVideosByIds([
        'granting',
      ], hydrateBulkStats: false),
    ).thenAnswer((_) async => []);

    expect(
      resolver.verify(_sound()),
      throwsA(isA<AudioReuseConsentUnavailableException>()),
    );
  });

  test('propagates a failed lookup instead of answering false', () async {
    when(
      () => soundsRepository.fetchVideosUsingSoundDetailed(_audioEventId),
    ).thenThrow(StateError('relay unavailable'));

    expect(resolver.verify(_sound()), throwsStateError);
  });

  // The editor stamps a `-<timestamp>` uniqueness suffix onto every timeline
  // track, so the sound the publisher re-verifies is never the one the picker
  // verified. Querying the raw id found no reusing videos and blocked a
  // publish the creator had explicitly allowed.
  test('looks past an editor timeline uniqueness suffix', () async {
    stubLookup(['granting']);
    when(
      () => videosRepository.getVideosByIds([
        'granting',
      ], hydrateBulkStats: false),
    ).thenAnswer((_) async => [_video(id: 'granting', createdAt: 120)]);

    expect(
      await resolver.verify(_sound(id: '$_audioEventId-1786032375630')),
      isTrue,
    );
    verify(
      () => soundsRepository.fetchVideosUsingSoundDetailed(_audioEventId),
    ).called(1);
  });

  test('resolves an original sound through its source video id', () async {
    stubLookup(['granting']);
    when(
      () => videosRepository.getVideosByIds([
        'granting',
      ], hydrateBulkStats: false),
    ).thenAnswer((_) async => [_video(id: 'granting', createdAt: 120)]);

    expect(await resolver.verify(_sound(id: 'video_$_audioEventId')), isTrue);
  });

  test('fails closed when the sound has no referenceable event id', () async {
    expect(await resolver.verify(_sound(id: 'not-a-nostr-event-id')), isFalse);
    verifyNever(() => soundsRepository.fetchVideosUsingSoundDetailed(any()));
  });
}
