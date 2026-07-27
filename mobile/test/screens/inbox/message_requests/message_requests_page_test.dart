// ABOUTME: Widget tests for MessageRequestsPage.
// ABOUTME: Verifies route constants and that it renders MessageRequestsView
// ABOUTME: with ConversationListBloc and MessageRequestActionsCubit provided.

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/conversation_list/conversation_list_bloc.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/screens/inbox/message_requests/message_requests_page.dart';
import 'package:openvine/screens/inbox/message_requests/message_requests_view.dart';
import 'package:openvine/screens/inbox/message_requests/widgets/request_tile.dart';
import 'package:openvine/services/auth_service.dart';

import '../../../helpers/go_router.dart';
import '../../../helpers/test_provider_overrides.dart';

class _MockDmRepository extends Mock implements DmRepository {}

class _MockAuthService extends Mock implements AuthService {}

class _MockFollowRepository extends Mock implements FollowRepository {}

/// Flip to force `dmRepositoryProvider` to hand over a different DmRepository
/// instance — mirrors the keepAlive provider rebuilding a fresh repository as
/// the nostr session advances identityKnown -> nostrReady.
final _dmRepoSwap = StateProvider<int>((ref) => 0);

void main() {
  const testPubkey =
      'aabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccdd';
  const strangerPubkey =
      '1122334411223344112233441122334411223344112233441122334411223344';

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
      when(() => mockDmRepository.isRecoveringHistory).thenReturn(false);
      when(
        () => mockDmRepository.historyRecoveryStream,
      ).thenAnswer((_) => const Stream<bool>.empty());
      // Recovery-aware request gate (#5304): recovery complete so the normal
      // accepted/request split applies.
      when(
        () => mockDmRepository.isHistoryRecoveryComplete,
      ).thenReturn(true);
      when(() => mockDmRepository.userPubkey).thenReturn(testPubkey);
      // Identity stream (#5374): ConversationListBloc subscribes to it via
      // `.startWith(userPubkey)`; an empty stream suffices for the seed.
      when(
        () => mockDmRepository.userPubkeyStream,
      ).thenAnswer((_) => const Stream<String>.empty());
      when(() => mockDmRepository.startListening()).thenAnswer((_) async {});
      when(() => mockDmRepository.stopListening()).thenAnswer((_) async {});
      when(
        () => mockDmRepository.backfillHistoryIfNeeded(),
      ).thenAnswer((_) async {});
      when(
        () => mockDmRepository.retryPendingDecryptions(),
      ).thenAnswer((_) async {});

      when(() => mockAuthService.currentPublicKeyHex).thenReturn(testPubkey);
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.authState).thenReturn(AuthState.authenticated);
      when(
        () => mockAuthService.authStateStream,
      ).thenAnswer((_) => const Stream<AuthState>.empty());
      // Read by isDmRestrictedProvider once the protected-minor gate actually
      // filters something — i.e. as soon as the request list is non-empty.
      when(
        () => mockAuthService.authenticationSource,
      ).thenReturn(AuthenticationSource.importedKeys);

      when(() => mockFollowRepository.followingPubkeys).thenReturn(const []);
      when(
        () => mockFollowRepository.followingStream,
      ).thenAnswer((_) => const Stream.empty());
      // Nobody is followed, so an unreplied conversation classifies as a
      // request — which is what this page renders.
      when(() => mockFollowRepository.isFollowing(any())).thenReturn(false);
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
            mockFollowRepository: mockFollowRepository,
            additionalOverrides: [
              dmRepositoryProvider.overrideWithValue(mockDmRepository),
              goRouterProvider.overrideWithValue(mockGoRouter),
            ],
          ),
        );
        await tester.pump();

        expect(find.byType(MessageRequestsView), findsOneWidget);
      });

      // This page builds its OWN ConversationListBloc. Without the support-row
      // wiring the moderation thread stays here while the inbox lifts it into
      // the pinned row — same thread on two surfaces, and the inbox's request
      // banner counts one fewer than this page lists (#6388 review).
      testWidgets(
        'does not list the moderation thread among message requests',
        (tester) async {
          final supportId = DmRepository.computeConversationId([
            testPubkey,
            kModerationPubkeyHex,
          ]);
          when(mockDmRepository.watchPotentialRequests).thenAnswer(
            (_) => Stream.value([
              DmConversation(
                id: supportId,
                participantPubkeys: const [testPubkey, kModerationPubkeyHex],
                isGroup: false,
                createdAt: 1700000000,
                lastMessageTimestamp: 1700000000,
                isRead: false,
              ),
              DmConversation(
                id: 'stranger-request',
                participantPubkeys: const [testPubkey, strangerPubkey],
                isGroup: false,
                createdAt: 1700000100,
                lastMessageTimestamp: 1700000100,
                isRead: false,
              ),
            ]),
          );

          await tester.pumpWidget(
            testMaterialApp(
              home: const MessageRequestsPage(),
              mockAuthService: mockAuthService,
              mockFollowRepository: mockFollowRepository,
              additionalOverrides: [
                dmRepositoryProvider.overrideWithValue(mockDmRepository),
                goRouterProvider.overrideWithValue(mockGoRouter),
              ],
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          expect(find.byType(RequestTile), findsOneWidget);
        },
      );
    });

    // Same defect as InboxPage: the keepAlive `dmRepositoryProvider` rebuilds a
    // fresh DmRepository on the identityKnown -> nostrReady transition, and only
    // the ready instance's userPubkeyStream ever delivers a pubkey. A keyless
    // BlocProvider strands the requests list on the orphaned not-ready repo.
    // Pins the ValueKey rebind fix in message_requests_page.dart.
    testWidgets(
      'recreates ConversationListBloc when dmRepositoryProvider hands over '
      'the ready instance',
      (tester) async {
        final notReadyRepo = _MockDmRepository();
        when(
          () => notReadyRepo.watchAcceptedConversations(
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) => Stream.value(const []));
        when(
          notReadyRepo.watchPotentialRequests,
        ).thenAnswer((_) => Stream.value(const []));
        when(() => notReadyRepo.isRecoveringHistory).thenReturn(false);
        when(
          () => notReadyRepo.historyRecoveryStream,
        ).thenAnswer((_) => const Stream<bool>.empty());
        when(() => notReadyRepo.isHistoryRecoveryComplete).thenReturn(true);
        when(() => notReadyRepo.userPubkey).thenReturn('');
        when(
          () => notReadyRepo.userPubkeyStream,
        ).thenAnswer((_) => const Stream<String>.empty());
        when(notReadyRepo.backfillHistoryIfNeeded).thenAnswer((_) async {});
        when(notReadyRepo.retryPendingDecryptions).thenAnswer((_) async {});

        await tester.pumpWidget(
          testMaterialApp(
            home: const MessageRequestsPage(),
            mockAuthService: mockAuthService,
            mockFollowRepository: mockFollowRepository,
            additionalOverrides: [
              // swap 0 -> not-ready instance, swap 1 -> ready (setUp mock).
              dmRepositoryProvider.overrideWith(
                (ref) => ref.watch(_dmRepoSwap) == 0
                    ? notReadyRepo
                    : mockDmRepository,
              ),
              goRouterProvider.overrideWithValue(mockGoRouter),
            ],
          ),
        );
        await tester.pump();

        final blocA = BlocProvider.of<ConversationListBloc>(
          tester.element(find.byType(MessageRequestsView)),
        );

        // Session advances identityKnown -> nostrReady: fresh ready repo.
        ProviderScope.containerOf(
          tester.element(find.byType(MessageRequestsPage)),
          listen: false,
        ).read(_dmRepoSwap.notifier).state = 1;
        await tester.pump();

        expect(
          BlocProvider.of<ConversationListBloc>(
            tester.element(find.byType(MessageRequestsView)),
          ),
          isNot(same(blocA)),
          reason:
              'a keyless BlocProvider strands the requests list on the '
              'orphaned not-ready DmRepository; the ValueKey must rebuild it '
              'bound to the ready instance',
        );
      },
    );
  });
}
