import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/video_recorder/shutter_gesture_detector.dart';

void main() {
  group(ShutterGestureDetector, () {
    Future<void> pumpHost(
      WidgetTester tester, {
      required VoidCallback onTapToggle,
      required VoidCallback onLongPressStartRecording,
      required VoidCallback onLongPressStopRecording,
      bool isRecording = false,
      bool isEnabled = true,
      bool isLongPressSupported = true,
      bool startsRecordingOnPressDown = false,
    }) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: ShutterGestureDetector(
              isEnabled: isEnabled,
              isRecording: isRecording,
              isLongPressSupported: isLongPressSupported,
              startsRecordingOnPressDown: startsRecordingOnPressDown,
              behavior: HitTestBehavior.opaque,
              onTapToggle: onTapToggle,
              onLongPressStartRecording: onLongPressStartRecording,
              onLongPressStopRecording: onLongPressStopRecording,
              child: const SizedBox(width: 80, height: 80),
            ),
          ),
        ),
      );
    }

    testWidgets('tap invokes toggle and does not prime stop on release', (
      tester,
    ) async {
      var toggled = 0;
      var started = 0;
      var stopped = 0;
      await pumpHost(
        tester,
        onTapToggle: () => toggled++,
        onLongPressStartRecording: () => started++,
        onLongPressStopRecording: () => stopped++,
      );

      await tester.tap(find.byType(ShutterGestureDetector));
      await tester.pumpAndSettle();

      expect(toggled, equals(1));
      expect(started, equals(0));
      expect(stopped, equals(0));
    });

    testWidgets(
      'incidental long-press while already recording does not start or stop',
      (tester) async {
        var started = 0;
        var stopped = 0;
        await pumpHost(
          tester,
          isRecording: true,
          onTapToggle: () {},
          onLongPressStartRecording: () => started++,
          onLongPressStopRecording: () => stopped++,
        );

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(ShutterGestureDetector)),
        );
        await tester.pump(const Duration(seconds: 1));
        await gesture.up();
        await tester.pumpAndSettle();

        expect(started, equals(0));
        expect(stopped, equals(0));
      },
    );

    testWidgets('long-press from idle starts recording and release stops it', (
      tester,
    ) async {
      var started = 0;
      var stopped = 0;
      await pumpHost(
        tester,
        onTapToggle: () {},
        onLongPressStartRecording: () => started++,
        onLongPressStopRecording: () => stopped++,
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(ShutterGestureDetector)),
      );
      await tester.pump(const Duration(seconds: 1));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(started, equals(1));
      expect(stopped, equals(1));
    });

    testWidgets(
      'press-down mode starts immediately and release stops recording',
      (tester) async {
        var toggled = 0;
        var started = 0;
        var stopped = 0;
        await pumpHost(
          tester,
          startsRecordingOnPressDown: true,
          onTapToggle: () => toggled++,
          onLongPressStartRecording: () => started++,
          onLongPressStopRecording: () => stopped++,
        );

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(ShutterGestureDetector)),
        );
        await tester.pump();

        expect(started, equals(1));
        expect(stopped, equals(0));
        expect(toggled, equals(0));

        await gesture.up();
        await tester.pumpAndSettle();

        expect(started, equals(1));
        expect(stopped, equals(1));
        expect(toggled, equals(0));
      },
    );

    testWidgets(
      'press-down mode stops a recording started by another source',
      (tester) async {
        var started = 0;
        var stopped = 0;
        await pumpHost(
          tester,
          isRecording: true,
          startsRecordingOnPressDown: true,
          onTapToggle: () {},
          onLongPressStartRecording: () => started++,
          onLongPressStopRecording: () => stopped++,
        );

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(ShutterGestureDetector)),
        );
        await tester.pump();

        expect(started, equals(0), reason: 'must not start a second recording');
        expect(stopped, equals(1), reason: 'press-down must stop it');

        await gesture.up();
        await tester.pumpAndSettle();

        expect(
          stopped,
          equals(1),
          reason: 'release must not stop again after a press-down stop',
        );
      },
    );

    testWidgets('release stops only once after a long-press start', (
      tester,
    ) async {
      var stopped = 0;
      await pumpHost(
        tester,
        onTapToggle: () {},
        onLongPressStartRecording: () {},
        onLongPressStopRecording: () => stopped++,
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(ShutterGestureDetector)),
      );
      await tester.pump(const Duration(seconds: 1));
      await gesture.up();
      await tester.pumpAndSettle();

      final secondGesture = await tester.startGesture(
        tester.getCenter(find.byType(ShutterGestureDetector)),
      );
      await secondGesture.up();
      await tester.pumpAndSettle();

      expect(
        stopped,
        equals(1),
        reason: 'second release must not stop again',
      );
    });

    testWidgets(
      'tap after a long-press take resets the flag for the next cycle',
      (tester) async {
        var stopped = 0;
        var isRecording = false;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: StatefulBuilder(
              builder: (context, setState) {
                return Center(
                  child: ShutterGestureDetector(
                    isEnabled: true,
                    isRecording: isRecording,
                    behavior: HitTestBehavior.opaque,
                    onTapToggle: () {
                      setState(() => isRecording = true);
                    },
                    onLongPressStartRecording: () {},
                    onLongPressStopRecording: () => stopped++,
                    child: const SizedBox(width: 80, height: 80),
                  ),
                );
              },
            ),
          ),
        );

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(ShutterGestureDetector)),
        );
        await tester.pump(const Duration(seconds: 1));
        await gesture.up();
        await tester.pumpAndSettle();

        await tester.tap(find.byType(ShutterGestureDetector));
        await tester.pumpAndSettle();

        final incidentalGesture = await tester.startGesture(
          tester.getCenter(find.byType(ShutterGestureDetector)),
        );
        await tester.pump(const Duration(seconds: 1));
        await incidentalGesture.up();
        await tester.pumpAndSettle();

        expect(stopped, equals(1));
      },
    );
  });
}
