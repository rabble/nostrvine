// ABOUTME: Tests for LibraryScreen - browsing and managing saved clips/drafts
// ABOUTME: Covers tabs, navigation, and empty states

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/l10n/generated/app_localizations_en.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/screens/library_screen.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:openvine/widgets/library/clips_tab.dart';
import 'package:openvine/widgets/library/drafts_tab.dart';
import 'package:openvine/widgets/library/empty_library_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockGallerySaveService extends Mock implements GallerySaveService {}

class _MockClipLibraryService extends Mock implements ClipLibraryService {}

class _MockDraftStorageService extends Mock implements DraftStorageService {}

void main() {
  final en = AppLocalizationsEn();

  group(LibraryScreen, () {
    late _MockGallerySaveService mockGallerySaveService;
    late _MockClipLibraryService mockClipLibraryService;
    late _MockDraftStorageService mockDraftStorageService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockGallerySaveService = _MockGallerySaveService();
      mockClipLibraryService = _MockClipLibraryService();
      mockDraftStorageService = _MockDraftStorageService();

      when(
        () => mockClipLibraryService.getAllClips(),
      ).thenAnswer((_) async => []);
      when(
        () => mockDraftStorageService.getAllDrafts(),
      ).thenAnswer((_) async => []);
    });

    Widget buildWidget({
      bool selectionMode = false,
      int initialTabIndex = 0,
    }) {
      return ProviderScope(
        overrides: [
          gallerySaveServiceProvider.overrideWithValue(mockGallerySaveService),
          clipLibraryServiceProvider.overrideWithValue(mockClipLibraryService),
          draftStorageServiceProvider.overrideWithValue(
            mockDraftStorageService,
          ),
          clipManagerProvider.overrideWith(ClipManagerNotifier.new),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: LibraryScreen(
            selectionMode: selectionMode,
            initialTabIndex: initialTabIndex,
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('screen with tabs', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        // Should find tab bar with Drafts and Clips
        expect(find.text(en.libraryTabDrafts), findsOneWidget);
        expect(find.text(en.libraryTabClips), findsOneWidget);
      });

      testWidgets('$DraftsTab initially (first tab)', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        // Drafts tab is default selected (first in order)
        expect(find.byType(DraftsTab), findsOneWidget);
      });

      testWidgets('$ClipsTab initially when initialTabIndex is 1', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget(initialTabIndex: 1));
        await tester.pumpAndSettle();

        expect(find.byType(ClipsTab), findsOneWidget);
      });

      testWidgets('$ClipSelectionHeader in selection mode', (tester) async {
        await tester.pumpWidget(buildWidget(selectionMode: true));
        await tester.pump();

        expect(find.byType(ClipSelectionHeader), findsOneWidget);
      });
    });

    group('tab navigation', () {
      testWidgets('can switch to $ClipsTab', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        // Switch to clips tab
        await tester.tap(find.text(en.libraryTabClips));
        await tester.pumpAndSettle();

        expect(find.byType(ClipsTab), findsOneWidget);
      });

      testWidgets('can switch back to $DraftsTab', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        // Switch to clips tab
        await tester.tap(find.text(en.libraryTabClips));
        await tester.pumpAndSettle();

        // Switch back to drafts tab
        await tester.tap(find.text(en.libraryTabDrafts));
        await tester.pumpAndSettle();

        expect(find.byType(DraftsTab), findsOneWidget);
      });
    });

    group('empty state', () {
      testWidgets(
        'drafts tab does not show path_provider plugin errors after load',
        (tester) async {
          await tester.pumpWidget(buildWidget());
          await tester.pumpAndSettle();

          expect(find.textContaining('MissingPluginException'), findsNothing);
          expect(
            find.textContaining('getApplicationDocumentsDirectory'),
            findsNothing,
          );
        },
      );

      testWidgets('shows $EmptyLibraryState when no drafts', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        // Drafts tab is default; with no drafts should show empty state
        expect(find.byType(EmptyLibraryState), findsOneWidget);
        expect(find.text(en.libraryNoDraftsYetTitle), findsOneWidget);
      });

      testWidgets('shows $EmptyLibraryState when no clips', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        // Switch to clips tab
        await tester.tap(find.text(en.libraryTabClips));
        await tester.pumpAndSettle();

        // With no clips saved, should show empty state
        expect(find.byType(EmptyLibraryState), findsOneWidget);
        expect(find.text(en.libraryNoClipsYetTitle), findsOneWidget);
      });
    });

    group('web', () {
      testWidgets(
        'shows mobile-app intercept instead of tabs',
        (tester) async {
          await tester.pumpWidget(buildWidget());
          await tester.pumpAndSettle();

          expect(
            find.text(en.libraryWebUnavailableHeadline),
            findsOneWidget,
          );
          expect(
            find.text(en.libraryWebUnavailableDescription),
            findsOneWidget,
          );
          expect(find.text(en.libraryTabDrafts), findsNothing);
          expect(find.text(en.libraryTabClips), findsNothing);
        },
        skip: !kIsWeb,
      );
    });
  });
}
