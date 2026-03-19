// ABOUTME: Widget tests for InboxView.
// ABOUTME: Verifies segmented toggle, message list states (loading, error,
// ABOUTME: empty, loaded), and tab switching between messages and notifications.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/conversation_list/conversation_list_bloc.dart';
import 'package:openvine/blocs/my_following/my_following_bloc.dart';
import 'package:openvine/providers/relay_notifications_provider.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/screens/inbox/conversation/conversation_page.dart';
import 'package:openvine/screens/inbox/inbox_view.dart';
import 'package:openvine/screens/inbox/message_requests/message_requests_page.dart';
import 'package:openvine/screens/inbox/message_requests/widgets/message_requests_banner.dart';
import 'package:openvine/screens/inbox/widgets/conversation_tile.dart';
import 'package:openvine/screens/inbox/widgets/following_bar.dart';
import 'package:openvine/screens/inbox/widgets/inbox_empty_state.dart';
import 'package:openvine/screens/inbox/widgets/inbox_segmented_toggle.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/utils/nostr_key_utils.dart';

import '../../helpers/go_router.dart';
import '../../helpers/test_provider_overrides.dart';

class _MockConversationListBloc
    extends MockBloc<ConversationListEvent, ConversationListState>
    implements ConversationListBloc {}

class _MockMyFollowingBloc extends MockBloc<MyFollowingEvent, MyFollowingState>
    implements MyFollowingBloc {}

/// Minimal mock so NotificationsScreen (default tab) renders without crashing.
class _MockRelayNotifications extends RelayNotifications {
  @override
  Future<NotificationFeedState> build() async {
    return NotificationFeedState(
      notifications: const [],
      isInitialLoad: false,
      lastUpdated: DateTime.now(),
    );
  }

  @override
  Future<void> markAsRead(String notificationId) async {}

  @override
  Future<void> markAllAsRead() async {}

  @override
  Future<void> loadMore() async {}

  @override
  Future<void> refresh() async {}
}

class _MockAuthService extends MockAuthService {
  _MockAuthService(this._pubkey) {
    when(() => authState).thenReturn(AuthState.authenticated);
    when(() => isAuthenticated).thenReturn(true);
    when(
      () => authStateStream,
    ).thenAnswer((_) => const Stream<AuthState>.empty());
  }
  final String _pubkey;

  @override
  String? get currentPublicKeyHex => _pubkey;
}

void main() {
  const currentPubkey =
      'aabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccdd';
  const otherPubkey =
      '1122334411223344112233441122334411223344112233441122334411223344';

  final now = DateTime.now();
  final nowUnix = now.millisecondsSinceEpoch ~/ 1000;

  group(InboxView, () {
    late _MockConversationListBloc mockBloc;
    late _MockMyFollowingBloc mockFollowingBloc;
    late _MockAuthService mockAuthService;
    late MockGoRouter mockGoRouter;

    setUp(() {
      mockBloc = _MockConversationListBloc();
      mockFollowingBloc = _MockMyFollowingBloc();
      mockAuthService = _MockAuthService(currentPubkey);
      mockGoRouter = MockGoRouter();

      whenListen(
        mockFollowingBloc,
        const Stream<MyFollowingState>.empty(),
        initialState: const MyFollowingState(),
      );
    });

    Widget buildSubject({ConversationListState? state}) {
      if (state != null) {
        whenListen(
          mockBloc,
          Stream<ConversationListState>.value(state),
          initialState: state,
        );
      } else {
        whenListen(
          mockBloc,
          const Stream<ConversationListState>.empty(),
          initialState: const ConversationListState(),
        );
      }

      return testMaterialApp(
        mockAuthService: mockAuthService,
        additionalOverrides: [
          relayNotificationUnreadCountProvider.overrideWithValue(0),
          relayNotificationsProvider.overrideWith(_MockRelayNotifications.new),
          goRouterProvider.overrideWithValue(mockGoRouter),
        ],
        home: MockGoRouterProvider(
          goRouter: mockGoRouter,
          child: MultiBlocProvider(
            providers: [
              BlocProvider<ConversationListBloc>.value(value: mockBloc),
              BlocProvider<MyFollowingBloc>.value(value: mockFollowingBloc),
            ],
            child: const InboxView(),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('renders $InboxSegmentedToggle', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pump();

        expect(find.byType(InboxSegmentedToggle), findsOneWidget);
      });

      testWidgets('renders $FollowingBar in messages tab', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pump();

        // Switch to Messages tab (default is Notifications).
        await tester.tap(find.text('Messages'));
        await tester.pump();

        expect(find.byType(FollowingBar), findsOneWidget);
      });

      testWidgets(
        'renders $CircularProgressIndicator when status is initial',
        (tester) async {
          await tester.pumpWidget(buildSubject());
          await tester.pump();

          // Switch to Messages tab (default is Notifications).
          await tester.tap(find.text('Messages'));
          await tester.pump();

          expect(find.byType(CircularProgressIndicator), findsOneWidget);
        },
      );

      testWidgets(
        'renders $InboxEmptyState when status is error',
        (tester) async {
          await tester.pumpWidget(
            buildSubject(
              state: const ConversationListState(
                status: ConversationListStatus.error,
              ),
            ),
          );
          await tester.pump();

          // Switch to Messages tab (default is Notifications).
          await tester.tap(find.text('Messages'));
          await tester.pump();

          expect(find.byType(InboxEmptyState), findsOneWidget);
        },
      );

      testWidgets(
        'renders $InboxEmptyState when loaded with no conversations',
        (tester) async {
          await tester.pumpWidget(
            buildSubject(
              state: const ConversationListState(
                status: ConversationListStatus.loaded,
              ),
            ),
          );
          await tester.pump();

          // Switch to Messages tab (default is Notifications).
          await tester.tap(find.text('Messages'));
          await tester.pump();

          expect(find.byType(InboxEmptyState), findsOneWidget);
        },
      );

      testWidgets(
        'renders $ConversationTile when loaded with conversations',
        (tester) async {
          final conversation = DmConversation(
            id: 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
            participantPubkeys: const [currentPubkey, otherPubkey],
            isGroup: false,
            createdAt: nowUnix,
            lastMessageContent: 'Hello',
            lastMessageTimestamp: nowUnix,
          );

          await tester.pumpWidget(
            buildSubject(
              state: ConversationListState(
                status: ConversationListStatus.loaded,
                conversations: [conversation],
                hasMore: false,
              ),
            ),
          );
          await tester.pump();

          // Switch to Messages tab (default is Notifications).
          await tester.tap(find.text('Messages'));
          await tester.pumpAndSettle();

          expect(find.byType(ConversationTile), findsOneWidget);
        },
      );

      testWidgets(
        'renders $MessageRequestsBanner when request conversations exist',
        (tester) async {
          final request = DmConversation(
            id: 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
            participantPubkeys: const [currentPubkey, otherPubkey],
            isGroup: false,
            createdAt: nowUnix,
            lastMessageContent: 'Hey',
            lastMessageTimestamp: nowUnix,
          );

          await tester.pumpWidget(
            buildSubject(
              state: ConversationListState(
                status: ConversationListStatus.loaded,
                requestConversations: [request],
                hasMore: false,
              ),
            ),
          );
          await tester.pump();

          // Switch to Messages tab (default is Notifications).
          await tester.tap(find.text('Messages'));
          await tester.pump();

          expect(find.byType(MessageRequestsBanner), findsOneWidget);
        },
      );

      testWidgets(
        'renders $MessageRequestsBanner above conversations when both exist',
        (tester) async {
          final conversation = DmConversation(
            id: 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
            participantPubkeys: const [currentPubkey, otherPubkey],
            isGroup: false,
            createdAt: nowUnix,
            lastMessageContent: 'Hello',
            lastMessageTimestamp: nowUnix,
          );

          final request = DmConversation(
            id: 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
            participantPubkeys: const [currentPubkey, otherPubkey],
            isGroup: false,
            createdAt: nowUnix,
            lastMessageContent: 'Hey',
            lastMessageTimestamp: nowUnix,
          );

          await tester.pumpWidget(
            buildSubject(
              state: ConversationListState(
                status: ConversationListStatus.loaded,
                conversations: [conversation],
                requestConversations: [request],
                hasMore: false,
              ),
            ),
          );
          await tester.pump();

          // Switch to Messages tab (default is Notifications).
          await tester.tap(find.text('Messages'));
          await tester.pumpAndSettle();

          expect(find.byType(MessageRequestsBanner), findsOneWidget);
          expect(find.byType(ConversationTile), findsOneWidget);
        },
      );
    });

    group('navigation', () {
      testWidgets('calls push when a conversation is tapped', (
        tester,
      ) async {
        final conversation = DmConversation(
          id: 'conv123',
          participantPubkeys: const [currentPubkey, otherPubkey],
          isGroup: false,
          createdAt: nowUnix,
          lastMessageContent: 'Hello',
          lastMessageTimestamp: nowUnix,
        );

        await tester.pumpWidget(
          buildSubject(
            state: ConversationListState(
              status: ConversationListStatus.loaded,
              conversations: [conversation],
              hasMore: false,
            ),
          ),
        );
        await tester.pump();

        // Switch to Messages tab (default is Notifications).
        await tester.tap(find.text('Messages'));
        await tester.pumpAndSettle();

        when(
          () => mockGoRouter.push(
            any(),
            extra: any(named: 'extra'),
          ),
        ).thenAnswer((_) async => null);

        await tester.tap(find.byType(ConversationTile));
        await tester.pump();

        verify(
          () => mockGoRouter.push(
            ConversationPage.pathForId('conv123'),
            extra: [otherPubkey],
          ),
        ).called(1);
      });

      testWidgets('calls pushNamed to message requests when banner is tapped', (
        tester,
      ) async {
        final request = DmConversation(
          id: 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
          participantPubkeys: const [currentPubkey, otherPubkey],
          isGroup: false,
          createdAt: nowUnix,
          lastMessageContent: 'Hey',
          lastMessageTimestamp: nowUnix,
        );

        await tester.pumpWidget(
          buildSubject(
            state: ConversationListState(
              status: ConversationListStatus.loaded,
              requestConversations: [request],
              hasMore: false,
            ),
          ),
        );
        await tester.pump();

        // Switch to Messages tab (default is Notifications).
        await tester.tap(find.text('Messages'));
        await tester.pump();

        when(
          () => mockGoRouter.pushNamed(any()),
        ).thenAnswer((_) async => null);

        await tester.tap(find.byType(MessageRequestsBanner));
        await tester.pump();

        verify(
          () => mockGoRouter.pushNamed(MessageRequestsPage.routeName),
        ).called(1);
      });

      testWidgets('adds navigate event when user is tapped in following bar', (
        tester,
      ) async {
        // Mock MyFollowingBloc state to show one user BEFORE building the subject
        whenListen(
          mockFollowingBloc,
          Stream<MyFollowingState>.value(
            const MyFollowingState(
              status: MyFollowingStatus.success,
              followingPubkeys: ['user123'],
            ),
          ),
          initialState: const MyFollowingState(
            status: MyFollowingStatus.success,
            followingPubkeys: ['user123'],
          ),
        );

        await tester.pumpWidget(buildSubject());
        await tester.pump();

        // Switch to Messages tab (default is Notifications).
        await tester.tap(find.text('Messages'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // FollowingBar uses fetchUserProfileProvider for names.
        // The truncateNpub will be used if profile is not found.
        final truncatedNpub = NostrKeyUtils.truncateNpub('user123');

        expect(find.text(truncatedNpub), findsOneWidget);

        await tester.tap(find.text(truncatedNpub));
        await tester.pump();

        verify(
          () => mockBloc.add(const ConversationListNavigateToUser('user123')),
        ).called(1);
      });
    });
  });
}
