// ABOUTME: Tests for ConversationState's pure projection getters —
// ABOUTME: specifically that an optimistic outgoing row's reply linkage
// ABOUTME: survives into the displayedMessages bubble.

import 'package:db_client/db_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/dm/conversation/conversation_bloc.dart';

/// Builds an [OutgoingDm] queue row for the [ConversationState] projection
/// tests. Mirrors the sibling builder in `conversation_bloc_test.dart` but
/// additionally exposes [replyToId], which the reply-linkage case needs.
OutgoingDm _outgoingDm({
  required String id,
  String content = 'test',
  int createdAtSec = 1700000000,
  String? replyToId,
  String ownerPubkey =
      '1111111111111111111111111111111111111111111111111111111111111111',
  String recipientPubkey =
      '2222222222222222222222222222222222222222222222222222222222222222',
  String conversationId =
      'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
  OutgoingWrapStatus recipientWrap = OutgoingWrapStatus.pending,
  OutgoingWrapStatus selfWrap = OutgoingWrapStatus.pending,
}) {
  return OutgoingDm(
    id: id,
    conversationId: conversationId,
    recipientPubkey: recipientPubkey,
    content: content,
    createdAt: createdAtSec,
    rumorEventJson: '{}',
    replyToId: replyToId,
    recipientWrapStatus: recipientWrap,
    selfWrapStatus: selfWrap,
    queuedAt: DateTime.fromMillisecondsSinceEpoch(createdAtSec * 1000),
    ownerPubkey: ownerPubkey,
  );
}

void main() {
  group(ConversationState, () {
    group('displayedMessages', () {
      const parentId =
          '7777777777777777777777777777777777777777777777777777777777777777';

      test(
        'optimistic outgoing bubble carries its replyToId so an in-flight '
        'reply can resolve its parent',
        () {
          final replyRow = _outgoingDm(
            id: 'rumor-reply',
            content: 'replying in-flight',
            replyToId: parentId,
          );
          final state = ConversationState(pendingOutgoing: [replyRow]);

          final bubble = state.displayedMessages.firstWhere(
            (m) => m.id == 'rumor-reply',
          );
          expect(bubble.replyToId, equals(parentId));
        },
      );

      test(
        'optimistic outgoing bubble has a null replyToId when the queued '
        'row is not a reply',
        () {
          final plainRow = _outgoingDm(id: 'rumor-plain', content: 'hi');
          final state = ConversationState(pendingOutgoing: [plainRow]);

          final bubble = state.displayedMessages.firstWhere(
            (m) => m.id == 'rumor-plain',
          );
          expect(bubble.replyToId, isNull);
        },
      );
    });
  });
}
