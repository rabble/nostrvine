// ABOUTME: Behavior tests for the layer enter/leave animation picker view.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_layer_animation_sheet.dart';
import 'package:pro_video_editor/pro_video_editor.dart' as editor;

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group(LayerAnimationPickerView, () {
    late _LayerAnimationResult? result;
    late bool returned;

    Future<void> openPicker(
      WidgetTester tester, {
      List<editor.LayerAnimation> initialEnter = const [],
      List<editor.LayerAnimation> initialLeave = const [],
    }) async {
      result = null;
      returned = false;
      // Tall viewport so the full picker (type tiles + curve wrap + direction
      // row + Done) fits without the Done button overflowing offscreen.
      tester.view.physicalSize = const Size(500, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await Navigator.of(context)
                      .push<_LayerAnimationResult>(
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            body: LayerAnimationPickerView(
                              initialEnter: initialEnter,
                              initialLeave: initialLeave,
                            ),
                          ),
                        ),
                      );
                  returned = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      // The preview loops forever, so never pumpAndSettle — advance manually.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
    }

    testWidgets('lists every animation type', (tester) async {
      await openPicker(tester);

      expect(find.text(l10n.videoEditorTransitionNone), findsOneWidget);
      expect(find.text(l10n.videoEditorLayerAnimationFade), findsOneWidget);
      expect(find.text(l10n.videoEditorTransitionSlide), findsOneWidget);
      expect(find.text(l10n.videoEditorLayerAnimationScale), findsOneWidget);
    });

    testWidgets('shows enter and leave toggles', (tester) async {
      await openPicker(tester);

      expect(find.text(l10n.videoEditorLayerAnimationEnter), findsOneWidget);
      expect(find.text(l10n.videoEditorLayerAnimationLeave), findsOneWidget);
    });

    testWidgets('shows duration + curve even for None', (tester) async {
      await openPicker(tester);

      // "None" is selected initially — duration and curve are still shown so
      // the values persist when a type is picked.
      expect(find.text(l10n.videoEditorTransitionDuration), findsOneWidget);
      expect(find.text(l10n.videoEditorTransitionCurve), findsOneWidget);
      // Type-specific controls stay hidden for None.
      expect(find.text(l10n.videoEditorTransitionDirection), findsNothing);
      expect(find.text(l10n.videoEditorLayerAnimationScaleFrom), findsNothing);
    });

    testWidgets('returns no animations when None stays selected', (
      tester,
    ) async {
      await openPicker(tester);

      await tester.tap(find.text(l10n.videoEditorDoneLabel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(returned, isTrue);
      expect(result?.enter, isEmpty);
      expect(result?.leave, isEmpty);
    });

    testWidgets('builds an enter animation for the chosen type', (
      tester,
    ) async {
      await openPicker(tester);

      await tester.tap(find.text(l10n.videoEditorLayerAnimationFade));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text(l10n.videoEditorDoneLabel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(result?.enter.single.type, editor.LayerAnimationType.fade);
      expect(result?.enter.single.phase, editor.AnimationPhase.animateIn);
      expect(result?.leave, isEmpty);
    });

    testWidgets('edits the leave phase independently of enter', (tester) async {
      await openPicker(
        tester,
        initialEnter: const [
          editor.LayerAnimation(
            type: editor.LayerAnimationType.fade,
            phase: editor.AnimationPhase.animateIn,
            duration: Duration(milliseconds: 400),
          ),
        ],
      );

      await tester.tap(find.text(l10n.videoEditorLayerAnimationLeave));
      await tester.pump();
      await tester.tap(find.text(l10n.videoEditorLayerAnimationScale));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text(l10n.videoEditorDoneLabel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(result?.enter.single.type, editor.LayerAnimationType.fade);
      expect(result?.leave.single.type, editor.LayerAnimationType.scale);
      expect(result?.leave.single.phase, editor.AnimationPhase.animateOut);
    });

    testWidgets('shows direction options only for slide', (tester) async {
      await openPicker(tester);

      await tester.tap(find.text(l10n.videoEditorLayerAnimationFade));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text(l10n.videoEditorTransitionDirection), findsNothing);

      await tester.tap(find.text(l10n.videoEditorTransitionSlide));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text(l10n.videoEditorTransitionDirection), findsOneWidget);
    });

    testWidgets('shows the scale-from control only for scale', (tester) async {
      await openPicker(tester);

      await tester.tap(find.text(l10n.videoEditorLayerAnimationScale));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(
        find.text(l10n.videoEditorLayerAnimationScaleFrom),
        findsOneWidget,
      );
    });

    testWidgets('carries the chosen slide direction into the result', (
      tester,
    ) async {
      await openPicker(tester);

      await tester.tap(find.text(l10n.videoEditorTransitionSlide));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is DivineIcon && w.icon == DivineIconName.arrowUp,
        ),
      );
      await tester.pump();
      await tester.tap(find.text(l10n.videoEditorDoneLabel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(result?.enter.single.type, editor.LayerAnimationType.slide);
      expect(result?.enter.single.slideDirection, editor.SlideDirection.top);
    });

    testWidgets('combines fade and slide into one phase', (tester) async {
      await openPicker(tester);

      await tester.tap(find.text(l10n.videoEditorLayerAnimationFade));
      await tester.pump();
      await tester.tap(find.text(l10n.videoEditorTransitionSlide));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text(l10n.videoEditorDoneLabel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(
        result?.enter.map((a) => a.type),
        containsAll(<editor.LayerAnimationType>[
          editor.LayerAnimationType.fade,
          editor.LayerAnimationType.slide,
        ]),
      );
      expect(result?.enter, hasLength(2));
      expect(
        result?.enter.every((a) => a.phase == editor.AnimationPhase.animateIn),
        isTrue,
      );
      expect(result?.leave, isEmpty);
    });

    testWidgets('toggling a selected type removes it', (tester) async {
      await openPicker(tester);

      await tester.tap(find.text(l10n.videoEditorLayerAnimationFade));
      await tester.pump();
      await tester.tap(find.text(l10n.videoEditorLayerAnimationFade));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text(l10n.videoEditorDoneLabel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(result?.enter, isEmpty);
    });
  });

  group('resolveLayerEndTime', () {
    const windowEnd = Duration(seconds: 5);

    test('anchors an untrimmed layer to the window end for a leave '
        'animation', () {
      expect(
        resolveLayerEndTime(
          currentEndTime: null,
          windowEndTime: windowEnd,
          hasLeaveAnimation: true,
        ),
        windowEnd,
      );
    });

    test('keeps an explicit trim end for a leave animation', () {
      const trimEnd = Duration(seconds: 2);
      expect(
        resolveLayerEndTime(
          currentEndTime: trimEnd,
          windowEndTime: windowEnd,
          hasLeaveAnimation: true,
        ),
        trimEnd,
      );
    });

    test('leaves an untrimmed layer untrimmed without a leave animation', () {
      expect(
        resolveLayerEndTime(
          currentEndTime: null,
          windowEndTime: windowEnd,
          hasLeaveAnimation: false,
        ),
        isNull,
      );
    });

    test('preserves an explicit trim end without a leave animation', () {
      const trimEnd = Duration(seconds: 3);
      expect(
        resolveLayerEndTime(
          currentEndTime: trimEnd,
          windowEndTime: windowEnd,
          hasLeaveAnimation: false,
        ),
        trimEnd,
      );
    });
  });
}

typedef _LayerAnimationResult = ({
  List<editor.LayerAnimation> enter,
  List<editor.LayerAnimation> leave,
});
