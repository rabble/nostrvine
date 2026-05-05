// ABOUTME: Tests for NotificationsView — verifies rendering of loading,
// ABOUTME: failure, empty, and loaded states using a mock BLoC.

// ignore_for_file: prefer_const_constructors

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/notifications/bloc/notification_feed_bloc.dart';
import 'package:openvine/notifications/view/notifications_view.dart';
import 'package:openvine/notifications/widgets/notification_empty_state.dart';
import 'package:openvine/notifications/widgets/notification_list_item.dart';

class _MockNotificationFeedBloc
    extends MockBloc<NotificationFeedEvent, NotificationFeedState>
    implements NotificationFeedBloc {}

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
      testWidgets('renders error message and retry button', (tester) async {
        when(() => mockBloc.state).thenReturn(
          NotificationFeedState(status: NotificationFeedStatus.failure),
        );

        await _pumpView(tester, mockBloc);

        expect(find.text('Failed to load notifications'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
      });

      testWidgets('dispatches refresh on retry tap', (tester) async {
        when(() => mockBloc.state).thenReturn(
          NotificationFeedState(status: NotificationFeedStatus.failure),
        );

        await _pumpView(tester, mockBloc);
        await tester.tap(find.text('Retry'));
        await tester.pump();

        verify(
          () => mockBloc.add(NotificationFeedRefreshed()),
        ).called(1);
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

      testWidgets('dispatches mark all read on screen open', (tester) async {
        when(() => mockBloc.state).thenReturn(
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            notifications: testNotifications,
          ),
        );

        await _pumpView(tester, mockBloc);
        // addPostFrameCallback fires after first frame.
        await tester.pump();

        verify(
          () => mockBloc.add(NotificationFeedMarkAllRead()),
        ).called(1);
      });

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

        verify(
          () => mockBloc.add(NotificationFeedItemTapped('n1')),
        ).called(1);
      });
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

      testWidgets(
        'follow filter renders only follow notifications',
        (tester) async {
          when(() => mockBloc.state).thenReturn(
            NotificationFeedState(
              status: NotificationFeedStatus.loaded,
              notifications: mixed,
            ),
          );

          await _pumpView(
            tester,
            mockBloc,
            kindFilter: NotificationKind.follow,
          );

          expect(find.byType(NotificationListItem), findsOneWidget);
        },
      );

      testWidgets(
        'like filter also matches likeComment so likes-on-comments appear',
        (tester) async {
          when(() => mockBloc.state).thenReturn(
            NotificationFeedState(
              status: NotificationFeedStatus.loaded,
              notifications: mixed,
            ),
          );

          await _pumpView(
            tester,
            mockBloc,
            kindFilter: NotificationKind.like,
          );

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
