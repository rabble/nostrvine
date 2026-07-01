import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';

void main() {
  group('VideoEditorRenderService.computeSegmentWindows', () {
    List<({Duration start, Duration end})> windows(int totalMs, int segMs) =>
        VideoEditorRenderService.computeSegmentWindows(
          totalDuration: Duration(milliseconds: totalMs),
          maxSegmentDuration: Duration(milliseconds: segMs),
        );

    test('returns a single full window when the source already fits', () {
      final result = windows(5000, 6300);
      expect(result, hasLength(1));
      expect(result.single.start, Duration.zero);
      expect(result.single.end, const Duration(milliseconds: 5000));
    });

    test('returns a single window when the source equals the limit', () {
      final result = windows(6300, 6300);
      expect(result, hasLength(1));
      expect(result.single.end, const Duration(milliseconds: 6300));
    });

    test('splits an exact multiple into equal windows', () {
      final result = windows(12600, 6300);
      expect(result, hasLength(2));
      expect(
        result[0],
        (start: Duration.zero, end: const Duration(milliseconds: 6300)),
      );
      expect(
        result[1],
        (
          start: const Duration(milliseconds: 6300),
          end: const Duration(milliseconds: 12600),
        ),
      );
    });

    test('makes the final window shorter for a non-multiple total', () {
      final result = windows(60000, 6300); // 9 full windows + a remainder

      expect(result, hasLength(10));
      expect(result.first.start, Duration.zero);
      expect(result.last.end, const Duration(milliseconds: 60000));
      expect(
        result.last.end - result.last.start,
        const Duration(milliseconds: 3300),
      );

      // Windows tile contiguously and none exceeds the per-segment limit.
      for (var i = 0; i < result.length; i++) {
        expect(
          result[i].end - result[i].start,
          lessThanOrEqualTo(const Duration(milliseconds: 6300)),
        );
        if (i > 0) expect(result[i].start, result[i - 1].end);
      }
    });

    test('returns no windows for a zero-length source', () {
      expect(windows(0, 6300), isEmpty);
    });
  });
}
