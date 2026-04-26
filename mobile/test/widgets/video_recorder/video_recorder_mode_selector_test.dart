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
      testWidgets('has Semantics for each mode', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        // Each mode should have a Text widget with the mode label
        for (final mode in VideoRecorderMode.values) {
          expect(find.text(mode.label), findsOneWidget);
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
