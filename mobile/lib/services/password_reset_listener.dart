import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/auth/reset_password.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:unified_logger/unified_logger.dart';

/// Service to listen for Password Reset redirects (deeplinks)
class PasswordResetListener {
  PasswordResetListener(this.ref);
  final Ref ref;

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;

  /// Initialize listeners for both cold starts and background resumes
  void initialize() {
    Log.info(
      '🔑 Initializing password reset listener...',
      name: '$PasswordResetListener',
    );

    // Handle link that launches the app from a closed state
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) handleUri(uri);
    });

    // Handle links while app is running in background
    _subscription = _appLinks.uriLinkStream.listen(handleUri);
  }

  @visibleForTesting
  Future<void> handleUri(Uri uri) async {
    Log.info(
      '🔑 callback from host ${uri.host} path: ${uri.path}',
      name: '$PasswordResetListener',
    );

    if (uri.host != 'login.divine.video' ||
        !uri.path.startsWith(ResetPasswordScreen.path)) {
      return;
    }

    // Log path only — query params can contain the account email (PII).
    Log.info(
      '🔑 Password reset callback detected for path: ${uri.path}',
      name: '$PasswordResetListener',
    );

    final params = uri.queryParameters;

    if (params.containsKey('token')) {
      final token = params['token']!;
      final email = params['email'];
      final router = ref.read(goRouterProvider);
      final buffer = StringBuffer(WelcomeScreen.resetPasswordPath)
        ..write('?token=')
        ..write(Uri.encodeQueryComponent(token));
      if (email != null && email.isNotEmpty) {
        buffer
          ..write('&email=')
          ..write(Uri.encodeQueryComponent(email));
      }
      router.go(buffer.toString());
    }
  }

  void dispose() {
    _subscription?.cancel();
    Log.info(
      '🔑 $PasswordResetListener disposed',
      name: '$PasswordResetListener',
    );
  }
}
