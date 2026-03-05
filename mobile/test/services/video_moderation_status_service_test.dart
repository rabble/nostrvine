import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openvine/services/video_moderation_status_service.dart';

void main() {
  group('VideoModerationStatus', () {
    test('detects AI-generated from categories list', () {
      final status = VideoModerationStatus.fromCheckResultJson({
        'moderated': true,
        'blocked': true,
        'age_restricted': false,
        'needs_review': true,
        'action': 'PERMANENT_BAN',
        'categories': ['ai_generated'],
        'scores': {'ai_generated': 0.95},
      });

      expect(status.isAiGeneratedBlocked, isTrue);
      expect(status.isUnavailableDueToModeration, isTrue);
    });

    test('detects AI-generated from high score when categories missing', () {
      final status = VideoModerationStatus.fromCheckResultJson({
        'moderated': true,
        'blocked': true,
        'age_restricted': false,
        'needs_review': true,
        'action': 'PERMANENT_BAN',
        'scores': {'ai_generated': 0.9},
      });

      expect(status.aiGenerated, isTrue);
      expect(status.isAiGeneratedBlocked, isTrue);
    });

    test('treats quarantined AI content as unavailable', () {
      final status = VideoModerationStatus.fromCheckResultJson({
        'moderated': true,
        'blocked': false,
        'quarantined': true,
        'age_restricted': false,
        'needs_review': true,
        'action': 'QUARANTINE',
        'categories': ['ai_generated'],
        'scores': {'ai_generated': 0.82},
      });

      expect(status.quarantined, isTrue);
      expect(status.isUnavailableDueToModeration, isTrue);
      expect(status.isAiGeneratedBlocked, isTrue);
    });
  });

  group('VideoModerationStatusService helpers', () {
    test('extracts sha256 from video URL', () {
      const hash =
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      final parsed = VideoModerationStatusService.extractSha256FromVideoUrl(
        'https://media.divine.video/$hash.mp4',
      );
      expect(parsed, hash);
    });

    test('checks moderation only for known hosts', () {
      expect(
        VideoModerationStatusService.shouldCheckModeration(
          'https://media.divine.video/abc',
        ),
        isTrue,
      );
      expect(
        VideoModerationStatusService.shouldCheckModeration(
          'https://example.com/abc',
        ),
        isFalse,
      );
    });
  });

  group('VideoModerationStatusService.fetchStatus', () {
    test('falls back across endpoints and caches result', () async {
      const hash =
          'abcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd';

      var calls = 0;
      final client = MockClient((request) async {
        calls++;

        if (request.url.host == 'first.example') {
          return http.Response('unavailable', 503);
        }

        return http.Response(
          jsonEncode({
            'moderated': true,
            'blocked': true,
            'age_restricted': false,
            'needs_review': true,
            'action': 'PERMANENT_BAN',
            'categories': ['ai_generated'],
            'scores': {'ai_generated': 0.95},
          }),
          200,
        );
      });

      final service = VideoModerationStatusService(
        httpClient: client,
        endpointBases: [
          Uri.parse('https://first.example'),
          Uri.parse('https://second.example'),
        ],
        cacheTtl: const Duration(hours: 1),
      );

      final first = await service.fetchStatus(hash);
      final second = await service.fetchStatus(hash);

      expect(first, isNotNull);
      expect(first!.isAiGeneratedBlocked, isTrue);
      expect(second, isNotNull);
      expect(second!.isAiGeneratedBlocked, isTrue);
      expect(calls, 2); // first endpoint failed + second endpoint succeeded
    });
  });
}
