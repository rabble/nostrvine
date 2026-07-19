import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_cache/media_cache.dart';
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

    test('classifies dart:_http missing-host URI failures as recoverable', () {
      final details = FlutterErrorDetails(
        exception: ArgumentError('No host specified in URI https:///thumb.jpg'),
        library: 'dart:_http',
      );

      expect(
        classifyRecoverableFlutterError(details),
        'Recoverable media load failure',
      );
    });

    test('classifies MediaCacheImageProvider download-without-file failures as '
        'recoverable regardless of host', () {
      // Dead legacy Vine avatars are commonly served through
      // web.archive.org, which is not in the recoverable-media host set —
      // the exception type alone must classify it, so the broken avatar
      // falls back to a placeholder instead of a fatal crash (#5782 follow
      // up: the download-without-file branch was still reported as fatal).
      const details = FlutterErrorDetails(
        exception: MediaCacheImageLoadException(
          'https://web.archive.org/web/20150907190604/'
          'http://v.cdn.vine.co/r/avatars/broken.jpg',
        ),
        library: 'package:media_cache/src/media_cache_image_provider.dart',
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

    test(
      'does not classify hardware keyboard assertion errors as recoverable',
      () {
        // Keyboard framework errors are not special-cased anywhere: they must
        // reach crash reporting through the normal chain (#4115).
        final details = FlutterErrorDetails(
          exception: AssertionError(
            'A KeyDownEvent is dispatched, but the state shows that the '
            'physical key is already pressed. HardwareKeyboard is in an '
            'inconsistent state.',
          ),
          library: 'services library',
        );

        expect(classifyRecoverableFlutterError(details), isNull);
      },
    );
  });
}
