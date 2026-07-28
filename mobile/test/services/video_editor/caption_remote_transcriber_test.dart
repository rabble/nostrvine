// ABOUTME: Tests for BlossomCaptionTranscriber.
// ABOUTME: Covers VTT->segment mapping and the fallback-signalling throw.

import 'dart:io';
import 'dart:typed_data';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/video_editor/caption_remote_transcriber.dart';

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

void main() {
  setUpAll(() => registerFallbackValue(Uint8List(0)));

  group(BlossomCaptionTranscriber, () {
    late _MockBlossomUploadService blossom;
    late BlossomCaptionTranscriber transcriber;
    late File audioFile;

    setUp(() {
      blossom = _MockBlossomUploadService();
      transcriber = BlossomCaptionTranscriber(blossom);
      audioFile = File(
        '${Directory.systemTemp.createTempSync('caption_remote').path}/a.wav',
      )..writeAsBytesSync(Uint8List.fromList([1, 2, 3]));
      addTearDown(() => audioFile.parent.deleteSync(recursive: true));
    });

    test('maps the returned WebVTT cues to timed segments', () async {
      when(
        () => blossom.transcribeAudio(
          bytes: any(named: 'bytes'),
          language: any(named: 'language'),
        ),
      ).thenAnswer(
        (_) async =>
            'WEBVTT\n\n'
            '00:00:00.000 --> 00:00:01.500\nHello\n\n'
            '00:00:02.000 --> 00:00:03.250\nworld\n',
      );

      final segments = await transcriber.transcribe(
        audioPath: audioFile.path,
        localeIdentifier: 'en-US',
      );

      expect(segments, hasLength(2));
      expect(segments.first.text, equals('Hello'));
      expect(segments.first.start, equals(Duration.zero));
      expect(segments.first.end, equals(const Duration(milliseconds: 1500)));
      expect(segments.last.text, equals('world'));
      expect(segments.last.start, equals(const Duration(seconds: 2)));
      expect(segments.last.end, equals(const Duration(milliseconds: 3250)));
    });

    test('throws when the server returns no transcript', () async {
      when(
        () => blossom.transcribeAudio(
          bytes: any(named: 'bytes'),
          language: any(named: 'language'),
        ),
      ).thenAnswer((_) async => null);

      expect(
        () => transcriber.transcribe(
          audioPath: audioFile.path,
          localeIdentifier: 'en-US',
        ),
        throwsA(isA<CaptionRemoteTranscriptionException>()),
      );
    });

    test('returns no segments for an empty (no-speech) transcript', () async {
      when(
        () => blossom.transcribeAudio(
          bytes: any(named: 'bytes'),
          language: any(named: 'language'),
        ),
      ).thenAnswer((_) async => 'WEBVTT\n');

      final segments = await transcriber.transcribe(
        audioPath: audioFile.path,
        localeIdentifier: 'en-US',
      );

      expect(segments, isEmpty);
    });
  });
}
