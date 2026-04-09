// ABOUTME: Unit tests for StereoWaveformPainter and WaveformConstants.
// ABOUTME: Tests shouldRepaint logic, paint with empty/valid data, and constants.

import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/stereo_waveform_painter.dart';

void main() {
  group(WaveformConstants, () {
    test('barStep equals barWidth + barSpacing', () {
      expect(
        WaveformConstants.barStep,
        equals(WaveformConstants.barWidth + WaveformConstants.barSpacing),
      );
    });

    test('barWidth is positive', () {
      expect(WaveformConstants.barWidth, greaterThan(0));
    });

    test('minBarHeight is positive', () {
      expect(WaveformConstants.minBarHeight, greaterThan(0));
    });

    test('amplitudeScale is between 0 and 1', () {
      expect(WaveformConstants.amplitudeScale, greaterThan(0));
      expect(WaveformConstants.amplitudeScale, lessThanOrEqualTo(1));
    });
  });

  group(StereoWaveformPainter, () {
    StereoWaveformPainter createPainter({
      Float32List? leftChannel,
      Float32List? rightChannel,
      double progress = 0.5,
      Color activeColor = Colors.green,
      Color inactiveColor = Colors.grey,
      Color? activeBackgroundColor,
      Duration audioDuration = const Duration(seconds: 10),
      Duration maxDuration = const Duration(seconds: 10),
      Duration startOffset = Duration.zero,
      double heightFactor = 1.0,
    }) {
      return StereoWaveformPainter(
        leftChannel: leftChannel ?? Float32List(0),
        rightChannel: rightChannel,
        progress: progress,
        activeColor: activeColor,
        inactiveColor: inactiveColor,
        activeBackgroundColor: activeBackgroundColor,
        audioDuration: audioDuration,
        maxDuration: maxDuration,
        startOffset: startOffset,
        heightFactor: heightFactor,
      );
    }

    group('shouldRepaint', () {
      test('returns false when all properties are identical', () {
        final left = Float32List.fromList([0.5, 0.3]);
        final painter = createPainter(leftChannel: left);
        final other = createPainter(leftChannel: left);

        expect(painter.shouldRepaint(other), isFalse);
      });

      test('returns true when progress changes', () {
        final left = Float32List.fromList([0.5]);
        final painter = createPainter(leftChannel: left);
        final other = createPainter(leftChannel: left, progress: 0.8);

        expect(painter.shouldRepaint(other), isTrue);
      });

      test('returns true when activeColor changes', () {
        final left = Float32List.fromList([0.5]);
        final painter = createPainter(
          leftChannel: left,
        );
        final other = createPainter(
          leftChannel: left,
          activeColor: Colors.red,
        );

        expect(painter.shouldRepaint(other), isTrue);
      });

      test('returns true when inactiveColor changes', () {
        final left = Float32List.fromList([0.5]);
        final painter = createPainter(
          leftChannel: left,
        );
        final other = createPainter(
          leftChannel: left,
          inactiveColor: Colors.white,
        );

        expect(painter.shouldRepaint(other), isTrue);
      });

      test('returns true when leftChannel changes', () {
        final painter = createPainter(
          leftChannel: Float32List.fromList([0.5]),
        );
        final other = createPainter(
          leftChannel: Float32List.fromList([0.8]),
        );

        expect(painter.shouldRepaint(other), isTrue);
      });

      test('returns true when rightChannel changes', () {
        final left = Float32List.fromList([0.5]);
        final painter = createPainter(
          leftChannel: left,
          rightChannel: Float32List.fromList([0.3]),
        );
        final other = createPainter(
          leftChannel: left,
          rightChannel: Float32List.fromList([0.7]),
        );

        expect(painter.shouldRepaint(other), isTrue);
      });

      test('returns true when audioDuration changes', () {
        final left = Float32List.fromList([0.5]);
        final painter = createPainter(
          leftChannel: left,
        );
        final other = createPainter(
          leftChannel: left,
          audioDuration: const Duration(seconds: 20),
        );

        expect(painter.shouldRepaint(other), isTrue);
      });

      test('returns true when maxDuration changes', () {
        final left = Float32List.fromList([0.5]);
        final painter = createPainter(
          leftChannel: left,
        );
        final other = createPainter(
          leftChannel: left,
          maxDuration: const Duration(seconds: 5),
        );

        expect(painter.shouldRepaint(other), isTrue);
      });

      test('returns true when heightFactor changes', () {
        final left = Float32List.fromList([0.5]);
        final painter = createPainter(leftChannel: left);
        final other = createPainter(leftChannel: left, heightFactor: 0.5);

        expect(painter.shouldRepaint(other), isTrue);
      });

      test('returns true when startOffset changes', () {
        final left = Float32List.fromList([0.5]);
        final painter = createPainter(leftChannel: left);
        final other = createPainter(
          leftChannel: left,
          startOffset: const Duration(seconds: 2),
        );

        expect(painter.shouldRepaint(other), isTrue);
      });
    });

    group('paint', () {
      test('does not throw with empty leftChannel', () {
        final painter = createPainter();
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);

        expect(
          () => painter.paint(canvas, const Size(200, 72)),
          returnsNormally,
        );
      });

      test('does not throw with valid waveform data', () {
        final painter = createPainter(
          leftChannel: Float32List.fromList([0.5, 0.3, 0.8, 0.1, 0.6]),
          rightChannel: Float32List.fromList([0.4, 0.2, 0.7, 0.3, 0.5]),
        );
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);

        expect(
          () => painter.paint(canvas, const Size(200, 72)),
          returnsNormally,
        );
      });

      test('does not throw with mono (no rightChannel)', () {
        final painter = createPainter(
          leftChannel: Float32List.fromList([0.5, 0.3, 0.8]),
        );
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);

        expect(
          () => painter.paint(canvas, const Size(200, 72)),
          returnsNormally,
        );
      });

      test('does not throw when audio is shorter than maxDuration', () {
        final painter = createPainter(
          leftChannel: Float32List.fromList([0.5, 0.3]),
          audioDuration: const Duration(seconds: 3),
        );
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);

        expect(
          () => painter.paint(canvas, const Size(200, 72)),
          returnsNormally,
        );
      });

      test('does not throw with startOffset', () {
        final painter = createPainter(
          leftChannel: Float32List.fromList(
            List.generate(100, (i) => i / 100),
          ),
          audioDuration: const Duration(seconds: 30),
          startOffset: const Duration(seconds: 5),
        );
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);

        expect(
          () => painter.paint(canvas, const Size(200, 72)),
          returnsNormally,
        );
      });

      test('does not throw with zero audioDuration', () {
        final painter = createPainter(
          leftChannel: Float32List.fromList([0.5]),
          audioDuration: Duration.zero,
        );
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);

        expect(
          () => painter.paint(canvas, const Size(200, 72)),
          returnsNormally,
        );
      });

      test('does not throw with activeBackgroundColor', () {
        final painter = createPainter(
          leftChannel: Float32List.fromList([0.5, 0.3, 0.8]),
          activeBackgroundColor: Colors.green.withValues(alpha: 0.2),
        );
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);

        expect(
          () => painter.paint(canvas, const Size(200, 72)),
          returnsNormally,
        );
      });

      test('does not throw with heightFactor 0', () {
        final painter = createPainter(
          leftChannel: Float32List.fromList([0.5, 0.3]),
          heightFactor: 0,
        );
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);

        expect(
          () => painter.paint(canvas, const Size(200, 72)),
          returnsNormally,
        );
      });

      test('does not throw with progress at boundaries', () {
        final left = Float32List.fromList([0.5, 0.3, 0.8]);

        for (final progress in [0.0, 1.0]) {
          final painter = createPainter(
            leftChannel: left,
            progress: progress,
          );
          final recorder = PictureRecorder();
          final canvas = Canvas(recorder);

          expect(
            () => painter.paint(canvas, const Size(200, 72)),
            returnsNormally,
          );
        }
      });

      test('does not throw with zero-size canvas', () {
        final painter = createPainter(
          leftChannel: Float32List.fromList([0.5, 0.3]),
        );
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);

        expect(
          () => painter.paint(canvas, Size.zero),
          returnsNormally,
        );
      });

      test('does not throw with startOffset exceeding audioDuration', () {
        final painter = createPainter(
          leftChannel: Float32List.fromList([0.5, 0.3]),
          audioDuration: const Duration(seconds: 5),
          startOffset: const Duration(seconds: 10),
        );
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);

        expect(
          () => painter.paint(canvas, const Size(200, 72)),
          returnsNormally,
        );
      });
    });

    group('renders via CustomPaint widget', () {
      testWidgets('renders $StereoWaveformPainter in widget tree', (
        tester,
      ) async {
        final painter = createPainter(
          leftChannel: Float32List.fromList([0.5, 0.3, 0.8]),
        );

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: CustomPaint(
                size: const Size(200, 72),
                painter: painter,
              ),
            ),
          ),
        );

        expect(find.byType(CustomPaint), findsWidgets);
      });
    });
  });
}
