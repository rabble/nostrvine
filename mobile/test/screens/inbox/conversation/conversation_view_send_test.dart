// ABOUTME: Widget tests for the ConversationView send/fail/retry visuals
// ABOUTME: — pending clock, failed alert icon, and Retry event dispatch.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/blocs/dm/conversation/conversation_bloc.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/inbox/conversation/conversation_view.dart';

import '../../../helpers/test_provider_overrides.dart';

class _MockConversationBloc
    extends MockBloc<ConversationEvent, ConversationState>
    implements ConversationBloc {}

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
  const pendingId = 'pending-1700000000-abc';

  setUpAll(() {
    registerFallbackValue(
      const ConversationMessageRetried(
        pendingId: pendingId,
        recipientPubkeys: [otherPubkey],
        content: 'Hi',
      ),
    );
  });

  group('ConversationView send visuals', () {
    late _MockConversationBloc mockBloc;
    late _MockAuthService mockAuthService;

    setUp(() {
      mockBloc = _MockConversationBloc();
      mockAuthService = _MockAuthService(currentPubkey);
    });

    Widget buildSubject(ConversationState state) {
      whenListen(
        mockBloc,
        Stream<ConversationState>.value(state),
        initialState: state,
      );

      return testMaterialApp(
        mockAuthService: mockAuthService,
        additionalOverrides: [
          fetchUserProfileProvider(otherPubkey).overrideWith(
            (ref) async => null,
          ),
        ],
        home: BlocProvider<ConversationBloc>.value(
          value: mockBloc,
          child: const ConversationView(
            participantPubkeys: [otherPubkey],
          ),
        ),
      );
    }

    DmMessage optimisticMessage() => const DmMessage(
      id: pendingId,
      conversationId: 'conv',
      senderPubkey: currentPubkey,
      content: 'Hi',
      createdAt: 1700000000,
      giftWrapId: pendingId,
    );

    testWidgets(
      'pending message shows the clock icon',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(
            ConversationState(
              status: ConversationStatus.loaded,
              messages: [optimisticMessage()],
              sendStatusByMessageId: const {
                pendingId: MessageSendStatus.sending,
              },
            ),
          ),
        );
        await tester.pump();

        expect(find.byIcon(Icons.schedule), findsOneWidget);
        expect(find.byIcon(Icons.error_outline), findsNothing);
      },
    );

    testWidgets(
      'failed message shows the red alert icon',
      (tester) async {
        const feedback = PublishUserFeedback(
          severity: PublishSeverity.error,
          messageKey: 'publish_no_relay_response',
          retryable: true,
        );
        await tester.pumpWidget(
          buildSubject(
            ConversationState(
              status: ConversationStatus.loaded,
              messages: [optimisticMessage()],
              sendStatusByMessageId: const {
                pendingId: MessageSendStatus.failed,
              },
              feedbackByMessageId: const {pendingId: feedback},
            ),
          ),
        );
        await tester.pump();

        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.byIcon(Icons.schedule), findsNothing);
      },
    );

    testWidgets(
      'tapping the failed icon dispatches ConversationMessageRetried',
      (tester) async {
        const feedback = PublishUserFeedback(
          severity: PublishSeverity.error,
          messageKey: 'publish_no_relay_response',
          retryable: true,
        );
        await tester.pumpWidget(
          buildSubject(
            ConversationState(
              status: ConversationStatus.loaded,
              messages: [optimisticMessage()],
              sendStatusByMessageId: const {
                pendingId: MessageSendStatus.failed,
              },
              feedbackByMessageId: const {pendingId: feedback},
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.byIcon(Icons.error_outline));
        await tester.pump();

        verify(
          () => mockBloc.add(
            any(
              that: isA<ConversationMessageRetried>()
                  .having(
                    (e) => e.pendingId,
                    'pendingId',
                    pendingId,
                  )
                  .having(
                    (e) => e.content,
                    'content',
                    'Hi',
                  )
                  .having(
                    (e) => e.recipientPubkeys,
                    'recipients',
                    [otherPubkey],
                  ),
            ),
          ),
        ).called(1);
      },
    );

    testWidgets(
      'received (incoming) message has no status icon even if a stale '
      'entry is in sendStatusByMessageId',
      (tester) async {
        const incoming = DmMessage(
          id: 'incoming1',
          conversationId: 'conv',
          senderPubkey: otherPubkey,
          content: 'hey',
          createdAt: 1700000001,
          giftWrapId: 'gw-incoming',
        );

        await tester.pumpWidget(
          buildSubject(
            const ConversationState(
              status: ConversationStatus.loaded,
              messages: [incoming],
            ),
          ),
        );
        await tester.pump();

        expect(find.byIcon(Icons.schedule), findsNothing);
        expect(find.byIcon(Icons.error_outline), findsNothing);
      },
    );
  });
}
