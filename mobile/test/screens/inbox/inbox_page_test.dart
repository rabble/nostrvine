// ABOUTME: Widget tests for InboxPage, verifying BLoC setup and route constants.
// ABOUTME: Ensures InboxPage provides ConversationListBloc, DmUnreadCountCubit,
// ABOUTME: and MyFollowingBloc to InboxView via MultiBlocProvider.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/relay_notifications_provider.dart';
import 'package:openvine/repositories/dm_repository.dart';
import 'package:openvine/repositories/follow_repository.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/screens/inbox/inbox_page.dart';
import 'package:openvine/screens/inbox/inbox_view.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/content_blocklist_service.dart';

import '../../helpers/go_router.dart';
import '../../helpers/test_provider_overrides.dart';

class _MockDmRepository extends Mock implements DmRepository {}

class _MockAuthService extends Mock implements AuthService {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockContentBlocklistService extends Mock
    implements ContentBlocklistService {}

void main() {
  const testPubkey =
      'aabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccdd';

  group(InboxPage, () {
    late _MockDmRepository mockDmRepository;
    late _MockAuthService mockAuthService;
    late _MockFollowRepository mockFollowRepository;
    late _MockContentBlocklistService mockBlocklistService;
    late MockGoRouter mockGoRouter;

    setUp(() {
      mockDmRepository = _MockDmRepository();
      mockAuthService = _MockAuthService();
      mockFollowRepository = _MockFollowRepository();
      mockBlocklistService = _MockContentBlocklistService();
      mockGoRouter = MockGoRouter();

      when(
        () => mockDmRepository.watchConversations(limit: any(named: 'limit')),
      ).thenAnswer((_) => Stream.value(const []));
      when(
        () => mockDmRepository.watchUnreadCount(),
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
        () => mockBlocklistService.isBlocked(any()),
      ).thenReturn(false);
    });

    test('has correct route constants', () {
      expect(InboxPage.routeName, equals('inbox'));
      expect(InboxPage.path, equals('/inbox'));
    });

    group('renders', () {
      testWidgets('renders $InboxView', (tester) async {
        await tester.pumpWidget(
          testMaterialApp(
            home: const InboxPage(),
            mockAuthService: mockAuthService,
            additionalOverrides: [
              dmRepositoryProvider.overrideWithValue(mockDmRepository),
              followRepositoryProvider.overrideWithValue(mockFollowRepository),
              contentBlocklistServiceProvider.overrideWithValue(
                mockBlocklistService,
              ),
              goRouterProvider.overrideWithValue(mockGoRouter),
              relayNotificationUnreadCountProvider.overrideWithValue(0),
            ],
          ),
        );
        await tester.pump();

        expect(find.byType(InboxView), findsOneWidget);
      });
    });
  });
}
