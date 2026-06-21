// ABOUTME: Widget tests for the "who reacted" sheet (ReactionsDetailSheet).
// ABOUTME: Covers reactor listing and own-row remove / retry dispatch through
// ABOUTME: the cubit re-provided above the modal via contentWrapper.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/reactions/conversation_reactions_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/inbox/conversation/widgets/reactions_detail_sheet.dart';
import 'package:openvine/widgets/user_avatar.dart';

import '../../../../helpers/test_provider_overrides.dart';

class _MockConversationReactionsCubit
    extends MockBloc<ConversationReactionsEvent, ConversationReactionsState>
    implements ConversationReactionsCubit {}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  const ownerPubkey =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  const otherPubkey =
      'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';
  const conversationId =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const messageId =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  DmReaction makeReaction({
    required String id,
    required String reactorPubkey,
    required String emoji,
    int createdAt = 1_700_000_000,
    DmReactionPublishStatus publishStatus = DmReactionPublishStatus.sent,
  }) {
    return DmReaction(
      id: id,
      conversationId: conversationId,
      targetMessageId: messageId,
      targetMessageAuthor: otherPubkey,
      reactorPubkey: reactorPubkey,
      emoji: emoji,
      createdAt: createdAt,
      ownerPubkey: ownerPubkey,
      publishStatus: publishStatus,
    );
  }

  Widget host(_MockConversationReactionsCubit cubit) {
    return testMaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => ReactionsDetailSheet.show(
                context: context,
                cubit: cubit,
                conversationId: conversationId,
                messageId: messageId,
                messageAuthorPubkey: otherPubkey,
                ownerPubkey: ownerPubkey,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  group('ReactionsDetailSheet', () {
    late _MockConversationReactionsCubit cubit;

    setUp(() {
      cubit = _MockConversationReactionsCubit();
    });

    void primeState(List<DmReaction> reactions) {
      final state = ConversationReactionsState(
        reactionsByMessageId: {messageId: reactions},
      );
      when(() => cubit.state).thenReturn(state);
      whenListen(cubit, Stream.value(state), initialState: state);
    }

    Future<void> open(WidgetTester tester, {bool settle = true}) async {
      await tester.pumpWidget(host(cubit));
      await tester.pump();
      await tester.tap(find.text('open'));
      if (settle) {
        await tester.pumpAndSettle();
      } else {
        await tester.pump(const Duration(milliseconds: 500));
      }
    }

    testWidgets('lists each reactor with their emoji and a remove action', (
      tester,
    ) async {
      primeState([
        makeReaction(id: 'own1', reactorPubkey: ownerPubkey, emoji: '🔥'),
        makeReaction(
          id: 'other1',
          reactorPubkey: otherPubkey,
          emoji: '😂',
          createdAt: 1_700_000_001,
          publishStatus: DmReactionPublishStatus.received,
        ),
      ]);

      await open(tester);

      expect(find.text(l10n.dmReactionsSheetTitle), findsOneWidget);
      expect(find.text('🔥'), findsOneWidget);
      expect(find.text('😂'), findsOneWidget);
      // Own row offers remove; the other participant's row does not.
      expect(find.text(l10n.dmReactionRemoveAction), findsOneWidget);
    });

    testWidgets('reactor avatar renders as a circle, not a clipped square', (
      tester,
    ) async {
      primeState([
        makeReaction(id: 'own1', reactorPubkey: ownerPubkey, emoji: '🔥'),
      ]);

      await open(tester);

      // cornerRadius == size / 2 makes the avatar (and its own border) a true
      // circle, so no external clip slices the border into arcs.
      final avatar = tester.widget<UserAvatar>(find.byType(UserAvatar));
      expect(avatar.cornerRadius, avatar.size / 2);
      expect(
        find.ancestor(
          of: find.byType(UserAvatar),
          matching: find.byType(ClipOval),
        ),
        findsNothing,
      );
    });

    testWidgets('tapping own row dispatches a toggle (remove) and closes', (
      tester,
    ) async {
      primeState([
        makeReaction(id: 'own1', reactorPubkey: ownerPubkey, emoji: '🔥'),
      ]);

      await open(tester);
      await tester.tap(find.text(l10n.dmReactionRemoveAction));
      await tester.pumpAndSettle();

      verify(
        () => cubit.add(
          const ConversationReactionToggled(
            conversationId: conversationId,
            messageId: messageId,
            messageAuthorPubkey: otherPubkey,
            emoji: '🔥',
          ),
        ),
      ).called(1);
      // Sheet dismissed after removal.
      expect(find.text(l10n.dmReactionsSheetTitle), findsNothing);
    });

    testWidgets('tapping own failed row dispatches a retry request', (
      tester,
    ) async {
      primeState([
        makeReaction(
          id: 'own1',
          reactorPubkey: ownerPubkey,
          emoji: '🔥',
          publishStatus: DmReactionPublishStatus.failed,
        ),
      ]);

      await open(tester);
      expect(find.text(l10n.dmReactionRetryAction), findsOneWidget);

      await tester.tap(find.text(l10n.dmReactionRetryAction));
      await tester.pump();

      verify(
        () => cubit.add(
          const ConversationReactionRetryRequested(
            rumorId: 'own1',
            messageId: messageId,
            messageAuthorPubkey: otherPubkey,
            emoji: '🔥',
          ),
        ),
      ).called(1);
    });

    testWidgets('own pending and failed rows expose state semantics', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      primeState([
        makeReaction(
          id: 'own-pending',
          reactorPubkey: ownerPubkey,
          emoji: '🔥',
          publishStatus: DmReactionPublishStatus.pending,
        ),
        makeReaction(
          id: 'own-failed',
          reactorPubkey: ownerPubkey,
          emoji: '😂',
          createdAt: 1_700_000_001,
          publishStatus: DmReactionPublishStatus.failed,
        ),
      ]);

      await open(tester, settle: false);

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label ==
                  l10n.dmReactionChipPendingA11yLabel('🔥'),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == l10n.dmReactionChipFailedA11yLabel,
        ),
        findsOneWidget,
      );

      semantics.dispose();
    });
  });
}
