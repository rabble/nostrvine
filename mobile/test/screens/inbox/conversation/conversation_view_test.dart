// ABOUTME: Widget tests for ConversationView.
// ABOUTME: Verifies loading, error, empty, and loaded message states,
// ABOUTME: plus the app bar and input bar rendering.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/conversation/collaborator_invite_actions_cubit.dart';
import 'package:openvine/blocs/dm/conversation/conversation_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/collaborator_invite.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/inbox/conversation/conversation_view.dart';
import 'package:openvine/screens/inbox/conversation/widgets/widgets.dart';
import 'package:openvine/screens/video_detail_screen.dart';

import '../../../helpers/go_router.dart';
import '../../../helpers/test_provider_overrides.dart';

class _MockConversationBloc
    extends MockBloc<ConversationEvent, ConversationState>
    implements ConversationBloc {}

class _MockCollaboratorInviteActionsCubit
    extends MockCubit<CollaboratorInviteActionsState>
    implements CollaboratorInviteActionsCubit {}

class _MockAuthService extends MockAuthService {
  _MockAuthService(this._pubkey);
  final String _pubkey;

  @override
  String? get currentPublicKeyHex => _pubkey;
}

void main() {
  const currentPubkey =
      'aabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccdd';
  const otherPubkey =
      '1122334411223344112233441122334411223344112233441122334411223344';
  const fallbackInvite = CollaboratorInvite(
    messageId:
        '9999999999999999999999999999999999999999999999999999999999999999',
    videoAddress:
        '34236:1122334411223344112233441122334411223344112233441122334411223344:skate-loop',
    videoKind: 34236,
    creatorPubkey: otherPubkey,
    videoDTag: 'skate-loop',
    role: 'Collaborator',
  );

  final now = DateTime.now();
  final l10n = lookupAppLocalizations(const Locale('en'));

  group(ConversationView, () {
    late _MockConversationBloc mockBloc;
    late _MockCollaboratorInviteActionsCubit mockInviteActionsCubit;
    late _MockAuthService mockAuthService;

    setUpAll(() {
      registerFallbackValue(fallbackInvite);
      registerFallbackValue(<CollaboratorInvite>[]);
      registerFallbackValue(
        const ConversationMessageSent(
          recipientPubkeys: [otherPubkey],
          content: '',
        ),
      );
    });

    setUp(() {
      mockBloc = _MockConversationBloc();
      mockInviteActionsCubit = _MockCollaboratorInviteActionsCubit();
      mockAuthService = _MockAuthService(currentPubkey);

      when(() => mockInviteActionsCubit.state).thenReturn(
        const CollaboratorInviteActionsState(),
      );
      when(
        () => mockInviteActionsCubit.acceptInvite(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockInviteActionsCubit.ignoreInvite(any()),
      ).thenAnswer((_) async {});
    });

    Widget buildSubject({
      ConversationState? state,
      UserProfile? otherProfile,
      MockGoRouter? goRouter,
    }) {
      final effectiveState = state ?? const ConversationState();
      whenListen(
        mockBloc,
        Stream<ConversationState>.value(effectiveState),
        initialState: effectiveState,
      );

      final app = testMaterialApp(
        mockAuthService: mockAuthService,
        additionalOverrides: [
          fetchUserProfileProvider(
            otherPubkey,
          ).overrideWith((ref) async => otherProfile),
        ],
        home: BlocProvider<ConversationBloc>.value(
          value: mockBloc,
          child: BlocProvider<CollaboratorInviteActionsCubit>.value(
            value: mockInviteActionsCubit,
            child: const ConversationView(
              participantPubkeys: [otherPubkey],
            ),
          ),
        ),
      );
      return goRouter == null
          ? app
          : MockGoRouterProvider(goRouter: goRouter, child: app);
    }

    group('renders', () {
      testWidgets('renders $ConversationAppBar', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pump();

        expect(find.byType(ConversationAppBar), findsOneWidget);
      });

      testWidgets('renders $MessageInputBar', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pump();

        expect(find.byType(MessageInputBar), findsOneWidget);
      });

      testWidgets('renders $CircularProgressIndicator when status is loading', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(
            state: const ConversationState(status: ConversationStatus.loading),
          ),
        );
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('renders error text when status is error', (tester) async {
        await tester.pumpWidget(
          buildSubject(
            state: const ConversationState(status: ConversationStatus.error),
          ),
        );
        await tester.pump();

        final l10n = AppLocalizations.of(
          tester.element(find.byType(ConversationView)),
        );
        expect(find.text(l10n.dmConversationLoadError), findsOneWidget);
        // Cross-check that the widget actually reads from l10n: the German
        // copy must NOT appear in an en-locale render. Catches a regression
        // where the migration accidentally hardcodes the English string
        // alongside the l10n key.
        expect(
          find.text(
            lookupAppLocalizations(
              const Locale('de'),
            ).dmConversationLoadError,
          ),
          findsNothing,
        );
      });

      testWidgets('renders $EmptyConversation when loaded with no messages', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(
            state: const ConversationState(status: ConversationStatus.loaded),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(EmptyConversation), findsOneWidget);
      });

      testWidgets('renders $MessageBubble when loaded with messages', (
        tester,
      ) async {
        final message = DmMessage(
          id: 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
          conversationId:
              'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
          senderPubkey: otherPubkey,
          content: 'Hello there!',
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          giftWrapId:
              'aaaaaaaabbbbbbbbccccccccddddddddaaaaaaaabbbbbbbbccccccccdddddddd',
        );

        await tester.pumpWidget(
          buildSubject(
            state: ConversationState(
              status: ConversationStatus.loaded,
              messages: [message],
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(MessageBubble), findsOneWidget);
        expect(find.text('Hello there!'), findsOneWidget);
      });

      testWidgets('renders display name from profile in app bar', (
        tester,
      ) async {
        final profile = UserProfile(
          pubkey: otherPubkey,
          displayName: 'Alice',
          name: 'alice',
          rawData: const {},
          createdAt: now,
          eventId:
              'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        );

        await tester.pumpWidget(buildSubject(otherProfile: profile));
        // Use pump() instead of pumpAndSettle() because the async
        // Riverpod provider may schedule continuous micro-tasks.
        await tester.pump();
        await tester.pump();

        expect(find.text('Alice'), findsOneWidget);
      });

      testWidgets(
        'renders collaborator invite card instead of plaintext invite copy',
        (tester) async {
          final message = DmMessage(
            id: '9999999999999999999999999999999999999999999999999999999999999999',
            conversationId:
                'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
            senderPubkey: otherPubkey,
            content: 'You were invited to collaborate.',
            createdAt: now.millisecondsSinceEpoch ~/ 1000,
            giftWrapId:
                'aaaaaaaabbbbbbbbccccccccddddddddaaaaaaaabbbbbbbbccccccccdddddddd',
            tags: const [
              ['divine', 'collab-invite'],
              [
                'a',
                '34236:1122334411223344112233441122334411223344112233441122334411223344:skate-loop',
                'wss://relay.divine.video',
              ],
              ['p', otherPubkey],
              ['role', 'Collaborator'],
              ['title', 'Skate loop'],
            ],
          );

          await tester.pumpWidget(
            buildSubject(
              state: ConversationState(
                status: ConversationStatus.loaded,
                messages: [message],
              ),
            ),
          );
          await tester.pump();

          expect(find.text(l10n.inboxCollabInviteCardTitle), findsOneWidget);
          expect(find.textContaining('Skate loop'), findsOneWidget);
          expect(find.text(l10n.inboxCollabInviteAcceptButton), findsOneWidget);
          expect(find.text(l10n.inboxCollabInviteIgnoreButton), findsOneWidget);
          expect(find.text('You were invited to collaborate.'), findsNothing);

          await tester.tap(find.text(l10n.inboxCollabInviteAcceptButton));
          await tester.pump();

          verify(
            () => mockInviteActionsCubit.acceptInvite(any()),
          ).called(1);
        },
      );

      testWidgets(
        'opens collaborator invite video when card is tapped',
        (tester) async {
          final mockGoRouter = MockGoRouter();
          when(() => mockGoRouter.push(any())).thenAnswer((_) async => null);

          final message = DmMessage(
            id: '9999999999999999999999999999999999999999999999999999999999999999',
            conversationId:
                'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
            senderPubkey: otherPubkey,
            content: 'You were invited to collaborate.',
            createdAt: now.millisecondsSinceEpoch ~/ 1000,
            giftWrapId:
                'aaaaaaaabbbbbbbbccccccccddddddddaaaaaaaabbbbbbbbccccccccdddddddd',
            tags: const [
              ['divine', 'collab-invite'],
              [
                'a',
                '34236:1122334411223344112233441122334411223344112233441122334411223344:skate-loop',
                'wss://relay.divine.video',
              ],
              ['p', otherPubkey],
              ['role', 'Collaborator'],
              ['title', 'Skate loop'],
            ],
          );

          await tester.pumpWidget(
            buildSubject(
              state: ConversationState(
                status: ConversationStatus.loaded,
                messages: [message],
              ),
              goRouter: mockGoRouter,
            ),
          );
          await tester.pump();

          await tester.tap(find.byType(CollaboratorInviteCard));
          await tester.pump();

          verify(
            () => mockGoRouter.push(
              VideoDetailScreen.pathForId(
                '34236:1122334411223344112233441122334411223344112233441122334411223344:skate-loop',
              ),
            ),
          ).called(1);
        },
      );

      // #3559 — NIP-17 echoes a sender's gift wrap back to themselves,
      // so the inviter's own outgoing collab invite shows up in their
      // conversation feed. The renderer must surface it as a static
      // "Invitation sent" status, not Accept/Ignore (the inviter
      // accepting their own invite is nonsensical and would publish a
      // malformed kind-34238 with creator==responder).
      testWidgets(
        'renders sender-direction invite as Sent status, no Accept/Ignore',
        (tester) async {
          final message = DmMessage(
            id: '8888888888888888888888888888888888888888888888888888888888888888',
            conversationId:
                'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
            senderPubkey: currentPubkey,
            content: 'You were invited to collaborate.',
            createdAt: now.millisecondsSinceEpoch ~/ 1000,
            giftWrapId:
                'bbbbbbbbccccccccddddddddeeeeeeeebbbbbbbbccccccccddddddddeeeeeeee',
            tags: const [
              ['divine', 'collab-invite'],
              [
                'a',
                '34236:$currentPubkey:skate-loop',
                'wss://relay.divine.video',
              ],
              ['p', currentPubkey],
              ['role', 'Collaborator'],
              ['title', 'Skate loop'],
            ],
          );

          await tester.pumpWidget(
            buildSubject(
              state: ConversationState(
                status: ConversationStatus.loaded,
                messages: [message],
              ),
            ),
          );
          await tester.pump();

          expect(find.text(l10n.inboxCollabInviteCardTitle), findsOneWidget);
          expect(find.textContaining('Skate loop'), findsOneWidget);
          expect(find.text(l10n.inboxCollabInviteSentStatus), findsOneWidget);
          expect(find.text(l10n.inboxCollabInviteAcceptButton), findsNothing);
          expect(find.text(l10n.inboxCollabInviteIgnoreButton), findsNothing);
          expect(find.text('You were invited to collaborate.'), findsNothing);

          // Stronger assertion than "no acceptInvite call": sender-side
          // cards do not subscribe to the cubit at all, so loadInvites
          // is never invoked. Prevents state-store pollution.
          verifyNever(() => mockInviteActionsCubit.loadInvites(any()));
        },
      );

      // #3559 Phase 2 — sender-side suppression handles the inviter's
      // own outgoing card. This test covers the recipient-side legacy
      // NIP-04 plaintext duplicate: when an older sender (or another
      // Nostr client) emits an invite as a plain DM with no Divine
      // structured tags, the bubble must not render — it would tell the
      // user to "open diVine" inside diVine itself, with no actionable
      // affordance.
      testWidgets(
        'suppresses legacy NIP-04 invite plaintext duplicates with no '
        'structured tags',
        (tester) async {
          final message = DmMessage(
            id: '7777777777777777777777777777777777777777777777777777777777777777',
            conversationId:
                'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
            senderPubkey: otherPubkey,
            content:
                'You were invited to collaborate on Skate loop. '
                'Open diVine to review and accept.',
            createdAt: now.millisecondsSinceEpoch ~/ 1000,
            giftWrapId:
                'ccccccccddddddddeeeeeeeeffffffff00000000111111112222222233333333',
          );

          await tester.pumpWidget(
            buildSubject(
              state: ConversationState(
                status: ConversationStatus.loaded,
                messages: [message],
              ),
            ),
          );
          await tester.pump();

          expect(find.byType(CollaboratorInviteCard), findsNothing);
          expect(find.byType(MessageBubble), findsNothing);
          expect(
            find.textContaining('Open diVine to review and accept'),
            findsNothing,
          );
        },
      );

      testWidgets(
        'still renders plain text DMs that do not match the invite suffix',
        (tester) async {
          final message = DmMessage(
            id: '6666666666666666666666666666666666666666666666666666666666666666',
            conversationId:
                'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
            senderPubkey: otherPubkey,
            content: 'Hey, want to ride together this weekend?',
            createdAt: now.millisecondsSinceEpoch ~/ 1000,
            giftWrapId:
                'ddddddddeeeeeeeeffffffff0000000011111111222222223333333344444444',
          );

          await tester.pumpWidget(
            buildSubject(
              state: ConversationState(
                status: ConversationStatus.loaded,
                messages: [message],
              ),
            ),
          );
          await tester.pump();

          expect(find.byType(MessageBubble), findsOneWidget);
          expect(
            find.text('Hey, want to ride together this weekend?'),
            findsOneWidget,
          );
        },
      );
    });

    // Send-failure UX (companion to ConversationBloc's clear-optimistic-on-
    // failure behavior). On `SendStatus.failed`, the bloc strips the
    // optimistic message; the UI's job is to surface a retry SnackBar so
    // the user knows the send actually failed and has a one-tap recovery.
    // Without this listener, the only visible change would be a brief
    // spinner flicker, and the user would discover the loss only after
    // navigating away and back — the "looks sent, then disappeared" bug.
    group('send-failure SnackBar', () {
      const failedSendContent = 'Hi there';
      const failedSend = FailedSend(
        content: failedSendContent,
        recipientPubkeys: [otherPubkey],
      );

      testWidgets(
        'shows a localized retry SnackBar when sendStatus transitions to '
        'failed',
        (tester) async {
          // Emit loaded → failed so the listenWhen guard fires.
          whenListen(
            mockBloc,
            Stream<ConversationState>.fromIterable(const [
              ConversationState(status: ConversationStatus.loaded),
              ConversationState(
                status: ConversationStatus.loaded,
                sendStatus: SendStatus.failed,
                lastFailedSend: failedSend,
              ),
            ]),
            initialState: const ConversationState(
              status: ConversationStatus.loaded,
            ),
          );

          await tester.pumpWidget(
            testMaterialApp(
              mockAuthService: mockAuthService,
              additionalOverrides: [
                fetchUserProfileProvider(
                  otherPubkey,
                ).overrideWith((ref) async => null),
              ],
              home: BlocProvider<ConversationBloc>.value(
                value: mockBloc,
                child: BlocProvider<CollaboratorInviteActionsCubit>.value(
                  value: mockInviteActionsCubit,
                  child: const ConversationView(
                    participantPubkeys: [otherPubkey],
                  ),
                ),
              ),
            ),
          );
          // Drain the controlled stream + SnackBar enter animation.
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          expect(
            find.text(l10n.dmSendFailedMessage),
            findsOneWidget,
            reason: 'localized failure message must come from context.l10n',
          );
          expect(find.text(l10n.dmSendFailedRetry), findsOneWidget);
          // Hardcoded English would silently regress if the widget stopped
          // reading l10n — guard via the German variant.
          final lookupGermanFailureMessage = lookupAppLocalizations(
            const Locale('de'),
          ).dmSendFailedMessage;
          if (lookupGermanFailureMessage != l10n.dmSendFailedMessage) {
            expect(find.text(lookupGermanFailureMessage), findsNothing);
          }
        },
      );

      testWidgets(
        'does not show a SnackBar when sendStatus stays non-failed '
        '(e.g. sending → sent)',
        (tester) async {
          whenListen(
            mockBloc,
            Stream<ConversationState>.fromIterable(const [
              ConversationState(
                status: ConversationStatus.loaded,
                sendStatus: SendStatus.sending,
              ),
              ConversationState(
                status: ConversationStatus.loaded,
                sendStatus: SendStatus.sent,
              ),
            ]),
            initialState: const ConversationState(
              status: ConversationStatus.loaded,
            ),
          );

          await tester.pumpWidget(
            testMaterialApp(
              mockAuthService: mockAuthService,
              additionalOverrides: [
                fetchUserProfileProvider(
                  otherPubkey,
                ).overrideWith((ref) async => null),
              ],
              home: BlocProvider<ConversationBloc>.value(
                value: mockBloc,
                child: BlocProvider<CollaboratorInviteActionsCubit>.value(
                  value: mockInviteActionsCubit,
                  child: const ConversationView(
                    participantPubkeys: [otherPubkey],
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          expect(find.text(l10n.dmSendFailedMessage), findsNothing);
        },
      );

      testWidgets(
        'tapping Retry redispatches ConversationMessageSent with the '
        'last failed content + recipients',
        (tester) async {
          whenListen(
            mockBloc,
            Stream<ConversationState>.fromIterable(const [
              ConversationState(status: ConversationStatus.loaded),
              ConversationState(
                status: ConversationStatus.loaded,
                sendStatus: SendStatus.failed,
                lastFailedSend: failedSend,
              ),
            ]),
            initialState: const ConversationState(
              status: ConversationStatus.loaded,
            ),
          );

          await tester.pumpWidget(
            testMaterialApp(
              mockAuthService: mockAuthService,
              additionalOverrides: [
                fetchUserProfileProvider(
                  otherPubkey,
                ).overrideWith((ref) async => null),
              ],
              home: BlocProvider<ConversationBloc>.value(
                value: mockBloc,
                child: BlocProvider<CollaboratorInviteActionsCubit>.value(
                  value: mockInviteActionsCubit,
                  child: const ConversationView(
                    participantPubkeys: [otherPubkey],
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          await tester.tap(find.text(l10n.dmSendFailedRetry));
          // Allow the SnackBar dismissal to settle.
          await tester.pump();

          final captured = verify(() => mockBloc.add(captureAny())).captured;
          expect(captured, isNotEmpty);
          final retryEvent = captured.last as ConversationMessageSent;
          expect(retryEvent.content, equals(failedSendContent));
          expect(retryEvent.recipientPubkeys, equals(const [otherPubkey]));
        },
      );

      // accessibility.md requires explicit `SemanticsService.announce` (or
      // its non-deprecated `sendAnnouncement` form) on async visible state
      // changes — Material's default SnackBar semantics are platform-
      // dependent and weaker than the written rule. The test intercepts
      // the platform's accessibility channel, where both APIs ultimately
      // deliver the announcement, and pins the localized failure string.
      testWidgets(
        'announces the localized failure message via SemanticsService '
        'when the SnackBar fires',
        (tester) async {
          final announcements = <Map<Object?, Object?>>[];
          tester.binding.defaultBinaryMessenger
              .setMockDecodedMessageHandler<Object?>(
                SystemChannels.accessibility,
                (Object? message) async {
                  if (message is Map) announcements.add(message);
                  return null;
                },
              );
          addTearDown(
            () => tester.binding.defaultBinaryMessenger
                .setMockDecodedMessageHandler<Object?>(
                  SystemChannels.accessibility,
                  null,
                ),
          );

          whenListen(
            mockBloc,
            Stream<ConversationState>.fromIterable(const [
              ConversationState(status: ConversationStatus.loaded),
              ConversationState(
                status: ConversationStatus.loaded,
                sendStatus: SendStatus.failed,
                lastFailedSend: failedSend,
              ),
            ]),
            initialState: const ConversationState(
              status: ConversationStatus.loaded,
            ),
          );

          await tester.pumpWidget(
            testMaterialApp(
              mockAuthService: mockAuthService,
              additionalOverrides: [
                fetchUserProfileProvider(
                  otherPubkey,
                ).overrideWith((ref) async => null),
              ],
              home: BlocProvider<ConversationBloc>.value(
                value: mockBloc,
                child: BlocProvider<CollaboratorInviteActionsCubit>.value(
                  value: mockInviteActionsCubit,
                  child: const ConversationView(
                    participantPubkeys: [otherPubkey],
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          final announceCalls = announcements.where(
            (m) => m['type'] == 'announce',
          );
          expect(
            announceCalls,
            isNotEmpty,
            reason:
                'expected SemanticsService.sendAnnouncement to deliver an '
                "'announce' event on SystemChannels.accessibility",
          );
          final announcedMessages = announceCalls
              .map((m) => (m['data'] as Map?)?['message'])
              .toList();
          expect(
            announcedMessages,
            contains(l10n.dmSendFailedMessage),
            reason: 'announce payload must carry the localized failure copy',
          );
        },
      );

      // The recipient-only partial-delivery path: NIP17MessageService
      // returned `success: true, selfWrapPublished: false`, so the bloc
      // emits SendStatus.sentPartial. The UI must show distinct copy
      // (the message *was* delivered) while still offering retry, so the
      // sender can attempt to re-publish their self-wrap and restore
      // cross-device sync. Pinned per PR #3908 review feedback.
      testWidgets(
        'shows the partial-delivery SnackBar copy when sendStatus '
        'transitions to sentPartial',
        (tester) async {
          whenListen(
            mockBloc,
            Stream<ConversationState>.fromIterable(const [
              ConversationState(status: ConversationStatus.loaded),
              ConversationState(
                status: ConversationStatus.loaded,
                sendStatus: SendStatus.sentPartial,
                lastFailedSend: failedSend,
              ),
            ]),
            initialState: const ConversationState(
              status: ConversationStatus.loaded,
            ),
          );

          await tester.pumpWidget(
            testMaterialApp(
              mockAuthService: mockAuthService,
              additionalOverrides: [
                fetchUserProfileProvider(
                  otherPubkey,
                ).overrideWith((ref) async => null),
              ],
              home: BlocProvider<ConversationBloc>.value(
                value: mockBloc,
                child: BlocProvider<CollaboratorInviteActionsCubit>.value(
                  value: mockInviteActionsCubit,
                  child: const ConversationView(
                    participantPubkeys: [otherPubkey],
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          expect(
            find.text(l10n.dmSendPartialMessage),
            findsOneWidget,
            reason:
                'partial-delivery copy must come from context.l10n and be '
                'distinct from the full-failure copy',
          );
          expect(find.text(l10n.dmSendFailedMessage), findsNothing);
          expect(find.text(l10n.dmSendFailedRetry), findsOneWidget);
        },
      );
    });
  });
}
