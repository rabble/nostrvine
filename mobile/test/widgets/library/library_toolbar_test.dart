// ABOUTME: Tests for LibraryToolbar widget
// ABOUTME: Covers title truncation, conditional actions, and button callbacks

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/l10n/generated/app_localizations_en.dart';
import 'package:openvine/widgets/library/library_toolbar.dart';

void main() {
  final en = AppLocalizationsEn();

  group(LibraryToolbar, () {
    Finder iconButton(DivineIconName icon) => find.byWidgetPredicate(
      (widget) => widget is DivineIconButton && widget.icon == icon,
    );

    Widget buildWidget({
      bool isLibrarySelectionMode = false,
      bool canExitSelectionMode = true,
      bool isClipsTabActive = true,
      VoidCallback? onLeadingPressed,
      VoidCallback? onOpenSortMenu,
      VoidCallback? onEnterSelectionMode,
      VoidCallback? onOpenTrash,
      VoidCallback? onDeleteSelectedClips,
    }) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: Scaffold(
          body: LibraryToolbar(
            isLibrarySelectionMode: isLibrarySelectionMode,
            canExitSelectionMode: canExitSelectionMode,
            isClipsTabActive: isClipsTabActive,
            onLeadingPressed: onLeadingPressed ?? () {},
            onOpenSortMenu: onOpenSortMenu ?? () {},
            onEnterSelectionMode: onEnterSelectionMode ?? () {},
            onOpenTrash: onOpenTrash ?? () {},
            onDeleteSelectedClips: onDeleteSelectedClips,
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('displays the library title', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(find.text(en.profileMyLibraryLabel), findsOneWidget);
      });

      testWidgets('title is limited to a single line with ellipsis', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());

        final title = tester.widget<Text>(
          find.text(en.profileMyLibraryLabel),
        );
        expect(title.maxLines, equals(1));
        expect(title.overflow, equals(TextOverflow.ellipsis));
      });

      testWidgets('shows back leading icon outside selection mode', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());

        expect(iconButton(DivineIconName.caretLeft), findsOneWidget);
        expect(iconButton(DivineIconName.x), findsNothing);
      });

      testWidgets('shows close leading icon in selection mode', (tester) async {
        await tester.pumpWidget(buildWidget(isLibrarySelectionMode: true));

        expect(iconButton(DivineIconName.x), findsOneWidget);
        expect(iconButton(DivineIconName.caretLeft), findsNothing);
        expect(find.bySemanticsLabel(en.commonCancel), findsOneWidget);
      });

      testWidgets('hides clip actions when clips tab is inactive', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget(isClipsTabActive: false));

        expect(find.text(en.librarySelect), findsNothing);
        expect(iconButton(DivineIconName.funnelSimple), findsNothing);
        expect(iconButton(DivineIconName.trash), findsNothing);
      });

      testWidgets('shows clip actions when clips tab is active', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());

        expect(find.text(en.librarySelect), findsOneWidget);
        expect(iconButton(DivineIconName.funnelSimple), findsOneWidget);
        expect(
          find.bySemanticsLabel(en.libraryTrashEntryLabel),
          findsOneWidget,
        );
      });

      testWidgets('swaps Select for delete in selection mode', (tester) async {
        await tester.pumpWidget(buildWidget(isLibrarySelectionMode: true));

        expect(find.text(en.librarySelect), findsNothing);
        expect(find.bySemanticsLabel(en.commonDelete), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('leading button triggers onLeadingPressed', (tester) async {
        var pressed = false;
        await tester.pumpWidget(
          buildWidget(onLeadingPressed: () => pressed = true),
        );

        await tester.tap(iconButton(DivineIconName.caretLeft));
        expect(pressed, isTrue);
      });

      testWidgets('sort button triggers onOpenSortMenu', (tester) async {
        var pressed = false;
        await tester.pumpWidget(
          buildWidget(onOpenSortMenu: () => pressed = true),
        );

        await tester.tap(iconButton(DivineIconName.funnelSimple));
        expect(pressed, isTrue);
      });

      testWidgets('Select button triggers onEnterSelectionMode', (
        tester,
      ) async {
        var pressed = false;
        await tester.pumpWidget(
          buildWidget(onEnterSelectionMode: () => pressed = true),
        );

        await tester.tap(find.text(en.librarySelect));
        expect(pressed, isTrue);
      });

      testWidgets('trash button triggers onOpenTrash', (tester) async {
        var pressed = false;
        await tester.pumpWidget(
          buildWidget(onOpenTrash: () => pressed = true),
        );

        await tester.tap(iconButton(DivineIconName.trash));
        expect(pressed, isTrue);
      });

      testWidgets('delete button triggers onDeleteSelectedClips', (
        tester,
      ) async {
        var pressed = false;
        await tester.pumpWidget(
          buildWidget(
            isLibrarySelectionMode: true,
            onDeleteSelectedClips: () => pressed = true,
          ),
        );

        await tester.tap(iconButton(DivineIconName.trash));
        expect(pressed, isTrue);
      });
    });
  });
}
