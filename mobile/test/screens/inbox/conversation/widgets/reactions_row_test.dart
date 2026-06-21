// ABOUTME: Widget tests for the combined reaction pill (ReactionsRow).
// ABOUTME: Covers distinct-glyph rendering, reactor avatars, the
// ABOUTME: "see who reacted" semantic label, and tap-opens-sheet.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/reactions/conversation_reactions_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/inbox/conversation/widgets/reactions_row.dart';
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

  ConversationReactionsState stateWith(List<DmReaction> reactions) {
    return ConversationReactionsState(
      reactionsByMessageId: {messageId: reactions},
    );
  }

  Widget buildSubject(_MockConversationReactionsCubit cubit) {
    return testMaterialApp(
      home: Scaffold(
        body: BlocProvider<ConversationReactionsCubit>.value(
          value: cubit,
          child: const ReactionsRow(
            conversationId: conversationId,
            messageId: messageId,
            messageAuthorPubkey: otherPubkey,
            ownerPubkey: ownerPubkey,
            isSentByMe: false,
          ),
        ),
      ),
    );
  }

  group('ReactionsRow', () {
    late _MockConversationReactionsCubit cubit;

    setUp(() {
      cubit = _MockConversationReactionsCubit();
    });

    void primeState(ConversationReactionsState state) {
      when(() => cubit.state).thenReturn(state);
      whenListen(cubit, Stream.value(state), initialState: state);
    }

    testWidgets('renders one pill with the distinct emoji glyphs', (
      tester,
    ) async {
      primeState(
        stateWith([
          makeReaction(id: '1', reactorPubkey: ownerPubkey, emoji: '🔥'),
          makeReaction(
            id: '2',
            reactorPubkey: otherPubkey,
            emoji: '😂',
            createdAt: 1_700_000_001,
            publishStatus: DmReactionPublishStatus.received,
          ),
        ]),
      );

      await tester.pumpWidget(buildSubject(cubit));
      await tester.pump();

      // Distinct glyphs both render in the single pill.
      expect(find.text('🔥'), findsOneWidget);
      expect(find.text('😂'), findsOneWidget);
      // One avatar per reactor.
      expect(find.byType(UserAvatar), findsNWidgets(2));
    });

    testWidgets('reactor avatar is vertically centered against the emoji', (
      tester,
    ) async {
      primeState(
        stateWith([
          makeReaction(id: '1', reactorPubkey: ownerPubkey, emoji: '🔥'),
        ]),
      );

      await tester.pumpWidget(buildSubject(cubit));
      await tester.pump();

      // The avatar box and the emoji box share a vertical centre. This guards
      // the avatar-stack centering (a sub-`_size` avatar otherwise pins to the
      // top edge). Real colour-emoji ink offset is engine-level and not
      // reproducible with the placeholder test font, so this checks box
      // alignment, not glyph ink.
      final emojiCenter = tester.getCenter(find.text('🔥')).dy;
      final avatarCenter = tester.getCenter(find.byType(UserAvatar)).dy;
      expect(avatarCenter, closeTo(emojiCenter, 0.5));
    });

    testWidgets('reactor avatar renders as a circle (no cut border)', (
      tester,
    ) async {
      primeState(
        stateWith([
          makeReaction(id: '1', reactorPubkey: ownerPubkey, emoji: '🔥'),
        ]),
      );

      await tester.pumpWidget(buildSubject(cubit));
      await tester.pump();

      // cornerRadius == size / 2 keeps UserAvatar's own border circular, so it
      // is not sliced into arcs by the surrounding circular outline.
      final avatar = tester.widget<UserAvatar>(find.byType(UserAvatar));
      expect(avatar.cornerRadius, avatar.size / 2);
    });

    testWidgets('pill exposes the "see who reacted" semantic label', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      primeState(
        stateWith([
          makeReaction(id: '1', reactorPubkey: ownerPubkey, emoji: '🔥'),
        ]),
      );

      await tester.pumpWidget(buildSubject(cubit));
      await tester.pump();

      expect(
        find.bySemanticsLabel(l10n.dmReactionsViewA11yLabel),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('renders nothing when there are no reactions', (tester) async {
      primeState(stateWith(const []));

      await tester.pumpWidget(buildSubject(cubit));
      await tester.pump();

      expect(find.text('🔥'), findsNothing);
      expect(find.byType(UserAvatar), findsNothing);
    });

    testWidgets('tapping the pill opens the who-reacted sheet', (tester) async {
      primeState(
        stateWith([
          makeReaction(id: '1', reactorPubkey: ownerPubkey, emoji: '🔥'),
        ]),
      );

      await tester.pumpWidget(buildSubject(cubit));
      await tester.pump();

      // Sheet not open yet.
      expect(find.text(l10n.dmReactionsSheetTitle), findsNothing);

      await tester.tap(find.text('🔥'));
      await tester.pumpAndSettle();

      // The sheet (re-providing the same cubit via contentWrapper) is shown.
      expect(find.text(l10n.dmReactionsSheetTitle), findsOneWidget);
    });

    testWidgets(
      'renders the own optimistic pill with NO persisted rows (#5389)',
      (tester) async {
        // No persisted reactions; the chip exists only because of the
        // synchronous optimistic overlay — i.e. before any Drift round-trip.
        final state = ConversationReactionsState(
          optimistic: {
            const ReactionPublishKey(
              messageId: messageId,
              emoji: '🔥',
            ): OptimisticReactionAdded(
              makeReaction(
                id: 'optimistic:$messageId:🔥',
                reactorPubkey: ownerPubkey,
                emoji: '🔥',
                publishStatus: DmReactionPublishStatus.pending,
              ),
            ),
          },
        );
        when(() => cubit.state).thenReturn(state);
        whenListen(cubit, Stream.value(state), initialState: state);

        await tester.pumpWidget(buildSubject(cubit));
        await tester.pump();

        expect(find.text('🔥'), findsOneWidget);
        expect(find.byType(UserAvatar), findsOneWidget);
        expect(
          find.bySemanticsLabel(l10n.dmReactionsViewA11yLabel),
          findsOneWidget,
        );
      },
    );
  });
}
