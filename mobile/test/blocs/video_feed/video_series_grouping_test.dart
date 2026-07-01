import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_feed/video_series_grouping.dart';

VideoEvent _video(String id, {VideoSeries? series}) => VideoEvent(
  id: id,
  pubkey: 'pk',
  createdAt: 0,
  content: '',
  timestamp: DateTime(2024),
  series: series,
);

VideoSeries _series(int index, {String id = 's1', int total = 3}) =>
    VideoSeries(id: id, index: index, total: total);

void main() {
  group('groupVideoSeries', () {
    test('passes non-series videos through unchanged', () {
      final videos = [_video('a'), _video('b'), _video('c')];
      final grouped = groupVideoSeries(videos);
      expect(grouped.items.map((v) => v.id), ['a', 'b', 'c']);
      expect(grouped.seriesSegments, isEmpty);
    });

    test('collapses a series to a single ordered anchor', () {
      final videos = [
        _video('s0', series: _series(0)),
        _video('s1', series: _series(1)),
        _video('s2', series: _series(2)),
      ];
      final grouped = groupVideoSeries(videos);
      expect(grouped.items, hasLength(1));
      expect(grouped.items.single.id, 's0');
      expect(grouped.seriesSegments['s1']!.map((v) => v.id), [
        's0',
        's1',
        's2',
      ]);
    });

    test(
      'places the anchor at the first-seen position, keeping feed order',
      () {
        final videos = [
          _video('a'),
          _video('s1', series: _series(1)),
          _video('b'),
          _video('s0', series: _series(0)),
        ];
        final grouped = groupVideoSeries(videos);
        // Anchor sits where the series first appeared (before 'b').
        expect(grouped.items.map((v) => v.id), ['a', 's0', 'b']);
      },
    );

    test('orders segments by index even when received out of order', () {
      final videos = [
        _video('s2', series: _series(2)),
        _video('s0', series: _series(0)),
        _video('s1', series: _series(1)),
      ];
      final grouped = groupVideoSeries(videos);
      expect(grouped.items.single.id, 's0');
      expect(grouped.seriesSegments['s1']!.map((v) => v.id), [
        's0',
        's1',
        's2',
      ]);
    });

    test('handles multiple distinct series independently', () {
      final videos = [
        _video('x0', series: _series(0, id: 'x', total: 2)),
        _video('y0', series: _series(0, id: 'y', total: 2)),
        _video('x1', series: _series(1, id: 'x', total: 2)),
        _video('y1', series: _series(1, id: 'y', total: 2)),
      ];
      final grouped = groupVideoSeries(videos);
      expect(grouped.items.map((v) => v.id), ['x0', 'y0']);
      expect(grouped.seriesSegments['x']!.map((v) => v.id), ['x0', 'x1']);
      expect(grouped.seriesSegments['y']!.map((v) => v.id), ['y0', 'y1']);
    });
  });
}
