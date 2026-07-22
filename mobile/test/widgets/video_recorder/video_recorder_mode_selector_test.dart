import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_mode_selector.dart';

void main() {
  group(VideoRecorderModeSelectorWheel, () {
    // Item widths follow each label's measured (wide, extra-bold) text, and
    // the wheel lazily builds only the items inside its viewport. The tests
    // below assert on every mode at once, so both the surface and the host
    // box are sized wide enough to lay out all modes on screen — otherwise
    // the outer labels scroll off and are never built or hit-testable.
    const surfaceWidth = 1500.0;

    late VideoRecorderMode selectedMode;
    late List<VideoRecorderMode> modeChanges;

    setUp(() {
      selectedMode = VideoRecorderMode.capture;
      modeChanges = [];
    });

    Widget buildWidget({VideoRecorderMode? mode}) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: surfaceWidth,
              child: VideoRecorderModeSelectorWheel(
                selectedMode: mode ?? selectedMode,
                onModeChanged: (m) => modeChanges.add(m),
              ),
            ),
          ),
        ),
      );
    }

    Future<void> pumpSelector(
      WidgetTester tester, {
      VideoRecorderMode? mode,
    }) async {
      tester.view.physicalSize = const Size(surfaceWidth, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(buildWidget(mode: mode));
      await tester.pumpAndSettle();
    }

    group('renders', () {
      testWidgets('renders all mode labels', (tester) async {
        await pumpSelector(tester);

        for (final mode in VideoRecorderMode.values) {
          expect(find.text(mode.label), findsOneWidget);
        }
      });

      testWidgets('renders with capture mode selected', (tester) async {
        await pumpSelector(tester, mode: VideoRecorderMode.capture);

        expect(find.byType(VideoRecorderModeSelectorWheel), findsOneWidget);
      });

      testWidgets('renders with classic mode selected', (tester) async {
        await pumpSelector(tester, mode: VideoRecorderMode.classic);

        expect(find.byType(VideoRecorderModeSelectorWheel), findsOneWidget);
      });

      testWidgets('renders pill background', (tester) async {
        await pumpSelector(tester);

        expect(find.byType(AnimatedContainer), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('calls onModeChanged when tapping a different mode', (
        tester,
      ) async {
        // Suppress haptic feedback method channel calls in test
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              return null;
            });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null);
        });

        await pumpSelector(tester, mode: VideoRecorderMode.capture);

        await tester.tap(find.text('Classic'));
        await tester.pumpAndSettle();

        expect(modeChanges, contains(VideoRecorderMode.classic));
      });

      testWidgets('a forward drag settles on one item, not the last', (
        tester,
      ) async {
        // Suppress haptic feedback method channel calls in test
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              return null;
            });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null);
        });

        await pumpSelector(tester, mode: VideoRecorderMode.capture);

        // A single user drag must produce a single snap. Regression guard:
        // the programmatic snap animation used to re-trigger snapping and run
        // the wheel all the way to the final ("Classic") item.
        await tester.drag(find.byType(ListView), const Offset(-60, 0));
        await tester.pumpAndSettle();

        expect(modeChanges, isNotEmpty);
        expect(modeChanges, isNot(contains(VideoRecorderMode.classic)));
      });

      testWidgets('uses ShaderMask for fade-out edges', (tester) async {
        await pumpSelector(tester);

        expect(find.byType(ShaderMask), findsOneWidget);
      });

      testWidgets('renders horizontal ListView', (tester) async {
        await pumpSelector(tester);

        final listView = tester.widget<ListView>(find.byType(ListView));
        expect(listView.scrollDirection, equals(Axis.horizontal));
      });
    });

    group('accessibility', () {
      testWidgets('each mode is exposed as a selectable Semantics button', (
        tester,
      ) async {
        await pumpSelector(tester, mode: VideoRecorderMode.capture);

        for (final mode in VideoRecorderMode.values) {
          final semantics = tester
              .widgetList<Semantics>(find.byType(Semantics))
              .firstWhere((s) => s.properties.label == mode.label);
          expect(semantics.properties.button, isTrue);
          expect(
            semantics.properties.selected,
            mode == VideoRecorderMode.capture,
          );
        }
      });

      testWidgets('each mode tap target meets the 48dp minimum', (
        tester,
      ) async {
        await pumpSelector(tester);

        final targets = find.descendant(
          of: find.byType(ListView),
          matching: find.byType(GestureDetector),
        );
        expect(targets, findsWidgets);
        for (final target in targets.evaluate()) {
          expect(
            tester.getSize(find.byWidget(target.widget)).height,
            greaterThanOrEqualTo(kMinInteractiveDimension),
          );
        }
      });
    });

    group('didUpdateWidget', () {
      testWidgets('updates selection when mode changes externally', (
        tester,
      ) async {
        await pumpSelector(tester, mode: VideoRecorderMode.capture);

        await pumpSelector(tester, mode: VideoRecorderMode.classic);

        expect(find.byType(VideoRecorderModeSelectorWheel), findsOneWidget);
      });

      testWidgets(
        'an external mode change repositions instantly without a scroll '
        'animation (persisted-mode restore on open)',
        (tester) async {
          await pumpSelector(tester, mode: VideoRecorderMode.capture);
          final scrollable = tester.state<ScrollableState>(
            find.byType(Scrollable).first,
          );
          final offsetBefore = scrollable.position.pixels;

          await tester.pumpWidget(buildWidget(mode: VideoRecorderMode.classic));

          // The wheel is already on the new mode after the rebuild frame —
          // no in-flight animation left for pumpAndSettle to advance.
          final offsetAfterRebuild = scrollable.position.pixels;
          expect(offsetAfterRebuild, isNot(equals(offsetBefore)));
          await tester.pumpAndSettle();
          expect(scrollable.position.pixels, equals(offsetAfterRebuild));
        },
      );
    });
  });
}
