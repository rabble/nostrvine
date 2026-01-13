import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/utils/unified_logger.dart';

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
      if (uri != null) _handleUri(uri);
    });

    // Handle links while app is running in background
    _subscription = _appLinks.uriLinkStream.listen(_handleUri);
  }

  Future<void> _handleUri(Uri uri) async {
    Log.info(
      '🔑 callback from host ${uri.host} path: ${uri.path}',
      name: '$PasswordResetListener',
    );

    if (uri.host != 'login.divine.video' ||
        !uri.path.startsWith('/reset-password')) {
      return;
    }

    Log.info(
      '🔑 Password reset callback detected: $uri',
      name: '$PasswordResetListener',
    );

    final params = uri.queryParameters;

    if (params.containsKey('token')) {
      final token = params['token'];
      final router = ref.read(goRouterProvider);
      router.go('/reset-password?token=$token');
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
