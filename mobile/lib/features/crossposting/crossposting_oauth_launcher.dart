// ABOUTME: Launches crossposting OAuth through flutter_web_auth_2.
// ABOUTME: Accepts only Divine's exact HTTPS callback route.

import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

const _invalidCallbackMessage =
    'Invalid crossposting OAuth callback. Expected '
    'https://divine.video/app/callback with no user info or explicit port.';
const _callbackPrefix = 'https://';
final _authorityTerminator = RegExp(r'[/#?]');
final _malformedPercentTriplet = RegExp(r'%(?![0-9A-Fa-f]{2})');

/// Authentication seam matching the arguments used by [FlutterWebAuth2].
typedef CrosspostingAuthenticate =
    Future<String> Function({
      required String url,
      required String callbackUrlScheme,
      required FlutterWebAuth2Options options,
    });

/// Opens [authorizationUri] in the native OAuth session and returns its callback.
Future<Uri?> launchCrosspostingOAuth(
  Uri authorizationUri, {
  CrosspostingAuthenticate authenticate = _authenticate,
}) async {
  try {
    final callback = await authenticate(
      url: authorizationUri.toString(),
      callbackUrlScheme: 'https',
      options: const FlutterWebAuth2Options(
        httpsHost: 'divine.video',
        httpsPath: '/app/callback',
      ),
    );
    return _parseCallback(callback);
  } on PlatformException catch (error) {
    if (error.code == 'CANCELED') return null;
    rethrow;
  }
}

Uri _parseCallback(String callback) {
  if (_malformedPercentTriplet.hasMatch(callback) ||
      !_hasExactRawAuthority(callback)) {
    throw const FormatException(_invalidCallbackMessage);
  }

  late final Uri uri;
  try {
    uri = Uri.parse(callback);
  } on FormatException {
    throw const FormatException(_invalidCallbackMessage);
  }

  if (uri.scheme != 'https' ||
      uri.host != 'divine.video' ||
      uri.path != '/app/callback' ||
      uri.hasPort ||
      uri.authority.contains('@')) {
    throw const FormatException(_invalidCallbackMessage);
  }
  return uri;
}

bool _hasExactRawAuthority(String callback) {
  if (!callback.startsWith(_callbackPrefix)) return false;

  final authorityStart = _callbackPrefix.length;
  final terminator = callback.indexOf(_authorityTerminator, authorityStart);
  final authorityEnd = terminator == -1 ? callback.length : terminator;
  return callback.substring(authorityStart, authorityEnd) == 'divine.video';
}

Future<String> _authenticate({
  required String url,
  required String callbackUrlScheme,
  required FlutterWebAuth2Options options,
}) => FlutterWebAuth2.authenticate(
  url: url,
  callbackUrlScheme: callbackUrlScheme,
  options: options,
);
