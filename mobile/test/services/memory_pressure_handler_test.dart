// ABOUTME: Tests MemoryPressureHandler observation and load-shedding order
// ABOUTME: Verifies telemetry failures cannot prevent either shedding action

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/memory_pressure_handler.dart';

void main() {
  group(MemoryPressureHandler, () {
    test('observes each event before shedding memory', () {
      final calls = <String>[];

      final handler = MemoryPressureHandler(
        onPressureObserved: (count) => calls.add('observe:$count'),
        clearImageCache: () => calls.add('clear'),
        shedIngestion: () => calls.add('shed'),
      );

      handler
        ..onMemoryPressure()
        ..onMemoryPressure();

      expect(calls, [
        'observe:1',
        'clear',
        'shed',
        'observe:2',
        'clear',
        'shed',
      ]);
    });

    test('still sheds memory when observation fails', () {
      var clearedImageCache = false;
      var shedIngestion = false;
      final handler = MemoryPressureHandler(
        onPressureObserved: (_) => throw StateError('telemetry unavailable'),
        clearImageCache: () => clearedImageCache = true,
        shedIngestion: () => shedIngestion = true,
      );

      expect(handler.onMemoryPressure, throwsStateError);
      expect(clearedImageCache, isTrue);
      expect(shedIngestion, isTrue);
    });
  });
}
