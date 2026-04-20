// ABOUTME: Tests for the VideoStats iterable extension that converts into
// ABOUTME: filtered VideoEvent lists.

import 'package:models/models.dart';
import 'package:test/test.dart';

VideoStats _stats({
  required String id,
  int? expirationSecondsFromNow,
}) => VideoStats(
  id: id,
  pubkey: 'pubkey-$id',
  createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
  kind: 34236,
  dTag: id,
  title: 'Video $id',
  thumbnail: '',
  videoUrl: 'https://example.com/$id.mp4',
  reactions: 0,
  comments: 0,
  reposts: 0,
  engagementScore: 0,
  rawTags: expirationSecondsFromNow == null
      ? const {}
      : {
          'expiration':
              (DateTime.now().millisecondsSinceEpoch ~/ 1000 +
                      expirationSecondsFromNow)
                  .toString(),
        },
);

void main() {
  group('VideoStatsIterableFilters', () {
    group('toVideoEvents', () {
      test('converts each VideoStats into a VideoEvent', () {
        final list = [_stats(id: 'a'), _stats(id: 'b')].toVideoEvents();

        expect(list, hasLength(2));
        expect(list.map((v) => v.id), equals(['a', 'b']));
      });

      test('drops videos whose NIP-40 expiration has passed', () {
        final list = [
          _stats(id: 'live', expirationSecondsFromNow: 3600),
          _stats(id: 'dead', expirationSecondsFromNow: -3600),
          _stats(id: 'no-exp'),
        ].toVideoEvents();

        expect(list.map((v) => v.id), equals(['live', 'no-exp']));
      });

      test('returns an empty list for an empty iterable', () {
        expect(<VideoStats>[].toVideoEvents(), isEmpty);
      });
    });
  });
}
