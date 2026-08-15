// ABOUTME: Providers for the deep-link listeners that route verification links
// ABOUTME: Lives in the router layer because both listeners navigate via goRouterProvider

import 'package:openvine/services/email_verification_listener.dart';
import 'package:openvine/services/password_reset_listener.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'deep_link_listeners.g.dart';

/// Listens for `login.divine.video` password-reset deep links.
///
/// Declared here rather than in `auth_providers.dart` so the provider layer
/// does not depend on a service that navigates through the router — that edge
/// put every auth-adjacent provider on a cycle back through the UI layer.
@Riverpod(keepAlive: true)
PasswordResetListener passwordResetListener(Ref ref) {
  final listener = PasswordResetListener(ref);
  ref.onDispose(listener.dispose);
  return listener;
}

/// Listens for `login.divine.video` email-verification deep links.
@Riverpod(keepAlive: true)
EmailVerificationListener emailVerificationListener(Ref ref) {
  final listener = EmailVerificationListener(ref);
  ref.onDispose(listener.dispose);
  return listener;
}
