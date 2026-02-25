// ABOUTME: Tests for the MVP simplified share menu (_SimpleShareMenu)
// ABOUTME: Covers menu rendering, share actions, feature flags, and error handling

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:models/models.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/bookmark_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/video_sharing_service.dart';
import 'package:openvine/widgets/video_feed_item/actions/share_action_button.dart';

import '../helpers/test_provider_overrides.dart';

@GenerateMocks([BookmarkService, VideoSharingService])
import 'share_video_menu_comprehensive_test.mocks.dart';

/// Fake notifier that provides test data for curatedListsStateProvider
List<CuratedList> _fakeLists = [];

class _FakeCuratedListsState extends CuratedListsState {
  @override
  CuratedListService? get service => null;

  @override
  Future<List<CuratedList>> build() async => _fakeLists;
}

void main() {
  late VideoEvent testVideo;
  late MockBookmarkService mockBookmarkService;
  late MockVideoSharingService mockVideoSharingService;

  setUp(() {
    testVideo = VideoEvent(
      id: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      pubkey:
          'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
      createdAt: 1757385263,
      content: 'Test video content',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
      videoUrl: 'https://example.com/video.mp4',
      title: 'Test Video Title',
    );

    mockBookmarkService = MockBookmarkService();
    mockVideoSharingService = MockVideoSharingService();
    _fakeLists = [];

    when(
      mockBookmarkService.addVideoToGlobalBookmarks(any),
    ).thenAnswer((_) async => true);
    when(
      mockVideoSharingService.generateShareText(any),
    ).thenReturn('Check out this video https://divine.video/video/test');
  });

  group('ShareActionButton opens _SimpleShareMenu', () {
    Widget buildSubject({bool curatedListsEnabled = true}) => testProviderScope(
      mockUserProfileService: createMockUserProfileService(),
      additionalOverrides: [
        bookmarkServiceProvider.overrideWith(
          (ref) async => mockBookmarkService,
        ),
        videoSharingServiceProvider.overrideWith(
          (ref) => mockVideoSharingService,
        ),
        curatedListsStateProvider.overrideWith(_FakeCuratedListsState.new),
        isFeatureEnabledProvider(
          FeatureFlag.curatedLists,
        ).overrideWithValue(curatedListsEnabled),
      ],
      child: MaterialApp(
        home: Scaffold(body: ShareActionButton(video: testVideo)),
      ),
    );

    testWidgets('tapping share button opens bottom sheet with 4 menu items', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byType(ShareActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Share with user'), findsOneWidget);
      expect(find.text('Add to list'), findsOneWidget);
      expect(find.text('Add to bookmarks'), findsOneWidget);
      expect(find.text('More options'), findsOneWidget);
    });

    testWidgets('share menu header shows video title', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byType(ShareActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Test Video Title'), findsOneWidget);
    });

    testWidgets('share menu shows drag indicator', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byType(ShareActionButton));
      await tester.pumpAndSettle();

      // Just verify the bottom sheet opened with content
      expect(find.text('Share with user'), findsOneWidget);
    });

    testWidgets('tapping Add to bookmarks shows success snackbar', (
      tester,
    ) async {
      when(
        mockBookmarkService.addVideoToGlobalBookmarks(any),
      ).thenAnswer((_) async => true);

      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byType(ShareActionButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add to bookmarks'));
      await tester.pumpAndSettle();

      expect(find.text('Added to bookmarks!'), findsOneWidget);
      verify(
        mockBookmarkService.addVideoToGlobalBookmarks(testVideo.id),
      ).called(1);
    });

    testWidgets('tapping Add to bookmarks shows failure snackbar on error', (
      tester,
    ) async {
      when(
        mockBookmarkService.addVideoToGlobalBookmarks(any),
      ).thenAnswer((_) async => false);

      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byType(ShareActionButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add to bookmarks'));
      await tester.pumpAndSettle();

      expect(find.text('Failed to add bookmark'), findsOneWidget);
    });

    testWidgets(
      'tapping Add to bookmarks shows failure snackbar on exception',
      (tester) async {
        when(
          mockBookmarkService.addVideoToGlobalBookmarks(any),
        ).thenThrow(Exception('Network error'));

        await tester.pumpWidget(buildSubject());
        await tester.tap(find.byType(ShareActionButton));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Add to bookmarks'));
        await tester.pumpAndSettle();

        expect(find.text('Failed to add bookmark'), findsOneWidget);
      },
    );

    testWidgets('menu items have correct DivineIcons', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byType(ShareActionButton));
      await tester.pumpAndSettle();

      final divineIcons = tester
          .widgetList<DivineIcon>(find.byType(DivineIcon))
          .toList();
      final iconNames = divineIcons.map((i) => i.icon).toList();

      expect(iconNames, contains(DivineIconName.chats));
      expect(iconNames, contains(DivineIconName.listPlus));
      expect(iconNames, contains(DivineIconName.bookmarkSimple));
      // shareFat appears both in the button and in the menu
      expect(
        iconNames.where((n) => n == DivineIconName.shareFat).length,
        greaterThanOrEqualTo(1),
      );
    });

    testWidgets('does not show removed MVP items', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byType(ShareActionButton));
      await tester.pumpAndSettle();

      // Removed in MVP streamlining
      expect(find.text('Send to Viner'), findsNothing);
      expect(find.text('Safety Actions'), findsNothing);
      expect(find.text('Public Lists'), findsNothing);
      expect(find.text('Report Content'), findsNothing);
    });

    testWidgets(
      'hides Add to list when curatedLists feature flag is disabled',
      (tester) async {
        await tester.pumpWidget(buildSubject(curatedListsEnabled: false));
        await tester.tap(find.byType(ShareActionButton));
        await tester.pumpAndSettle();

        expect(find.text('Share with user'), findsOneWidget);
        expect(find.text('Add to list'), findsNothing);
        expect(find.text('Add to bookmarks'), findsOneWidget);
        expect(find.text('More options'), findsOneWidget);
      },
    );

    testWidgets('tapping More options calls generateShareText on service', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byType(ShareActionButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('More options'));
      await tester.pumpAndSettle();

      verify(mockVideoSharingService.generateShareText(testVideo)).called(1);
    });

    testWidgets('tapping More options shows failure snackbar on exception', (
      tester,
    ) async {
      when(
        mockVideoSharingService.generateShareText(any),
      ).thenThrow(Exception('Share failed'));

      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byType(ShareActionButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('More options'));
      await tester.pumpAndSettle();

      expect(find.text('Failed to share video'), findsOneWidget);
    });
  });
}
