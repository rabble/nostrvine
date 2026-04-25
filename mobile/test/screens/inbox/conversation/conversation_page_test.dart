// ABOUTME: Widget tests for ConversationPage, verifying BLoC setup and
// ABOUTME: route constants. Ensures ConversationPage provides ConversationBloc
// ABOUTME: to ConversationView via BlocProvider.

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/inbox/conversation/conversation_page.dart';
import 'package:openvine/screens/inbox/conversation/conversation_view.dart';
import 'package:openvine/services/auth_service.dart';

import '../../../helpers/test_provider_overrides.dart';

class _MockDmRepository extends Mock implements DmRepository {}

class _MockAuthService extends Mock implements AuthService {}

void main() {
  const testPubkey =
      'aabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccdd';
  const otherPubkey =
      '1122334455667788112233445566778811223344556677881122334455667788';
  const testConversationId =
      'ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00';

  group(ConversationPage, () {
    late _MockDmRepository mockDmRepository;
    late _MockAuthService mockAuthService;

    setUp(() {
      mockDmRepository = _MockDmRepository();
      mockAuthService = _MockAuthService();

      when(
        () => mockDmRepository.markConversationAsRead(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockDmRepository.watchMessages(any()),
      ).thenAnswer((_) => Stream.value(const []));

      when(() => mockAuthService.currentPublicKeyHex).thenReturn(testPubkey);
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.authState).thenReturn(AuthState.authenticated);
      when(
        () => mockAuthService.authStateStream,
      ).thenAnswer((_) => const Stream<AuthState>.empty());
    });

    test('has correct route constants', () {
      expect(ConversationPage.routeName, equals('conversation'));
      expect(ConversationPage.pathPattern, equals('/inbox/conversation/:id'));
      expect(
        ConversationPage.pathForId('abc'),
        equals('/inbox/conversation/abc'),
      );
    });

    group('renders', () {
      testWidgets('renders $ConversationView', (tester) async {
        await tester.pumpWidget(
          testMaterialApp(
            home: const ConversationPage(
              conversationId: testConversationId,
              participantPubkeys: [otherPubkey],
            ),
            mockAuthService: mockAuthService,
            additionalOverrides: [
              dmRepositoryProvider.overrideWithValue(mockDmRepository),
              fetchUserProfileProvider(
                otherPubkey,
              ).overrideWith((ref) async => null),
            ],
          ),
        );
        await tester.pump();

        expect(find.byType(ConversationView), findsOneWidget);
      });
    });
  });
}
