// ABOUTME: Pure router helper functions shared between route modules and tests
// ABOUTME: Kept dependency-free of app_router.dart so route modules import them cycle-free

import 'package:openvine/screens/auth/welcome_screen.dart';

/// Rewrites a `/reset-password` deep link to the nested
/// [WelcomeScreen.resetPasswordPath] route, preserving `token` and
/// optional `email` query params.
///
/// Shared by the auth reset-password route redirect and the router-level
/// regression test so both paths produce the same output for the same
/// input. See issue #3156.
String rewriteResetPasswordDeepLink(Uri uri) {
  final token = uri.queryParameters['token'] ?? '';
  final email = uri.queryParameters['email'];
  final buffer = StringBuffer(WelcomeScreen.resetPasswordPath)
    ..write('?token=')
    ..write(Uri.encodeQueryComponent(token));
  if (email != null && email.isNotEmpty) {
    buffer
      ..write('&email=')
      ..write(Uri.encodeQueryComponent(email));
  }
  return buffer.toString();
}

int homeInitialIndexFromPathParameters(Map<String, String> pathParameters) {
  final rawIndex = int.tryParse(pathParameters['index'] ?? '') ?? 0;
  return rawIndex < 0 ? 0 : rawIndex;
}
