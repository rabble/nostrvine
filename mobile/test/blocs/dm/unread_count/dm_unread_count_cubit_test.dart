// ABOUTME: Unit tests for DmUnreadCountCubit.
// ABOUTME: Verifies stream subscription, emission, and cleanup.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/blocs/dm/unread_count/dm_unread_count_cubit.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockDirectMessagesDao extends Mock implements DirectMessagesDao {}

class _MockConversationsDao extends Mock implements ConversationsDao {}

void main() {
  group(DmUnreadCountCubit, () {
    late _MockConversationsDao mockConversationsDao;
    late DmRepository dmRepository;

    setUp(() {
      mockConversationsDao = _MockConversationsDao();
    });

    DmUnreadCountCubit buildCubit() {
      dmRepository = DmRepository(
        nostrClient: _MockNostrClient(),
        directMessagesDao: _MockDirectMessagesDao(),
        conversationsDao: mockConversationsDao,
      );
      return DmUnreadCountCubit(dmRepository: dmRepository);
    }

    test('initial state is 0', () {
      when(
        () => mockConversationsDao.watchUnreadAcceptedCount(),
      ).thenAnswer((_) => const Stream.empty());

      final cubit = buildCubit();

      expect(cubit.state, equals(0));

      cubit.close();
    });

    blocTest<DmUnreadCountCubit, int>(
      'emits counts from watchUnreadAcceptedCount stream',
      setUp: () {
        when(
          () => mockConversationsDao.watchUnreadAcceptedCount(),
        ).thenAnswer((_) => Stream.fromIterable([1, 3, 0]));
      },
      build: buildCubit,
      expect: () => const [1, 3, 0],
    );

    blocTest<DmUnreadCountCubit, int>(
      'emits nothing when stream is empty',
      setUp: () {
        when(
          () => mockConversationsDao.watchUnreadAcceptedCount(),
        ).thenAnswer((_) => const Stream.empty());
      },
      build: buildCubit,
      expect: () => const <int>[],
    );

    test('cancels subscription on close', () async {
      final controller = StreamController<int>();
      when(
        () => mockConversationsDao.watchUnreadAcceptedCount(),
      ).thenAnswer((_) => controller.stream);

      final cubit = buildCubit();
      await cubit.close();

      // Adding to the controller after close should not throw.
      controller.add(5);
      await controller.close();
    });
  });
}
