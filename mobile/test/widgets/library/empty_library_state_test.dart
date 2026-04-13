// ABOUTME: Tests for EmptyLibraryState widget
// ABOUTME: Verifies icon, title, subtitle, and optional record button

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/library/empty_library_state.dart';

void main() {
  group(EmptyLibraryState, () {
    Widget buildWidget({
      DivineIconName icon = DivineIconName.filmSlate,
      String title = 'Test Title',
      String subtitle = 'Test Subtitle',
      bool showRecordButton = true,
    }) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: Scaffold(
          body: EmptyLibraryState(
            icon: icon,
            title: title,
            subtitle: subtitle,
            showRecordButton: showRecordButton,
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('displays icon with correct $DivineIconName', (tester) async {
        await tester.pumpWidget(buildWidget(icon: DivineIconName.play));

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is DivineIcon && widget.icon == DivineIconName.play,
          ),
          findsOneWidget,
        );
      });

      testWidgets('displays title text', (tester) async {
        await tester.pumpWidget(buildWidget(title: 'No Clips Yet'));

        expect(find.text('No Clips Yet'), findsOneWidget);
      });

      testWidgets('displays subtitle text', (tester) async {
        await tester.pumpWidget(
          buildWidget(subtitle: 'Clips will appear here'),
        );

        expect(find.text('Clips will appear here'), findsOneWidget);
      });

      testWidgets('displays record button by default', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(find.text('Record a Video'), findsOneWidget);
        expect(find.byType(DivineButton), findsOneWidget);
      });

      testWidgets('hides record button when showRecordButton is false', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget(showRecordButton: false));

        expect(find.text('Record a Video'), findsNothing);
        expect(find.byType(ElevatedButton), findsNothing);
      });

      testWidgets('displays circular container with icon', (tester) async {
        await tester.pumpWidget(buildWidget());

        final container = tester.widget<Container>(
          find.ancestor(
            of: find.byType(DivineIcon),
            matching: find.byType(Container),
          ),
        );

        expect(container.decoration, isA<BoxDecoration>());
        final decoration = container.decoration! as BoxDecoration;
        expect(decoration.shape, BoxShape.circle);
      });

      testWidgets('record button has videocam icon', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is DivineIcon &&
                widget.icon == DivineIconName.videoCamera,
          ),
          findsOneWidget,
        );
      });
    });
  });
}
