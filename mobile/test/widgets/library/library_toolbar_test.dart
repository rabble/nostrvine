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
  final displayOptionsLabel =
      '${en.librarySortClipsSemanticLabel}. ${en.libraryGridSizeLabel}';

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
      bool isTrashFilterActive = false,
      VoidCallback? onEmptyTrash,
      VoidCallback? onManageActiveCategory,
      VoidCallback? onMoveSelectedClips,
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
            isTrashFilterActive: isTrashFilterActive,
            onEmptyTrash: onEmptyTrash,
            onManageActiveCategory: onManageActiveCategory,
            onMoveSelectedClips: onMoveSelectedClips,
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

        final title = tester.widget<Text>(find.text(en.profileMyLibraryLabel));
        expect(title.maxLines, equals(1));
        expect(title.overflow, equals(TextOverflow.ellipsis));
      });

      testWidgets('shows back leading icon outside selection mode', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());

        expect(iconButton(DivineIconName.caretLeft), findsOneWidget);
        expect(iconButton(DivineIconName.x), findsNothing);
        expect(
          find.bySemanticsLabel(en.libraryCloseSemanticLabel),
          findsOneWidget,
        );
      });

      testWidgets('shows close leading icon in selection mode', (tester) async {
        await tester.pumpWidget(buildWidget(isLibrarySelectionMode: true));

        expect(iconButton(DivineIconName.x), findsOneWidget);
        expect(iconButton(DivineIconName.caretLeft), findsNothing);
        expect(
          find.bySemanticsLabel(en.libraryStopSelectingClipsSemanticLabel),
          findsOneWidget,
        );
      });

      testWidgets('locked selection mode labels leading action as close', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            isLibrarySelectionMode: true,
            canExitSelectionMode: false,
          ),
        );

        expect(
          find.bySemanticsLabel(en.libraryCloseSemanticLabel),
          findsOneWidget,
        );
        expect(iconButton(DivineIconName.caretLeft), findsOneWidget);
        expect(iconButton(DivineIconName.x), findsNothing);
      });

      testWidgets('shows back icon for a preserved selection on Drafts', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            isLibrarySelectionMode: true,
            canExitSelectionMode: false,
            isClipsTabActive: false,
          ),
        );

        expect(iconButton(DivineIconName.caretLeft), findsOneWidget);
        expect(iconButton(DivineIconName.x), findsNothing);
        expect(
          find.bySemanticsLabel(en.libraryCloseSemanticLabel),
          findsOneWidget,
        );
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
          find.bySemanticsLabel(displayOptionsLabel),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(en.librarySelectClipsSemanticLabel),
          findsOneWidget,
        );
      });

      testWidgets('swaps Select for move and delete in selection mode', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget(isLibrarySelectionMode: true));

        expect(find.text(en.librarySelect), findsNothing);
        expect(
          find.bySemanticsLabel(en.libraryMoveSelectedClipsTooltip),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(en.libraryDeleteSelectedClipsTooltip),
          findsOneWidget,
        );
      });

      testWidgets('offers only Empty trash while the trash filter is on', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(isTrashFilterActive: true, onEmptyTrash: () {}),
        );

        expect(find.text(en.libraryTrashEmptyAllLabel), findsOneWidget);
        expect(find.text(en.librarySelect), findsNothing);
        expect(iconButton(DivineIconName.funnelSimple), findsNothing);
      });

      testWidgets('hides Empty trash when the bin is empty', (tester) async {
        await tester.pumpWidget(buildWidget(isTrashFilterActive: true));

        expect(find.text(en.libraryTrashEmptyAllLabel), findsNothing);
      });

      testWidgets('shows the manage action only for a category filter', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        expect(iconButton(DivineIconName.pencilSimple), findsNothing);

        await tester.pumpWidget(
          buildWidget(onManageActiveCategory: () {}),
        );
        expect(
          find.bySemanticsLabel(en.libraryCategoryManageSemanticLabel),
          findsOneWidget,
        );
      });
    });

    group('layout', () {
      testWidgets('keeps the same height across every action set', (
        tester,
      ) async {
        // The toolbar sits above the clip grid, so any height change shifts
        // the content under it. Switching to the trash filter swaps the whole
        // action set, which must not move the grid.
        final heights = <String, double>{};
        final cases = <String, Widget>{
          'browse': buildWidget(),
          'selection': buildWidget(
            isLibrarySelectionMode: true,
            onMoveSelectedClips: () {},
            onDeleteSelectedClips: () {},
          ),
          'category active': buildWidget(onManageActiveCategory: () {}),
          'trash with items': buildWidget(
            isTrashFilterActive: true,
            onEmptyTrash: () {},
          ),
          'trash empty': buildWidget(isTrashFilterActive: true),
          'drafts tab': buildWidget(isClipsTabActive: false),
        };

        for (final entry in cases.entries) {
          await tester.pumpWidget(entry.value);
          heights[entry.key] = tester
              .getSize(find.byType(LibraryToolbar))
              .height;
        }

        expect(
          heights.values.toSet(),
          hasLength(1),
          reason: 'toolbar height varies by action set: $heights',
        );
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

      testWidgets('Empty trash button triggers onEmptyTrash', (tester) async {
        var pressed = false;
        await tester.pumpWidget(
          buildWidget(
            isTrashFilterActive: true,
            onEmptyTrash: () => pressed = true,
          ),
        );

        await tester.tap(find.text(en.libraryTrashEmptyAllLabel));
        expect(pressed, isTrue);
      });

      testWidgets('move button triggers onMoveSelectedClips', (tester) async {
        var pressed = false;
        await tester.pumpWidget(
          buildWidget(
            isLibrarySelectionMode: true,
            onMoveSelectedClips: () => pressed = true,
          ),
        );

        await tester.tap(iconButton(DivineIconName.folderOpen));
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
