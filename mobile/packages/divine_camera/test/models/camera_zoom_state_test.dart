import 'package:divine_camera/divine_camera.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(CameraZoomState, () {
    group('fromMap', () {
      test('parses all fields from a platform channel map', () {
        final state = CameraZoomState.fromMap(const {
          'zoomLevel': 5.2,
          'minZoomLevel': 0.5,
          'maxZoomLevel': 61.875,
        });

        expect(state.zoomLevel, 5.2);
        expect(state.minZoomLevel, 0.5);
        expect(state.maxZoomLevel, 61.875);
      });

      test('converts integer values to doubles', () {
        final state = CameraZoomState.fromMap(const {
          'zoomLevel': 2,
          'minZoomLevel': 1,
          'maxZoomLevel': 8,
        });

        expect(state.zoomLevel, 2.0);
        expect(state.minZoomLevel, 1.0);
        expect(state.maxZoomLevel, 8.0);
      });

      test('falls back to 1.0 for missing fields', () {
        final state = CameraZoomState.fromMap(const {});

        expect(state.zoomLevel, 1.0);
        expect(state.minZoomLevel, 1.0);
        expect(state.maxZoomLevel, 1.0);
      });
    });

    test('toString contains all fields', () {
      const state = CameraZoomState(
        zoomLevel: 5.2,
        minZoomLevel: 0.5,
        maxZoomLevel: 61.875,
      );

      expect(
        state.toString(),
        'CameraZoomState(zoomLevel: 5.2, '
        'minZoomLevel: 0.5, maxZoomLevel: 61.875)',
      );
    });
  });
}
