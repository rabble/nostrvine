import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/video_recorder/shutter_long_press_mixin.dart';

void main() {
  group(ShutterLongPressMixin, () {
    late _HostState host;

    Future<void> pumpHost(WidgetTester tester) async {
      await tester.pumpWidget(_Host(onState: (state) => host = state));
    }

    testWidgets('handleShutterTap resets the flag and invokes toggle', (
      tester,
    ) async {
      await pumpHost(tester);

      var toggled = 0;
      host.handleShutterTap(() => toggled++);

      expect(toggled, equals(1));
      // After a tap, a following long-press release must not stop.
      var stopped = 0;
      host.handleShutterLongPressUp(() => stopped++);
      expect(stopped, equals(0));
    });

    testWidgets(
      'handleShutterLongPressStart is a no-op when already recording',
      (tester) async {
        await pumpHost(tester);

        var started = 0;
        host.handleShutterLongPressStart(
          isRecording: true,
          start: () => started++,
        );

        expect(started, equals(0));
        // Flag must stay false → release is also a no-op.
        var stopped = 0;
        host.handleShutterLongPressUp(() => stopped++);
        expect(stopped, equals(0));
      },
    );

    testWidgets(
      'handleShutterLongPressStart sets the flag and invokes start when idle',
      (tester) async {
        await pumpHost(tester);

        var started = 0;
        host.handleShutterLongPressStart(
          isRecording: false,
          start: () => started++,
        );

        expect(started, equals(1));
        // Flag is now true → release stops exactly once.
        var stopped = 0;
        host.handleShutterLongPressUp(() => stopped++);
        expect(stopped, equals(1));
      },
    );

    testWidgets('handleShutterLongPressUp resets the flag after stopping', (
      tester,
    ) async {
      await pumpHost(tester);

      host.handleShutterLongPressStart(isRecording: false, start: () {});
      var stopped = 0;
      host.handleShutterLongPressUp(() => stopped++);
      host.handleShutterLongPressUp(() => stopped++);

      expect(
        stopped,
        equals(1),
        reason: 'second release must not stop again',
      );
    });

    testWidgets(
      'tap after a long-press take resets the flag for the next cycle',
      (tester) async {
        await pumpHost(tester);

        // Long-press cycle: start + release sets and clears the flag.
        host.handleShutterLongPressStart(isRecording: false, start: () {});
        host.handleShutterLongPressUp(() {});

        // New tap-started take → incidental long-press release must no-op.
        host.handleShutterTap(() {});
        var stopped = 0;
        host.handleShutterLongPressUp(() => stopped++);
        expect(stopped, equals(0));
      },
    );
  });
}

class _Host extends StatefulWidget {
  const _Host({required this.onState});

  final void Function(_HostState state) onState;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with ShutterLongPressMixin<_Host> {
  @override
  void initState() {
    super.initState();
    widget.onState(this);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
