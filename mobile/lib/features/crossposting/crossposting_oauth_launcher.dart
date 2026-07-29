// ABOUTME: Launches crossposting OAuth through flutter_web_auth_2.
// ABOUTME: Accepts only Divine's exact HTTPS callback route.

import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:openvine/features/crossposting/crossposting_callback.dart';

const _invalidCallbackMessage =
    'Invalid crossposting OAuth callback. Expected '
    '$crosspostingOAuthCallbackScheme://$crosspostingOAuthCallbackHost'
    '$crosspostingOAuthCallbackPath with no user info or explicit port.';
const _callbackPrefix = '$crosspostingOAuthCallbackScheme://';
final _authorityTerminator = RegExp('[/#?]');
final _malformedPercentTriplet = RegExp('%(?![0-9A-Fa-f]{2})');

/// Authentication seam matching the arguments used by [FlutterWebAuth2].
typedef CrosspostingAuthenticate =
    Future<String> Function({
      required String url,
      required String callbackUrlScheme,
      required FlutterWebAuth2Options options,
    });

/// Opens [authorizationUri] in the native OAuth session and returns its callback.
///
/// The HTTPS universal-link callback relies on
/// `ASWebAuthenticationSession.Callback.https(host:path:)`, available on
/// iOS 17.4+; older iOS can silently report a completed connection as a
/// cancel. The app floor stays at iOS 16.0, so the flow is gated at runtime
/// instead: `crosspostingOAuthSupportProvider` hides it where this path is
/// unreliable.
Future<Uri?> launchCrosspostingOAuth(
  Uri authorizationUri, {
  CrosspostingAuthenticate authenticate = _authenticate,
}) async {
  try {
    final callback = await authenticate(
      url: authorizationUri.toString(),
      callbackUrlScheme: crosspostingOAuthCallbackScheme,
      options: const FlutterWebAuth2Options(
        httpsHost: crosspostingOAuthCallbackHost,
        httpsPath: crosspostingOAuthCallbackPath,
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

  if (uri.scheme != crosspostingOAuthCallbackScheme ||
      uri.host != crosspostingOAuthCallbackHost ||
      uri.path != crosspostingOAuthCallbackPath ||
      uri.hasPort ||
      uri.authority.contains('@')) {
    throw const FormatException(_invalidCallbackMessage);
  }
  return uri;
}

bool _hasExactRawAuthority(String callback) {
  if (!callback.startsWith(_callbackPrefix)) return false;

  const authorityStart = _callbackPrefix.length;
  final terminator = callback.indexOf(_authorityTerminator, authorityStart);
  final authorityEnd = terminator == -1 ? callback.length : terminator;
  return callback.substring(authorityStart, authorityEnd) ==
      crosspostingOAuthCallbackHost;
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
