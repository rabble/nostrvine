import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:invite_api_client/invite_api_client.dart';

void main() {
  group('InviteApiException', () {
    test('cause defaults to null', () {
      const exception = InviteApiException('test error');
      expect(exception.cause, isNull);
    });

    test('preserves cause when provided', () {
      final cause = TimeoutException('timed out');
      final exception = InviteApiException(
        'Request failed',
        cause: cause,
      );
      expect(exception.cause, same(cause));
    });

    test('toString includes cause runtimeType when present', () {
      final exception = InviteApiException(
        'Request failed',
        code: InviteApiErrorCode.clientTimeout,
        cause: TimeoutException('timed out'),
      );
      final str = exception.toString();
      expect(str, contains('TimeoutException'));
    });

    test('toString omits cause when null', () {
      const exception = InviteApiException(
        'Request failed',
        code: InviteApiErrorCode.clientTimeout,
      );
      final str = exception.toString();
      expect(str, isNot(contains('cause')));
    });

    test('const constructor still works without cause', () {
      const exception = InviteApiException(
        'test',
        statusCode: 401,
        code: InviteApiErrorCode.authInvalid,
      );
      expect(exception.message, 'test');
      expect(exception.statusCode, 401);
      expect(exception.cause, isNull);
    });

    test('preserves SocketException as cause', () {
      const cause = SocketException('Connection refused');
      const exception = InviteApiException(
        'Network error',
        code: InviteApiErrorCode.clientNetworkError,
        cause: cause,
      );
      expect(exception.cause, isA<SocketException>());
      expect(exception.cause.toString(), contains('Connection refused'));
    });
  });
}
