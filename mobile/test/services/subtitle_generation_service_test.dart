// ABOUTME: Tests for SubtitleGenerationService pipeline orchestration.
// ABOUTME: Verifies whisper -> publish subtitle event -> republish video flow.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/subtitle_generation_service.dart';
import 'package:openvine/services/subtitle_service.dart';
import 'package:openvine/services/video_event_publisher.dart';
import 'package:openvine/services/whisper_transcription_service.dart';

class _MockWhisperTranscriptionService extends Mock
    implements WhisperTranscriptionService {}

class _MockAuthService extends Mock implements AuthService {}

class _MockVideoEventPublisher extends Mock implements VideoEventPublisher {}

class _MockNostrClient extends Mock implements NostrClient {}

void main() {
  const testPubkey =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  late _MockWhisperTranscriptionService mockWhisper;
  late _MockAuthService mockAuth;
  late _MockVideoEventPublisher mockPublisher;
  late _MockNostrClient mockNostrClient;
  late SubtitleGenerationService service;
  late VideoEvent testVideo;

  setUpAll(() {
    registerFallbackValue(
      Event(testPubkey, 39307, <List<String>>[], '', createdAt: 1757385263),
    );
    registerFallbackValue(
      VideoEvent(
        id: 'fallback-event-id',
        pubkey: testPubkey,
        createdAt: 1757385263,
        content: '',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
        vineId: 'fallback-vine-id',
      ),
    );
  });

  setUp(() {
    mockWhisper = _MockWhisperTranscriptionService();
    mockAuth = _MockAuthService();
    mockPublisher = _MockVideoEventPublisher();
    mockNostrClient = _MockNostrClient();

    service = SubtitleGenerationService(
      whisperService: mockWhisper,
      authService: mockAuth,
      eventPublisher: mockPublisher,
      nostrClient: mockNostrClient,
    );

    testVideo = VideoEvent(
      id: 'test-event-id',
      pubkey: testPubkey,
      createdAt: 1757385263,
      content: '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
      vineId: 'test-vine-id',
      title: 'Test Video',
    );
  });

  group(SubtitleGenerationService, () {
    test('calls whisperService.transcribe with video path', () async {
      when(
        () => mockWhisper.ensureModel(onProgress: any(named: 'onProgress')),
      ).thenAnswer((_) async {});
      when(() => mockWhisper.transcribe('/path/to/video.mp4')).thenAnswer(
        (_) async => [const SubtitleCue(start: 500, end: 3000, text: 'Hello')],
      );
      when(
        () => mockAuth.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer(
        (_) async => Event(
          testPubkey,
          39307,
          <List<String>>[
            ['d', 'subtitles:test-vine-id'],
          ],
          'WEBVTT\n\n1\n00:00:00.500 --> 00:00:03.000\nHello\n\n',
          createdAt: 1757385263,
        ),
      );
      when(() => mockNostrClient.publishEvent(any())).thenAnswer(
        (_) async => Event(
          testPubkey,
          39307,
          <List<String>>[],
          '',
          createdAt: 1757385263,
        ),
      );
      when(
        () => mockPublisher.republishWithSubtitles(
          existingEvent: any(named: 'existingEvent'),
          textTrackRef: any(named: 'textTrackRef'),
          textTrackLang: any(named: 'textTrackLang'),
        ),
      ).thenAnswer((_) async => true);

      await service.generateAndPublish(
        video: testVideo,
        videoFilePath: '/path/to/video.mp4',
      );

      verify(() => mockWhisper.transcribe('/path/to/video.mp4')).called(1);
    });

    test('publishes subtitle event with kind 39307', () async {
      when(
        () => mockWhisper.ensureModel(onProgress: any(named: 'onProgress')),
      ).thenAnswer((_) async {});
      when(() => mockWhisper.transcribe(any())).thenAnswer(
        (_) async => [const SubtitleCue(start: 500, end: 3000, text: 'Hello')],
      );
      when(
        () => mockAuth.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer(
        (_) async => Event(
          testPubkey,
          39307,
          <List<String>>[
            ['d', 'subtitles:test-vine-id'],
          ],
          'WEBVTT content',
          createdAt: 1757385263,
        ),
      );
      when(() => mockNostrClient.publishEvent(any())).thenAnswer(
        (_) async => Event(
          testPubkey,
          39307,
          <List<String>>[],
          '',
          createdAt: 1757385263,
        ),
      );
      when(
        () => mockPublisher.republishWithSubtitles(
          existingEvent: any(named: 'existingEvent'),
          textTrackRef: any(named: 'textTrackRef'),
          textTrackLang: any(named: 'textTrackLang'),
        ),
      ).thenAnswer((_) async => true);

      await service.generateAndPublish(
        video: testVideo,
        videoFilePath: '/path/to/video.mp4',
      );

      verify(
        () => mockAuth.createAndSignEvent(
          kind: 39307,
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).called(1);
    });

    test('subtitle event has correct d-tag, a-tag, m-tag, l-tag', () async {
      when(
        () => mockWhisper.ensureModel(onProgress: any(named: 'onProgress')),
      ).thenAnswer((_) async {});
      when(() => mockWhisper.transcribe(any())).thenAnswer(
        (_) async => [const SubtitleCue(start: 500, end: 3000, text: 'Hello')],
      );

      List<List<String>>? capturedTags;
      when(
        () => mockAuth.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((invocation) async {
        capturedTags = invocation.namedArguments[#tags] as List<List<String>>?;
        return Event(
          testPubkey,
          39307,
          capturedTags ?? <List<String>>[],
          'WEBVTT content',
          createdAt: 1757385263,
        );
      });
      when(() => mockNostrClient.publishEvent(any())).thenAnswer(
        (_) async => Event(
          testPubkey,
          39307,
          <List<String>>[],
          '',
          createdAt: 1757385263,
        ),
      );
      when(
        () => mockPublisher.republishWithSubtitles(
          existingEvent: any(named: 'existingEvent'),
          textTrackRef: any(named: 'textTrackRef'),
          textTrackLang: any(named: 'textTrackLang'),
        ),
      ).thenAnswer((_) async => true);

      await service.generateAndPublish(
        video: testVideo,
        videoFilePath: '/path/to/video.mp4',
      );

      expect(capturedTags, isNotNull);
      expect(
        capturedTags!.any(
          (t) => t[0] == 'd' && t[1] == 'subtitles:test-vine-id',
        ),
        isTrue,
      );
      expect(
        capturedTags!.any(
          (t) => t[0] == 'a' && t[1] == '34236:$testPubkey:test-vine-id',
        ),
        isTrue,
      );
      expect(
        capturedTags!.any((t) => t[0] == 'm' && t[1] == 'text/vtt'),
        isTrue,
      );
      expect(
        capturedTags!.any(
          (t) => t[0] == 'l' && t[1] == 'en' && t[2] == 'ISO-639-1',
        ),
        isTrue,
      );
    });

    test('text-track tag references subtitle event coordinates', () async {
      when(
        () => mockWhisper.ensureModel(onProgress: any(named: 'onProgress')),
      ).thenAnswer((_) async {});
      when(() => mockWhisper.transcribe(any())).thenAnswer(
        (_) async => [const SubtitleCue(start: 500, end: 3000, text: 'Hello')],
      );
      when(
        () => mockAuth.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer(
        (_) async => Event(
          testPubkey,
          39307,
          <List<String>>[],
          'VTT',
          createdAt: 1757385263,
        ),
      );
      when(() => mockNostrClient.publishEvent(any())).thenAnswer(
        (_) async => Event(
          testPubkey,
          39307,
          <List<String>>[],
          '',
          createdAt: 1757385263,
        ),
      );
      when(
        () => mockPublisher.republishWithSubtitles(
          existingEvent: any(named: 'existingEvent'),
          textTrackRef: any(named: 'textTrackRef'),
          textTrackLang: any(named: 'textTrackLang'),
        ),
      ).thenAnswer((_) async => true);

      await service.generateAndPublish(
        video: testVideo,
        videoFilePath: '/path/to/video.mp4',
      );

      verify(
        () => mockPublisher.republishWithSubtitles(
          existingEvent: testVideo,
          textTrackRef: '39307:$testPubkey:subtitles:test-vine-id',
          textTrackLang: 'en',
        ),
      ).called(1);
    });

    test('reports progress stages correctly', () async {
      final stages = <SubtitleGenerationStage>[];

      when(
        () => mockWhisper.ensureModel(onProgress: any(named: 'onProgress')),
      ).thenAnswer((_) async {});
      when(() => mockWhisper.transcribe(any())).thenAnswer(
        (_) async => [const SubtitleCue(start: 500, end: 3000, text: 'Hello')],
      );
      when(
        () => mockAuth.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer(
        (_) async => Event(
          testPubkey,
          39307,
          <List<String>>[],
          'VTT',
          createdAt: 1757385263,
        ),
      );
      when(() => mockNostrClient.publishEvent(any())).thenAnswer(
        (_) async => Event(
          testPubkey,
          39307,
          <List<String>>[],
          '',
          createdAt: 1757385263,
        ),
      );
      when(
        () => mockPublisher.republishWithSubtitles(
          existingEvent: any(named: 'existingEvent'),
          textTrackRef: any(named: 'textTrackRef'),
          textTrackLang: any(named: 'textTrackLang'),
        ),
      ).thenAnswer((_) async => true);

      await service.generateAndPublish(
        video: testVideo,
        videoFilePath: '/path/to/video.mp4',
        onStage: stages.add,
      );

      expect(
        stages,
        equals([
          SubtitleGenerationStage.downloadingModel,
          SubtitleGenerationStage.extractingAudio,
          SubtitleGenerationStage.transcribing,
          SubtitleGenerationStage.publishingSubtitles,
          SubtitleGenerationStage.publishingEvent,
          SubtitleGenerationStage.done,
        ]),
      );
    });

    test(
      'throws "No speech detected" when transcription has no cues',
      () async {
        when(
          () => mockWhisper.ensureModel(onProgress: any(named: 'onProgress')),
        ).thenAnswer((_) async {});
        when(() => mockWhisper.transcribe(any())).thenAnswer((_) async => []);

        expect(
          () => service.generateAndPublish(
            video: testVideo,
            videoFilePath: '/path/to/video.mp4',
          ),
          throwsA(
            isA<SubtitleGenerationException>().having(
              (e) => e.message,
              'message',
              'No speech detected',
            ),
          ),
        );
      },
    );

    test('throws when signing fails', () async {
      when(
        () => mockWhisper.ensureModel(onProgress: any(named: 'onProgress')),
      ).thenAnswer((_) async {});
      when(() => mockWhisper.transcribe(any())).thenAnswer(
        (_) async => [const SubtitleCue(start: 500, end: 3000, text: 'Hello')],
      );
      when(
        () => mockAuth.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => null);

      expect(
        () => service.generateAndPublish(
          video: testVideo,
          videoFilePath: '/path/to/video.mp4',
        ),
        throwsA(
          isA<SubtitleGenerationException>().having(
            (e) => e.message,
            'message',
            'Failed to sign subtitle event',
          ),
        ),
      );
    });

    test('throws when publishing subtitle event fails', () async {
      when(
        () => mockWhisper.ensureModel(onProgress: any(named: 'onProgress')),
      ).thenAnswer((_) async {});
      when(() => mockWhisper.transcribe(any())).thenAnswer(
        (_) async => [const SubtitleCue(start: 500, end: 3000, text: 'Hello')],
      );
      when(
        () => mockAuth.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer(
        (_) async => Event(
          testPubkey,
          39307,
          <List<String>>[],
          'VTT',
          createdAt: 1757385263,
        ),
      );
      when(
        () => mockNostrClient.publishEvent(any()),
      ).thenAnswer((_) async => null);

      expect(
        () => service.generateAndPublish(
          video: testVideo,
          videoFilePath: '/path/to/video.mp4',
        ),
        throwsA(
          isA<SubtitleGenerationException>().having(
            (e) => e.message,
            'message',
            'Failed to publish subtitle event',
          ),
        ),
      );
    });
  });
}
