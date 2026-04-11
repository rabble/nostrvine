// ABOUTME: Widget tests for RequestPreviewPage.
// ABOUTME: Verifies route constants and that it renders RequestPreviewView
// ABOUTME: with RequestPreviewCubit and MessageRequestActionsCubit provided.

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/screens/inbox/message_requests/request_preview_page.dart';
import 'package:openvine/screens/inbox/message_requests/request_preview_view.dart';
import 'package:openvine/services/auth_service.dart';

import '../../../helpers/go_router.dart';
import '../../../helpers/test_provider_overrides.dart';

class _MockDmRepository extends Mock implements DmRepository {}

class _MockAuthService extends Mock implements AuthService {}

void main() {
  const testPubkey =
      'aabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccdd';
  const otherPubkey =
      '1122334411223344112233441122334411223344112233441122334411223344';
  const conversationId =
      'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

  group(RequestPreviewPage, () {
    late _MockDmRepository mockDmRepository;
    late _MockAuthService mockAuthService;
    late MockGoRouter mockGoRouter;

    setUp(() {
      mockDmRepository = _MockDmRepository();
      mockAuthService = _MockAuthService();
      mockGoRouter = MockGoRouter();

      when(() => mockDmRepository.userPubkey).thenReturn(testPubkey);
      when(
        () => mockDmRepository.countMessagesInConversation(any()),
      ).thenAnswer((_) async => 3);
      when(
        () => mockDmRepository.getConversation(any()),
      ).thenAnswer((_) async => null);

      when(() => mockAuthService.currentPublicKeyHex).thenReturn(testPubkey);
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.authState).thenReturn(AuthState.authenticated);
      when(
        () => mockAuthService.authStateStream,
      ).thenAnswer((_) => const Stream<AuthState>.empty());
    });

    test('has correct route constants', () {
      expect(RequestPreviewPage.routeName, equals('requestPreview'));
      expect(
        RequestPreviewPage.pathPattern,
        equals('/inbox/message-requests/:id'),
      );
    });

    group('renders', () {
      testWidgets('renders $RequestPreviewView', (tester) async {
        await tester.pumpWidget(
          testMaterialApp(
            home: const RequestPreviewPage(
              conversationId: conversationId,
              participantPubkeys: [otherPubkey],
            ),
            mockAuthService: mockAuthService,
            additionalOverrides: [
              dmRepositoryProvider.overrideWithValue(mockDmRepository),
              goRouterProvider.overrideWithValue(mockGoRouter),
            ],
          ),
        );
        await tester.pump();

        expect(find.byType(RequestPreviewView), findsOneWidget);
      });
    });
  });
}
