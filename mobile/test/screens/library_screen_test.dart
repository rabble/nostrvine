// ABOUTME: Tests for LibraryScreen - browsing and managing saved clips/drafts
// ABOUTME: Covers tabs, navigation, empty states, and clip selection flows

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as models;
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/l10n/generated/app_localizations_en.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/screens/library_screen.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:openvine/widgets/library/clips_tab.dart';
import 'package:openvine/widgets/library/drafts_tab.dart';
import 'package:openvine/widgets/library/empty_library_state.dart';
import 'package:openvine/widgets/video_clip/video_clip_thumbnail_card.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/go_router.dart';

class _MockGallerySaveService extends Mock implements GallerySaveService {}

class _MockClipLibraryService extends Mock implements ClipLibraryService {}

class _MockDraftStorageService extends Mock implements DraftStorageService {}

void main() {
  final en = AppLocalizationsEn();

  group(LibraryScreen, () {
    late _MockGallerySaveService mockGallerySaveService;
    late _MockClipLibraryService mockClipLibraryService;
    late _MockDraftStorageService mockDraftStorageService;

    setUpAll(() {
      registerFallbackValue(<DivineVideoClip>[]);
    });

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
      bool enableSoundTab = true,
      List<DivineVideoClip> editorClips = const [],
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
            enableSoundTab: enableSoundTab,
            editorClips: editorClips,
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('screen with tabs and My library title', (tester) async {
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

      testWidgets('no app bar in selection mode', (tester) async {
        await tester.pumpWidget(buildWidget(selectionMode: true));
        await tester.pump();

        // In selection mode, appBar is null
        expect(find.text('My library'), findsNothing);
      });

      testWidgets('no FloatingActionButton', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        expect(find.byType(FloatingActionButton), findsNothing);
      });
    });

    group('tab navigation', () {
      testWidgets('hides Sounds tab when enableSoundTab is false', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget(enableSoundTab: false));
        await tester.pumpAndSettle();

        expect(find.text('Drafts'), findsOneWidget);
        expect(find.text('Clips'), findsOneWidget);
        expect(find.text('Sounds'), findsNothing);
      });

      testWidgets('tab flow stays stable with only Drafts and Clips', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(enableSoundTab: false, initialTabIndex: 1),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ClipsTab), findsOneWidget);

        await tester.tap(find.text('Drafts'));
        await tester.pumpAndSettle();

        expect(find.byType(DraftsTab), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

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

    group('_createVideoFromSelected', () {
      testWidgets(
        'selection mode does not return clips already in editorClips',
        (tester) async {
          final existingClip = DivineVideoClip(
            id: 'existing-clip',
            video: EditorVideo.file('/test/existing.mp4'),
            duration: const Duration(seconds: 2),
            recordedAt: DateTime.now(),
            targetAspectRatio: models.AspectRatio.vertical,
            originalAspectRatio: 9 / 16,
            thumbnailPath: '/test/existing.jpg',
            ghostFramePath: '/test/existing_ghost.jpg',
          );
          final newClip = DivineVideoClip(
            id: 'new-clip',
            video: EditorVideo.file('/test/new.mp4'),
            duration: const Duration(seconds: 3),
            recordedAt: DateTime.now(),
            targetAspectRatio: models.AspectRatio.vertical,
            originalAspectRatio: 9 / 16,
            thumbnailPath: '/test/new.jpg',
            ghostFramePath: '/test/new_ghost.jpg',
          );

          when(
            () => mockClipLibraryService.getAllClips(),
          ).thenAnswer((_) async => [existingClip, newClip]);
          when(
            () => mockClipLibraryService.recoverMissingAssets(any()),
          ).thenAnswer((_) async => [existingClip, newClip]);

          final mockGoRouter = MockGoRouter();

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                gallerySaveServiceProvider.overrideWithValue(
                  mockGallerySaveService,
                ),
                clipLibraryServiceProvider.overrideWithValue(
                  mockClipLibraryService,
                ),
                draftStorageServiceProvider.overrideWithValue(
                  mockDraftStorageService,
                ),
                clipManagerProvider.overrideWith(ClipManagerNotifier.new),
              ],
              child: MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: VineTheme.theme,
                home: MockGoRouterProvider(
                  goRouter: mockGoRouter,
                  child: LibraryScreen(
                    selectionMode: true,
                    initialTabIndex: 1,
                    editorClips: [existingClip],
                    enableSoundTab: false,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final cards = find.byType(VideoClipThumbnailCard);
          expect(cards, findsNWidgets(2));

          await tester.tap(cards.at(0));
          await tester.tap(cards.at(1));
          await tester.pumpAndSettle();

          await tester.tap(find.text('Select').first);
          await tester.pumpAndSettle();

          final captured = verify(
            () => mockGoRouter.pop<List<DivineVideoClip>>(captureAny()),
          ).captured;
          expect(captured, hasLength(1));

          final clips = captured.first as List<DivineVideoClip>;
          expect(clips.map((c) => c.id), isNot(contains('existing-clip')));
          expect(clips.map((c) => c.id), contains('new-clip'));
        },
      );

      testWidgets(
        'selection mode pops with selected clips when Add is tapped',
        (tester) async {
          final testClip = DivineVideoClip(
            id: 'sel-clip-1',
            video: EditorVideo.file('/test/clip1.mp4'),
            duration: const Duration(seconds: 3),
            recordedAt: DateTime.now(),
            targetAspectRatio: models.AspectRatio.vertical,
            originalAspectRatio: 9 / 16,
            thumbnailPath: '/test/thumb1.jpg',
            ghostFramePath: '/test/ghost1.jpg',
          );

          when(
            () => mockClipLibraryService.getAllClips(),
          ).thenAnswer((_) async => [testClip]);
          when(
            () => mockClipLibraryService.recoverMissingAssets(any()),
          ).thenAnswer((_) async => [testClip]);

          final mockGoRouter = MockGoRouter();

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                gallerySaveServiceProvider.overrideWithValue(
                  mockGallerySaveService,
                ),
                clipLibraryServiceProvider.overrideWithValue(
                  mockClipLibraryService,
                ),
                draftStorageServiceProvider.overrideWithValue(
                  mockDraftStorageService,
                ),
                clipManagerProvider.overrideWith(ClipManagerNotifier.new),
              ],
              child: MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: VineTheme.theme,
                home: MockGoRouterProvider(
                  goRouter: mockGoRouter,
                  child: const LibraryScreen(
                    selectionMode: true,
                    initialTabIndex: 1,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Clips tab should show the clip
          expect(find.byType(ClipSelectionHeader), findsOneWidget);

          // Locate a clip thumbnail card and tap to select it
          final clipCard = find.byType(VideoClipThumbnailCard);
          expect(clipCard, findsOneWidget);
          await tester.tap(clipCard);
          await tester.pumpAndSettle();

          // Tap "Select" button (visible in the header)
          await tester.tap(find.text('Select').first);
          await tester.pumpAndSettle();

          // Verify context.pop was called with the selected clip list
          final captured = verify(
            () => mockGoRouter.pop<List<DivineVideoClip>>(captureAny()),
          ).captured;
          expect(captured, hasLength(1));
          final clips = captured.first as List<DivineVideoClip>;
          expect(clips, hasLength(1));
          expect(clips.first.id, equals('sel-clip-1'));
        },
      );
    });
    group('web', () {
      testWidgets('shows mobile-app intercept instead of tabs', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.text(en.libraryWebUnavailableHeadline), findsOneWidget);
        expect(find.text(en.libraryWebUnavailableDescription), findsOneWidget);
        expect(find.text(en.libraryTabDrafts), findsNothing);
        expect(find.text(en.libraryTabClips), findsNothing);
      }, skip: !kIsWeb);
    });
  });
}
