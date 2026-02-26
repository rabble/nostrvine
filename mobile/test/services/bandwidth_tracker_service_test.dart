import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/bandwidth_tracker_service.dart';

void main() {
  group(BandwidthTrackerService, () {
    late BandwidthTrackerService service;

    setUp(() {
      service = BandwidthTrackerService.instance;
      service.clearSamples();
    });

    group('averageBandwidth', () {
      test('returns 3.0 Mbps default when no samples', () {
        expect(service.averageBandwidth, equals(3.0));
      });

      test('returns average of recorded samples', () {
        // Record two samples: 2 Mbps and 4 Mbps -> avg 3 Mbps
        // 2 Mbps: 2 * 1024 * 1024 / 8 = 262144 bytes/sec
        // In 1000ms: 262144 bytes
        service.recordSample(videoSizeBytes: 262144, loadTimeMs: 1000);
        // 4 Mbps: 4 * 1024 * 1024 / 8 = 524288 bytes/sec
        service.recordSample(videoSizeBytes: 524288, loadTimeMs: 1000);

        // Average should be ~3 Mbps
        expect(service.averageBandwidth, closeTo(3.0, 0.1));
      });
    });

    group('recordSample', () {
      test('ignores zero load time', () {
        service.recordSample(videoSizeBytes: 1000, loadTimeMs: 0);
        // Should still return default (no valid samples)
        expect(service.averageBandwidth, equals(3.0));
      });

      test('ignores zero video size', () {
        service.recordSample(videoSizeBytes: 0, loadTimeMs: 1000);
        expect(service.averageBandwidth, equals(3.0));
      });

      test('ignores negative values', () {
        service.recordSample(videoSizeBytes: -100, loadTimeMs: 1000);
        service.recordSample(videoSizeBytes: 1000, loadTimeMs: -100);
        expect(service.averageBandwidth, equals(3.0));
      });
    });

    group('recordTimeToFirstFrame', () {
      test('ignores zero or negative TTFF', () {
        service.recordTimeToFirstFrame(0);
        service.recordTimeToFirstFrame(-100);
        expect(service.averageBandwidth, equals(3.0));
      });

      test('estimates fast connection for low TTFF', () {
        service.recordTimeToFirstFrame(200); // < 500ms -> 4.0 Mbps
        expect(service.averageBandwidth, equals(4.0));
      });

      test('estimates medium connection for moderate TTFF', () {
        service.recordTimeToFirstFrame(1000); // 500-1500ms -> 2.5 Mbps
        expect(service.averageBandwidth, equals(2.5));
      });

      test('estimates slow connection for high TTFF', () {
        service.recordTimeToFirstFrame(2000); // 1500-3000ms -> 1.5 Mbps
        expect(service.averageBandwidth, equals(1.5));
      });

      test('estimates very slow connection for very high TTFF', () {
        service.recordTimeToFirstFrame(5000); // > 3000ms -> 0.8 Mbps
        expect(service.averageBandwidth, equals(0.8));
      });
    });

    group('recommendedQuality', () {
      test('returns high quality for fast connections (>4 Mbps)', () {
        service.recordTimeToFirstFrame(200); // 4.0 Mbps
        expect(service.recommendedQuality, equals(VideoQuality.high));
      });

      test('returns medium quality for decent connections (2-4 Mbps)', () {
        service.recordTimeToFirstFrame(1000); // 2.5 Mbps
        expect(service.recommendedQuality, equals(VideoQuality.medium));
      });

      test('returns low quality for slow connections (<2 Mbps)', () {
        service.recordTimeToFirstFrame(2000); // 1.5 Mbps
        expect(service.recommendedQuality, equals(VideoQuality.low));
      });
    });

    group('shouldUseHighQuality', () {
      test('returns true for high quality', () {
        service.recordTimeToFirstFrame(200); // 4.0 Mbps -> high
        expect(service.shouldUseHighQuality, isTrue);
      });

      test('returns true for medium quality', () {
        service.recordTimeToFirstFrame(1000); // 2.5 Mbps -> medium
        expect(service.shouldUseHighQuality, isTrue);
      });

      test('returns false for low quality', () {
        service.recordTimeToFirstFrame(5000); // 0.8 Mbps -> low
        expect(service.shouldUseHighQuality, isFalse);
      });
    });

    group('qualityOverride', () {
      test('starts as null (auto mode)', () {
        expect(service.qualityOverride, isNull);
      });

      test('override takes precedence over measured bandwidth', () async {
        service.recordTimeToFirstFrame(200); // Would be high
        await service.setQualityOverride(VideoQuality.low);

        expect(service.recommendedQuality, equals(VideoQuality.low));

        // Clean up
        await service.setQualityOverride(null);
      });
    });

    group('clearSamples', () {
      test('resets to default bandwidth', () {
        service.recordTimeToFirstFrame(200); // 4.0 Mbps
        expect(service.averageBandwidth, isNot(equals(3.0)));

        service.clearSamples();
        expect(service.averageBandwidth, equals(3.0));
      });
    });
  });
}
