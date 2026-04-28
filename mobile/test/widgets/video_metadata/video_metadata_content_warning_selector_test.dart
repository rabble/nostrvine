import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_content_warning_selector.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_selection_tile.dart';

import '../../helpers/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(VideoMetadataContentWarningSelector, () {
    late MockGoRouter mockGoRouter;

    setUp(() {
      mockGoRouter = MockGoRouter();
      when(mockGoRouter.canPop).thenReturn(true);
      when(() => mockGoRouter.pop<Object?>(any())).thenAnswer((_) async {});
      when(
        () => mockGoRouter.pop<Set<ContentLabel>>(any()),
      ).thenAnswer((_) async {});
    });

    Widget buildWidget({
      VideoEditorProviderState? state,
      _MockVideoEditorNotifier? notifier,
    }) {
      return ProviderScope(
        overrides: [
          videoEditorProvider.overrideWith(
            () =>
                notifier ??
                _MockVideoEditorNotifier(state ?? VideoEditorProviderState()),
          ),
        ],
        child: MockGoRouterProvider(
          goRouter: mockGoRouter,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: VideoMetadataContentWarningSelector()),
          ),
        ),
      );
    }

    testWidgets('renders $VideoMetadataContentWarningSelector', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(
        find.byType(VideoMetadataContentWarningSelector),
        findsOneWidget,
      );
    });

    testWidgets('renders $VideoMetadataSelectionTile', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(find.byType(VideoMetadataSelectionTile), findsOneWidget);
    });

    testWidgets('shows "None" when no content warnings are selected', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget());

      expect(find.text('None'), findsOneWidget);
    });

    testWidgets('displays "Content Warning" label', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(
        find.byWidgetPredicate(
          (w) => w is DivineTextField && w.labelText == 'Content Warning',
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows warning name when one content warning is selected', (
      tester,
    ) async {
      final state = VideoEditorProviderState(
        contentWarnings: {ContentLabel.nudity},
      );
      await tester.pumpWidget(buildWidget(state: state));

      expect(find.text('Nudity'), findsOneWidget);
    });

    testWidgets(
      'shows comma-joined names when multiple warnings are selected',
      (tester) async {
        final state = VideoEditorProviderState(
          contentWarnings: {ContentLabel.nudity, ContentLabel.violence},
        );
        await tester.pumpWidget(buildWidget(state: state));

        // The displayed text combines both labels. Since Set iteration order
        // follows enum declaration order, "Nudity" comes before "Violence".
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is EditableText &&
                w.controller.text.contains('Nudity') &&
                w.controller.text.contains('Violence'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('opens bottom sheet when tapped', (tester) async {
      await tester.pumpWidget(buildWidget());

      await tester.tap(
        find.bySemanticsLabel('Select content warnings'),
      );
      await tester.pumpAndSettle();

      // Bottom sheet header title should appear.
      expect(find.text('Content Warnings'), findsOneWidget);
    });

    testWidgets('bottom sheet shows all ContentLabel options', (
      tester,
    ) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;

      await tester.pumpWidget(buildWidget());

      await tester.tap(find.bySemanticsLabel('Select content warnings'));
      await tester.pumpAndSettle();

      expect(find.text('Nudity'), findsOneWidget);
      expect(find.text('Violence'), findsOneWidget);
      expect(find.text('Alcohol'), findsOneWidget);
    });

    testWidgets('tapping confirm button pops with selected labels', (
      tester,
    ) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;

      await tester.pumpWidget(buildWidget());

      await tester.tap(
        find.bySemanticsLabel('Select content warnings'),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      // Tap "Nudity" in the list.
      await tester.tap(find.text('Nudity'));
      await tester.pumpAndSettle();

      // Tap the check (confirm) icon button.
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byWidgetPredicate(
            (w) => w is DivineIconButton && w.icon == DivineIconName.check,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The bottom sheet pops via go_router with the selected labels.
      verify(
        () => mockGoRouter.pop<Set<ContentLabel>>(any()),
      ).called(1);
    });

    testWidgets('tapping an option toggles its checkbox state', (
      tester,
    ) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;

      await tester.pumpWidget(buildWidget());

      await tester.tap(find.bySemanticsLabel('Select content warnings'));
      await tester.pumpAndSettle();

      final unchecked = find.byWidgetPredicate(
        (w) =>
            w is DivineSpriteCheckbox &&
            w.state == DivineCheckboxState.unselected,
      );
      expect(unchecked, findsWidgets);

      // Tap the first label ("Nudity").
      await tester.tap(find.text('Nudity'));
      await tester.pump();

      final checked = find.byWidgetPredicate(
        (w) =>
            w is DivineSpriteCheckbox &&
            w.state == DivineCheckboxState.selected,
      );
      expect(checked, findsOneWidget);
    });
  });
}

class _MockVideoEditorNotifier extends VideoEditorNotifier {
  _MockVideoEditorNotifier(
    this._state, {
    this.onSetContentWarnings,
  });

  final VideoEditorProviderState _state;
  final void Function(Set<ContentLabel>)? onSetContentWarnings;

  @override
  VideoEditorProviderState build() => _state;

  @override
  void setContentWarnings(Set<ContentLabel> labels) {
    onSetContentWarnings?.call(labels);
    state = state.copyWith(contentWarnings: Set.of(labels));
  }
}
