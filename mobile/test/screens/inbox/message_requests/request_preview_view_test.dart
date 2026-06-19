// ABOUTME: Widget tests for RequestPreviewView.
// ABOUTME: Verifies rendering of profile info, action buttons, message count,
// ABOUTME: and navigation to profile view, conversation, and decline action.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/conversation/collaborator_invite_actions_cubit.dart';
import 'package:openvine/blocs/dm/message_requests/message_request_actions_cubit.dart';
import 'package:openvine/blocs/dm/message_requests/request_preview_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/collaborator_invite.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/screens/inbox/conversation/conversation_page.dart';
import 'package:openvine/screens/inbox/message_requests/request_preview_view.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/widgets/user_avatar.dart';

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

class _MockVideoEventService extends Mock implements VideoEventService {}

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
    late _MockVideoEventService mockVideoEventService;
    late MockNostrClient mockNostrClient;
    late _MockAuthService mockAuthService;
    late MockGoRouter mockGoRouter;
    late UserProfile testProfile;

    setUpAll(() {
      registerFallbackValue(fallbackInvite);
    });

    setUp(() {
      mockActionsCubit = _MockMessageRequestActionsCubit();
      mockPreviewCubit = _MockRequestPreviewCubit();
      mockInviteActionsCubit = _MockCollaboratorInviteActionsCubit();
      mockVideoEventService = _MockVideoEventService();
      mockNostrClient = createMockNostrService();
      mockAuthService = _MockAuthService(currentPubkey);
      mockGoRouter = MockGoRouter();

      when(
        () => mockActionsCubit.state,
      ).thenReturn(const MessageRequestActionsState());

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
      when(() => mockVideoEventService.getVideoById(any())).thenReturn(null);
      when(
        () => mockVideoEventService.getVideoEventByVineId(any()),
      ).thenReturn(null);
      when(
        () => mockNostrClient.fetchEventById(any()),
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
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
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
          ).thenAnswer((_) async {});

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
    });
  });
}
