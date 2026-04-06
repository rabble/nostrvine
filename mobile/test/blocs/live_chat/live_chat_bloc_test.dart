import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/live_chat/live_chat_bloc.dart';
import 'package:openvine/models/live/live_chat_message.dart';
import 'package:openvine/repositories/live_chat_repository.dart';

class _MockLiveChatRepository extends Mock implements LiveChatRepository {}

void main() {
  group('LiveChatBloc', () {
    late _MockLiveChatRepository mockRepository;
    late StreamController<List<LiveChatMessage>> messagesController;

    const hostPubkey =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const sessionAddress = '30313:$hostPubkey:session-abc';
    final firstMessage = LiveChatMessage(
      id: '1' * 64,
      sessionAddress: sessionAddress,
      pubkey: hostPubkey,
      content: 'First message',
      createdAt: DateTime.utc(2026, 4, 6, 12),
    );

    setUp(() {
      mockRepository = _MockLiveChatRepository();
      messagesController = StreamController<List<LiveChatMessage>>.broadcast(
        sync: true,
      );

      when(
        () => mockRepository.watchChatMessages(sessionAddress: sessionAddress),
      ).thenAnswer((_) => messagesController.stream);
      when(
        () => mockRepository.publishMessage(
          sessionAddress: sessionAddress,
          content: 'Hello room',
        ),
      ).thenAnswer((_) async => null);
    });

    tearDown(() async {
      await messagesController.close();
    });

    test('start subscribes to chat updates and exposes ready state', () async {
      final bloc = LiveChatBloc(liveChatRepository: mockRepository);

      bloc.add(const LiveChatStarted(sessionAddress: sessionAddress));
      await _flush();

      messagesController.add(<LiveChatMessage>[firstMessage]);
      await _flush();

      expect(bloc.state.status, LiveChatStatus.ready);
      expect(bloc.state.sessionAddress, sessionAddress);
      expect(bloc.state.messages, <LiveChatMessage>[firstMessage]);

      verify(
        () => mockRepository.watchChatMessages(sessionAddress: sessionAddress),
      ).called(1);

      await bloc.close();
    });

    test('send request trims content and publishes the message', () async {
      final bloc = LiveChatBloc(liveChatRepository: mockRepository);

      bloc.add(const LiveChatStarted(sessionAddress: sessionAddress));
      await _flush();

      messagesController.add(<LiveChatMessage>[firstMessage]);
      await _flush();

      bloc.add(const LiveChatMessageSendRequested('  Hello room  '));
      await _flush();

      expect(bloc.state.isSending, isFalse);
      expect(bloc.state.errorMessage, isNull);
      verify(
        () => mockRepository.publishMessage(
          sessionAddress: sessionAddress,
          content: 'Hello room',
        ),
      ).called(1);

      await bloc.close();
    });
  });
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
