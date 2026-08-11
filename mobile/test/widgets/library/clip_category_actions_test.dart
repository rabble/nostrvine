// ABOUTME: Tests for the clip-category bottom sheets
// ABOUTME: Covers the name prompt's blank-input guard and returned value

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/l10n/generated/app_localizations_en.dart';
import 'package:openvine/widgets/library/clip_category_actions.dart';

void main() {
  final en = AppLocalizationsEn();

  group(ClipCategoryActions, () {
    late String? result;
    late bool completed;

    setUp(() {
      result = null;
      completed = false;
    });

    Widget buildHost({String? initialName}) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async {
                  result = await ClipCategoryActions.showNamePrompt(
                    context: context,
                    title: en.libraryCategoryCreateTitle,
                    confirmLabel: en.libraryCategoryCreateAction,
                    initialName: initialName,
                  );
                  completed = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
    }

    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    DivineButton confirmButton(WidgetTester tester) =>
        tester.widget<DivineButton>(
          find.ancestor(
            of: find.text(en.libraryCategoryCreateAction),
            matching: find.byType(DivineButton),
          ),
        );

    testWidgets('disables confirm until the name has usable text', (
      tester,
    ) async {
      await tester.pumpWidget(buildHost());
      await openSheet(tester);

      expect(confirmButton(tester).onPressed, isNull);

      await tester.enterText(
        find.byKey(const Key('clip_category_name_field')),
        '   ',
      );
      await tester.pump();
      expect(
        confirmButton(tester).onPressed,
        isNull,
        reason: 'whitespace is not a category name',
      );

      await tester.enterText(
        find.byKey(const Key('clip_category_name_field')),
        'Travel',
      );
      await tester.pump();
      expect(confirmButton(tester).onPressed, isNotNull);
    });

    testWidgets('returns the entered name', (tester) async {
      await tester.pumpWidget(buildHost());
      await openSheet(tester);

      await tester.enterText(
        find.byKey(const Key('clip_category_name_field')),
        'Travel',
      );
      await tester.pump();
      await tester.tap(find.text(en.libraryCategoryCreateAction));
      await tester.pumpAndSettle();

      expect(result, 'Travel');
    });

    testWidgets('seeds the field when renaming and returns null on dismiss', (
      tester,
    ) async {
      await tester.pumpWidget(buildHost(initialName: 'Travel'));
      await openSheet(tester);

      expect(find.text('Travel'), findsOneWidget);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(completed, isTrue);
      expect(result, isNull);
    });
  });
}
