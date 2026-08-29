// ABOUTME: Tests for ComposableVideoGrid widget
// ABOUTME: Verifies grid rendering, broken video filtering, and user interactions
//
// NOTE: Tests that render video tiles are skipped because ComposableVideoGrid
// uses UserName widget, which triggers the Nostr provider chain
// (userProfileReactive -> userProfileService -> nostrService) that attempts
// real WebSocket connections to relays.
//
// Flutter's TestWidgetsFlutterBinding automatically intercepts and mocks all
// HTTP/WebSocket connections, returning "Mocked response" errors. This is built
// into Flutter's test framework, not something we control.
//
// For tests with real Nostr connections, see the integration test version at:
// test/integration/composable_video_grid_test.dart
//
// That version uses IntegrationTestWidgetsFlutterBinding which allows real
// network connections and tests the widget in the context of the running app.
//
// The skipped tile tests are kept for reference and potential future
// refactoring where ComposableVideoGrid could accept profile data as props
// instead of fetching via providers, which would allow isolated widget testing.

import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/creator_delete_enforcement_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/repositories/creator_delete_enforcement_repository.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/broken_video_tracker.dart' as broken_tracker;
import 'package:openvine/services/content_deletion_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/composable_video_grid.dart';
// Override lives in riverpod's misc barrel; flutter_riverpod does not
// re-export the type name even though it accepts List<Override>.
import 'package:riverpod/misc.dart' show Override;

import '../helpers/test_provider_overrides.dart';

const _ownPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

class _MockContentDeletionService extends Mock
    implements ContentDeletionService {}

class _MockEnforcementRepository extends Mock
    implements CreatorDeleteEnforcementRepository {}

class _MockVideoEventService extends Mock implements VideoEventService {}

/// Provider overrides every scope in this file needs.
///
/// [ComposableVideoGrid] renders `UserName`, which reaches the user-profile
/// provider chain and transitively requires SharedPreferences. Without the
/// override the scope throws `UnimplementedError: sharedPreferencesProvider
/// must be overridden`, which is why this file's tile-rendering tests were
/// previously disabled with `skip: true`.
List<Override> _gridOverrides(
  broken_tracker.BrokenVideoTracker tracker, {
  MockNostrClient? nostrService,
  MockAuthService? authService,
  List<Override> extra = const [],
}) => [
  sharedPreferencesProvider.overrideWithValue(createMockSharedPreferences()),
  authServiceProvider.overrideWithValue(authService ?? createMockAuthService()),
  nostrServiceProvider.overrideWithValue(
    nostrService ?? createMockNostrService(),
  ),
  brokenVideoTrackerProvider.overrideWith((ref) async => tracker),
  subscribedListVideoCacheProvider.overrideWithValue(null),
  userProfileReactiveProvider.overrideWith((ref, pubkey) => Stream.value(null)),
  ...extra,
];

MockAuthService _authenticatedAuthService(String pubkey) {
  final authService = createMockAuthService();
  when(() => authService.authState).thenReturn(AuthState.authenticated);
  when(() => authService.currentPublicKeyHex).thenReturn(pubkey);
  return authService;
}

void main() {
  group('ComposableVideoGrid', () {
    late List<VideoEvent> testVideos;
    late broken_tracker.BrokenVideoTracker mockTracker;

    setUp(() {
      final now = DateTime.now();
      final nowTimestamp = now.millisecondsSinceEpoch ~/ 1000;
      testVideos = [
        VideoEvent(
          id: 'video1',
          pubkey:
              'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2', // 64-char hex pubkey
          content: 'Test video 1',
          title: 'Video 1',
          videoUrl: 'https://example.com/video1.mp4',
          thumbnailUrl: 'https://example.com/thumb1.jpg',
          duration: 5,
          originalLikes: 10,
          originalLoops: 100,
          createdAt: nowTimestamp,
          timestamp: now,
        ),
        VideoEvent(
          id: 'video2',
          pubkey:
              'b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3', // 64-char hex pubkey
          content: 'Test video 2',
          title: 'Video 2',
          videoUrl: 'https://example.com/video2.mp4',
          thumbnailUrl: 'https://example.com/thumb2.jpg',
          duration: 3,
          originalLikes: 5,
          originalLoops: 50,
          createdAt: nowTimestamp,
          timestamp: now,
        ),
        VideoEvent(
          id: 'broken_video',
          pubkey:
              'c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4', // 64-char hex pubkey
          content: 'Broken video',
          title: 'Broken Video',
          videoUrl: 'https://example.com/broken.mp4',
          duration: 4,
          createdAt: nowTimestamp,
          timestamp: now,
        ),
      ];

      // Create mock tracker with no broken videos
      mockTracker = broken_tracker.BrokenVideoTracker();
    });

    testWidgets('renders grid with provided videos', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _gridOverrides(mockTracker),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ComposableVideoGrid(
                videos: testVideos.take(2).toList(), // Only non-broken videos
                onVideoTap: (videos, index) {},
              ),
            ),
          ),
        ),
      );

      // Wait for widget to build
      await tester.pump();

      // Should render 2 video tiles
      expect(find.byType(GestureDetector), findsNWidgets(2));
    });

    testWidgets('filters out broken videos using BrokenVideoTracker', (
      tester,
    ) async {
      // Mark video as broken
      mockTracker.markVideoBroken('broken_video', 'Test broken');

      await tester.pumpWidget(
        ProviderScope(
          overrides: _gridOverrides(mockTracker),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ComposableVideoGrid(
                videos: testVideos, // All 3 videos including broken one
                onVideoTap: (videos, index) {},
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Should only render 2 tiles (broken_video filtered out)
      expect(find.byType(GestureDetector), findsNWidgets(2));
    });

    testWidgets('shows empty state when no videos after filtering', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _gridOverrides(mockTracker),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ComposableVideoGrid(
                videos: const [],
                onVideoTap: (videos, index) {},
                emptyBuilder: () => const Text('No videos available'),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('No videos available'), findsOneWidget);
    });

    testWidgets('keeps empty state refreshable when refresh callback is set', (
      tester,
    ) async {
      var refreshCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: _gridOverrides(mockTracker),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ComposableVideoGrid(
                videos: const [],
                onVideoTap: (videos, index) {},
                onRefresh: () async {
                  refreshCount++;
                },
                emptyBuilder: () => const Text('No videos available'),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('No videos available'), findsOneWidget);
      expect(find.byType(RefreshIndicator), findsOneWidget);
      expect(find.byType(Scrollable), findsOneWidget);

      final refreshIndicator = tester.widget<RefreshIndicator>(
        find.byType(RefreshIndicator),
      );
      await refreshIndicator.onRefresh();

      expect(refreshCount, 1);
    });

    testWidgets('refreshes empty state from top-edge pointer scroll down', (
      tester,
    ) async {
      var refreshCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: _gridOverrides(mockTracker),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ComposableVideoGrid(
                videos: const [],
                onVideoTap: (videos, index) {},
                onRefresh: () async {
                  refreshCount++;
                },
                emptyBuilder: () => const Text('No videos available'),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      final pointer = TestPointer(1, PointerDeviceKind.trackpad);
      pointer.hover(tester.getCenter(find.byType(Scrollable)));

      await tester.sendEventToBinding(pointer.scroll(const Offset(0, -120)));
      await tester.pumpAndSettle();

      expect(refreshCount, 1);
    });

    testWidgets('calls onVideoTap with correct params when tile tapped', (
      tester,
    ) async {
      List<VideoEvent>? tappedVideos;
      int? tappedIndex;

      await tester.pumpWidget(
        ProviderScope(
          overrides: _gridOverrides(mockTracker),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ComposableVideoGrid(
                videos: testVideos.take(2).toList(),
                onVideoTap: (videos, index) {
                  tappedVideos = videos;
                  tappedIndex = index;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Tap the second video
      await tester.tap(find.byType(GestureDetector).at(1));
      await tester.pump();

      expect(tappedIndex, equals(1));
      expect(tappedVideos, isNotNull);
      expect(tappedVideos!.length, equals(2));
    });

    testWidgets('uses correct grid parameters', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _gridOverrides(mockTracker),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ComposableVideoGrid(
                videos: testVideos.take(2).toList(),
                onVideoTap: (videos, index) {},
                crossAxisCount: 3,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // The grid is built from slivers inside a CustomScrollView, so the
      // delegate hangs off SliverGrid rather than a GridView.
      final sliverGrid = tester.widget<SliverGrid>(find.byType(SliverGrid));
      final delegate =
          sliverGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;

      expect(delegate.crossAxisCount, equals(3));
      expect(delegate.childAspectRatio, equals(1.0));
    });

    testWidgets('renders the video title over the thumbnail', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _gridOverrides(mockTracker),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ComposableVideoGrid(
                videos: [testVideos.first],
                onVideoTap: (videos, index) {},
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // The info overlay carries the author and the title. Engagement counts
      // and the duration badge are no longer rendered here.
      expect(find.text('Video 1'), findsOneWidget);
    });

    group('delete confirmation copy', () {
      testWidgets(
        'uses the shared owner-delete confirmation copy for owned videos',
        (tester) async {
          final mockNostr = createMockNostrService();
          when(() => mockNostr.publicKey).thenReturn(_ownPubkey);
          final l10n = lookupAppLocalizations(const Locale('en'));
          final video = VideoEvent(
            id: 'owned-video',
            pubkey: _ownPubkey,
            content: 'Owned video',
            title: 'Owned video',
            authorName: 'Creator',
            videoUrl: 'https://example.com/owned.mp4',
            thumbnailUrl: 'https://example.com/owned.jpg',
            duration: 5,
            createdAt: DateTime(2026).millisecondsSinceEpoch ~/ 1000,
            timestamp: DateTime(2026),
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: _gridOverrides(
                mockTracker,
                nostrService: mockNostr,
                authService: _authenticatedAuthService(_ownPubkey),
              ),
              child: MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: ComposableVideoGrid(
                    videos: [video],
                    onVideoTap: (videos, index) {},
                  ),
                ),
              ),
            ),
          );

          await tester.pump();
          await tester.longPress(
            find.bySemanticsLabel(l10n.profileVideoThumbnailLabel(1)),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text(l10n.videoGridDeleteVideo));
          await tester.pumpAndSettle();

          final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
          expect(dialog.title, isA<Text>());
          expect((dialog.title! as Text).data, l10n.shareMenuDeleteVideo);
          expect(dialog.content, isA<Text>());
          expect(
            (dialog.content! as Text).data,
            l10n.shareMenuDeleteConfirmation,
          );
          expect(dialog.actions, hasLength(2));
          expect(find.text(l10n.shareMenuDeleteConfirmation), findsOneWidget);
        },
      );
      testWidgets('shows the relay failure result after delete', (
        tester,
      ) async {
        final mockNostr = createMockNostrService();
        when(() => mockNostr.publicKey).thenReturn(_ownPubkey);
        final l10n = lookupAppLocalizations(const Locale('en'));
        final deletionService = _MockContentDeletionService();
        final enforcementRepository = _MockEnforcementRepository();
        final videoEventService = _MockVideoEventService();
        final relayCompleter = Completer<DeleteResult>();
        final video = VideoEvent(
          id: 'owned-video',
          pubkey: _ownPubkey,
          content: 'Owned video',
          title: 'Owned video',
          authorName: 'Creator',
          videoUrl: 'https://example.com/owned.mp4',
          thumbnailUrl: 'https://example.com/owned.jpg',
          duration: 5,
          createdAt: DateTime(2026).millisecondsSinceEpoch ~/ 1000,
          timestamp: DateTime(2026),
        );
        when(
          () => deletionService.quickDelete(
            video: video,
            reason: DeleteReason.personalChoice,
          ),
        ).thenAnswer((_) => relayCompleter.future);

        await tester.pumpWidget(
          ProviderScope(
            overrides: _gridOverrides(
              mockTracker,
              nostrService: mockNostr,
              authService: _authenticatedAuthService(_ownPubkey),
              extra: [
                contentDeletionServiceProvider.overrideWith(
                  (ref) async => deletionService,
                ),
                creatorDeleteEnforcementRepositoryProvider.overrideWithValue(
                  enforcementRepository,
                ),
                videoEventServiceProvider.overrideWithValue(videoEventService),
              ],
            ),
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: ComposableVideoGrid(
                  videos: [video],
                  onVideoTap: (videos, index) {},
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.longPress(
          find.bySemanticsLabel(l10n.profileVideoThumbnailLabel(1)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.videoGridDeleteVideo));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.shareMenuDelete));
        await tester.pump();

        await tester.longPress(
          find.bySemanticsLabel(l10n.profileVideoThumbnailLabel(1)),
        );
        await tester.pump(const Duration(milliseconds: 500));
        final editTile = tester.widget<ListTile>(
          find.ancestor(
            of: find.text(l10n.videoGridEditVideo),
            matching: find.byType(ListTile),
          ),
        );
        expect(editTile.enabled, isFalse);

        relayCompleter.complete(
          DeleteResult.failure(
            'relay rejected',
            DeleteFailureKind.relayRejected,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(l10n.shareMenuDeleteFailedRelayRejected),
          findsOneWidget,
        );
      });
      testWidgets('keeps Edit and Delete blocked until cleanup finishes', (
        tester,
      ) async {
        final mockNostr = createMockNostrService();
        final deletionService = _MockContentDeletionService();
        final enforcementRepository = _MockEnforcementRepository();
        final videoEventService = _MockVideoEventService();
        final cleanupCompleter = Completer<CreatorDeleteEnforcementResult>();
        when(() => mockNostr.publicKey).thenReturn(_ownPubkey);
        final l10n = lookupAppLocalizations(const Locale('en'));
        final video = VideoEvent(
          id: 'owned-video',
          pubkey: _ownPubkey,
          content: 'Owned video',
          title: 'Owned video',
          authorName: 'Creator',
          videoUrl: 'https://example.com/owned.mp4',
          thumbnailUrl: 'https://example.com/owned.jpg',
          duration: 5,
          createdAt: DateTime(2026).millisecondsSinceEpoch ~/ 1000,
          timestamp: DateTime(2026),
        );
        when(
          () => deletionService.quickDelete(
            video: video,
            reason: DeleteReason.personalChoice,
          ),
        ).thenAnswer(
          (_) async => DeleteResult.createSuccess(
            'delete-event-id',
            acceptance: DeleteAcceptance.everyRelay,
          ),
        );
        when(
          () => enforcementRepository.enforce('delete-event-id'),
        ).thenAnswer((_) => cleanupCompleter.future);

        await tester.pumpWidget(
          ProviderScope(
            overrides: _gridOverrides(
              mockTracker,
              nostrService: mockNostr,
              authService: _authenticatedAuthService(_ownPubkey),
              extra: [
                contentDeletionServiceProvider.overrideWith(
                  (ref) async => deletionService,
                ),
                creatorDeleteEnforcementRepositoryProvider.overrideWithValue(
                  enforcementRepository,
                ),
                videoEventServiceProvider.overrideWithValue(videoEventService),
              ],
            ),
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: ComposableVideoGrid(
                  videos: [video],
                  onVideoTap: (videos, index) {},
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        final tile = find.bySemanticsLabel(l10n.profileVideoThumbnailLabel(1));
        await tester.longPress(tile);
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.videoGridDeleteVideo));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.shareMenuDelete));
        await tester.pumpAndSettle();

        await tester.longPress(tile);
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        var deleteTile = tester.widget<ListTile>(
          find.ancestor(
            of: find.text(l10n.videoGridDeleteVideo),
            matching: find.byType(ListTile),
          ),
        );
        expect(deleteTile.enabled, isFalse);
        var editTile = tester.widget<ListTile>(
          find.ancestor(
            of: find.text(l10n.videoGridEditVideo),
            matching: find.byType(ListTile),
          ),
        );
        expect(editTile.enabled, isFalse);

        cleanupCompleter.complete(
          const CreatorDeleteEnforcementResult.confirmed(),
        );
        await tester.pumpAndSettle();

        expect(find.byType(CircularProgressIndicator), findsNothing);
        deleteTile = tester.widget<ListTile>(
          find.ancestor(
            of: find.text(l10n.videoGridDeleteVideo),
            matching: find.byType(ListTile),
          ),
        );
        expect(deleteTile.enabled, isTrue);
        editTile = tester.widget<ListTile>(
          find.ancestor(
            of: find.text(l10n.videoGridEditVideo),
            matching: find.byType(ListTile),
          ),
        );
        expect(editTile.enabled, isTrue);
      });
    });

    group('load-more footer', () {
      // Renders the grid path with no tiles (empty list + no emptyBuilder) so
      // the footer can be exercised without the video-tile Nostr/network chain.
      Widget buildGrid({
        required bool isLoadingMore,
        required bool hasMoreContent,
        Future<void> Function()? onLoadMore,
      }) {
        return ProviderScope(
          overrides: _gridOverrides(mockTracker),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ComposableVideoGrid(
                videos: const [],
                onVideoTap: (videos, index) {},
                isLoadingMore: isLoadingMore,
                hasMoreContent: hasMoreContent,
                onLoadMore: onLoadMore,
              ),
            ),
          ),
        );
      }

      testWidgets(
        'shows a centered $BrandedLoadingIndicator below the scrolling grid '
        'while loading more',
        (tester) async {
          await tester.pumpWidget(
            buildGrid(
              isLoadingMore: true,
              hasMoreContent: true,
              onLoadMore: () async {},
            ),
          );
          await tester.pump(); // resolve broken-tracker future

          expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
          // The footer is no longer a grid cell: the grid is a sliver scroll
          // view and the legacy box-scrolling GridView is gone.
          expect(find.byType(CustomScrollView), findsOneWidget);
          expect(find.byType(GridView), findsNothing);

          // Horizontally centered across the full scrollable width.
          final indicatorCenter = tester.getCenter(
            find.byType(BrandedLoadingIndicator),
          );
          final scrollViewCenter = tester.getCenter(
            find.byType(CustomScrollView),
          );
          expect(
            indicatorCenter.dx,
            moreOrLessEquals(scrollViewCenter.dx, epsilon: 1),
          );
        },
      );

      testWidgets('does not show the loading indicator when not loading more', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildGrid(
            isLoadingMore: false,
            hasMoreContent: true,
            onLoadMore: () async {},
          ),
        );
        await tester.pump();

        // Footer slot exists (more content available) but stays empty until
        // a load actually starts.
        expect(find.byType(BrandedLoadingIndicator), findsNothing);
      });

      testWidgets('omits the loading indicator when there is no more content', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildGrid(isLoadingMore: false, hasMoreContent: false),
        );
        await tester.pump();

        expect(find.byType(BrandedLoadingIndicator), findsNothing);
      });
    });

    group('owner action affordance', () {
      const otherPubkey =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

      VideoEvent videoBy(String pubkey) => VideoEvent(
        id: 'video-by-$pubkey',
        pubkey: pubkey,
        content: 'A video',
        title: 'A video',
        authorName: 'Creator',
        videoUrl: 'https://example.com/v.mp4',
        thumbnailUrl: 'https://example.com/v.jpg',
        duration: 5,
        createdAt: DateTime(2026).millisecondsSinceEpoch ~/ 1000,
        timestamp: DateTime(2026),
      );

      Future<void> pumpGridFor(
        WidgetTester tester, {
        required VideoEvent video,
        required String nostrClientPubkey,
        String? authServicePubkey,
      }) async {
        final mockNostr = createMockNostrService();
        when(() => mockNostr.publicKey).thenReturn(nostrClientPubkey);
        final mockAuth = createMockAuthService();
        when(() => mockAuth.currentPublicKeyHex).thenReturn(authServicePubkey);
        when(() => mockAuth.authState).thenReturn(
          authServicePubkey == null
              ? AuthState.unauthenticated
              : AuthState.authenticated,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: _gridOverrides(
              mockTracker,
              nostrService: mockNostr,
              authService: mockAuth,
            ),
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: ComposableVideoGrid(
                  videos: [video],
                  onVideoTap: (videos, index) {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();
      }

      SemanticsNode tileNode(WidgetTester tester) {
        final l10n = lookupAppLocalizations(const Locale('en'));
        return tester.getSemantics(
          find.bySemanticsLabel(l10n.profileVideoThumbnailLabel(1)),
        );
      }

      testWidgets(
        'does not advertise a long-press action on a video the viewer '
        'does not own',
        (tester) async {
          final handle = tester.ensureSemantics();

          await pumpGridFor(
            tester,
            video: videoBy(otherPubkey),
            nostrClientPubkey: _ownPubkey,
            authServicePubkey: _ownPubkey,
          );

          expect(
            tileNode(
              tester,
            ).getSemanticsData().hasAction(SemanticsAction.longPress),
            isFalse,
            reason:
                'Advertising a long-press on a video the viewer does not own '
                'invites assistive-tech users to perform an action that '
                'silently does nothing.',
          );
          handle.dispose();
        },
      );

      testWidgets('labels the owner long-press action with the options hint', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        final l10n = lookupAppLocalizations(const Locale('en'));

        await pumpGridFor(
          tester,
          video: videoBy(_ownPubkey),
          nostrClientPubkey: _ownPubkey,
          authServicePubkey: _ownPubkey,
        );

        expect(
          tileNode(
            tester,
          ).getSemanticsData().hasAction(SemanticsAction.longPress),
          isTrue,
        );
        expect(
          tileNode(tester),
          isSemantics(onLongPressHint: l10n.videoGridOptionsTitle),
          reason:
              'Without a hint, assistive tech announces that a long-press '
              'exists but cannot say what it does.',
        );
        handle.dispose();
      });

      testWidgets(
        'opens the owner sheet when the Nostr client public-key cache is '
        'still empty but the auth service knows the owner',
        (tester) async {
          final l10n = lookupAppLocalizations(const Locale('en'));

          // NostrClient.publicKey is a plain cache read that starts empty and
          // is not re-refreshed on a miss (#6813), so ownership must not
          // depend on it alone.
          await pumpGridFor(
            tester,
            video: videoBy(_ownPubkey),
            nostrClientPubkey: '',
            authServicePubkey: _ownPubkey,
          );

          await tester.longPress(
            find.bySemanticsLabel(l10n.profileVideoThumbnailLabel(1)),
          );
          await tester.pumpAndSettle();

          expect(
            find.text(l10n.videoGridDeleteVideo),
            findsOneWidget,
            reason:
                'The signed-in owner must keep the edit/delete affordance even '
                'while the Nostr client key cache is empty.',
          );
        },
      );

      testWidgets('advertises no long-press action when signed out', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();

        await pumpGridFor(
          tester,
          video: videoBy(_ownPubkey),
          // Client replacement is queued during sign-out, so the old client
          // can still expose its cached key for a rebuild. Auth state must win.
          nostrClientPubkey: _ownPubkey,
        );

        expect(
          tileNode(
            tester,
          ).getSemanticsData().hasAction(SemanticsAction.longPress),
          isFalse,
        );
        handle.dispose();
      });
    });
  });
}
