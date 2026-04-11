// ABOUTME: Widget tests for MessageRequestsPage.
// ABOUTME: Verifies route constants and that it renders MessageRequestsView
// ABOUTME: with ConversationListBloc and MessageRequestActionsCubit provided.

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/repositories/follow_repository.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/screens/inbox/message_requests/message_requests_page.dart';
import 'package:openvine/screens/inbox/message_requests/message_requests_view.dart';
import 'package:openvine/services/auth_service.dart';

import '../../../helpers/go_router.dart';
import '../../../helpers/test_provider_overrides.dart';

class _MockDmRepository extends Mock implements DmRepository {}

class _MockAuthService extends Mock implements AuthService {}

class _MockFollowRepository extends Mock implements FollowRepository {}

void main() {
  const testPubkey =
      'aabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccdd';

  group(MessageRequestsPage, () {
    late _MockDmRepository mockDmRepository;
    late _MockAuthService mockAuthService;
    late _MockFollowRepository mockFollowRepository;
    late MockGoRouter mockGoRouter;

    setUp(() {
      mockDmRepository = _MockDmRepository();
      mockAuthService = _MockAuthService();
      mockFollowRepository = _MockFollowRepository();
      mockGoRouter = MockGoRouter();

      when(
        () => mockDmRepository.watchAcceptedConversations(
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) => Stream.value(const []));
      when(
        () => mockDmRepository.watchPotentialRequests(),
      ).thenAnswer((_) => Stream.value(const []));
      when(() => mockDmRepository.userPubkey).thenReturn(testPubkey);
      when(() => mockDmRepository.startListening()).thenAnswer((_) async {});
      when(() => mockDmRepository.stopListening()).thenAnswer((_) async {});

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
    });

    test('has correct route constants', () {
      expect(MessageRequestsPage.routeName, equals('messageRequests'));
      expect(MessageRequestsPage.path, equals('/inbox/message-requests'));
    });

    group('renders', () {
      testWidgets('renders $MessageRequestsView', (tester) async {
        await tester.pumpWidget(
          testMaterialApp(
            home: const MessageRequestsPage(),
            mockAuthService: mockAuthService,
            additionalOverrides: [
              dmRepositoryProvider.overrideWithValue(mockDmRepository),
              followRepositoryProvider.overrideWithValue(mockFollowRepository),
              goRouterProvider.overrideWithValue(mockGoRouter),
            ],
          ),
        );
        await tester.pump();

        expect(find.byType(MessageRequestsView), findsOneWidget);
      });
    });
  });
}
