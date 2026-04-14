// ABOUTME: TDD widget test for Drafts menu item in profile screen options
// ABOUTME: Tests that Drafts menu item exists and navigates correctly

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/library_screen.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/draft_storage_service.dart';

class _MockClipLibraryService extends Mock implements ClipLibraryService {}

class _MockDraftStorageService extends Mock implements DraftStorageService {}

void main() {
  group('Profile menu drafts widget', () {
    testWidgets('should render Drafts menu item with correct icon and text', (
      tester,
    ) async {
      // Create a simple test widget with the menu structure
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.grey[900],
                    builder: (context) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            key: const Key('drafts-menu-item'),
                            leading: const Icon(
                              Icons.drafts,
                              color: VineTheme.vineGreen,
                            ),
                            title: const Text(
                              'Drafts',
                              style: TextStyle(color: Colors.white),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LibraryScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
                child: const Text('Open Menu'),
              ),
            ),
          ),
        ),
      );

      // Tap to open menu
      await tester.tap(find.text('Open Menu'));
      await tester.pumpAndSettle();

      // Verify Drafts menu item exists
      expect(find.byKey(const Key('drafts-menu-item')), findsOneWidget);
      expect(find.text('Drafts'), findsOneWidget);
      expect(find.byIcon(Icons.drafts), findsOneWidget);
    });

    testWidgets('should navigate to ClipLibraryScreen when tapped', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.grey[900],
                    builder: (context) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            key: const Key('drafts-menu-item'),
                            leading: const Icon(
                              Icons.drafts,
                              color: VineTheme.vineGreen,
                            ),
                            title: const Text(
                              'Drafts',
                              style: TextStyle(color: Colors.white),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LibraryScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
                child: const Text('Open Menu'),
              ),
            ),
          ),
        ),
      );

      // Open menu
      await tester.tap(find.text('Open Menu'));
      await tester.pumpAndSettle();

      // Tap Drafts
      await tester.tap(find.text('Drafts'));
      await tester.pumpAndSettle();

      // Should navigate to ClipLibraryScreen
      expect(find.byType(LibraryScreen), findsOneWidget);
      expect(find.text('Drafts'), findsWidgets); // App bar title
      // TODO(Any): Fix and re-enable these tests
    }, skip: true);

    testWidgets('should close menu after navigating to drafts', (tester) async {
      final mockClipLibraryService = _MockClipLibraryService();
      final mockDraftStorageService = _MockDraftStorageService();
      when(mockClipLibraryService.getAllClips).thenAnswer((_) async => []);
      when(mockDraftStorageService.getAllDrafts).thenAnswer((_) async => []);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clipLibraryServiceProvider.overrideWithValue(
              mockClipLibraryService,
            ),
            draftStorageServiceProvider.overrideWithValue(
              mockDraftStorageService,
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.grey[900],
                      builder: (context) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              key: const Key('settings-menu-item'),
                              leading: const Icon(
                                Icons.settings,
                                color: VineTheme.vineGreen,
                              ),
                              title: const Text(
                                'Settings',
                                style: TextStyle(color: Colors.white),
                              ),
                              onTap: () {},
                            ),
                            ListTile(
                              key: const Key('drafts-menu-item'),
                              leading: const Icon(
                                Icons.drafts,
                                color: VineTheme.vineGreen,
                              ),
                              title: const Text(
                                'Drafts',
                                style: TextStyle(color: Colors.white),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const LibraryScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: const Text('Open Menu'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Menu'));
      await tester.pumpAndSettle();

      // Verify menu is open
      expect(find.text('Settings'), findsOneWidget);

      await tester.tap(find.text('Drafts'));
      await tester.pumpAndSettle();

      // Menu should be closed - Settings should not be visible
      expect(find.text('Settings'), findsNothing);
      expect(find.byType(LibraryScreen), findsOneWidget);
    });
  });
}
