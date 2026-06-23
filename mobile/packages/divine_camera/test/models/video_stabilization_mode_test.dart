import 'package:divine_camera/divine_camera.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(DivineVideoStabilizationMode, () {
    test('toNativeString maps every value', () {
      expect(DivineVideoStabilizationMode.off.toNativeString(), 'off');
      expect(
        DivineVideoStabilizationMode.standard.toNativeString(),
        'standard',
      );
      expect(
        DivineVideoStabilizationMode.cinematic.toNativeString(),
        'cinematic',
      );
      expect(
        DivineVideoStabilizationMode.cinematicExtended.toNativeString(),
        'cinematicExtended',
      );
      expect(
        DivineVideoStabilizationMode.previewOptimized.toNativeString(),
        'previewOptimized',
      );
      expect(
        DivineVideoStabilizationMode.lowLatency.toNativeString(),
        'lowLatency',
      );
      expect(DivineVideoStabilizationMode.auto.toNativeString(), 'auto');
    });

    test('fromNativeString parses every known value', () {
      expect(
        DivineVideoStabilizationMode.fromNativeString('off'),
        DivineVideoStabilizationMode.off,
      );
      expect(
        DivineVideoStabilizationMode.fromNativeString('standard'),
        DivineVideoStabilizationMode.standard,
      );
      expect(
        DivineVideoStabilizationMode.fromNativeString('cinematic'),
        DivineVideoStabilizationMode.cinematic,
      );
      expect(
        DivineVideoStabilizationMode.fromNativeString('cinematicExtended'),
        DivineVideoStabilizationMode.cinematicExtended,
      );
      expect(
        DivineVideoStabilizationMode.fromNativeString('previewOptimized'),
        DivineVideoStabilizationMode.previewOptimized,
      );
      expect(
        DivineVideoStabilizationMode.fromNativeString('lowLatency'),
        DivineVideoStabilizationMode.lowLatency,
      );
      expect(
        DivineVideoStabilizationMode.fromNativeString('auto'),
        DivineVideoStabilizationMode.auto,
      );
    });

    test('fromNativeString falls back to off for unknown values', () {
      expect(
        DivineVideoStabilizationMode.fromNativeString('bogus'),
        DivineVideoStabilizationMode.off,
      );
    });

    test('round-trips every value', () {
      for (final mode in DivineVideoStabilizationMode.values) {
        expect(
          DivineVideoStabilizationMode.fromNativeString(mode.toNativeString()),
          mode,
        );
      }
    });

    group('fromNativeStringList', () {
      test('maps values preserving order', () {
        expect(
          DivineVideoStabilizationMode.fromNativeStringList(
            ['off', 'standard', 'cinematic'],
          ),
          const [
            DivineVideoStabilizationMode.off,
            DivineVideoStabilizationMode.standard,
            DivineVideoStabilizationMode.cinematic,
          ],
        );
      });

      test('drops duplicates', () {
        expect(
          DivineVideoStabilizationMode.fromNativeStringList(
            ['off', 'standard', 'standard', 'off'],
          ),
          const [
            DivineVideoStabilizationMode.off,
            DivineVideoStabilizationMode.standard,
          ],
        );
      });

      test('inserts off at the front when missing', () {
        expect(
          DivineVideoStabilizationMode.fromNativeStringList(
            ['standard', 'cinematic'],
          ),
          const [
            DivineVideoStabilizationMode.off,
            DivineVideoStabilizationMode.standard,
            DivineVideoStabilizationMode.cinematic,
          ],
        );
      });

      test('keeps off in place when already present', () {
        expect(
          DivineVideoStabilizationMode.fromNativeStringList(
            ['standard', 'off'],
          ),
          const [
            DivineVideoStabilizationMode.standard,
            DivineVideoStabilizationMode.off,
          ],
        );
      });
    });
  });
}
