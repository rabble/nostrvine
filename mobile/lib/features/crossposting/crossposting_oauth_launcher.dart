// ABOUTME: Launches crossposting OAuth through the shared Divine OAuth
// ABOUTME: session. Accepts only Divine's exact HTTPS callback route.

import 'package:openvine/services/oauth/app_oauth_callback.dart';

/// Authentication seam matching the arguments used by `FlutterWebAuth2`.
typedef CrosspostingAuthenticate = AppOAuthAuthenticate;

/// Opens [authorizationUri] in the native OAuth session and returns its
/// callback, or null when the user dismissed the session.
///
/// The HTTPS universal-link callback relies on
/// `ASWebAuthenticationSession.Callback.https(host:path:)`, available on
/// iOS 17.4+; older iOS can silently report a completed connection as a
/// cancel. The app floor stays at iOS 16.0, so the flow is gated at runtime
/// instead: `crosspostingOAuthSupportProvider` hides it where this path is
/// unreliable.
Future<Uri?> launchCrosspostingOAuth(
  Uri authorizationUri, {
  CrosspostingAuthenticate? authenticate,
}) {
  return authenticate == null
      ? launchAppOAuth(authorizationUri)
      : launchAppOAuth(authorizationUri, authenticate: authenticate);
}
