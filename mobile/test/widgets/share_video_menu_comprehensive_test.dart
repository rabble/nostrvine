// ABOUTME: Tests for the unified share sheet (_UnifiedShareSheet)
// ABOUTME: Covers share sheet rendering, contact row, more actions, feature
// ABOUTME: flags, save/bookmark, copy link, share via, and error handling

@Tags(['skip_very_good_optimization'])
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/bookmark_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/video_sharing_service.dart';
import 'package:openvine/widgets/video_feed_item/actions/share_action_button.dart';
import 'package:profile_repository/profile_repository.dart';

import '../helpers/test_provider_overrides.dart';

class _MockBookmarkService extends Mock implements BookmarkService {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockVideoSharingService extends Mock implements VideoSharingService {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _FakeVideoEvent extends Fake implements VideoEvent {}

/// Fake notifier that provides test data for curatedListsStateProvider.
///
/// Uses a static field instead of a module-level variable so that state
/// does not leak between test files when running in a shared isolate.
class _FakeCuratedListsState extends CuratedListsState {
  static List<CuratedList> fakeLists = [];

  @override
  CuratedListService? get service => null;

  @override
  Future<List<CuratedList>> build() async => fakeLists;
}

void main() {
  late VideoEvent testVideo;
  late _MockBookmarkService mockBookmarkService;
  late _MockVideoSharingService mockVideoSharingService;
  late _MockProfileRepository mockProfileRepository;

  setUpAll(() {
    registerFallbackValue(_FakeVideoEvent());
  });

  setUp(() {
    mockProfileRepository = _MockProfileRepository();
    when(
      () => mockProfileRepository.getCachedProfile(
        pubkey: any(named: 'pubkey'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => mockProfileRepository.fetchFreshProfile(
        pubkey: any(named: 'pubkey'),
      ),
    ).thenAnswer((_) async => null);

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

    mockBookmarkService = _MockBookmarkService();
    mockVideoSharingService = _MockVideoSharingService();
    _FakeCuratedListsState.fakeLists = [];

    when(
      () => mockBookmarkService.addVideoToGlobalBookmarks(any()),
    ).thenAnswer((_) async => true);
    when(
      () => mockVideoSharingService.generateShareText(any()),
    ).thenReturn('https://divine.video/video/test');
    when(
      () => mockVideoSharingService.generateShareUrl(any()),
    ).thenReturn('https://divine.video/video/test');
    when(() => mockVideoSharingService.recentlySharedWith).thenReturn([]);
  });

  group('Unified share sheet', () {
    Widget buildSubject({
      bool curatedListsEnabled = true,
      bool debugToolsEnabled = true,
    }) => testProviderScope(
      additionalOverrides: [
        profileRepositoryProvider.overrideWithValue(mockProfileRepository),
        bookmarkServiceProvider.overrideWith((ref) => mockBookmarkService),
        videoSharingServiceProvider.overrideWith(
          (ref) => mockVideoSharingService,
        ),
        curatedListsStateProvider.overrideWith(_FakeCuratedListsState.new),
        isFeatureEnabledProvider(
          FeatureFlag.curatedLists,
        ).overrideWithValue(curatedListsEnabled),
        isFeatureEnabledProvider(
          FeatureFlag.debugTools,
        ).overrideWithValue(debugToolsEnabled),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ShareActionButton(video: testVideo)),
      ),
    );

    testWidgets('tapping share button opens unified share sheet', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byType(ShareActionButton));
      await tester.pumpAndSettle();

      // Verify section headers
      expect(find.text('Share with'), findsOneWidget);
      expect(find.text('More actions'), findsOneWidget);
    });

    testWidgets('share sheet header shows video title', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byType(ShareActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Test Video Title'), findsOneWidget);
    });

    testWidgets('share sheet shows Find people item', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byType(ShareActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Find\npeople'), findsOneWidget);
    });

    testWidgets('More actions row shows Save action', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byType(ShareActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('More actions row shows Copy action', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byType(ShareActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Copy'), findsOneWidget);
    });

    testWidgets('More actions row shows Share via action', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byType(ShareActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Share via'), findsOneWidget);
    });

    testWidgets('More actions row shows Report action', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byType(ShareActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Report'), findsOneWidget);
    });

    testWidgets('tapping Save shows success snackbar', (tester) async {
      when(
        () => mockBookmarkService.addVideoToGlobalBookmarks(any()),
      ).thenAnswer((_) async => true);

      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byType(ShareActionButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Added to bookmarks'), findsOneWidget);
      verify(
        () => mockBookmarkService.addVideoToGlobalBookmarks(testVideo.id),
      ).called(1);
    });

    testWidgets('tapping Save shows failure snackbar on error', (tester) async {
      when(
        () => mockBookmarkService.addVideoToGlobalBookmarks(any()),
      ).thenAnswer((_) async => false);

      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byType(ShareActionButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Failed to add bookmark'), findsOneWidget);
    });

    testWidgets('tapping Save shows failure snackbar on exception', (
      tester,
    ) async {
      when(
        () => mockBookmarkService.addVideoToGlobalBookmarks(any()),
      ).thenThrow(Exception('Network error'));

      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byType(ShareActionButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Failed to add bookmark'), findsOneWidget);
    });

    testWidgets('share sheet has correct DivineIcons', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byType(ShareActionButton));
      await tester.pumpAndSettle();

      final divineIcons = tester
          .widgetList<DivineIcon>(find.byType(DivineIcon))
          .toList();
      final iconNames = divineIcons.map((i) => i.icon).toList();

      // Share with section
      expect(iconNames, contains(DivineIconName.search));
      // More actions section
      expect(iconNames, contains(DivineIconName.bookmarkSimple));
      expect(iconNames, contains(DivineIconName.linkSimple));
      expect(iconNames, contains(DivineIconName.flag));
      // shareFat appears in button and Share via action
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
    });

    testWidgets(
      'hides Add to List when curatedLists feature flag is disabled',
      (tester) async {
        await tester.pumpWidget(buildSubject(curatedListsEnabled: false));
        await tester.tap(find.byType(ShareActionButton));
        await tester.pumpAndSettle();

        expect(find.text('Share with'), findsOneWidget);
        expect(find.text('Add to List'), findsNothing);
        expect(find.text('Save'), findsOneWidget);
      },
    );

    testWidgets('shows Add to List when curatedLists feature flag is enabled', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byType(ShareActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Add to List'), findsOneWidget);
    });

    testWidgets(
      'shows Event JSON and Event ID when debugTools flag is enabled',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.tap(find.byType(ShareActionButton));
        await tester.pumpAndSettle();

        expect(find.text('Event JSON'), findsOneWidget);
        expect(find.text('Event ID'), findsOneWidget);
      },
    );

    testWidgets(
      'hides Event JSON and Event ID when debugTools flag is disabled',
      (tester) async {
        await tester.pumpWidget(buildSubject(debugToolsEnabled: false));
        await tester.tap(find.byType(ShareActionButton));
        await tester.pumpAndSettle();

        expect(find.text('Event JSON'), findsNothing);
        expect(find.text('Event ID'), findsNothing);
      },
    );
  });

  group('Quick-send behavior', () {
    const testContact = ShareableUser(
      pubkey:
          '1111111111111111111111111111111111111111111111111111111111111111',
      displayName: 'Alice',
    );
    late _MockFollowRepository mockFollowRepository;

    setUp(() {
      mockFollowRepository = _MockFollowRepository();
      when(() => mockFollowRepository.followingPubkeys).thenReturn([]);
    });

    Widget buildSubjectWithContacts() {
      when(
        () => mockVideoSharingService.recentlySharedWith,
      ).thenReturn([testContact]);

      return testProviderScope(
        additionalOverrides: [
          profileRepositoryProvider.overrideWithValue(mockProfileRepository),
          followRepositoryProvider.overrideWithValue(mockFollowRepository),
          bookmarkServiceProvider.overrideWith((ref) => mockBookmarkService),
          videoSharingServiceProvider.overrideWith(
            (ref) => mockVideoSharingService,
          ),
          curatedListsStateProvider.overrideWith(_FakeCuratedListsState.new),
          isFeatureEnabledProvider(
            FeatureFlag.curatedLists,
          ).overrideWithValue(true),
          isFeatureEnabledProvider(
            FeatureFlag.debugTools,
          ).overrideWithValue(true),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ShareActionButton(video: testVideo)),
        ),
      );
    }

    testWidgets('tapping contact quick-sends video', (tester) async {
      when(
        () => mockVideoSharingService.shareVideoWithUser(
          video: any(named: 'video'),
          recipientPubkey: any(named: 'recipientPubkey'),
          personalMessage: any(named: 'personalMessage'),
        ),
      ).thenAnswer(
        (_) async => ShareResult.createSuccess(
          '2222222222222222222222222222222222222222222222222222222222222222',
        ),
      );

      await tester.pumpWidget(buildSubjectWithContacts());
      await tester.tap(find.byType(ShareActionButton));
      await tester.pumpAndSettle();

      // Verify contact appears in horizontal row
      expect(find.text('Alice'), findsOneWidget);

      // Tap contact — should quick-send immediately
      await tester.tap(find.text('Alice'));
      await tester.pumpAndSettle();

      // Verify shareVideoWithUser was called
      verify(
        () => mockVideoSharingService.shareVideoWithUser(
          video: any(named: 'video'),
          recipientPubkey: any(named: 'recipientPubkey'),
          personalMessage: any(named: 'personalMessage'),
        ),
      ).called(1);

      // Verify success snackbar
      expect(find.text('Post shared with Alice'), findsOneWidget);
    });

    testWidgets('sent contact shows Sent label', (tester) async {
      when(
        () => mockVideoSharingService.shareVideoWithUser(
          video: any(named: 'video'),
          recipientPubkey: any(named: 'recipientPubkey'),
          personalMessage: any(named: 'personalMessage'),
        ),
      ).thenAnswer(
        (_) async => ShareResult.createSuccess(
          '2222222222222222222222222222222222222222222222222222222222222222',
        ),
      );

      await tester.pumpWidget(buildSubjectWithContacts());
      await tester.tap(find.byType(ShareActionButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alice'));
      await tester.pumpAndSettle();

      // Contact label replaced with 'Sent'
      expect(find.text('Sent'), findsOneWidget);
      expect(find.text('Alice'), findsNothing);
    });

    testWidgets('sent contact ignores subsequent taps', (tester) async {
      when(
        () => mockVideoSharingService.shareVideoWithUser(
          video: any(named: 'video'),
          recipientPubkey: any(named: 'recipientPubkey'),
          personalMessage: any(named: 'personalMessage'),
        ),
      ).thenAnswer(
        (_) async => ShareResult.createSuccess(
          '2222222222222222222222222222222222222222222222222222222222222222',
        ),
      );

      await tester.pumpWidget(buildSubjectWithContacts());
      await tester.tap(find.byType(ShareActionButton));
      await tester.pumpAndSettle();

      // First tap — sends
      await tester.tap(find.text('Alice'));
      await tester.pumpAndSettle();

      // Second tap on 'Sent' — should be ignored
      await tester.tap(find.text('Sent'));
      await tester.pumpAndSettle();

      // shareVideoWithUser only called once
      verify(
        () => mockVideoSharingService.shareVideoWithUser(
          video: any(named: 'video'),
          recipientPubkey: any(named: 'recipientPubkey'),
          personalMessage: any(named: 'personalMessage'),
        ),
      ).called(1);
    });

    testWidgets('quick-send shows failure snackbar on error', (tester) async {
      when(
        () => mockVideoSharingService.shareVideoWithUser(
          video: any(named: 'video'),
          recipientPubkey: any(named: 'recipientPubkey'),
          personalMessage: any(named: 'personalMessage'),
        ),
      ).thenAnswer((_) async => ShareResult.failure('Network timeout'));

      await tester.pumpWidget(buildSubjectWithContacts());
      await tester.tap(find.byType(ShareActionButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alice'));
      await tester.pumpAndSettle();

      expect(find.text('Failed to send video'), findsOneWidget);
    });
  });
}
