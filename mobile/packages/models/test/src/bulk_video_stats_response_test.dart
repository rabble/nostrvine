import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group(BulkVideoStatsResponse, () {
    group('constructor', () {
      test('creates instance with empty map', () {
        const response = BulkVideoStatsResponse(stats: {});

        expect(response.stats, isEmpty);
      });

      test('creates instance with stats', () {
        const entry = BulkVideoStatsEntry(
          eventId: 'abc123',
          reactions: 10,
          comments: 5,
          reposts: 2,
        );
        const response = BulkVideoStatsResponse(
          stats: {'abc123': entry},
        );

        expect(response.stats, hasLength(1));
        expect(
          response.stats['abc123']?.reactions,
          equals(10),
        );
      });
    });
  });
}
