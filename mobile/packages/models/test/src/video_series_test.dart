import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group('VideoSeries.fromTag', () {
    test('parses a well-formed series tag', () {
      final series = VideoSeries.fromTag(['series', 'abc123', '2', '10']);
      expect(series, isNotNull);
      expect(series!.id, 'abc123');
      expect(series.index, 2);
      expect(series.total, 10);
    });

    test('accepts dynamic (non-string) tag values', () {
      final series = VideoSeries.fromTag(['series', 'abc', 0, 3]);
      expect(series, isNotNull);
      expect(series!.index, 0);
      expect(series.total, 3);
    });

    test('returns null when the tag name is not "series"', () {
      expect(VideoSeries.fromTag(['t', 'abc', '0', '3']), isNull);
    });

    test('returns null when fields are missing', () {
      expect(VideoSeries.fromTag(['series', 'abc', '0']), isNull);
    });

    test('returns null for a non-numeric index or total', () {
      expect(VideoSeries.fromTag(['series', 'abc', 'x', '3']), isNull);
      expect(VideoSeries.fromTag(['series', 'abc', '0', 'y']), isNull);
    });

    test('returns null for an empty id', () {
      expect(VideoSeries.fromTag(['series', '', '0', '3']), isNull);
    });
  });

  group('VideoSeries', () {
    test('positionLabel is one-based', () {
      const series = VideoSeries(id: 'a', index: 0, total: 10);
      expect(series.positionLabel, '1/10');
    });

    test('json round-trips', () {
      const series = VideoSeries(id: 'a', index: 3, total: 7);
      expect(VideoSeries.fromJson(series.toJson()), series);
    });

    test('fromJson returns null for an invalid map', () {
      expect(VideoSeries.fromJson(null), isNull);
      expect(VideoSeries.fromJson({'id': 'a', 'index': 1}), isNull);
    });

    test('equality is by value', () {
      expect(
        const VideoSeries(id: 'a', index: 1, total: 5),
        const VideoSeries(id: 'a', index: 1, total: 5),
      );
    });
  });
}
