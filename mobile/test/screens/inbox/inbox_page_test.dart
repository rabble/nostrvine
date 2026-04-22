// ABOUTME: Widget tests for InboxPage, verifying BLoC setup and route constants.
// ABOUTME: Ensures InboxPage provides ConversationListBloc, DmUnreadCountCubit,
// ABOUTME: and MyFollowingBloc to InboxView via MultiBlocProvider.

import 'package:bloc_test/bloc_test.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/invite_status/invite_status_cubit.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/relay_notifications_provider.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/screens/inbox/inbox_page.dart';
import 'package:openvine/screens/inbox/inbox_view.dart';
import 'package:openvine/services/auth_service.dart';

import '../../helpers/go_router.dart';
import '../../helpers/test_provider_overrides.dart';

class _MockDmRepository extends Mock implements DmRepository {}

class _MockAuthService extends Mock implements AuthService {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _MockInviteStatusCubit extends MockCubit<InviteStatusState>
    implements InviteStatusCubit {}

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

void main() {
  const testPubkey =
      'aabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccdd';

  group(InboxPage, () {
    late _MockDmRepository mockDmRepository;
    late _MockAuthService mockAuthService;
    late _MockFollowRepository mockFollowRepository;
    late _MockContentBlocklistRepository mockBlocklistRepository;
    late MockGoRouter mockGoRouter;
    late _MockInviteStatusCubit mockInviteCubit;

    setUp(() {
      mockDmRepository = _MockDmRepository();
      mockAuthService = _MockAuthService();
      mockFollowRepository = _MockFollowRepository();
      mockBlocklistRepository = _MockContentBlocklistRepository();
      mockGoRouter = MockGoRouter();
      mockInviteCubit = _MockInviteStatusCubit();
      when(() => mockInviteCubit.state).thenReturn(const InviteStatusState());
      when(mockInviteCubit.load).thenAnswer((_) async {});

      when(
        () => mockDmRepository.watchAcceptedConversations(
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) => Stream.value(const []));
      when(
        () => mockDmRepository.watchPotentialRequests(),
      ).thenAnswer((_) => Stream.value(const []));
      when(
        () => mockDmRepository.watchUnreadAcceptedCount(),
      ).thenAnswer((_) => Stream.value(0));
      when(() => mockDmRepository.userPubkey).thenReturn(testPubkey);

      when(() => mockAuthService.currentPublicKeyHex).thenReturn(testPubkey);
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.authState).thenReturn(AuthState.authenticated);
      when(
        () => mockAuthService.authStateStream,
      ).thenAnswer((_) => const Stream<AuthState>.empty());

      when(() => mockFollowRepository.followingPubkeys).thenReturn(const []);
      when(
        () => mockFollowRepository.followingStream,
      ).thenAnswer((_) => const Stream.empty());

      when(
        () => mockBlocklistRepository.isBlocked(any()),
      ).thenReturn(false);

      when(() => mockDmRepository.startListening()).thenAnswer((_) async {});
      when(
        () => mockDmRepository.stopListening(),
      ).thenAnswer((_) async {});
    });

    test('has correct route constants', () {
      expect(InboxPage.routeName, equals('inbox'));
      expect(InboxPage.path, equals('/inbox'));
    });

    group('dm subscription lifecycle', () {
      testWidgets(
        'does not start or stop the subscription — auth-scoped (#2931)',
        (tester) async {
          await tester.pumpWidget(
            testMaterialApp(
              home: BlocProvider<InviteStatusCubit>.value(
                value: mockInviteCubit,
                child: const InboxPage(),
              ),
              mockAuthService: mockAuthService,
              additionalOverrides: [
                dmRepositoryProvider.overrideWithValue(mockDmRepository),
                followRepositoryProvider.overrideWithValue(
                  mockFollowRepository,
                ),
                contentBlocklistRepositoryProvider.overrideWithValue(
                  mockBlocklistRepository,
                ),
                goRouterProvider.overrideWithValue(mockGoRouter),
                relayNotificationUnreadCountProvider.overrideWithValue(0),
                relayNotificationsProvider.overrideWith(
                  _MockRelayNotifications.new,
                ),
              ],
            ),
          );
          await tester.pump();

          // Regression guard for #2931: the gift-wrap subscription is owned
          // by `dmRepositoryProvider` for the entire authenticated session,
          // not by this screen. Mounting and unmounting the inbox must NOT
          // touch the subscription lifecycle, otherwise users who never
          // open the inbox would never receive DMs.
          verifyNever(() => mockDmRepository.startListening());
          verifyNever(() => mockDmRepository.stopListening());

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();

          verifyNever(() => mockDmRepository.startListening());
          verifyNever(() => mockDmRepository.stopListening());
        },
      );
    });

    group('renders', () {
      testWidgets('renders $InboxView', (tester) async {
        await tester.pumpWidget(
          testMaterialApp(
            home: BlocProvider<InviteStatusCubit>.value(
              value: mockInviteCubit,
              child: const InboxPage(),
            ),
            mockAuthService: mockAuthService,
            additionalOverrides: [
              dmRepositoryProvider.overrideWithValue(mockDmRepository),
              followRepositoryProvider.overrideWithValue(mockFollowRepository),
              contentBlocklistRepositoryProvider.overrideWithValue(
                mockBlocklistRepository,
              ),
              goRouterProvider.overrideWithValue(mockGoRouter),
              relayNotificationUnreadCountProvider.overrideWithValue(0),
              relayNotificationsProvider.overrideWith(
                _MockRelayNotifications.new,
              ),
            ],
          ),
        );
        await tester.pump();

        expect(find.byType(InboxView), findsOneWidget);
      });
    });
  });
}
