// ABOUTME: Widget tests for ConversationView.
// ABOUTME: Verifies loading, error, empty, and loaded message states,
// ABOUTME: plus the app bar and input bar rendering.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/conversation/conversation_bloc.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/inbox/conversation/conversation_view.dart';
import 'package:openvine/screens/inbox/conversation/widgets/widgets.dart';

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

  final now = DateTime.now();

  group(ConversationView, () {
    late _MockConversationBloc mockBloc;
    late _MockAuthService mockAuthService;

    setUp(() {
      mockBloc = _MockConversationBloc();
      mockAuthService = _MockAuthService(currentPubkey);
    });

    Widget buildSubject({ConversationState? state, UserProfile? otherProfile}) {
      final effectiveState = state ?? const ConversationState();
      whenListen(
        mockBloc,
        Stream<ConversationState>.value(effectiveState),
        initialState: effectiveState,
      );

      return testMaterialApp(
        mockAuthService: mockAuthService,
        additionalOverrides: [
          fetchUserProfileProvider(
            otherPubkey,
          ).overrideWith((ref) async => otherProfile),
        ],
        home: BlocProvider<ConversationBloc>.value(
          value: mockBloc,
          child: const ConversationView(participantPubkeys: [otherPubkey]),
        ),
      );
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

        expect(find.text('Could not load messages'), findsOneWidget);
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
    });
  });
}
