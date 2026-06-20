// ABOUTME: Tests for the shared fetchSubtitleCues fallback chain.
// ABOUTME: Verifies embedded content, ordered HTTP refs, and relay ref fallback.

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:openvine/services/subtitle_fetcher.dart';

class _FakeClient extends http.BaseClient {
  _FakeClient(this.handler);
  final Future<http.Response> Function(http.Request) handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final res = await handler(request as http.Request);
    return http.StreamedResponse(
      Stream.value(res.bodyBytes),
      res.statusCode,
      headers: res.headers,
    );
  }
}

const _vtt = 'WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nhello\n';

void main() {
  group('fetchSubtitleCues', () {
    test('parses embedded textTrackContent first (no network)', () async {
      final cues = await fetchSubtitleCues(
        httpClient: _FakeClient((_) async => throw StateError('no network')),
        nostrClient: null,
        delay: (_) async {},
        textTrackContent: _vtt,
      );
      expect(cues, hasLength(1));
      expect(cues.first.text, equals('hello'));
    });

    test(
      'falls back to second ref when first http ref is unavailable',
      () async {
        final cues = await fetchSubtitleCues(
          httpClient: _FakeClient((req) async {
            if (req.url.toString() == 'https://media.divine.video/dead') {
              return http.Response('', 404);
            }
            if (req.url.toString() == 'https://media.divine.video/live') {
              return http.Response(_vtt, 200);
            }
            return http.Response('', 500);
          }),
          nostrClient: null,
          delay: (_) async {},
          textTrackRefs: const [
            'https://media.divine.video/dead',
            'https://media.divine.video/live',
          ],
        );
        expect(cues, hasLength(1));
        expect(cues.first.text, equals('hello'));
      },
    );

    test('returns empty list when all sources fail', () async {
      final cues = await fetchSubtitleCues(
        httpClient: _FakeClient((_) async => http.Response('', 404)),
        nostrClient: null,
        delay: (_) async {},
        textTrackRefs: const ['https://media.divine.video/missing'],
      );
      expect(cues, isEmpty);
    });

    test('returns empty list when no sources provided', () async {
      final cues = await fetchSubtitleCues(
        httpClient: _FakeClient(
          (_) async => throw StateError('should not be called'),
        ),
        nostrClient: null,
        delay: (_) async {},
      );
      expect(cues, isEmpty);
    });

    test(
      'fetches from sha256 Blossom path when no refs and sha256 provided',
      () async {
        final cues = await fetchSubtitleCues(
          httpClient: _FakeClient((req) async {
            if (req.url.toString() == 'https://media.divine.video/abc123/vtt') {
              return http.Response(_vtt, 200);
            }
            return http.Response('', 404);
          }),
          nostrClient: null,
          delay: (_) async {},
          sha256: 'abc123',
        );
        expect(cues, hasLength(1));
        expect(cues.first.text, equals('hello'));
      },
    );
  });
}
