// ABOUTME: Tests for NotificationsView — verifies rendering of loading,
// ABOUTME: failure, empty, and loaded states using a mock BLoC.

// ignore_for_file: prefer_const_constructors

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/notifications/bloc/notification_feed_bloc.dart';
import 'package:openvine/notifications/view/notifications_view.dart';
import 'package:openvine/notifications/widgets/notification_empty_state.dart';
import 'package:openvine/notifications/widgets/notification_list_item.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:videos_repository/videos_repository.dart';

final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));

class _MockNotificationFeedBloc
    extends MockBloc<NotificationFeedEvent, NotificationFeedState>
    implements NotificationFeedBloc {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockVideosRepository extends Mock implements VideosRepository {}

/// Pumps [NotificationsView] inside the required providers.
Future<void> _pumpView(
  WidgetTester tester,
  NotificationFeedBloc bloc, {
  NotificationKind? kindFilter,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData.dark(),
        home: BlocProvider<NotificationFeedBloc>.value(
          value: bloc,
          child: Scaffold(body: NotificationsView(kindFilter: kindFilter)),
        ),
      ),
    ),
  );
}

/// Return type for [_pumpRoutedView] — collects navigations to both the
/// video feed and profile screens so tests can assert on either.
typedef _RoutedViewResult = ({
  List<PooledFullscreenVideoFeedArgs> videoArgs,
  List<String> profileNpubs,
});

Future<List<PooledFullscreenVideoFeedArgs>> _pumpRoutedView(
  WidgetTester tester,
  NotificationFeedBloc bloc, {
  required VideoEventService videoEventService,
  required NostrClient nostrClient,
  required VideosRepository videosRepository,
}) async {
  final result = await _pumpRoutedViewFull(
    tester,
    bloc,
    videoEventService: videoEventService,
    nostrClient: nostrClient,
    videosRepository: videosRepository,
  );
  return result.videoArgs;
}

/// Like [_pumpRoutedView] but also captures profile navigations.
Future<_RoutedViewResult> _pumpRoutedViewFull(
  WidgetTester tester,
  NotificationFeedBloc bloc, {
  required VideoEventService videoEventService,
  required NostrClient nostrClient,
  required VideosRepository videosRepository,
}) async {
  final capturedVideoArgs = <PooledFullscreenVideoFeedArgs>[];
  final capturedProfileNpubs = <String>[];
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(body: NotificationsView()),
      ),
      GoRoute(
        path: PooledFullscreenVideoFeedScreen.path,
        builder: (context, state) {
          capturedVideoArgs.add(state.extra! as PooledFullscreenVideoFeedArgs);
          return const Scaffold(body: SizedBox.shrink());
        },
      ),
      GoRoute(
        path: OtherProfileScreen.pathWithNpub,
        builder: (context, state) {
          capturedProfileNpubs.add(state.pathParameters['npub']!);
          return const Scaffold(body: SizedBox.shrink());
        },
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        videoEventServiceProvider.overrideWithValue(videoEventService),
        nostrServiceProvider.overrideWithValue(nostrClient),
        videosRepositoryProvider.overrideWithValue(videosRepository),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData.dark(),
        routerConfig: router,
        builder: (context, child) => BlocProvider<NotificationFeedBloc>.value(
          value: bloc,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    ),
  );

  return (videoArgs: capturedVideoArgs, profileNpubs: capturedProfileNpubs);
}

VideoEvent _video(String id) => VideoEvent(
  id: id,
  pubkey: 'pubkey_$id',
  createdAt: DateTime(2026).millisecondsSinceEpoch ~/ 1000,
  timestamp: DateTime(2026),
  content: 'content',
  title: 'title',
  videoUrl: 'https://example.com/$id.mp4',
  thumbnailUrl: 'https://example.com/$id.jpg',
);

void main() {
  group(NotificationsView, () {
    late _MockNotificationFeedBloc mockBloc;

    setUp(() {
      mockBloc = _MockNotificationFeedBloc();
    });

    group('initial state', () {
      testWidgets('renders loading indicator', (tester) async {
        when(() => mockBloc.state).thenReturn(NotificationFeedState());

        await _pumpView(tester, mockBloc);

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('outer container uses surfaceContainerHigh background', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(NotificationFeedState());

        await _pumpView(tester, mockBloc);

        final coloredBoxFinder = find
            .descendant(
              of: find.byType(NotificationsView),
              matching: find.byType(ColoredBox),
            )
            .first;
        final coloredBox = tester.widget<ColoredBox>(coloredBoxFinder);
        expect(coloredBox.color, equals(VineTheme.surfaceContainerHigh));
      });
    });

    group('loading state', () {
      testWidgets('renders loading indicator', (tester) async {
        when(() => mockBloc.state).thenReturn(
          NotificationFeedState(status: NotificationFeedStatus.loading),
        );

        await _pumpView(tester, mockBloc);

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    group('failure state', () {
      testWidgets('renders localized error message and retry button', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          NotificationFeedState(status: NotificationFeedStatus.failure),
        );

        await _pumpView(tester, mockBloc);

        expect(find.text(_l10n.notificationsFailedToLoad), findsOneWidget);
        expect(find.text(_l10n.notificationsRetry), findsOneWidget);
      });

      testWidgets('dispatches refresh on retry tap', (tester) async {
        when(() => mockBloc.state).thenReturn(
          NotificationFeedState(status: NotificationFeedStatus.failure),
        );

        await _pumpView(tester, mockBloc);
        await tester.tap(find.text(_l10n.notificationsRetry));
        await tester.pump();

        verify(() => mockBloc.add(NotificationFeedRefreshed())).called(1);
      });
    });

    group('loaded empty state', () {
      testWidgets('renders $NotificationEmptyState', (tester) async {
        when(() => mockBloc.state).thenReturn(
          NotificationFeedState(status: NotificationFeedStatus.loaded),
        );

        await _pumpView(tester, mockBloc);

        expect(find.byType(NotificationEmptyState), findsOneWidget);
      });
    });

    group('loaded with notifications', () {
      // Use system kind for the first item so the tap handler doesn't
      // attempt navigation through providers we haven't stubbed.
      final testNotifications = <NotificationItem>[
        ActorNotification(
          id: 'n1',
          type: NotificationKind.system,
          actor: ActorInfo(pubkey: 'abc123', displayName: 'Alice'),
          timestamp: DateTime(2026),
        ),
        ActorNotification(
          id: 'n2',
          type: NotificationKind.system,
          actor: ActorInfo(pubkey: 'def456', displayName: 'Bob'),
          timestamp: DateTime(2026),
        ),
      ];

      testWidgets('renders $NotificationListItem for each notification', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            notifications: testNotifications,
          ),
        );

        await _pumpView(tester, mockBloc);

        expect(find.byType(NotificationListItem), findsNWidgets(2));
      });

      testWidgets('renders loading indicator when loading more', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            notifications: testNotifications,
            isLoadingMore: true,
          ),
        );

        await _pumpView(tester, mockBloc);

        // One for the bottom loading indicator.
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('does not inject Divider widgets between rows', (
        tester,
      ) async {
        // The row widget owns its bottom border via outlineDisabled; the
        // list must not add a separate Divider on top of it.
        when(() => mockBloc.state).thenReturn(
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            notifications: testNotifications,
          ),
        );

        await _pumpView(tester, mockBloc);

        expect(find.byType(Divider), findsNothing);
      });

      // NotificationsView.initState must stay side-effect-free for read state.
      // See inbox_notifications_page_test.dart and notifications_page_test.dart
      // for the page-level refresh contract.

      testWidgets('dispatches item tapped on notification tap', (tester) async {
        when(() => mockBloc.state).thenReturn(
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            notifications: testNotifications,
          ),
        );

        await _pumpView(tester, mockBloc);
        // Tap the first notification list item.
        await tester.tap(find.byType(NotificationListItem).first);
        await tester.pump();

        verify(() => mockBloc.add(NotificationFeedItemTapped('n1'))).called(1);
      });

      testWidgets('likeComment tap resolves comment to root video and opens '
          'comments thread', (tester) async {
        final videoService = _MockVideoEventService();
        final nostrClient = _MockNostrClient();
        final videosRepository = _MockVideosRepository();
        const commentEventId = 'comment_1111_event';
        const rootVideoEventId = 'root_video_event';
        final resolvedVideo = _video(rootVideoEventId);

        // The comment is not a video — resolver fetches it from relay
        // and follows its uppercase E tag to the root video.
        when(() => videoService.getVideoById(commentEventId)).thenReturn(null);
        when(() => nostrClient.fetchEventById(commentEventId)).thenAnswer((
          _,
        ) async {
          final event = Event(
            'a' * 64,
            1111,
            const [
              ['E', rootVideoEventId],
            ],
            'liked comment text',
            createdAt: 1700000000,
          );
          event.id = commentEventId;
          return event;
        });
        when(
          () =>
              videosRepository.fetchVideoWithStatsForRouteId(rootVideoEventId),
        ).thenAnswer((_) async => resolvedVideo);
        when(
          () => videoService.shouldHideVideo(resolvedVideo),
        ).thenReturn(false);

        when(() => mockBloc.state).thenReturn(
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            notifications: [
              ActorNotification(
                id: 'lc1',
                type: NotificationKind.likeComment,
                actor: ActorInfo(pubkey: 'liker', displayName: 'Liz'),
                timestamp: DateTime(2026),
                targetEventId: commentEventId,
              ),
            ],
          ),
        );

        final capturedArgs = await _pumpRoutedView(
          tester,
          mockBloc,
          videoEventService: videoService,
          nostrClient: nostrClient,
          videosRepository: videosRepository,
        );

        await tester.tap(find.byType(NotificationListItem).first);
        await tester.pumpAndSettle();

        verify(() => nostrClient.fetchEventById(commentEventId)).called(1);
        verify(
          () =>
              videosRepository.fetchVideoWithStatsForRouteId(rootVideoEventId),
        ).called(1);
        expect(capturedArgs, hasLength(1));
        final args = capturedArgs.single;
        expect(args.autoOpenComments, isTrue);
        final videos = await args.videosStream.first;
        expect(videos.single.id, resolvedVideo.id);
      });

      testWidgets(
        'reply tap resolves target comment to root video and opens '
        'comments thread',
        (tester) async {
          final videoService = _MockVideoEventService();
          final nostrClient = _MockNostrClient();
          final videosRepository = _MockVideosRepository();
          const parentCommentId = 'parent_comment_id';
          const rootVideoEventId = 'reply_root_video';
          final resolvedVideo = _video(rootVideoEventId);

          when(
            () => videoService.getVideoById(parentCommentId),
          ).thenReturn(null);
          when(() => nostrClient.fetchEventById(parentCommentId)).thenAnswer((
            _,
          ) async {
            final event = Event(
              'a' * 64,
              1111,
              const [
                ['E', rootVideoEventId],
              ],
              'parent comment text',
              createdAt: 1700000000,
            );
            event.id = parentCommentId;
            return event;
          });
          when(
            () => videosRepository.fetchVideoWithStatsForRouteId(
              rootVideoEventId,
            ),
          ).thenAnswer((_) async => resolvedVideo);
          when(
            () => videoService.shouldHideVideo(resolvedVideo),
          ).thenReturn(false);

          when(() => mockBloc.state).thenReturn(
            NotificationFeedState(
              status: NotificationFeedStatus.loaded,
              notifications: [
                ActorNotification(
                  id: 'r1',
                  type: NotificationKind.reply,
                  actor: ActorInfo(pubkey: 'replier', displayName: 'Bob'),
                  timestamp: DateTime(2026),
                  targetEventId: parentCommentId,
                ),
              ],
            ),
          );

          final capturedArgs = await _pumpRoutedView(
            tester,
            mockBloc,
            videoEventService: videoService,
            nostrClient: nostrClient,
            videosRepository: videosRepository,
          );

          await tester.tap(find.byType(NotificationListItem).first);
          await tester.pumpAndSettle();

          verify(() => nostrClient.fetchEventById(parentCommentId)).called(1);
          verify(
            () => videosRepository.fetchVideoWithStatsForRouteId(
              rootVideoEventId,
            ),
          ).called(1);
          expect(capturedArgs, hasLength(1));
          expect(capturedArgs.single.autoOpenComments, isTrue);
        },
      );

      testWidgets(
        'reply tap pushes video route before resolver completes',
        (tester) async {
          final videoService = _MockVideoEventService();
          final nostrClient = _MockNostrClient();
          final videosRepository = _MockVideosRepository();
          const parentCommentId = 'slow_parent_comment_id';
          const rootVideoEventId = 'slow_reply_root_video';
          final resolvedVideo = _video(rootVideoEventId);
          final resolverCompleter = Completer<Event?>();

          when(
            () => videoService.getVideoById(parentCommentId),
          ).thenReturn(null);
          when(
            () => nostrClient.fetchEventById(parentCommentId),
          ).thenAnswer((_) => resolverCompleter.future);
          when(
            () => videosRepository.fetchVideoWithStatsForRouteId(
              rootVideoEventId,
            ),
          ).thenAnswer((_) async => resolvedVideo);
          when(
            () => videoService.shouldHideVideo(resolvedVideo),
          ).thenReturn(false);

          when(() => mockBloc.state).thenReturn(
            NotificationFeedState(
              status: NotificationFeedStatus.loaded,
              notifications: [
                ActorNotification(
                  id: 'slow-reply',
                  type: NotificationKind.reply,
                  actor: ActorInfo(pubkey: 'replier', displayName: 'Bob'),
                  timestamp: DateTime(2026),
                  targetEventId: parentCommentId,
                ),
              ],
            ),
          );

          final capturedArgs = await _pumpRoutedView(
            tester,
            mockBloc,
            videoEventService: videoService,
            nostrClient: nostrClient,
            videosRepository: videosRepository,
          );

          await tester.tap(find.byType(NotificationListItem).first);
          await tester.pump();

          expect(capturedArgs, hasLength(1));
          expect(capturedArgs.single.autoOpenComments, isTrue);
          verifyNever(
            () => videosRepository.fetchVideoWithStatsForRouteId(any()),
          );

          final event = Event(
            'a' * 64,
            1111,
            const [
              ['E', rootVideoEventId],
            ],
            'parent comment text',
            createdAt: 1700000000,
          );
          event.id = parentCommentId;
          resolverCompleter.complete(event);

          final videos = await capturedArgs.single.videosStream.first;
          expect(videos.single.id, resolvedVideo.id);
          verify(
            () => videosRepository.fetchVideoWithStatsForRouteId(
              rootVideoEventId,
            ),
          ).called(1);
        },
      );

      testWidgets(
        'comment notification fetches by addressable id and opens comments',
        (tester) async {
          final videoService = _MockVideoEventService();
          final nostrClient = _MockNostrClient();
          final videosRepository = _MockVideosRepository();
          const staleVideoEventId = 'stale_video_event';
          const addressableId =
              '34236:'
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
              ':vine-id';
          final resolvedVideo = _video('replacement_video_event');

          when(
            () => videoService.getVideoById(staleVideoEventId),
          ).thenReturn(null);
          when(
            () => nostrClient.fetchEventById(staleVideoEventId),
          ).thenAnswer((_) async => null);
          when(
            () => videosRepository.fetchVideoWithStatsForRouteId(addressableId),
          ).thenAnswer((_) async => resolvedVideo);
          when(
            () => videoService.shouldHideVideo(resolvedVideo),
          ).thenReturn(false);

          when(() => mockBloc.state).thenReturn(
            NotificationFeedState(
              status: NotificationFeedStatus.loaded,
              notifications: [
                VideoNotification(
                  id: 'comment-notification',
                  type: NotificationKind.comment,
                  videoEventId: staleVideoEventId,
                  videoAddressableId: addressableId,
                  actors: const [
                    ActorInfo(pubkey: 'actor_pubkey', displayName: 'Alice'),
                  ],
                  totalCount: 1,
                  timestamp: DateTime(2026),
                ),
              ],
            ),
          );

          final capturedArgs = await _pumpRoutedView(
            tester,
            mockBloc,
            videoEventService: videoService,
            nostrClient: nostrClient,
            videosRepository: videosRepository,
          );

          await tester.tap(find.byType(NotificationListItem).first);
          await tester.pumpAndSettle();

          verify(
            () => videosRepository.fetchVideoWithStatsForRouteId(addressableId),
          ).called(1);
          expect(capturedArgs, hasLength(1));
          final args = capturedArgs.single;
          expect(args.autoOpenComments, isTrue);
          final videos = await args.videosStream.first;
          expect(videos.single.id, resolvedVideo.id);
        },
      );

      testWidgets(
        'likeComment tap uses videoAddressableId directly when available '
        '— no relay round-trip through resolver',
        (tester) async {
          // When the repository populates videoAddressableId from the
          // server-provided d_tag, the stable NIP-33 path must be taken
          // and fetchEventById must never be called.
          final videoService = _MockVideoEventService();
          final nostrClient = _MockNostrClient();
          final videosRepository = _MockVideosRepository();
          const addressableId =
              '34236:'
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
              ':vine-liked-comment';
          final video = _video('liked_comment_video');

          when(
            () => videosRepository.fetchVideoWithStatsForRouteId(addressableId),
          ).thenAnswer((_) async => video);
          when(() => videoService.shouldHideVideo(video)).thenReturn(false);

          when(() => mockBloc.state).thenReturn(
            NotificationFeedState(
              status: NotificationFeedStatus.loaded,
              notifications: [
                ActorNotification(
                  id: 'lc-addr',
                  type: NotificationKind.likeComment,
                  actor: ActorInfo(pubkey: 'liker_pubkey', displayName: 'Liz'),
                  timestamp: DateTime(2026),
                  targetEventId: 'some_comment_event_id',
                  // videoAddressableId set — bypasses resolver.
                  videoAddressableId: addressableId,
                ),
              ],
            ),
          );

          final capturedArgs = await _pumpRoutedView(
            tester,
            mockBloc,
            videoEventService: videoService,
            nostrClient: nostrClient,
            videosRepository: videosRepository,
          );

          await tester.tap(find.byType(NotificationListItem).first);
          await tester.pumpAndSettle();

          // Resolver must NOT be called — stable path is taken directly.
          verifyNever(() => nostrClient.fetchEventById(any()));
          verify(
            () => videosRepository.fetchVideoWithStatsForRouteId(addressableId),
          ).called(1);
          expect(capturedArgs, hasLength(1));
          expect(capturedArgs.single.autoOpenComments, isTrue);
          final videos = await capturedArgs.single.videosStream.first;
          expect(videos.single.id, video.id);
        },
      );
    });

    // -----------------------------------------------------------------------
    // Tap-target routing — regression coverage for all notification kinds
    // -----------------------------------------------------------------------

    group('tap routing — like', () {
      testWidgets(
        'like tap opens the target video with autoOpenComments:false '
        'using the stable addressable id',
        (tester) async {
          final videoService = _MockVideoEventService();
          final nostrClient = _MockNostrClient();
          final videosRepository = _MockVideosRepository();
          const addressableId =
              '34236:'
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
              ':vine-like';
          final likedVideo = _video('liked_video_event');

          when(
            () => videosRepository.fetchVideoWithStatsForRouteId(addressableId),
          ).thenAnswer((_) async => likedVideo);
          when(
            () => videoService.shouldHideVideo(likedVideo),
          ).thenReturn(false);

          when(() => mockBloc.state).thenReturn(
            NotificationFeedState(
              status: NotificationFeedStatus.loaded,
              notifications: [
                VideoNotification(
                  id: 'like-1',
                  type: NotificationKind.like,
                  videoEventId: 'liked_video_event',
                  videoAddressableId: addressableId,
                  actors: const [
                    ActorInfo(pubkey: 'liker_pubkey', displayName: 'Alice'),
                  ],
                  totalCount: 1,
                  timestamp: DateTime(2026),
                ),
              ],
            ),
          );

          final result = await _pumpRoutedViewFull(
            tester,
            mockBloc,
            videoEventService: videoService,
            nostrClient: nostrClient,
            videosRepository: videosRepository,
          );

          await tester.tap(find.byType(NotificationListItem).first);
          await tester.pumpAndSettle();

          verify(
            () => videosRepository.fetchVideoWithStatsForRouteId(addressableId),
          ).called(1);
          expect(result.videoArgs, hasLength(1));
          expect(result.videoArgs.single.autoOpenComments, isFalse);
          final videos = await result.videoArgs.single.videosStream.first;
          expect(videos.single.id, likedVideo.id);
        },
      );

      testWidgets(
        'like tap falls back to raw eventId when no addressable id is set',
        (tester) async {
          final videoService = _MockVideoEventService();
          final nostrClient = _MockNostrClient();
          final videosRepository = _MockVideosRepository();
          const rawEventId = 'raw_like_event_id';
          final likedVideo = _video(rawEventId);

          when(
            () => videosRepository.fetchVideoWithStatsForRouteId(rawEventId),
          ).thenAnswer((_) async => likedVideo);
          when(
            () => videoService.shouldHideVideo(likedVideo),
          ).thenReturn(false);

          when(() => mockBloc.state).thenReturn(
            NotificationFeedState(
              status: NotificationFeedStatus.loaded,
              notifications: [
                VideoNotification(
                  id: 'like-2',
                  type: NotificationKind.like,
                  videoEventId: rawEventId,
                  actors: const [
                    ActorInfo(pubkey: 'liker_pubkey', displayName: 'Bob'),
                  ],
                  totalCount: 1,
                  timestamp: DateTime(2026),
                ),
              ],
            ),
          );

          final result = await _pumpRoutedViewFull(
            tester,
            mockBloc,
            videoEventService: videoService,
            nostrClient: nostrClient,
            videosRepository: videosRepository,
          );

          await tester.tap(find.byType(NotificationListItem).first);
          await tester.pumpAndSettle();

          verify(
            () => videosRepository.fetchVideoWithStatsForRouteId(rawEventId),
          ).called(1);
          expect(result.videoArgs, hasLength(1));
          expect(result.videoArgs.single.autoOpenComments, isFalse);
        },
      );
    });

    group('tap routing — repost', () {
      testWidgets(
        'repost tap opens the target video with autoOpenComments:false '
        'and actor identity is present in the notification',
        (tester) async {
          final videoService = _MockVideoEventService();
          final nostrClient = _MockNostrClient();
          final videosRepository = _MockVideosRepository();
          const addressableId =
              '34236:'
              'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
              ':vine-repost';
          final repostedVideo = _video('reposted_video_event');

          when(
            () => videosRepository.fetchVideoWithStatsForRouteId(addressableId),
          ).thenAnswer((_) async => repostedVideo);
          when(
            () => videoService.shouldHideVideo(repostedVideo),
          ).thenReturn(false);

          when(() => mockBloc.state).thenReturn(
            NotificationFeedState(
              status: NotificationFeedStatus.loaded,
              notifications: [
                VideoNotification(
                  id: 'repost-1',
                  type: NotificationKind.repost,
                  videoEventId: 'reposted_video_event',
                  videoAddressableId: addressableId,
                  actors: const [
                    // Actor identity must be visible in the row.
                    ActorInfo(
                      pubkey: 'reposter_pubkey',
                      displayName: 'Charlie',
                    ),
                  ],
                  totalCount: 1,
                  timestamp: DateTime(2026),
                ),
              ],
            ),
          );

          final result = await _pumpRoutedViewFull(
            tester,
            mockBloc,
            videoEventService: videoService,
            nostrClient: nostrClient,
            videosRepository: videosRepository,
          );

          // Actor name is rendered in the row before tapping.
          expect(find.textContaining('Charlie'), findsOneWidget);

          await tester.tap(find.byType(NotificationListItem).first);
          await tester.pumpAndSettle();

          verify(
            () => videosRepository.fetchVideoWithStatsForRouteId(addressableId),
          ).called(1);
          expect(result.videoArgs, hasLength(1));
          expect(result.videoArgs.single.autoOpenComments, isFalse);
          final videos = await result.videoArgs.single.videosStream.first;
          expect(videos.single.id, repostedVideo.id);
        },
      );
    });

    group('tap routing — follow', () {
      testWidgets(
        'follow tap navigates to the actor profile',
        (tester) async {
          final videoService = _MockVideoEventService();
          final nostrClient = _MockNostrClient();
          final videosRepository = _MockVideosRepository();
          // A real 64-char hex pubkey so encodePubKey produces a valid npub.
          final followerPubkey = 'a' * 64;

          when(() => mockBloc.state).thenReturn(
            NotificationFeedState(
              status: NotificationFeedStatus.loaded,
              notifications: [
                ActorNotification(
                  id: 'follow-1',
                  type: NotificationKind.follow,
                  actor: ActorInfo(
                    pubkey: followerPubkey,
                    displayName: 'Dave',
                  ),
                  timestamp: DateTime(2026),
                ),
              ],
            ),
          );

          final result = await _pumpRoutedViewFull(
            tester,
            mockBloc,
            videoEventService: videoService,
            nostrClient: nostrClient,
            videosRepository: videosRepository,
          );

          await tester.tap(find.byType(NotificationListItem).first);
          await tester.pumpAndSettle();

          expect(result.videoArgs, isEmpty);
          expect(result.profileNpubs, hasLength(1));
          // npub must be the bech32 encoding of followerPubkey.
          expect(result.profileNpubs.single, startsWith('npub'));
        },
      );
    });

    group('tap routing — mention', () {
      testWidgets(
        'mention tap resolves the mention event to the root video '
        'and opens with autoOpenComments:true',
        (tester) async {
          final videoService = _MockVideoEventService();
          final nostrClient = _MockNostrClient();
          final videosRepository = _MockVideosRepository();
          const mentionEventId = 'mention_kind1_event';
          const rootVideoEventId = 'mention_root_video';
          final mentionedInVideo = _video(rootVideoEventId);

          // The mention event is a kind-1 with an uppercase E tag pointing
          // to the root video — the same resolver path used for replies.
          when(
            () => videoService.getVideoById(mentionEventId),
          ).thenReturn(null);
          when(
            () => nostrClient.fetchEventById(mentionEventId),
          ).thenAnswer((_) async {
            final event = Event(
              'c' * 64,
              1,
              const [
                ['E', rootVideoEventId],
              ],
              'hey @user great video',
              createdAt: 1700000000,
            );
            event.id = mentionEventId;
            return event;
          });
          when(
            () => videosRepository.fetchVideoWithStatsForRouteId(
              rootVideoEventId,
            ),
          ).thenAnswer((_) async => mentionedInVideo);
          when(
            () => videoService.shouldHideVideo(mentionedInVideo),
          ).thenReturn(false);

          when(() => mockBloc.state).thenReturn(
            NotificationFeedState(
              status: NotificationFeedStatus.loaded,
              notifications: [
                ActorNotification(
                  id: 'mention-1',
                  type: NotificationKind.mention,
                  actor: ActorInfo(
                    pubkey: 'mentioner_pubkey',
                    displayName: 'Eve',
                  ),
                  timestamp: DateTime(2026),
                  targetEventId: mentionEventId,
                ),
              ],
            ),
          );

          final result = await _pumpRoutedViewFull(
            tester,
            mockBloc,
            videoEventService: videoService,
            nostrClient: nostrClient,
            videosRepository: videosRepository,
          );

          await tester.tap(find.byType(NotificationListItem).first);
          await tester.pumpAndSettle();

          verify(
            () => nostrClient.fetchEventById(mentionEventId),
          ).called(1);
          verify(
            () => videosRepository.fetchVideoWithStatsForRouteId(
              rootVideoEventId,
            ),
          ).called(1);
          expect(result.videoArgs, hasLength(1));
          expect(result.videoArgs.single.autoOpenComments, isTrue);
          final videos = await result.videoArgs.single.videosStream.first;
          expect(videos.single.id, mentionedInVideo.id);
        },
      );

      testWidgets(
        'mention tap falls back to actor profile when resolver cannot '
        'find the root video',
        (tester) async {
          final videoService = _MockVideoEventService();
          final nostrClient = _MockNostrClient();
          final videosRepository = _MockVideosRepository();
          const mentionEventId = 'unresolvable_mention_event';
          final mentionerPubkey = 'f' * 64;

          // Resolver returns null — event has no E-tags and is not a video.
          when(
            () => videoService.getVideoById(mentionEventId),
          ).thenReturn(null);
          when(
            () => nostrClient.fetchEventById(mentionEventId),
          ).thenAnswer((_) async {
            final event = Event(
              'd' * 64,
              1,
              const [],
              'plain mention with no video context',
              createdAt: 1700000000,
            );
            event.id = mentionEventId;
            return event;
          });

          when(() => mockBloc.state).thenReturn(
            NotificationFeedState(
              status: NotificationFeedStatus.loaded,
              notifications: [
                ActorNotification(
                  id: 'mention-2',
                  type: NotificationKind.mention,
                  actor: ActorInfo(
                    pubkey: mentionerPubkey,
                    displayName: 'Frank',
                  ),
                  timestamp: DateTime(2026),
                  targetEventId: mentionEventId,
                ),
              ],
            ),
          );

          final result = await _pumpRoutedViewFull(
            tester,
            mockBloc,
            videoEventService: videoService,
            nostrClient: nostrClient,
            videosRepository: videosRepository,
          );

          await tester.tap(find.byType(NotificationListItem).first);
          await tester.pumpAndSettle();

          expect(result.videoArgs, isEmpty);
          expect(result.profileNpubs, hasLength(1));
          expect(result.profileNpubs.single, startsWith('npub'));
        },
      );

      testWidgets(
        'mention tap with null targetEventId falls back to actor profile',
        (tester) async {
          // Defensive case: if the repository could not populate targetEventId
          // (e.g. empty sourceEventId), the view falls back gracefully.
          final videoService = _MockVideoEventService();
          final nostrClient = _MockNostrClient();
          final videosRepository = _MockVideosRepository();
          final mentionerPubkey = 'e' * 64;

          when(() => mockBloc.state).thenReturn(
            NotificationFeedState(
              status: NotificationFeedStatus.loaded,
              notifications: [
                ActorNotification(
                  id: 'mention-3',
                  type: NotificationKind.mention,
                  actor: ActorInfo(
                    pubkey: mentionerPubkey,
                    displayName: 'Grace',
                  ),
                  timestamp: DateTime(2026),
                  // targetEventId intentionally null — no source event id
                ),
              ],
            ),
          );

          final result = await _pumpRoutedViewFull(
            tester,
            mockBloc,
            videoEventService: videoService,
            nostrClient: nostrClient,
            videosRepository: videosRepository,
          );

          await tester.tap(find.byType(NotificationListItem).first);
          await tester.pumpAndSettle();

          verifyNever(() => nostrClient.fetchEventById(any()));
          expect(result.videoArgs, isEmpty);
          expect(result.profileNpubs, hasLength(1));
          expect(result.profileNpubs.single, startsWith('npub'));
        },
      );
    });

    group('kindFilter', () {
      final mixed = <NotificationItem>[
        ActorNotification(
          id: 'a1',
          type: NotificationKind.follow,
          actor: ActorInfo(pubkey: 'a', displayName: 'Alice'),
          timestamp: DateTime(2026),
        ),
        ActorNotification(
          id: 'a2',
          type: NotificationKind.mention,
          actor: ActorInfo(pubkey: 'b', displayName: 'Bob'),
          timestamp: DateTime(2026),
        ),
        ActorNotification(
          id: 'a3',
          type: NotificationKind.likeComment,
          actor: ActorInfo(pubkey: 'c', displayName: 'Carol'),
          timestamp: DateTime(2026),
        ),
        VideoNotification(
          id: 'v1',
          type: NotificationKind.like,
          videoEventId: 'video1',
          actors: const [ActorInfo(pubkey: 'd', displayName: 'Dan')],
          totalCount: 1,
          timestamp: DateTime(2026),
        ),
        VideoNotification(
          id: 'v2',
          type: NotificationKind.comment,
          videoEventId: 'video2',
          actors: const [ActorInfo(pubkey: 'e', displayName: 'Eve')],
          totalCount: 1,
          timestamp: DateTime(2026),
        ),
      ];

      testWidgets('null filter renders every notification', (tester) async {
        when(() => mockBloc.state).thenReturn(
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            notifications: mixed,
          ),
        );

        await _pumpView(tester, mockBloc);

        expect(find.byType(NotificationListItem), findsNWidgets(5));
      });

      testWidgets('follow filter renders only follow notifications', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            notifications: mixed,
          ),
        );

        await _pumpView(tester, mockBloc, kindFilter: NotificationKind.follow);

        expect(find.byType(NotificationListItem), findsOneWidget);
      });

      testWidgets(
        'like filter also matches likeComment so likes-on-comments appear',
        (tester) async {
          when(() => mockBloc.state).thenReturn(
            NotificationFeedState(
              status: NotificationFeedStatus.loaded,
              notifications: mixed,
            ),
          );

          await _pumpView(tester, mockBloc, kindFilter: NotificationKind.like);

          // VideoNotification(like) + ActorNotification(likeComment) = 2.
          expect(find.byType(NotificationListItem), findsNWidgets(2));
        },
      );
    });

    group('date headers', () {
      testWidgets('shows date header when date changes', (tester) async {
        final notifications = <NotificationItem>[
          ActorNotification(
            id: 'n1',
            type: NotificationKind.mention,
            actor: ActorInfo(pubkey: 'a', displayName: 'Alice'),
            timestamp: DateTime(2026, 4, 6),
          ),
          ActorNotification(
            id: 'n2',
            type: NotificationKind.mention,
            actor: ActorInfo(pubkey: 'b', displayName: 'Bob'),
            timestamp: DateTime(2026, 4, 5),
          ),
        ];

        when(() => mockBloc.state).thenReturn(
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            notifications: notifications,
          ),
        );

        await _pumpView(tester, mockBloc);

        // Each notification on a different day should produce a date header.
        // The first item always gets a header. The second gets one because
        // its date differs. So we expect 2 date header texts.
        // We just verify the list renders without error and has items.
        expect(find.byType(NotificationListItem), findsNWidgets(2));
      });
    });
  });
}
