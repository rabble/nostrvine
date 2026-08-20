// ABOUTME: Unit tests for ConversationParticipantsCubit.
// ABOUTME: Covers the route hint, the DB fallback, and the #176 gate.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/conversation/conversation_participants_cubit.dart';

class _MockDmRepository extends Mock implements DmRepository {}

void main() {
  const selfPubkey =
      'aabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccdd';
  const otherPubkey =
      '1122334411223344112233441122334411223344112233441122334411223344';
  const groupPubkey =
      '5566778855667788556677885566778855667788556677885566778855667788';
  const conversationId =
      'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

  DmConversation conversationWith(List<String> participants) {
    return DmConversation(
      id: conversationId,
      participantPubkeys: participants,
      isGroup: participants.length > 2,
      createdAt: 1700000000,
    );
  }

  group(ConversationParticipantsCubit, () {
    late _MockDmRepository dmRepository;

    setUp(() {
      dmRepository = _MockDmRepository();
      when(() => dmRepository.userPubkey).thenReturn(selfPubkey);
    });

    ConversationParticipantsCubit buildCubit({
      List<String> initialParticipantPubkeys = const [],
      bool isDmRestricted = false,
      bool Function(String)? isApprovedRecipient,
    }) {
      return ConversationParticipantsCubit(
        dmRepository: dmRepository,
        conversationId: conversationId,
        initialParticipantPubkeys: initialParticipantPubkeys,
        isDmRestricted: () => isDmRestricted,
        isApprovedRecipient: isApprovedRecipient ?? (_) => true,
      );
    }

    test('starts loading', () {
      expect(
        buildCubit().state,
        equals(const ConversationParticipantsState()),
      );
    });

    group('load', () {
      test('uses the route hint without reading the repository', () async {
        final cubit = buildCubit(initialParticipantPubkeys: [otherPubkey]);

        await cubit.load();

        expect(
          cubit.state.status,
          equals(ConversationParticipantsStatus.ready),
        );
        expect(cubit.state.participantPubkeys, equals([otherPubkey]));
        verifyNever(() => dmRepository.getConversation(any()));
      });

      test('resolves the hint before the first await, so an inbox tap '
          'renders no loading frame', () async {
        final cubit = buildCubit(initialParticipantPubkeys: [otherPubkey]);

        final pending = cubit.load();

        expect(
          cubit.state.status,
          equals(ConversationParticipantsStatus.ready),
        );
        await pending;
      });

      test('falls back to the conversation row when the route has no hint '
          '(deep link / browser refresh)', () async {
        when(() => dmRepository.getConversation(conversationId)).thenAnswer(
          (_) async => conversationWith([selfPubkey, otherPubkey]),
        );

        final cubit = buildCubit();
        await cubit.load();

        expect(
          cubit.state.status,
          equals(ConversationParticipantsStatus.ready),
        );
        expect(cubit.state.participantPubkeys, equals([otherPubkey]));
      });

      test('excludes self from the resolved counterparties', () async {
        when(() => dmRepository.getConversation(conversationId)).thenAnswer(
          (_) async => conversationWith([selfPubkey, otherPubkey, groupPubkey]),
        );

        final cubit = buildCubit();
        await cubit.load();

        expect(
          cubit.state.participantPubkeys,
          equals([otherPubkey, groupPubkey]),
        );
      });

      test('is ready with no counterparties when the conversation has no '
          'stored row', () async {
        when(
          () => dmRepository.getConversation(conversationId),
        ).thenAnswer((_) async => null);

        final cubit = buildCubit();
        await cubit.load();

        expect(
          cubit.state.status,
          equals(ConversationParticipantsStatus.ready),
        );
        expect(cubit.state.participantPubkeys, isEmpty);
      });

      blocTest<ConversationParticipantsCubit, ConversationParticipantsState>(
        'reports a repository failure and degrades to no counterparties',
        setUp: () {
          when(
            () => dmRepository.getConversation(conversationId),
          ).thenThrow(Exception('drift read failed'));
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => const [
          ConversationParticipantsState(
            status: ConversationParticipantsStatus.ready,
          ),
        ],
        errors: () => [isA<Exception>()],
      );
    });

    group('#176 DM restriction', () {
      test('denies a restricted user arriving without a route hint, without '
          'reading the repository', () async {
        final cubit = buildCubit(isDmRestricted: true);

        await cubit.load();

        expect(
          cubit.state.status,
          equals(ConversationParticipantsStatus.denied),
        );
        // Resolving counterparties is itself a read of conversation data the
        // restricted user may not access — the gate must precede it.
        verifyNever(() => dmRepository.getConversation(any()));
      });

      test('denies before the first await', () async {
        final cubit = buildCubit(isDmRestricted: true);

        final pending = cubit.load();

        expect(
          cubit.state.status,
          equals(ConversationParticipantsStatus.denied),
        );
        await pending;
      });

      test(
        'denies a restricted user whose counterparty is not approved',
        () async {
          final cubit = buildCubit(
            initialParticipantPubkeys: [otherPubkey],
            isDmRestricted: true,
            isApprovedRecipient: (_) => false,
          );

          await cubit.load();

          expect(
            cubit.state.status,
            equals(ConversationParticipantsStatus.denied),
          );
        },
      );

      test('denies a restricted user when only some counterparties are '
          'approved', () async {
        final cubit = buildCubit(
          initialParticipantPubkeys: [otherPubkey, groupPubkey],
          isDmRestricted: true,
          isApprovedRecipient: (pubkey) => pubkey == otherPubkey,
        );

        await cubit.load();

        expect(
          cubit.state.status,
          equals(ConversationParticipantsStatus.denied),
        );
      });

      test('allows a restricted user whose counterparty is approved', () async {
        final cubit = buildCubit(
          initialParticipantPubkeys: [otherPubkey],
          isDmRestricted: true,
        );

        await cubit.load();

        expect(
          cubit.state.status,
          equals(ConversationParticipantsStatus.ready),
        );
        expect(cubit.state.participantPubkeys, equals([otherPubkey]));
      });
    });

    test('does not emit or throw when closed mid-load', () async {
      final completer = Completer<DmConversation?>();
      when(
        () => dmRepository.getConversation(conversationId),
      ).thenAnswer((_) => completer.future);

      final cubit = buildCubit();
      final pending = cubit.load();
      await cubit.close();
      completer.complete(conversationWith([selfPubkey, otherPubkey]));

      await expectLater(pending, completes);
      expect(
        cubit.state.status,
        equals(ConversationParticipantsStatus.loading),
      );
    });
  });
}
