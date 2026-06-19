// ABOUTME: Widget tests for PerPersonReactionsRow (group reel reactions).

import 'dart:async';

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/reactions/conversation_reactions_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/inbox/conversation/widgets/per_person_reactions_row.dart';
import 'package:openvine/widgets/user_avatar.dart';

class _MockReactionsRepository extends Mock implements DmReactionsRepository {}

const _owner =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _peerA =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _peerB =
    '3333333333333333333333333333333333333333333333333333333333333333';
const _convo = 'convo';
const _msgId =
    'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr';

DmReaction reaction({
  required String reactor,
  required String emoji,
  required String id,
}) => DmReaction(
  id: id,
  conversationId: _convo,
  targetMessageId: _msgId,
  targetMessageAuthor: _peerA,
  reactorPubkey: reactor,
  emoji: emoji,
  createdAt: 1700000000,
  ownerPubkey: _owner,
  publishStatus: DmReactionPublishStatus.received,
);

UserProfile _profileFor(String pubkey, String name) => UserProfile(
  pubkey: pubkey,
  displayName: name,
  rawData: const {},
  createdAt: DateTime(2026),
  eventId: 'evt-$pubkey',
);

void main() {
  late _MockReactionsRepository repo;
  late StreamController<List<DmReaction>> stream;

  setUp(() {
    repo = _MockReactionsRepository();
    stream = StreamController<List<DmReaction>>.broadcast();
    when(
      () => repo.watchForConversation(any()),
    ).thenAnswer((_) => stream.stream);
  });

  tearDown(() => stream.close());

  Future<void> pumpRow(WidgetTester tester) => tester.pumpWidget(
    ProviderScope(
      overrides: [
        userProfileReactiveProvider(_peerA).overrideWith(
          (ref) => Stream.value(_profileFor(_peerA, 'Alice')),
        ),
        userProfileReactiveProvider(_peerB).overrideWith(
          (ref) => Stream.value(_profileFor(_peerB, 'Bob')),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider(
            create: (_) =>
                ConversationReactionsCubit(
                  reactionsRepository: repo,
                  ownerPubkey: _owner,
                )..add(
                  const ConversationReactionsStarted(conversationId: _convo),
                ),
            child: const PerPersonReactionsRow(
              messageId: _msgId,
              ownerPubkey: _owner,
              isSentByMe: false,
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('renders one avatar+emoji chip per reactor', (tester) async {
    await pumpRow(tester);
    await tester.pump();
    stream.add([
      reaction(reactor: _peerA, emoji: '❤️', id: 'a'),
      reaction(reactor: _peerB, emoji: '😂', id: 'b'),
    ]);
    await tester.pump();
    await tester.pump();

    expect(find.text('❤️'), findsOneWidget);
    expect(find.text('😂'), findsOneWidget);
    expect(find.byType(UserAvatar), findsNWidgets(2));
  });

  testWidgets('renders nothing when there are no reactions', (tester) async {
    await pumpRow(tester);
    await tester.pump();
    stream.add(const []);
    await tester.pump();

    expect(find.byType(UserAvatar), findsNothing);
  });
}
