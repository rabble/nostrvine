// ABOUTME: Unit tests for ConversationMuteCubit.
// ABOUTME: Verifies toggle, persistence load, and state transitions.

import 'dart:convert';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/dm/conversation_mute/conversation_mute_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockSharedPreferences extends Mock implements SharedPreferences {}

void main() {
  const conversationId =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const conversationId2 =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  group(ConversationMuteCubit, () {
    late _MockSharedPreferences mockPrefs;

    setUp(() {
      mockPrefs = _MockSharedPreferences();
      when(() => mockPrefs.getString(any())).thenReturn(null);
      when(
        () => mockPrefs.setString(any(), any()),
      ).thenAnswer((_) async => true);
    });

    ConversationMuteCubit buildCubit() =>
        ConversationMuteCubit(prefs: mockPrefs);

    test('initial state has empty mutedIds and idle status', () {
      final cubit = buildCubit();
      expect(cubit.state.mutedIds, isEmpty);
      expect(cubit.state.status, equals(ConversationMuteStatus.idle));
      addTearDown(cubit.close);
    });

    group('_load', () {
      test('loads saved muted IDs from SharedPreferences', () {
        final storedJson = jsonEncode([conversationId, conversationId2]);
        when(
          () => mockPrefs.getString('muted_conversations'),
        ).thenReturn(storedJson);

        final cubit = buildCubit();

        expect(cubit.state.mutedIds, contains(conversationId));
        expect(cubit.state.mutedIds, contains(conversationId2));
        addTearDown(cubit.close);
      });

      test('handles empty stored value gracefully', () {
        when(() => mockPrefs.getString('muted_conversations')).thenReturn('');

        final cubit = buildCubit();

        expect(cubit.state.mutedIds, isEmpty);
        addTearDown(cubit.close);
      });

      test('handles corrupted JSON gracefully', () {
        when(
          () => mockPrefs.getString('muted_conversations'),
        ).thenReturn('not-valid-json');

        final cubit = buildCubit();

        expect(cubit.state.mutedIds, isEmpty);
        addTearDown(cubit.close);
      });
    });

    group('toggleMute', () {
      blocTest<ConversationMuteCubit, ConversationMuteState>(
        'mutes a conversation when not muted',
        build: buildCubit,
        act: (cubit) => cubit.toggleMute(conversationId),
        expect: () => [
          isA<ConversationMuteState>()
              .having(
                (s) => s.mutedIds.contains(conversationId),
                'contains conversationId',
                isTrue,
              )
              .having(
                (s) => s.status,
                'status',
                ConversationMuteStatus.success,
              ),
        ],
        verify: (_) {
          verify(
            () => mockPrefs.setString('muted_conversations', any()),
          ).called(1);
        },
      );

      blocTest<ConversationMuteCubit, ConversationMuteState>(
        'unmutes a conversation when already muted',
        build: buildCubit,
        seed: () => const ConversationMuteState(mutedIds: {conversationId}),
        act: (cubit) => cubit.toggleMute(conversationId),
        expect: () => [
          isA<ConversationMuteState>()
              .having(
                (s) => s.mutedIds.contains(conversationId),
                'contains conversationId',
                isFalse,
              )
              .having(
                (s) => s.status,
                'status',
                ConversationMuteStatus.success,
              ),
        ],
      );

      blocTest<ConversationMuteCubit, ConversationMuteState>(
        'returns true when muting',
        build: buildCubit,
        act: (cubit) async {
          final result = await cubit.toggleMute(conversationId);
          expect(result, isTrue);
        },
      );

      blocTest<ConversationMuteCubit, ConversationMuteState>(
        'returns false when unmuting',
        build: buildCubit,
        seed: () => const ConversationMuteState(mutedIds: {conversationId}),
        act: (cubit) async {
          final result = await cubit.toggleMute(conversationId);
          expect(result, isFalse);
        },
      );

      blocTest<ConversationMuteCubit, ConversationMuteState>(
        'rolls back mutedIds when save fails',
        setUp: () {
          when(
            () => mockPrefs.setString(any(), any()),
          ).thenThrow(Exception('disk full'));
        },
        build: buildCubit,
        act: (cubit) => cubit.toggleMute(conversationId),
        expect: () => [
          isA<ConversationMuteState>()
              .having(
                (s) => s.mutedIds.contains(conversationId),
                'optimistic add',
                isTrue,
              )
              .having(
                (s) => s.status,
                'status',
                ConversationMuteStatus.success,
              ),
          isA<ConversationMuteState>()
              .having(
                (s) => s.mutedIds.contains(conversationId),
                'rolled back',
                isFalse,
              )
              .having((s) => s.status, 'status', ConversationMuteStatus.error),
        ],
        errors: () => [isA<Exception>()],
      );
    });

    group('isMuted', () {
      test('returns true for muted conversation', () {
        when(
          () => mockPrefs.getString('muted_conversations'),
        ).thenReturn(jsonEncode([conversationId]));

        final cubit = buildCubit();

        expect(cubit.state.isMuted(conversationId), isTrue);
        addTearDown(cubit.close);
      });

      test('returns false for unmuted conversation', () {
        final cubit = buildCubit();

        expect(cubit.state.isMuted(conversationId), isFalse);
        addTearDown(cubit.close);
      });
    });
  });
}
