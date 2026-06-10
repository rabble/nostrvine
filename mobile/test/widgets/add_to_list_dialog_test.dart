// ABOUTME: Tests for SelectListDialog and CreateListDialog widgets
// ABOUTME: Verifies list selection, list item interactions, and list creation form

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/widgets/add_to_list_dialog.dart';

import '../helpers/go_router.dart';
import '../helpers/test_provider_overrides.dart';

class _MockCuratedListService extends Mock implements CuratedListService {}

/// Test data for the fake notifier - set before each test
List<CuratedList> _fakeLists = [];

Finder _divineIcon(DivineIconName name) =>
    find.byWidgetPredicate((w) => w is DivineIcon && w.icon == name);

/// Mock service for the fake notifier - set before tests that need interactions
_MockCuratedListService? _fakeService;

/// Fake notifier that provides test data for curatedListsStateProvider
class _FakeCuratedListsState extends CuratedListsState {
  @override
  CuratedListService? get service => _fakeService;

  @override
  Future<List<CuratedList>> build() async => _fakeLists;
}

void main() {
  group(SelectListDialog, () {
    late VideoEvent testVideo;
    late _MockCuratedListService mockListService;

    setUp(() {
      testVideo = VideoEvent(
        id: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        pubkey:
            'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
        createdAt: 1757385263,
        content: 'Test video',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
        videoUrl: 'https://example.com/video.mp4',
        title: 'Test Video',
      );
      _fakeLists = [];
      mockListService = _MockCuratedListService();
      _fakeService = mockListService;
    });

    Widget buildSubject() => testProviderScope(
      additionalOverrides: [
        curatedListsStateProvider.overrideWith(_FakeCuratedListsState.new),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SelectListDialog(video: testVideo)),
      ),
    );

    testWidgets('renders Add to List title', (tester) async {
      _fakeLists = [
        CuratedList(
          id: 'list0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
          pubkey:
              'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
          name: 'My Test List',
          description: 'A test list',
          videoEventIds: const [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Add to List'), findsOneWidget);
      expect(find.text('My Test List'), findsOneWidget);
      expect(find.text('0 videos'), findsOneWidget);
    });

    testWidgets('shows check icon for video already in list', (tester) async {
      _fakeLists = [
        CuratedList(
          id: 'list0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
          pubkey:
              'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
          name: 'Contains Video',
          videoEventIds: const [
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          ],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(_divineIcon(DivineIconName.checkCircle), findsOneWidget);
    });

    testWidgets('shows playlist icon for video not in list', (tester) async {
      _fakeLists = [
        CuratedList(
          id: 'list0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
          pubkey:
              'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
          name: 'Empty List',
          videoEventIds: const [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(_divineIcon(DivineIconName.playlist), findsOneWidget);
    });

    testWidgets('displays video count for each list', (tester) async {
      _fakeLists = [
        CuratedList(
          id: 'list0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
          pubkey:
              'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
          name: 'Three Videos',
          videoEventIds: const ['vid1', 'vid2', 'vid3'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('3 videos'), findsOneWidget);
    });

    testWidgets('tapping list item adds video and shows snackbar', (
      tester,
    ) async {
      const listId =
          'list0123456789abcdef0123456789abcdef0123456789abcdef0123456789';
      _fakeLists = [
        CuratedList(
          id: listId,
          pubkey:
              'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
          name: 'My List',
          videoEventIds: const [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      when(
        () => mockListService.addVideoToList(any(), any()),
      ).thenAnswer((_) async => true);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text('My List'));
      await tester.pumpAndSettle();

      verify(
        () => mockListService.addVideoToList(listId, testVideo.id),
      ).called(1);
      expect(find.text('Added to My List'), findsOneWidget);
    });

    testWidgets('tapping list item with video removes it and shows snackbar', (
      tester,
    ) async {
      const listId =
          'list0123456789abcdef0123456789abcdef0123456789abcdef0123456789';
      _fakeLists = [
        CuratedList(
          id: listId,
          pubkey:
              'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
          name: 'My List',
          videoEventIds: [testVideo.id],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      when(
        () => mockListService.removeVideoFromList(any(), any()),
      ).thenAnswer((_) async => true);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text('My List'));
      await tester.pumpAndSettle();

      verify(
        () => mockListService.removeVideoFromList(listId, testVideo.id),
      ).called(1);
      expect(find.text('Removed from My List'), findsOneWidget);
    });

    testWidgets('renders Done button', (tester) async {
      _fakeLists = [];

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('renders multiple lists', (tester) async {
      _fakeLists = [
        CuratedList(
          id: 'list_a_23456789abcdef0123456789abcdef0123456789abcdef0123456789',
          pubkey:
              'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
          name: 'Favorites',
          videoEventIds: const [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        CuratedList(
          id: 'list_b_23456789abcdef0123456789abcdef0123456789abcdef0123456789',
          pubkey:
              'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
          name: 'Watch Later',
          isPublic: false,
          videoEventIds: const [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Favorites'), findsOneWidget);
      expect(find.text('Watch Later'), findsOneWidget);
    });
  });

  group(CreateListDialog, () {
    late VideoEvent testVideo;
    late _MockCuratedListService mockListService;
    final l10n = lookupAppLocalizations(const Locale('en'));

    setUp(() {
      testVideo = VideoEvent(
        id: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        pubkey:
            'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
        createdAt: 1757385263,
        content: 'Test video',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
        videoUrl: 'https://example.com/video.mp4',
        title: 'Test Video',
      );
      mockListService = _MockCuratedListService();
      _fakeService = mockListService;
    });

    CuratedList createdList(String name) => CuratedList(
      id: 'list_created_456789abcdef0123456789abcdef0123456789abcdef012345',
      pubkey:
          'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
      name: name,
      videoEventIds: const [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    Widget buildSubject({VideoEvent? video, MockGoRouter? goRouter}) {
      final dialog = CreateListDialog(video: video);
      return testProviderScope(
        additionalOverrides: [
          curatedListsStateProvider.overrideWith(_FakeCuratedListsState.new),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: goRouter == null
                ? dialog
                : MockGoRouterProvider(goRouter: goRouter, child: dialog),
          ),
        ),
      );
    }

    testWidgets('renders Create New List form', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('Create New List'), findsOneWidget);
      expect(find.text('List Name'), findsOneWidget);
      expect(find.text('Description (optional)'), findsOneWidget);
      expect(find.text('Public List'), findsOneWidget);
      expect(find.text('Create'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('public list switch toggles', (tester) async {
      await tester.pumpWidget(buildSubject());

      // Public switch should be on by default
      final switchWidget = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(switchWidget.value, isTrue);

      // Tap to toggle off
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();

      final updatedSwitch = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(updatedSwitch.value, isFalse);
    });

    testWidgets('shows subtitle text for public list switch', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('Others can follow and see this list'), findsOneWidget);
    });

    testWidgets('Create button does nothing when name is empty', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      // Tap Create with empty name
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      // Should not call createList
      verifyNever(
        () => mockListService.createList(
          name: any(named: 'name'),
          description: any(named: 'description'),
          isPublic: any(named: 'isPublic'),
        ),
      );
    });

    testWidgets('creates list and pops without adding video when no video '
        'is provided', (tester) async {
      final goRouter = MockGoRouter();
      when(goRouter.canPop).thenReturn(true);
      when(() => goRouter.pop<Object?>()).thenReturn(null);
      when(
        () => mockListService.createList(
          name: any(named: 'name'),
          description: any(named: 'description'),
          isPublic: any(named: 'isPublic'),
        ),
      ).thenAnswer((_) async => createdList('Fresh List'));

      await tester.pumpWidget(buildSubject(goRouter: goRouter));
      await tester.enterText(find.byType(TextField).first, 'Fresh List');
      await tester.tap(find.text(l10n.listCreate));
      await tester.pumpAndSettle();

      verify(
        () => mockListService.createList(
          name: 'Fresh List',
          description: any(named: 'description'),
          isPublic: any(named: 'isPublic'),
        ),
      ).called(1);
      verifyNever(() => mockListService.addVideoToList(any(), any()));
      verify(() => goRouter.pop<Object?>()).called(1);
    });

    testWidgets('creates list and adds video when a video is provided', (
      tester,
    ) async {
      final goRouter = MockGoRouter();
      when(goRouter.canPop).thenReturn(true);
      when(() => goRouter.pop<Object?>()).thenReturn(null);
      final newList = createdList('Video List');
      when(
        () => mockListService.createList(
          name: any(named: 'name'),
          description: any(named: 'description'),
          isPublic: any(named: 'isPublic'),
        ),
      ).thenAnswer((_) async => newList);
      when(
        () => mockListService.addVideoToList(any(), any()),
      ).thenAnswer((_) async => true);

      await tester.pumpWidget(
        buildSubject(video: testVideo, goRouter: goRouter),
      );
      await tester.enterText(find.byType(TextField).first, 'Video List');
      await tester.tap(find.text(l10n.listCreate));
      await tester.pumpAndSettle();

      verify(
        () => mockListService.addVideoToList(newList.id, testVideo.id),
      ).called(1);
      verify(() => goRouter.pop<Object?>()).called(1);
    });

    testWidgets('shows failure snackbar and keeps dialog open when '
        'createList returns null', (tester) async {
      final goRouter = MockGoRouter();
      when(goRouter.canPop).thenReturn(true);
      when(
        () => mockListService.createList(
          name: any(named: 'name'),
          description: any(named: 'description'),
          isPublic: any(named: 'isPublic'),
        ),
      ).thenAnswer((_) async => null);

      await tester.pumpWidget(buildSubject(goRouter: goRouter));
      await tester.enterText(find.byType(TextField).first, 'Doomed List');
      await tester.tap(find.text(l10n.listCreate));
      await tester.pumpAndSettle();

      expect(find.text(l10n.listCreateFailed), findsOneWidget);
      expect(find.text(l10n.listCreateNewList), findsOneWidget);
      verifyNever(() => mockListService.addVideoToList(any(), any()));
      verifyNever(() => goRouter.pop<Object?>());
    });
  });
}
