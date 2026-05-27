import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';

/// Defers login-options navigation until in-flight background uploads finish.
class DeferredLoginOptionsNavigator {
  StreamSubscription<BackgroundPublishState>? _subscription;
  var _isDisposed = false;

  void dispose() {
    _isDisposed = true;
    _subscription?.cancel();
    _subscription = null;
  }

  void goAfterUploadsComplete({
    required BuildContext context,
    required BackgroundPublishBloc publishBloc,
  }) {
    if (_isDisposed) return;
    final router = GoRouter.of(context);

    _subscription?.cancel();
    _subscription = publishBloc.stream.listen((state) {
      if (!state.hasUploadInProgress) {
        _navigateNow(router);
      }
    });

    // Re-check current state now that the listener is attached. If the last
    // upload already finished before we subscribed, no further emission will
    // arrive and we must navigate immediately.
    if (!publishBloc.state.hasUploadInProgress) {
      _navigateNow(router);
    }
  }

  void _navigateNow(GoRouter router) {
    if (_isDisposed) return;
    _subscription?.cancel();
    _subscription = null;
    router.go(WelcomeScreen.loginOptionsPath);
  }
}
