// ABOUTME: Tests the canonical shared-channel registry in test_setup.dart (#5738).
// ABOUTME: Verifies identities are recorded and the restore helpers reinstall them.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_setup.dart';

TestDefaultBinaryMessenger get _messenger =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

Future<Object?>? _foreign(MethodCall call) async => null;

void main() {
  test('registers a canonical handler for every shared channel', () {
    expect(
      canonicalSharedHandlers.keys.toSet(),
      equals(sharedChannelNames),
    );
    for (final name in sharedChannelNames) {
      expect(
        _messenger.checkMockMessageHandler(name, canonicalSharedHandlers[name]),
        isTrue,
        reason: '$name should carry its canonical handler after setup',
      );
    }
  });

  test('restoreSharedChannel reinstalls one channel canonical', () {
    const channel = MethodChannel('plugins.flutter.io/image_picker');
    _messenger.setMockMethodCallHandler(channel, _foreign);
    expect(
      _messenger.checkMockMessageHandler(
        channel.name,
        canonicalSharedHandlers[channel.name],
      ),
      isFalse,
    );

    restoreSharedChannel(channel);

    expect(
      _messenger.checkMockMessageHandler(
        channel.name,
        canonicalSharedHandlers[channel.name],
      ),
      isTrue,
    );
  });

  test('restoreSharedChannelDefaults reinstalls all shared channels', () {
    for (final name in sharedChannelNames) {
      _messenger.setMockMethodCallHandler(MethodChannel(name), _foreign);
    }

    restoreSharedChannelDefaults();

    for (final name in sharedChannelNames) {
      expect(
        _messenger.checkMockMessageHandler(name, canonicalSharedHandlers[name]),
        isTrue,
        reason: '$name should be canonical after restoreSharedChannelDefaults',
      );
    }
  });
}
