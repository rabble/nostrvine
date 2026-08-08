import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/extensions/media_query_extensions.dart';

void main() {
  group('MediaQueryExtensions', () {
    const data = MediaQueryData(
      size: Size(390, 844),
      devicePixelRatio: 3,
      textScaler: TextScaler.linear(1.4),
      disableAnimations: true,
      viewPadding: EdgeInsets.only(top: 47, bottom: 34),
      padding: EdgeInsets.only(top: 47),
      viewInsets: EdgeInsets.only(bottom: 336),
    );

    Future<BuildContext> pumpContext(
      WidgetTester tester,
      MediaQueryData data,
    ) async {
      late BuildContext captured;
      await tester.pumpWidget(
        MediaQuery(
          data: data,
          child: Builder(
            builder: (context) {
              captured = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return captured;
    }

    testWidgets('reads scalar metrics from the ambient $MediaQuery', (
      tester,
    ) async {
      final context = await pumpContext(tester, data);

      expect(context.reduceMotion, isTrue);
      expect(context.textScaler, equals(const TextScaler.linear(1.4)));
      expect(context.screenSize, equals(const Size(390, 844)));
      expect(context.devicePixelRatio, equals(3.0));
    });

    testWidgets('keeps padding, viewPadding and viewInsets distinct', (
      tester,
    ) async {
      final context = await pumpContext(tester, data);

      expect(context.padding, equals(const EdgeInsets.only(top: 47)));
      expect(
        context.viewPadding,
        equals(const EdgeInsets.only(top: 47, bottom: 34)),
      );
      expect(context.viewInsets, equals(const EdgeInsets.only(bottom: 336)));
    });

    testWidgets('depends only on the metric it reads', (tester) async {
      // The child is const so it is identical across pumps — the only thing
      // that can rebuild it is the inherited metric it depends on.
      _ReduceMotionProbe.buildCount = 0;
      Widget build(MediaQueryData data) =>
          MediaQuery(data: data, child: const _ReduceMotionProbe());

      await tester.pumpWidget(build(data));
      expect(_ReduceMotionProbe.buildCount, equals(1));

      // An unrelated metric changing must not wake a reduce-motion reader.
      // Reading through MediaQuery.of(context) instead would rebuild here.
      await tester.pumpWidget(build(data.copyWith(devicePixelRatio: 2)));
      expect(_ReduceMotionProbe.buildCount, equals(1));

      await tester.pumpWidget(build(data.copyWith(disableAnimations: false)));
      expect(_ReduceMotionProbe.buildCount, equals(2));
    });
  });

  group('ReduceMotionDuration', () {
    Future<BuildContext> pumpContext(
      WidgetTester tester, {
      required bool reduceMotion,
    }) async {
      late BuildContext captured;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Builder(
            builder: (context) {
              captured = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return captured;
    }

    testWidgets('collapses to zero when reduced motion is on', (tester) async {
      final context = await pumpContext(tester, reduceMotion: true);

      expect(
        const Duration(milliseconds: 200).autoReduceMotion(context),
        equals(Duration.zero),
      );
    });

    testWidgets('keeps the duration when reduced motion is off', (
      tester,
    ) async {
      final context = await pumpContext(tester, reduceMotion: false);

      expect(
        const Duration(milliseconds: 200).autoReduceMotion(context),
        equals(const Duration(milliseconds: 200)),
      );
    });
  });
}

/// Counts its own builds so a test can assert which metric changes reach it.
class _ReduceMotionProbe extends StatelessWidget {
  const _ReduceMotionProbe();

  static int buildCount = 0;

  @override
  Widget build(BuildContext context) {
    buildCount++;
    return SizedBox.square(dimension: context.reduceMotion ? 1 : 2);
  }
}
