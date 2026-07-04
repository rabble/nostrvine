// ABOUTME: Tests the sanctioned-override + heal-and-blame harness for #5738.
// ABOUTME: Each test heals within itself so the root tearDown sees no leak.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_setup.dart';
import 'shared_channel_override.dart';

const MethodChannel _secureStorage = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

TestDefaultBinaryMessenger get _messenger =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

Future<Object?>? _leakHandler(MethodCall call) async => null;

SharedChannelHandler get _canonical =>
    canonicalSharedHandlers[_secureStorage.name]!;

void main() {
  group('overrideSharedChannel', () {
    test('installs the override and sanctions the channel', () {
      expect(
        _messenger.checkMockMessageHandler(_secureStorage.name, _canonical),
        isTrue,
      );

      overrideSharedChannel(_secureStorage, _leakHandler);

      expect(
        _messenger.checkMockMessageHandler(_secureStorage.name, _leakHandler),
        isTrue,
      );
      expect(sanctionedChannels, contains(_secureStorage.name));
      expect(findSharedChannelViolations(), isEmpty);
    });

    test('auto-restored the canonical handler after the previous test', () {
      expect(
        _messenger.checkMockMessageHandler(_secureStorage.name, _canonical),
        isTrue,
      );
      expect(sanctionedChannels, isNot(contains(_secureStorage.name)));
    });

    test('asserts when the channel is not a shared channel', () {
      expect(
        () => overrideSharedChannel(
          const MethodChannel('test.local.not_shared'),
          _leakHandler,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('findSharedChannelViolations', () {
    test('is empty when every shared channel is canonical', () {
      expect(findSharedChannelViolations(), isEmpty);
    });

    test('flags a shared channel replaced without a sanction', () {
      _messenger.setMockMethodCallHandler(_secureStorage, _leakHandler);
      addTearDown(() => restoreSharedChannel(_secureStorage));

      expect(findSharedChannelViolations(), contains(_secureStorage.name));
    });
  });

  group('healAndBlameSharedChannels', () {
    test('non-strict heals the violation and does not throw', () {
      _messenger.setMockMethodCallHandler(_secureStorage, _leakHandler);

      healAndBlameSharedChannels(strict: false);

      expect(findSharedChannelViolations(), isEmpty);
      expect(
        _messenger.checkMockMessageHandler(_secureStorage.name, _canonical),
        isTrue,
      );
    });

    test('strict heals AND fails the test with a TestFailure', () {
      _messenger.setMockMethodCallHandler(_secureStorage, _leakHandler);

      expect(
        () => healAndBlameSharedChannels(strict: true),
        throwsA(isA<TestFailure>()),
      );
      // Healing runs before the blame, so the channel is canonical again.
      expect(findSharedChannelViolations(), isEmpty);
    });
  });
}
