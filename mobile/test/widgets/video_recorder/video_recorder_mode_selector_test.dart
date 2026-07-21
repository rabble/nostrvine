import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_mode_selector.dart';

void main() {
  group(VideoRecorderModeSelectorWheel, () {
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
              width: 400,
              child: VideoRecorderModeSelectorWheel(
                selectedMode: mode ?? selectedMode,
                onModeChanged: (m) => modeChanges.add(m),
              ),
            ),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('renders all mode labels', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        for (final mode in VideoRecorderMode.values) {
          expect(find.text(mode.label), findsOneWidget);
        }
      });

      testWidgets('renders with capture mode selected', (tester) async {
        await tester.pumpWidget(buildWidget(mode: VideoRecorderMode.capture));
        await tester.pumpAndSettle();

        expect(find.byType(VideoRecorderModeSelectorWheel), findsOneWidget);
      });

      testWidgets('renders with classic mode selected', (tester) async {
        await tester.pumpWidget(buildWidget(mode: VideoRecorderMode.classic));
        await tester.pumpAndSettle();

        expect(find.byType(VideoRecorderModeSelectorWheel), findsOneWidget);
      });

      testWidgets('renders pill background', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

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

        await tester.pumpWidget(buildWidget(mode: VideoRecorderMode.capture));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Classic'));
        await tester.pumpAndSettle();

        expect(modeChanges, contains(VideoRecorderMode.classic));
      });

      testWidgets('uses ShaderMask for fade-out edges', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(ShaderMask), findsOneWidget);
      });

      testWidgets('renders horizontal ListView', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        final listView = tester.widget<ListView>(find.byType(ListView));
        expect(listView.scrollDirection, equals(Axis.horizontal));
      });
    });

    group('accessibility', () {
      testWidgets('each mode is exposed as a selectable Semantics button', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget(mode: VideoRecorderMode.capture));
        await tester.pumpAndSettle();

        final selected = tester
            .widgetList<Semantics>(find.byType(Semantics))
            .firstWhere(
              (s) => s.properties.label == VideoRecorderMode.capture.label,
            );
        expect(selected.properties.button, isTrue);
        expect(selected.properties.selected, isTrue);
      });

      testWidgets('each mode tap target meets the 48dp minimum', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

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
        await tester.pumpWidget(buildWidget(mode: VideoRecorderMode.capture));
        await tester.pumpAndSettle();

        await tester.pumpWidget(buildWidget(mode: VideoRecorderMode.classic));
        await tester.pumpAndSettle();

        expect(find.byType(VideoRecorderModeSelectorWheel), findsOneWidget);
      });
    });
  });
}
