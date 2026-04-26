import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/recoverable_flutter_error.dart';

void main() {
  group('classifyRecoverableFlutterError', () {
    test('classifies image 404 codec failures as recoverable', () {
      final details = FlutterErrorDetails(
        exception: Exception(
          'HTTP request failed, statusCode: 404, '
          'https://cdn.divine.video/test/thumbnails/thumbnail.jpg. '
          'Error thrown resolving an image codec.',
        ),
        library: 'package:flutter/src/painting/_network_image_io.dart',
      );

      expect(
        classifyRecoverableFlutterError(details),
        'Recoverable media load failure',
      );
    });

    test('classifies Divine media host lookup failures as recoverable', () {
      const details = FlutterErrorDetails(
        exception: SocketException("Failed host lookup: 'media.divine.video'"),
        library: 'dart:_http',
      );

      expect(
        classifyRecoverableFlutterError(details),
        'Recoverable media load failure',
      );
    });

    test('classifies invalid image data failures as recoverable', () {
      const details = FlutterErrorDetails(
        exception: FormatException('Invalid image data.'),
        library: 'dart:ui',
      );

      expect(
        classifyRecoverableFlutterError(details),
        'Recoverable media load failure',
      );
    });

    test('classifies interrupted Divine media downloads as recoverable', () {
      const details = FlutterErrorDetails(
        exception: HttpException(
          'Connection closed while receiving data, '
          'uri = https://media.divine.video/hash',
        ),
        library: 'dart:_http',
      );

      expect(
        classifyRecoverableFlutterError(details),
        'Recoverable media load failure',
      );
    });

    test('does not classify unrelated gesture errors as recoverable', () {
      final details = FlutterErrorDetails(
        exception: Exception('GoError: There is nothing to pop.'),
        library: 'package:go_router/src/delegate.dart',
      );

      expect(classifyRecoverableFlutterError(details), isNull);
    });
  });
}
