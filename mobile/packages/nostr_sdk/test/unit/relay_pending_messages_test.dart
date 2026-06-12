// ABOUTME: Regression tests for Relay pending-message replay on reconnect.
// ABOUTME: Ensures failed replays are re-queued without corrupting iteration.

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

class _RequeueingRelay extends Relay {
  _RequeueingRelay(String url, {required this.failedMessage})
    : super(url, RelayStatus(url));

  final List<dynamic> failedMessage;
  final List<List<dynamic>> sentMessages = [];

  @override
  Future<bool> doConnect() async => true;

  @override
  Future<void> disconnect() async {}

  @override
  Future<bool> send(
    List<dynamic> message, {
    bool? forceSend,
    bool queueIfFailed = true,
    bool skipReconnect = false,
    DateTime? deadline,
  }) async {
    sentMessages.add(List<dynamic>.from(message));

    if (_messagesEqual(message, failedMessage)) {
      if (queueIfFailed) {
        pendingMessages.add(message);
      }
      return false;
    }

    return true;
  }

  bool _messagesEqual(List<dynamic> a, List<dynamic> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

void main() {
  group('Relay pending-message replay', () {
    test(
      're-queues failed sends without mutating the active iteration',
      () async {
        final failedMessage = [
          'EVENT',
          {'id': 'retry'},
        ];
        final relay =
            _RequeueingRelay(
                'wss://relay.example',
                failedMessage: failedMessage,
              )
              ..pendingMessages.addAll([
                [
                  'EVENT',
                  {'id': 'sent'},
                ],
                failedMessage,
              ]);

        await expectLater(relay.onConnected(source: 'test'), completes);

        expect(relay.sentMessages, [
          [
            'EVENT',
            {'id': 'sent'},
          ],
          failedMessage,
        ]);
        expect(relay.pendingMessages, [failedMessage]);
      },
    );
  });
}
