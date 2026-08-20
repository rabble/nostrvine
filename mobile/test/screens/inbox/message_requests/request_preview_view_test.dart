// ABOUTME: Widget tests for RequestPreviewView.
// ABOUTME: Verifies rendering of profile info, action buttons, message count,
// ABOUTME: and navigation to profile view, conversation, and decline action.

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/conversation/collaborator_invite_actions_cubit.dart';
import 'package:openvine/blocs/dm/message_requests/message_request_actions_cubit.dart';
import 'package:openvine/blocs/dm/message_requests/request_preview_cubit.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/collaborator_invite.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/screens/inbox/conversation/conversation_page.dart';
import 'package:openvine/screens/inbox/inbox_page.dart';
import 'package:openvine/screens/inbox/message_requests/request_preview_view.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/widgets/user_avatar.dart';
import 'package:videos_repository/videos_repository.dart';

import '../../../helpers/go_router.dart';
import '../../../helpers/test_provider_overrides.dart';

class _MockMessageRequestActionsCubit
    extends MockCubit<MessageRequestActionsState>
    implements MessageRequestActionsCubit {}

class _MockRequestPreviewCubit extends MockCubit<RequestPreviewState>
    implements RequestPreviewCubit {}

class _MockCollaboratorInviteActionsCubit
    extends MockCubit<CollaboratorInviteActionsState>
    implements CollaboratorInviteActionsCubit {}

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockAuthService extends MockAuthService {
  _MockAuthService(this._pubkey) {
    when(() => authState).thenReturn(AuthState.authenticated);
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
  const conversationId =
      'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
  const fallbackInvite = CollaboratorInvite(
    messageId:
        'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
    videoAddress:
        '34236:1122334411223344112233441122334411223344112233441122334411223344:skate-loop',
    videoKind: 34236,
    creatorPubkey: otherPubkey,
    videoDTag: 'skate-loop',
    role: 'Collaborator',
  );
  final l10n = lookupAppLocalizations(const Locale('en'));

  group(RequestPreviewView, () {
    late _MockMessageRequestActionsCubit mockActionsCubit;
    late _MockRequestPreviewCubit mockPreviewCubit;
    late _MockCollaboratorInviteActionsCubit mockInviteActionsCubit;
    late _MockVideosRepository mockVideosRepository;
    late MockNostrClient mockNostrClient;
    late _MockAuthService mockAuthService;
    late MockGoRouter mockGoRouter;
    late UserProfile testProfile;

    setUpAll(() {
      registerFallbackValue(fallbackInvite);
      registerFallbackValue(<String>[]);
    });

    setUp(() {
      mockActionsCubit = _MockMessageRequestActionsCubit();
      mockPreviewCubit = _MockRequestPreviewCubit();
      mockInviteActionsCubit = _MockCollaboratorInviteActionsCubit();
      mockVideosRepository = _MockVideosRepository();
      mockNostrClient = createMockNostrService();
      mockAuthService = _MockAuthService(currentPubkey);
      mockGoRouter = MockGoRouter();

      // Default to the settled success status: the action buttons read this
      // after awaiting to decide whether to confirm-and-pop or surface an
      // error. Individual tests override it for the error / in-flight paths.
      when(() => mockActionsCubit.state).thenReturn(
        const MessageRequestActionsState(
          status: MessageRequestActionsStatus.success,
        ),
      );

      when(() => mockPreviewCubit.state).thenReturn(
        const RequestPreviewState(
          status: RequestPreviewStatus.loaded,
          messageCount: 3,
          participantPubkeys: [otherPubkey],
        ),
      );

      when(() => mockPreviewCubit.conversationId).thenReturn(conversationId);
      when(
        () => mockInviteActionsCubit.state,
      ).thenReturn(const CollaboratorInviteActionsState());
      when(
        () => mockInviteActionsCubit.acceptInvite(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockInviteActionsCubit.ignoreInvite(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockVideosRepository.fetchVideoWithStatsForRouteId(
          any(),
          fallbackRouteIds: any(named: 'fallbackRouteIds'),
        ),
      ).thenAnswer((_) async => null);

      testProfile = UserProfile(
        pubkey: otherPubkey,
        displayName: 'TestUser',
        rawData: const {},
        createdAt: DateTime.now(),
        eventId:
            'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
      );
    });

    Widget buildSubject({RequestPreviewState? previewState}) {
      if (previewState != null) {
        when(() => mockPreviewCubit.state).thenReturn(previewState);
      }

      return testMaterialApp(
        mockAuthService: mockAuthService,
        mockNostrService: mockNostrClient,
        additionalOverrides: [
          goRouterProvider.overrideWithValue(mockGoRouter),
          videosRepositoryProvider.overrideWithValue(mockVideosRepository),
          userProfileReactiveProvider(
            otherPubkey,
          ).overrideWith((ref) => Stream.value(testProfile)),
        ],
        home: MockGoRouterProvider(
          goRouter: mockGoRouter,
          child: MultiBlocProvider(
            providers: [
              BlocProvider<RequestPreviewCubit>.value(value: mockPreviewCubit),
              BlocProvider<MessageRequestActionsCubit>.value(
                value: mockActionsCubit,
              ),
              BlocProvider<CollaboratorInviteActionsCubit>.value(
                value: mockInviteActionsCubit,
              ),
            ],
            child: const RequestPreviewView(),
          ),
        ),
      );
    }

    // #6416. This screen is where an inbound-first moderation notice is first
    // seen, and it offered "Decline and remove" against an unidentified
    // "Adjective Animal N" — moderation recognition never reached the requests
    // flow, and neither moderation key has a kind-0 the app can read.
    group('moderation identity', () {
      Widget buildModerationSubject(String counterparty) {
        when(() => mockPreviewCubit.state).thenReturn(
          RequestPreviewState(
            status: RequestPreviewStatus.loaded,
            messageCount: 1,
            participantPubkeys: [counterparty],
          ),
        );

        return testMaterialApp(
          mockAuthService: mockAuthService,
          mockNostrService: mockNostrClient,
          additionalOverrides: [
            goRouterProvider.overrideWithValue(mockGoRouter),
            videosRepositoryProvider.overrideWithValue(mockVideosRepository),
            userProfileReactiveProvider(
              counterparty,
            ).overrideWith((ref) => Stream.value(null)),
          ],
          home: MockGoRouterProvider(
            goRouter: mockGoRouter,
            child: MultiBlocProvider(
              providers: [
                BlocProvider<RequestPreviewCubit>.value(
                  value: mockPreviewCubit,
                ),
                BlocProvider<MessageRequestActionsCubit>.value(
                  value: mockActionsCubit,
                ),
                BlocProvider<CollaboratorInviteActionsCubit>.value(
                  value: mockInviteActionsCubit,
                ),
              ],
              child: const RequestPreviewView(),
            ),
          ),
        );
      }

      testWidgets('a retired moderation request identifies itself as Divine', (
        tester,
      ) async {
        final retired = kLegacyModerationPubkeys.first;

        await tester.pumpWidget(buildModerationSubject(retired));
        await tester.pumpAndSettle();

        // Header, the name under the avatar, and the "wants to message you"
        // sentence all read from the same resolved name.
        expect(find.text(l10n.inboxSupportRowTitle), findsWidgets);
        expect(
          find.textContaining(UserProfile.defaultDisplayNameFor(retired)),
          findsNothing,
        );
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is DivineIcon && widget.icon == DivineIconName.logo,
            description: 'bundled Divine wordmark',
          ),
          findsOneWidget,
        );
      });

      testWidgets('an ordinary request is untouched', (tester) async {
        await tester.pumpWidget(buildModerationSubject(otherPubkey));
        await tester.pumpAndSettle();

        expect(
          find.text(UserProfile.defaultDisplayNameFor(otherPubkey)),
          findsWidgets,
        );
        expect(find.text(l10n.inboxSupportRowTitle), findsNothing);
      });
    });

    group('renders', () {
      testWidgets('renders app bar with display name as title', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        expect(find.text('TestUser'), findsWidgets);
      });

      testWidgets('renders $UserAvatar', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        expect(find.byType(UserAvatar), findsOneWidget);
      });

      testWidgets('renders "View profile" button', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        expect(find.text('View profile'), findsOneWidget);
      });

      testWidgets('renders "View messages" button', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        expect(find.text('View messages'), findsOneWidget);
      });

      testWidgets('renders "Decline and remove" button', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        expect(find.text('Decline and remove'), findsOneWidget);
      });

      testWidgets('renders "Block" button', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        expect(find.text(l10n.messageRequestBlockButton), findsOneWidget);
      });

      testWidgets('renders message count description', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        expect(find.textContaining('3 messages'), findsOneWidget);
      });

      testWidgets('renders collaborator invite actions without plaintext', (
        tester,
      ) async {
        const inviteMessage = DmMessage(
          id: 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
          conversationId: conversationId,
          senderPubkey: otherPubkey,
          content: 'You were invited to collaborate.',
          createdAt: 1700000000,
          giftWrapId:
              'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
          tags: [
            ['divine', 'collab-invite'],
            [
              'a',
              '34236:1122334411223344112233441122334411223344112233441122334411223344:skate-loop',
              'wss://relay.divine.video',
            ],
            ['p', otherPubkey],
            ['role', 'Collaborator'],
            ['title', 'Skate loop'],
            ['thumb', 'https://cdn.divine.video/thumbs/skate-loop.jpg'],
          ],
        );

        await tester.pumpWidget(
          buildSubject(
            previewState: const RequestPreviewState(
              status: RequestPreviewStatus.loaded,
              messageCount: 1,
              participantPubkeys: [otherPubkey],
              messages: [inviteMessage],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(l10n.inboxCollabInvitePreviewTitleFrom('TestUser')),
          findsOneWidget,
        );
        expect(find.text('Skate loop'), findsOneWidget);
        expect(find.text(l10n.inboxCollabInviteCoPostButton), findsOneWidget);
        expect(find.text(l10n.inboxCollabInviteNotMineButton), findsOneWidget);
        expect(
          find.byKey(const ValueKey('collaborator_invite_thumbnail')),
          findsOneWidget,
        );
        expect(
          find.text(l10n.inboxCollabInviteTimelineConsequence),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(
            l10n.notificationsVideoThumbnailFor('Skate loop'),
          ),
          findsOneWidget,
        );
        expect(find.text('You were invited to collaborate.'), findsNothing);

        await tester.ensureVisible(
          find.text(l10n.inboxCollabInviteNotMineButton),
        );
        await tester.pump();
        await tester.tap(find.text(l10n.inboxCollabInviteNotMineButton));
        await tester.pump();

        verify(() => mockInviteActionsCubit.ignoreInvite(any())).called(1);
        verifyNever(() => mockActionsCubit.declineRequest(any()));
      });

      testWidgets('renders sent collaborator invite preview without actions', (
        tester,
      ) async {
        const inviteMessage = DmMessage(
          id: 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
          conversationId: conversationId,
          senderPubkey: currentPubkey,
          content: 'You were invited to collaborate.',
          createdAt: 1700000000,
          giftWrapId:
              'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
          tags: [
            ['divine', 'collab-invite'],
            [
              'a',
              '34236:aabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccdd:skate-loop',
              'wss://relay.divine.video',
            ],
            ['p', currentPubkey],
            ['role', 'Collaborator'],
            ['title', 'Skate loop'],
          ],
        );

        await tester.pumpWidget(
          buildSubject(
            previewState: const RequestPreviewState(
              status: RequestPreviewStatus.loaded,
              messageCount: 1,
              participantPubkeys: [otherPubkey],
              messages: [inviteMessage],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.inboxCollabInviteCardTitle), findsOneWidget);
        expect(find.text(l10n.inboxCollabInviteSentStatus), findsOneWidget);
        expect(find.text(l10n.inboxCollabInviteCoPostButton), findsNothing);
        expect(find.text(l10n.inboxCollabInviteNotMineButton), findsNothing);
      });
    });

    group('navigation', () {
      testWidgets('navigates to profile view when "View profile" tapped', (
        tester,
      ) async {
        when(() => mockGoRouter.push(any())).thenAnswer((_) async => null);

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await tester.tap(find.text('View profile'));
        await tester.pump();

        verify(
          () => mockGoRouter.push(any(that: startsWith('/profile-view/'))),
        ).called(1);
      });

      testWidgets('navigates to conversation when "View messages" tapped', (
        tester,
      ) async {
        when(
          () => mockGoRouter.pushReplacementNamed(
            any(),
            pathParameters: any(named: 'pathParameters'),
            extra: any(named: 'extra'),
          ),
        ).thenAnswer((_) async => null);

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await tester.tap(find.text('View messages'));
        await tester.pump();

        verify(
          () => mockGoRouter.pushReplacementNamed(
            ConversationPage.routeName,
            pathParameters: {'id': conversationId},
            extra: [otherPubkey],
          ),
        ).called(1);
      });

      testWidgets(
        'calls declineRequest and pops when "Decline and remove" tapped',
        (tester) async {
          when(
            () => mockActionsCubit.declineRequest(any()),
          ).thenAnswer((_) async => true);

          when(mockGoRouter.canPop).thenReturn(true);
          when(() => mockGoRouter.pop()).thenAnswer((_) async {});

          await tester.pumpWidget(buildSubject());
          await tester.pumpAndSettle();

          await tester.tap(find.text('Decline and remove'));
          await tester.pumpAndSettle();

          verify(
            () => mockActionsCubit.declineRequest(conversationId),
          ).called(1);

          verify(() => mockGoRouter.pop()).called(1);
        },
      );

      // The loaded state is deep-linkable too: `loading` is only the first
      // frame of that same cold entry, so both of its navigating affordances
      // meet the one-entry stack that plain `pop()` throws on (#6112).
      testWidgets('back from a cold loaded entry lands on the inbox', (
        tester,
      ) async {
        when(mockGoRouter.canPop).thenReturn(false);

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Back'));
        await tester.pump();

        verify(() => mockGoRouter.go(InboxPage.path)).called(1);
      });

      testWidgets('decline from a cold loaded entry lands on the inbox', (
        tester,
      ) async {
        when(
          () => mockActionsCubit.declineRequest(any()),
        ).thenAnswer((_) async => true);
        when(mockGoRouter.canPop).thenReturn(false);

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Decline and remove'));
        await tester.pumpAndSettle();

        verify(() => mockGoRouter.go(InboxPage.path)).called(1);
      });
    });

    group('block and decline feedback', () {
      // The screen's Block affordance opens a confirmation sheet; the sheet's
      // own Block button (a DivineButton, distinct from the screen's custom
      // action button) is what actually triggers the block.
      Future<void> tapBlockAndConfirm(WidgetTester tester) async {
        await tester.tap(find.text(l10n.messageRequestBlockButton));
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(DivineButton, l10n.messageRequestBlockButton),
        );
        await tester.pumpAndSettle();
      }

      testWidgets('Block opens a confirmation before blocking', (
        tester,
      ) async {
        when(
          () => mockActionsCubit.blockAndRemoveRequest(any(), any()),
        ).thenAnswer((_) async => true);

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await tester.tap(find.text(l10n.messageRequestBlockButton));
        await tester.pumpAndSettle();

        expect(
          find.text(l10n.profileBlockTitle('TestUser')),
          findsOneWidget,
        );
        expect(
          find.text(l10n.messageRequestBlockConfirmBody),
          findsOneWidget,
        );
        // The block has not run yet — only the confirmation is showing.
        verifyNever(() => mockActionsCubit.blockAndRemoveRequest(any(), any()));
      });

      testWidgets('cancelling the confirmation does not block', (
        tester,
      ) async {
        when(
          () => mockActionsCubit.blockAndRemoveRequest(any(), any()),
        ).thenAnswer((_) async => true);

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await tester.tap(find.text(l10n.messageRequestBlockButton));
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(DivineButton, l10n.commonCancel),
        );
        await tester.pumpAndSettle();

        verifyNever(() => mockActionsCubit.blockAndRemoveRequest(any(), any()));
      });

      testWidgets('blocks the sender and pops after confirming', (
        tester,
      ) async {
        when(
          () => mockActionsCubit.blockAndRemoveRequest(any(), any()),
        ).thenAnswer((_) async => true);
        when(mockGoRouter.canPop).thenReturn(true);
        when(() => mockGoRouter.pop()).thenAnswer((_) async {});

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await tapBlockAndConfirm(tester);

        verify(
          () => mockActionsCubit.blockAndRemoveRequest(
            conversationId,
            otherPubkey,
          ),
        ).called(1);
        verify(() => mockGoRouter.pop()).called(1);
      });

      testWidgets('confirms with a snackbar after declining', (tester) async {
        when(
          () => mockActionsCubit.declineRequest(any()),
        ).thenAnswer((_) async => true);
        when(mockGoRouter.canPop).thenReturn(true);
        when(() => mockGoRouter.pop()).thenAnswer((_) async {});

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await tester.tap(find.text(l10n.messageRequestDeclineAndRemoveButton));
        await tester.pump();

        expect(
          find.text(l10n.messageRequestDeclinedSnackbar('TestUser')),
          findsOneWidget,
        );
      });

      testWidgets('confirms with a snackbar after blocking', (tester) async {
        when(
          () => mockActionsCubit.blockAndRemoveRequest(any(), any()),
        ).thenAnswer((_) async => true);
        when(mockGoRouter.canPop).thenReturn(true);
        when(() => mockGoRouter.pop()).thenAnswer((_) async {});

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await tapBlockAndConfirm(tester);

        expect(
          find.text(l10n.inboxBlockedUser('TestUser')),
          findsOneWidget,
        );
      });

      testWidgets(
        'when the block fails, warns and keeps the user on the request',
        (tester) async {
          when(
            () => mockActionsCubit.blockAndRemoveRequest(any(), any()),
          ).thenAnswer((_) async => false);
          when(mockGoRouter.canPop).thenReturn(true);
          when(() => mockGoRouter.pop()).thenAnswer((_) async {});

          await tester.pumpWidget(buildSubject());
          await tester.pumpAndSettle();

          await tapBlockAndConfirm(tester);

          expect(find.text(l10n.commonSomethingWentWrong), findsOneWidget);
          expect(
            find.text(l10n.inboxBlockedUser('TestUser')),
            findsNothing,
          );
          verifyNever(() => mockGoRouter.pop());
        },
      );

      testWidgets(
        'when the decline fails, warns and does not claim success',
        (tester) async {
          when(
            () => mockActionsCubit.declineRequest(any()),
          ).thenAnswer((_) async => false);
          when(mockGoRouter.canPop).thenReturn(true);
          when(() => mockGoRouter.pop()).thenAnswer((_) async {});

          await tester.pumpWidget(buildSubject());
          await tester.pumpAndSettle();

          await tester.tap(
            find.text(l10n.messageRequestDeclineAndRemoveButton),
          );
          await tester.pump();

          expect(find.text(l10n.commonSomethingWentWrong), findsOneWidget);
          expect(
            find.text(l10n.messageRequestDeclinedSnackbar('TestUser')),
            findsNothing,
          );
          verifyNever(() => mockGoRouter.pop());
        },
      );

      testWidgets('ignores a second tap while an action is in flight', (
        tester,
      ) async {
        when(() => mockActionsCubit.state).thenReturn(
          const MessageRequestActionsState(
            status: MessageRequestActionsStatus.processing,
          ),
        );
        when(
          () => mockActionsCubit.blockAndRemoveRequest(any(), any()),
        ).thenAnswer((_) async => true);

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        // The in-flight guard returns before the confirmation sheet opens.
        await tester.tap(find.text(l10n.messageRequestBlockButton));
        await tester.pumpAndSettle();

        expect(find.text(l10n.messageRequestBlockConfirmBody), findsNothing);
        verifyNever(
          () => mockActionsCubit.blockAndRemoveRequest(any(), any()),
        );
      });

      testWidgets('hides Block for a group request with two counterparties', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(
            previewState: const RequestPreviewState(
              status: RequestPreviewStatus.loaded,
              messageCount: 3,
              participantPubkeys: [otherPubkey, currentPubkey],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(l10n.messageRequestDeclineAndRemoveButton),
          findsOneWidget,
        );
        expect(find.text(l10n.messageRequestBlockButton), findsNothing);
      });
    });

    // #7335. `build` branched on `denied` only, so `loading` and `error` fell
    // through to the loaded layout with `participantPubkeys` still empty:
    // live accept/decline buttons over an unknown sender, a generated
    // "Adjective Animal N" name in the header, a count of 0, and — per the
    // August iOS release log — a profile fetch for the empty string that the
    // REST fallback rejects with "Pubkey cannot be empty" before falling back
    // to relays for `''`. `loaded` is included because `_resolveParticipants`
    // returns `[]` for a conversation the DB does not have, which reaches the
    // same layout by a different route.
    group('states without a resolved participant', () {
      late MockProfileRepository mockProfileRepository;

      setUp(() {
        mockProfileRepository = MockProfileRepository();
        when(
          () => mockProfileRepository.getCachedProfile(
            pubkey: any(named: 'pubkey'),
          ),
        ).thenAnswer((_) async => null);
        when(
          () => mockProfileRepository.fetchFreshProfile(
            pubkey: any(named: 'pubkey'),
          ),
        ).thenAnswer((_) async => null);
        when(
          () =>
              mockProfileRepository.watchProfile(pubkey: any(named: 'pubkey')),
        ).thenAnswer((_) => const Stream<UserProfile?>.empty());
        when(
          () => mockProfileRepository.watchProfileStats(
            pubkey: any(named: 'pubkey'),
          ),
        ).thenAnswer((_) => const Stream<ProfileStats?>.empty());
        when(() => mockPreviewCubit.load()).thenAnswer((_) async {});
      });

      Widget buildStatusSubject(RequestPreviewState previewState) {
        when(() => mockPreviewCubit.state).thenReturn(previewState);

        return testMaterialApp(
          mockAuthService: mockAuthService,
          mockNostrService: mockNostrClient,
          mockProfileRepository: mockProfileRepository,
          additionalOverrides: [
            goRouterProvider.overrideWithValue(mockGoRouter),
            videosRepositoryProvider.overrideWithValue(mockVideosRepository),
          ],
          home: MockGoRouterProvider(
            goRouter: mockGoRouter,
            child: MultiBlocProvider(
              providers: [
                BlocProvider<RequestPreviewCubit>.value(
                  value: mockPreviewCubit,
                ),
                BlocProvider<MessageRequestActionsCubit>.value(
                  value: mockActionsCubit,
                ),
                BlocProvider<CollaboratorInviteActionsCubit>.value(
                  value: mockInviteActionsCubit,
                ),
              ],
              child: const RequestPreviewView(),
            ),
          ),
        );
      }

      // A CircularProgressIndicator never settles, so these pump explicitly.
      Future<void> pumpTwice(WidgetTester tester, Widget subject) async {
        await tester.pumpWidget(subject);
        await tester.pump();
        await tester.pump();
      }

      // `loading` is the first frame of every entry to this route, deep links
      // included, so its back button is the one most likely to meet a one-entry
      // stack — where a plain `pop()` throws GoError (#6112).
      testWidgets('back from a cold entry lands on the inbox', (tester) async {
        when(mockGoRouter.canPop).thenReturn(false);

        await pumpTwice(
          tester,
          buildStatusSubject(const RequestPreviewState()),
        );

        await tester.tap(find.byTooltip('Back'));
        await tester.pump();

        verify(() => mockGoRouter.go(InboxPage.path)).called(1);
      });

      testWidgets('loading offers no accept action', (tester) async {
        await pumpTwice(
          tester,
          buildStatusSubject(const RequestPreviewState()),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text(l10n.messageRequestViewMessagesButton), findsNothing);
      });

      testWidgets('error offers a retry instead of accept', (tester) async {
        await pumpTwice(
          tester,
          buildStatusSubject(
            const RequestPreviewState(status: RequestPreviewStatus.error),
          ),
        );

        expect(find.text(l10n.messageRequestLoadFailed), findsOneWidget);
        expect(find.text(l10n.messageRequestViewMessagesButton), findsNothing);

        await tester.tap(find.text(l10n.commonRetry));
        await tester.pump();

        verify(() => mockPreviewCubit.load()).called(1);
      });

      // The unresolved-counterparty gate must not take decline down with the
      // accept action: `declineRequest` keys off the conversation ID alone, and
      // stripping it leaves an unwanted request dismissable only by the
      // inbox-wide "Remove all requests".
      for (final entry in const {
        'loading': RequestPreviewState(),
        'error': RequestPreviewState(status: RequestPreviewStatus.error),
        'participant-less loaded': RequestPreviewState(
          status: RequestPreviewStatus.loaded,
        ),
      }.entries) {
        testWidgets('${entry.key} can still decline the request', (
          tester,
        ) async {
          when(
            () => mockActionsCubit.declineRequest(any()),
          ).thenAnswer((_) async => true);
          when(mockGoRouter.canPop).thenReturn(true);
          when(() => mockGoRouter.pop()).thenAnswer((_) async {});

          await pumpTwice(tester, buildStatusSubject(entry.value));

          await tester.tap(
            find.text(l10n.messageRequestDeclineAndRemoveButton),
          );
          await tester.pump();

          verify(
            () => mockActionsCubit.declineRequest(conversationId),
          ).called(1);
          verify(() => mockGoRouter.pop()).called(1);
        });
      }

      // Same one-entry-stack exposure as the back button: decline navigates
      // away too, and a cold deep link has nothing to pop (#6112).
      testWidgets('decline from a cold entry lands on the inbox', (
        tester,
      ) async {
        when(
          () => mockActionsCubit.declineRequest(any()),
        ).thenAnswer((_) async => true);
        when(mockGoRouter.canPop).thenReturn(false);

        await pumpTwice(
          tester,
          buildStatusSubject(
            const RequestPreviewState(status: RequestPreviewStatus.error),
          ),
        );

        await tester.tap(find.text(l10n.messageRequestDeclineAndRemoveButton));
        await tester.pump();

        verify(() => mockGoRouter.go(InboxPage.path)).called(1);
      });

      // With no resolved counterparty there is no name to put in the
      // confirmation, so decline falls back to the name-free "Removed
      // conversation" rather than either staying silent or naming a generated
      // "Adjective Animal N" placeholder (the #7335 leak / #7881 review).
      testWidgets('declining an unresolved request confirms without a name', (
        tester,
      ) async {
        when(
          () => mockActionsCubit.declineRequest(any()),
        ).thenAnswer((_) async => true);
        when(mockGoRouter.canPop).thenReturn(true);
        when(() => mockGoRouter.pop()).thenAnswer((_) async {});

        await pumpTwice(
          tester,
          buildStatusSubject(
            const RequestPreviewState(status: RequestPreviewStatus.error),
          ),
        );

        await tester.tap(find.text(l10n.messageRequestDeclineAndRemoveButton));
        await tester.pump();

        verify(() => mockActionsCubit.declineRequest(conversationId)).called(1);
        expect(find.text(l10n.inboxRemovedConversation), findsOneWidget);
      });

      testWidgets('error does not name the sender or count its messages', (
        tester,
      ) async {
        await pumpTwice(
          tester,
          buildStatusSubject(
            const RequestPreviewState(status: RequestPreviewStatus.error),
          ),
        );

        expect(
          find.textContaining(UserProfile.defaultDisplayNameFor('')),
          findsNothing,
        );
        expect(
          find.textContaining(l10n.messageRequestMessageCount(0)),
          findsNothing,
        );
      });

      testWidgets('loaded without a participant renders the failure state', (
        tester,
      ) async {
        await pumpTwice(
          tester,
          buildStatusSubject(
            const RequestPreviewState(
              status: RequestPreviewStatus.loaded,
              messageCount: 2,
            ),
          ),
        );

        expect(find.text(l10n.messageRequestLoadFailed), findsOneWidget);
        expect(find.text(l10n.messageRequestViewMessagesButton), findsNothing);
      });

      for (final entry in const {
        'initial': RequestPreviewState(),
        'error': RequestPreviewState(status: RequestPreviewStatus.error),
        'participant-less loaded': RequestPreviewState(
          status: RequestPreviewStatus.loaded,
        ),
      }.entries) {
        testWidgets(
          'the ${entry.key} build never reads a profile for the empty pubkey',
          (tester) async {
            await pumpTwice(tester, buildStatusSubject(entry.value));

            verifyNever(
              () => mockProfileRepository.getCachedProfile(pubkey: ''),
            );
            verifyNever(
              () => mockProfileRepository.fetchFreshProfile(pubkey: ''),
            );
            verifyNever(() => mockProfileRepository.watchProfile(pubkey: ''));
          },
        );
      }
    });
  });
}
