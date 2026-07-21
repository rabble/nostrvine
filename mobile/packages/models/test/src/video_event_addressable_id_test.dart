// ABOUTME: Tests VideoEvent.addressableId derives its kind from the event's
// ABOUTME: actual NIP-71 kind (34235 vs 34236), not a hardcoded value.

import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group('VideoEvent.addressableId', () {
    const pubkey =
        'c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0';
    const eventId =
        'f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2';

    VideoEvent build({int? eventKind, String? vineId}) => VideoEvent(
      id: eventId,
      pubkey: pubkey,
      createdAt: 1704067200,
      content: '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1704067200 * 1000),
      vineId: vineId,
      eventKind: eventKind,
    );

    test('uses kind 34236 for an addressable short video', () {
      final video = build(eventKind: 34236, vineId: 'vine123');
      expect(video.addressableId, equals('34236:$pubkey:vine123'));
    });

    test('uses kind 34235 for an addressable normal video', () {
      final video = build(eventKind: 34235, vineId: 'reel456');
      expect(video.addressableId, equals('34235:$pubkey:reel456'));
    });

    test('falls back to 34236 when the event kind is unknown', () {
      final video = build(vineId: 'vine789');
      expect(video.addressableId, equals('34236:$pubkey:vine789'));
    });

    test('is null when the video has no d-tag', () {
      final video = build(eventKind: 34236);
      expect(video.addressableId, isNull);
    });
  });
}
