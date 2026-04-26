import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_editor/audio_editor/video_editor_audio_adjust_sheet.dart';

import '../../../helpers/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(VideoEditorAudioAdjustSheet, () {
    late MockGoRouter mockGoRouter;

    setUp(() {
      mockGoRouter = MockGoRouter();
      when(
        () => mockGoRouter.pop<AudioAdjustResult>(any()),
      ).thenAnswer((_) async {});
    });

    Widget buildSheet({
      double initialRecordedVolume = 1,
      double initialCustomVolume = 1,
      ValueChanged<double>? onRecordedVolumeChanged,
      ValueChanged<double>? onCustomVolumeChanged,
    }) {
      return MockGoRouterProvider(
        goRouter: mockGoRouter,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoEditorAudioAdjustSheet(
              initialRecordedVolume: initialRecordedVolume,
              initialCustomVolume: initialCustomVolume,
              onRecordedVolumeChanged: onRecordedVolumeChanged,
              onCustomVolumeChanged: onCustomVolumeChanged,
            ),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('title text', (tester) async {
        await tester.pumpWidget(buildSheet());

        expect(find.text('Adjust volume'), findsOneWidget);
      });

      testWidgets('recorded audio label', (tester) async {
        await tester.pumpWidget(buildSheet());

        expect(find.text('Recorded audio'), findsOneWidget);
      });

      testWidgets('custom audio label', (tester) async {
        await tester.pumpWidget(buildSheet());

        expect(find.text('Custom audio'), findsOneWidget);
      });

      testWidgets('two $DivineSlider widgets', (tester) async {
        await tester.pumpWidget(buildSheet());

        expect(find.byType(DivineSlider), findsNWidgets(2));
      });

      testWidgets('close and confirm $DivineIconButton widgets', (
        tester,
      ) async {
        await tester.pumpWidget(buildSheet());

        expect(find.byType(DivineIconButton), findsNWidgets(2));
      });

      testWidgets('initial volume percentages at 100%', (tester) async {
        await tester.pumpWidget(buildSheet());

        expect(find.text('100%'), findsNWidgets(2));
      });

      testWidgets('initial volume percentages with custom values', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSheet(initialRecordedVolume: 0.5, initialCustomVolume: 0.75),
        );

        expect(find.text('50%'), findsOneWidget);
        expect(find.text('75%'), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('tapping close pops without result', (tester) async {
        await tester.pumpWidget(buildSheet());

        // First DivineIconButton is the close (x) button
        final closeButtons = find.byType(DivineIconButton);
        await tester.tap(closeButtons.first);
        await tester.pump();

        verify(() => mockGoRouter.pop<AudioAdjustResult>(any())).called(1);
      });

      testWidgets('tapping confirm pops with result', (tester) async {
        await tester.pumpWidget(
          buildSheet(initialRecordedVolume: 0.8, initialCustomVolume: 0.6),
        );

        // Last DivineIconButton is the confirm (check) button
        final confirmButtons = find.byType(DivineIconButton);
        await tester.tap(confirmButtons.last);
        await tester.pump();

        final captured = verify(
          () => mockGoRouter.pop<AudioAdjustResult>(captureAny()),
        ).captured;

        expect(captured, hasLength(1));
        final result = captured.first as AudioAdjustResult;
        expect(result.recordedVolume, equals(0.8));
        expect(result.customVolume, equals(0.6));
      });

      testWidgets(
        'dragging recorded audio slider calls onRecordedVolumeChanged',
        (tester) async {
          final values = <double>[];

          await tester.pumpWidget(
            buildSheet(onRecordedVolumeChanged: values.add),
          );

          // First slider is the recorded audio slider
          final sliders = find.byType(Slider);
          await tester.drag(sliders.first, const Offset(-50, 0));
          await tester.pump();

          expect(values, isNotEmpty);
        },
      );

      testWidgets('dragging custom audio slider calls onCustomVolumeChanged', (
        tester,
      ) async {
        final values = <double>[];

        await tester.pumpWidget(buildSheet(onCustomVolumeChanged: values.add));

        // Second slider is the custom audio slider
        final sliders = find.byType(Slider);
        await tester.drag(sliders.last, const Offset(-50, 0));
        await tester.pump();

        expect(values, isNotEmpty);
      });

      testWidgets('slider drag updates displayed percentage', (tester) async {
        await tester.pumpWidget(buildSheet());

        // Drag the first slider (recorded audio) to the left to reduce volume
        final sliders = find.byType(Slider);
        final sliderFinder = sliders.first;
        final topLeft = tester.getTopLeft(sliderFinder);
        final size = tester.getSize(sliderFinder);

        // Tap at ~0% of the slider width
        await tester.tapAt(
          Offset(topLeft.dx + size.width * 0.01, topLeft.dy + size.height / 2),
        );
        await tester.pump();

        // Should now show a percentage below 100% for recorded audio
        // Verify at least one slider changed from 100%
        final hundredPercentCount = find.text('100%').evaluate().length;
        expect(hundredPercentCount, lessThanOrEqualTo(1));
      });
    });
  });
}
