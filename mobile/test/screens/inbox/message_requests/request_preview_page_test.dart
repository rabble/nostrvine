// ABOUTME: Widget tests for RequestPreviewPage.
// ABOUTME: Verifies route constants and that it renders RequestPreviewView
// ABOUTME: with RequestPreviewCubit and MessageRequestActionsCubit provided.

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/official_accounts_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/screens/inbox/inbox_page.dart';
import 'package:openvine/screens/inbox/message_requests/request_preview_page.dart';
import 'package:openvine/screens/inbox/message_requests/request_preview_view.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/official_accounts_service.dart';

import '../../../helpers/go_router.dart';
import '../../../helpers/test_provider_overrides.dart';

class _MockDmRepository extends Mock implements DmRepository {}

class _MockAuthService extends Mock implements AuthService {}

class _MockOfficials extends Mock implements OfficialAccountsService {}

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
    late _MockOfficials mockOfficials;

    setUp(() {
      mockDmRepository = _MockDmRepository();
      mockAuthService = _MockAuthService();
      mockGoRouter = MockGoRouter();
      mockOfficials = _MockOfficials();

      when(() => mockDmRepository.userPubkey).thenReturn(testPubkey);
      when(
        () => mockDmRepository.countMessagesInConversation(any()),
      ).thenAnswer((_) async => 3);
      when(
        () => mockDmRepository.getMessages(any(), limit: any(named: 'limit')),
      ).thenAnswer((_) async => const []);
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
              isDmRestrictedProvider.overrideWithValue(false),
              officialAccountsServiceProvider.overrideWithValue(mockOfficials),
            ],
          ),
        );
        await tester.pump();

        expect(find.byType(RequestPreviewView), findsOneWidget);
      });
    });

    group('protected-minor gate (#176)', () {
      testWidgets(
        'a DM-restricted user with a non-approved counterparty is bounced '
        'to the inbox before any request data renders',
        (tester) async {
          when(
            () => mockOfficials.isApprovedMinorDmRecipientSync(any()),
          ).thenReturn(false);

          await tester.pumpWidget(
            testMaterialApp(
              home: MockGoRouterProvider(
                goRouter: mockGoRouter,
                child: const RequestPreviewPage(
                  conversationId: conversationId,
                  participantPubkeys: [otherPubkey],
                ),
              ),
              mockAuthService: mockAuthService,
              additionalOverrides: [
                dmRepositoryProvider.overrideWithValue(mockDmRepository),
                goRouterProvider.overrideWithValue(mockGoRouter),
                isDmRestrictedProvider.overrideWithValue(true),
                officialAccountsServiceProvider.overrideWithValue(
                  mockOfficials,
                ),
              ],
            ),
          );
          await tester.pump();

          verify(() => mockGoRouter.go(InboxPage.path)).called(1);
          // No hidden request metadata was read for the denied preview.
          verifyNever(
            () => mockDmRepository.countMessagesInConversation(any()),
          );
        },
      );

      testWidgets(
        'a DM-restricted user landing via direct link (no route extras) is '
        'bounced to the inbox without the conversation being read',
        (tester) async {
          when(
            () => mockOfficials.isApprovedMinorDmRecipientSync(any()),
          ).thenReturn(true);

          await tester.pumpWidget(
            testMaterialApp(
              home: MockGoRouterProvider(
                goRouter: mockGoRouter,
                child: const RequestPreviewPage(
                  conversationId: conversationId,
                ),
              ),
              mockAuthService: mockAuthService,
              additionalOverrides: [
                dmRepositoryProvider.overrideWithValue(mockDmRepository),
                goRouterProvider.overrideWithValue(mockGoRouter),
                isDmRestrictedProvider.overrideWithValue(true),
                officialAccountsServiceProvider.overrideWithValue(
                  mockOfficials,
                ),
              ],
            ),
          );
          await tester.pump();

          verify(() => mockGoRouter.go(InboxPage.path)).called(1);
          // Resolving counterparties from the DB is itself a hidden-data
          // read, so the denied direct-link path must not touch the repo.
          verifyNever(() => mockDmRepository.getConversation(any()));
          verifyNever(
            () => mockDmRepository.countMessagesInConversation(any()),
          );
          verifyNever(
            () => mockDmRepository.getMessages(
              any(),
              limit: any(named: 'limit'),
            ),
          );
        },
      );

      testWidgets(
        'a DM-restricted user with an approved counterparty sees the preview',
        (tester) async {
          when(
            () => mockOfficials.isApprovedMinorDmRecipientSync(otherPubkey),
          ).thenReturn(true);

          await tester.pumpWidget(
            testMaterialApp(
              home: MockGoRouterProvider(
                goRouter: mockGoRouter,
                child: const RequestPreviewPage(
                  conversationId: conversationId,
                  participantPubkeys: [otherPubkey],
                ),
              ),
              mockAuthService: mockAuthService,
              additionalOverrides: [
                dmRepositoryProvider.overrideWithValue(mockDmRepository),
                goRouterProvider.overrideWithValue(mockGoRouter),
                isDmRestrictedProvider.overrideWithValue(true),
                officialAccountsServiceProvider.overrideWithValue(
                  mockOfficials,
                ),
              ],
            ),
          );
          await tester.pump();

          expect(find.byType(RequestPreviewView), findsOneWidget);
          verifyNever(() => mockGoRouter.go(any()));
        },
      );
    });
  });
}
