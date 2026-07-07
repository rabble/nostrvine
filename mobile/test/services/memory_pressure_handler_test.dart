// ABOUTME: Tests MemoryPressureHandler fans out to both load-shedding callbacks
// ABOUTME: Injects spies and asserts image-cache clear + ingestion shed both fire

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/memory_pressure_handler.dart';

void main() {
  group(MemoryPressureHandler, () {
    test('onMemoryPressure invokes both shedding callbacks once', () {
      var clearImageCacheCalls = 0;
      var shedIngestionCalls = 0;

      final handler = MemoryPressureHandler(
        clearImageCache: () => clearImageCacheCalls++,
        shedIngestion: () => shedIngestionCalls++,
      );

      handler.onMemoryPressure();

      expect(clearImageCacheCalls, equals(1));
      expect(shedIngestionCalls, equals(1));
    });
  });
}
