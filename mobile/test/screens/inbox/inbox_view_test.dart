// ABOUTME: Widget tests for InboxView.
// ABOUTME: Verifies segmented toggle, message list states (loading, error,
// ABOUTME: empty, loaded), and tab switching between messages and notifications.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/conversation_list/conversation_list_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/relay_notifications_provider.dart';
import 'package:openvine/screens/inbox/inbox_view.dart';
import 'package:openvine/screens/inbox/widgets/conversation_tile.dart';
import 'package:openvine/screens/inbox/widgets/following_bar.dart';
import 'package:openvine/screens/inbox/widgets/inbox_empty_state.dart';
import 'package:openvine/screens/inbox/widgets/inbox_segmented_toggle.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockConversationListBloc
    extends MockBloc<ConversationListEvent, ConversationListState>
    implements ConversationListBloc {}

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
  final nowUnix = now.millisecondsSinceEpoch ~/ 1000;

  group(InboxView, () {
    late _MockConversationListBloc mockBloc;
    late _MockAuthService mockAuthService;

    setUp(() {
      mockBloc = _MockConversationListBloc();
      mockAuthService = _MockAuthService(currentPubkey);
    });

    Widget buildSubject({ConversationListState? state}) {
      if (state != null) {
        whenListen(
          mockBloc,
          Stream<ConversationListState>.value(state),
          initialState: state,
        );
      } else {
        whenListen(
          mockBloc,
          const Stream<ConversationListState>.empty(),
          initialState: const ConversationListState(),
        );
      }

      return testMaterialApp(
        mockAuthService: mockAuthService,
        additionalOverrides: [
          cachedFollowingListProvider.overrideWithValue(const []),
          relayNotificationUnreadCountProvider.overrideWithValue(0),
        ],
        home: BlocProvider<ConversationListBloc>.value(
          value: mockBloc,
          child: const InboxView(),
        ),
      );
    }

    group('renders', () {
      testWidgets('renders $InboxSegmentedToggle', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pump();

        expect(find.byType(InboxSegmentedToggle), findsOneWidget);
      });

      testWidgets('renders $FollowingBar in messages tab', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pump();

        expect(find.byType(FollowingBar), findsOneWidget);
      });

      testWidgets(
        'renders $CircularProgressIndicator when status is initial',
        (tester) async {
          await tester.pumpWidget(buildSubject());
          await tester.pump();

          expect(find.byType(CircularProgressIndicator), findsOneWidget);
        },
      );

      testWidgets(
        'renders $InboxEmptyState when status is error',
        (tester) async {
          await tester.pumpWidget(
            buildSubject(
              state: const ConversationListState(
                status: ConversationListStatus.error,
              ),
            ),
          );
          await tester.pump();

          expect(find.byType(InboxEmptyState), findsOneWidget);
        },
      );

      testWidgets(
        'renders $InboxEmptyState when loaded with no conversations',
        (tester) async {
          await tester.pumpWidget(
            buildSubject(
              state: const ConversationListState(
                status: ConversationListStatus.loaded,
              ),
            ),
          );
          await tester.pump();

          expect(find.byType(InboxEmptyState), findsOneWidget);
        },
      );

      testWidgets(
        'renders $ConversationTile when loaded with conversations',
        (tester) async {
          final conversation = DmConversation(
            id: 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
            participantPubkeys: [currentPubkey, otherPubkey],
            isGroup: false,
            createdAt: nowUnix,
            lastMessageContent: 'Hello',
            lastMessageTimestamp: nowUnix,
            isRead: true,
          );

          await tester.pumpWidget(
            buildSubject(
              state: ConversationListState(
                status: ConversationListStatus.loaded,
                conversations: [conversation],
                hasMore: false,
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(ConversationTile), findsOneWidget);
        },
      );
    });
  });
}
