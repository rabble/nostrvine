// ABOUTME: Behavior tests for the transition picker view (preview + controls).

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_editor/transition_boundary/transition_boundary_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_transition_sheet.dart';
import 'package:pro_video_editor/pro_video_editor.dart' as editor;

/// Stand-in cubit that holds fixed (null) boundary frames without touching the
/// platform thumbnail service, so the picker renders its gradient fallback.
class _FakeTransitionBoundaryCubit extends Cubit<TransitionBoundaryState>
    implements TransitionBoundaryCubit {
  _FakeTransitionBoundaryCubit() : super(const TransitionBoundaryState());
}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group(TransitionPickerView, () {
    late ({editor.ClipTransition? transition})? result;
    late bool returned;

    Future<void> openPicker(
      WidgetTester tester, {
      editor.ClipTransition? initial,
      int maxDurationMs = 2000,
    }) async {
      result = null;
      returned = false;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await Navigator.of(context)
                      .push<({editor.ClipTransition? transition})>(
                        MaterialPageRoute(
                          builder: (_) => BlocProvider<TransitionBoundaryCubit>(
                            create: (_) => _FakeTransitionBoundaryCubit(),
                            child: Scaffold(
                              body: TransitionPickerView(
                                initial: initial,
                                maxDurationMs: maxDurationMs,
                              ),
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
      // The picker loops forever, so never pumpAndSettle — advance manually.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
    }

    testWidgets('lists every transition option', (tester) async {
      await openPicker(tester);

      expect(find.text(l10n.videoEditorTransitionNone), findsOneWidget);
      expect(find.text(l10n.videoEditorTransitionDissolve), findsOneWidget);
      expect(find.text(l10n.videoEditorTransitionFadeToBlack), findsOneWidget);
      expect(find.text(l10n.videoEditorTransitionWipe), findsOneWidget);
    });

    testWidgets('reveals duration + curve only once a transition is picked', (
      tester,
    ) async {
      await openPicker(tester);

      // "None" is selected initially → no duration/curve controls.
      expect(find.text(l10n.videoEditorTransitionDuration), findsNothing);

      await tester.tap(find.text(l10n.videoEditorTransitionDissolve));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text(l10n.videoEditorTransitionDuration), findsOneWidget);
      expect(find.text(l10n.videoEditorTransitionCurve), findsOneWidget);
    });

    testWidgets('keeps the duration when the type changes, on confirm', (
      tester,
    ) async {
      await openPicker(
        tester,
        initial: const editor.ClipTransition(
          type: editor.ClipTransitionType.dissolve,
          duration: Duration(milliseconds: 1200),
        ),
      );

      await tester.tap(find.text(l10n.videoEditorTransitionFadeToBlack));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text(l10n.videoEditorDoneLabel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(returned, isTrue);
      expect(result?.transition?.type, editor.ClipTransitionType.fadeToBlack);
      expect(
        result?.transition?.duration,
        const Duration(milliseconds: 1200),
      );
    });

    testWidgets('dragging the slider to the end sets the max duration', (
      tester,
    ) async {
      await openPicker(tester);

      await tester.tap(find.text(l10n.videoEditorTransitionDissolve));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      await tester.drag(find.byType(DivineSlider), const Offset(1000, 0));
      await tester.pump();
      await tester.tap(find.text(l10n.videoEditorDoneLabel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(returned, isTrue);
      expect(
        result?.transition?.duration,
        const Duration(milliseconds: 2000),
      );
    });

    testWidgets('caps an over-long duration at the boundary maximum', (
      tester,
    ) async {
      await openPicker(
        tester,
        maxDurationMs: 500,
        initial: const editor.ClipTransition(
          type: editor.ClipTransitionType.dissolve,
          duration: Duration(milliseconds: 1200),
        ),
      );

      await tester.tap(find.text(l10n.videoEditorDoneLabel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(
        result?.transition?.duration,
        const Duration(milliseconds: 500),
      );
    });

    testWidgets('returns null (hard cut) when None is confirmed', (
      tester,
    ) async {
      await openPicker(
        tester,
        initial: const editor.ClipTransition(
          type: editor.ClipTransitionType.dissolve,
        ),
      );

      await tester.tap(find.text(l10n.videoEditorTransitionNone));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text(l10n.videoEditorDoneLabel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(returned, isTrue);
      expect(result?.transition, isNull);
    });

    testWidgets('shows direction options only for directional transitions', (
      tester,
    ) async {
      await openPicker(tester);

      await tester.tap(find.text(l10n.videoEditorTransitionDissolve));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text(l10n.videoEditorTransitionDirection), findsNothing);

      await tester.tap(find.text(l10n.videoEditorTransitionSlide));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text(l10n.videoEditorTransitionDirection), findsOneWidget);
    });

    testWidgets('returns the chosen direction on confirm', (tester) async {
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

      expect(result?.transition?.type, editor.ClipTransitionType.slide);
      expect(
        result?.transition?.direction,
        editor.ClipTransitionDirection.up,
      );
    });
  });
}
