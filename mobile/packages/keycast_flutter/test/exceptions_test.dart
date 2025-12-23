// ABOUTME: Tests for Keycast custom exceptions
// ABOUTME: Verifies exception types, messages, and inheritance hierarchy

import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/src/models/exceptions.dart';

void main() {
  group('KeycastException', () {
    test('stores message', () {
      final exception = KeycastException('test message');
      expect(exception.message, 'test message');
    });

    test('toString includes message', () {
      final exception = KeycastException('test message');
      expect(exception.toString(), contains('test message'));
    });
  });

  group('SessionExpiredException', () {
    test('extends KeycastException', () {
      final exception = SessionExpiredException();
      expect(exception, isA<KeycastException>());
    });

    test('has default message', () {
      final exception = SessionExpiredException();
      expect(exception.message, contains('expired'));
    });

    test('accepts custom message', () {
      final exception = SessionExpiredException('custom expired message');
      expect(exception.message, 'custom expired message');
    });
  });

  group('OAuthException', () {
    test('extends KeycastException', () {
      final exception = OAuthException('oauth error');
      expect(exception, isA<KeycastException>());
    });

    test('stores error code', () {
      final exception = OAuthException('desc', errorCode: 'invalid_request');
      expect(exception.errorCode, 'invalid_request');
    });

    test('errorCode is optional', () {
      final exception = OAuthException('oauth error');
      expect(exception.errorCode, isNull);
    });
  });

  group('RpcException', () {
    test('extends KeycastException', () {
      final exception = RpcException('rpc error');
      expect(exception, isA<KeycastException>());
    });

    test('stores method name', () {
      final exception = RpcException('failed', method: 'sign_event');
      expect(exception.method, 'sign_event');
    });

    test('method is optional', () {
      final exception = RpcException('rpc error');
      expect(exception.method, isNull);
    });
  });

  group('InvalidKeyException', () {
    test('extends KeycastException', () {
      final exception = InvalidKeyException('bad key');
      expect(exception, isA<KeycastException>());
    });
  });
}
