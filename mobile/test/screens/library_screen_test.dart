// ABOUTME: Tests for LibraryScreen - browsing and managing saved clips/drafts
// ABOUTME: Covers tabs, navigation, and empty states

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/screens/library_screen.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:openvine/widgets/library/clips_tab.dart';
import 'package:openvine/widgets/library/drafts_tab.dart';
import 'package:openvine/widgets/library/empty_library_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockGallerySaveService extends Mock implements GallerySaveService {}

void main() {
  group(LibraryScreen, () {
    late _MockGallerySaveService mockGallerySaveService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockGallerySaveService = _MockGallerySaveService();
    });

    Widget buildWidget({bool selectionMode = false}) {
      return ProviderScope(
        overrides: [
          gallerySaveServiceProvider.overrideWith(
            (ref) => mockGallerySaveService,
          ),
          clipManagerProvider.overrideWith(ClipManagerNotifier.new),
        ],
        child: MaterialApp(
          theme: VineTheme.theme,
          home: LibraryScreen(selectionMode: selectionMode),
        ),
      );
    }

    group('renders', () {
      testWidgets('screen with tabs', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        // Should find tab bar with Drafts and Clips
        expect(find.text('Drafts'), findsOneWidget);
        expect(find.text('Clips'), findsOneWidget);
      });

      testWidgets('$DraftsTab initially (first tab)', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        // Drafts tab is default selected (first in order)
        expect(find.byType(DraftsTab), findsOneWidget);
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
        await tester.tap(find.text('Clips'));
        await tester.pumpAndSettle();

        expect(find.byType(ClipsTab), findsOneWidget);
      });

      testWidgets('can switch back to $DraftsTab', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        // Switch to clips tab
        await tester.tap(find.text('Clips'));
        await tester.pumpAndSettle();

        // Switch back to drafts tab
        await tester.tap(find.text('Drafts'));
        await tester.pumpAndSettle();

        expect(find.byType(DraftsTab), findsOneWidget);
      });
    });

    group('empty state', () {
      testWidgets('shows $EmptyLibraryState when no drafts', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        // Drafts tab is default; with no drafts should show empty state
        expect(find.byType(EmptyLibraryState), findsOneWidget);
        expect(find.text('No Drafts Yet'), findsOneWidget);
      });

      testWidgets('shows $EmptyLibraryState when no clips', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        // Switch to clips tab
        await tester.tap(find.text('Clips'));
        await tester.pumpAndSettle();

        // With no clips saved, should show empty state
        expect(find.byType(EmptyLibraryState), findsOneWidget);
        expect(find.text('No Clips Yet'), findsOneWidget);
      });
    });
  });
}
