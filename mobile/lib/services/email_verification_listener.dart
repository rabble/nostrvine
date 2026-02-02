// ABOUTME: Service to listen for email verification deep links
// ABOUTME: Handles verify-email redirects from login.divine.video

import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/auth/email_verification_screen.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Service to listen for email verification redirects (deeplinks)
class EmailVerificationListener {
  EmailVerificationListener(this.ref);
  final Ref ref;

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;

  /// Initialize listeners for both cold starts and background resumes
  void initialize() {
    Log.info(
      'Initializing email verification listener...',
      name: '$EmailVerificationListener',
      category: LogCategory.auth,
    );

    // Handle link that launches the app from a closed state
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleUri(uri);
    });

    // Handle links while app is running in background
    _subscription = _appLinks.uriLinkStream.listen(_handleUri);
  }

  Future<void> _handleUri(Uri uri) async {
    Log.info(
      'Callback from host ${uri.host} path: ${uri.path}',
      name: '$EmailVerificationListener',
      category: LogCategory.auth,
    );

    if (uri.host != 'login.divine.video' ||
        !uri.path.startsWith(EmailVerificationScreen.path)) {
      return;
    }

    Log.info(
      'Email verification callback detected: $uri',
      name: '$EmailVerificationListener',
      category: LogCategory.auth,
    );

    final params = uri.queryParameters;

    if (params.containsKey('token')) {
      final token = params['token'];
      final router = ref.read(goRouterProvider);
      router.go('${EmailVerificationScreen.path}?token=$token');
    }
  }

  void dispose() {
    _subscription?.cancel();
    Log.info(
      '$EmailVerificationListener disposed',
      name: '$EmailVerificationListener',
      category: LogCategory.auth,
    );
  }
}
