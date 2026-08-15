// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'deep_link_listeners.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Listens for `login.divine.video` password-reset deep links.
///
/// Declared here rather than in `auth_providers.dart` so the provider layer
/// does not depend on a service that navigates through the router — that edge
/// put every auth-adjacent provider on a cycle back through the UI layer.

@ProviderFor(passwordResetListener)
final passwordResetListenerProvider = PasswordResetListenerProvider._();

/// Listens for `login.divine.video` password-reset deep links.
///
/// Declared here rather than in `auth_providers.dart` so the provider layer
/// does not depend on a service that navigates through the router — that edge
/// put every auth-adjacent provider on a cycle back through the UI layer.

final class PasswordResetListenerProvider
    extends
        $FunctionalProvider<
          PasswordResetListener,
          PasswordResetListener,
          PasswordResetListener
        >
    with $Provider<PasswordResetListener> {
  /// Listens for `login.divine.video` password-reset deep links.
  ///
  /// Declared here rather than in `auth_providers.dart` so the provider layer
  /// does not depend on a service that navigates through the router — that edge
  /// put every auth-adjacent provider on a cycle back through the UI layer.
  PasswordResetListenerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'passwordResetListenerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$passwordResetListenerHash();

  @$internal
  @override
  $ProviderElement<PasswordResetListener> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PasswordResetListener create(Ref ref) {
    return passwordResetListener(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PasswordResetListener value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PasswordResetListener>(value),
    );
  }
}

String _$passwordResetListenerHash() =>
    r'3fe0dd6870cd754567aaaf53b5b74f439f232ad4';

/// Listens for `login.divine.video` email-verification deep links.

@ProviderFor(emailVerificationListener)
final emailVerificationListenerProvider = EmailVerificationListenerProvider._();

/// Listens for `login.divine.video` email-verification deep links.

final class EmailVerificationListenerProvider
    extends
        $FunctionalProvider<
          EmailVerificationListener,
          EmailVerificationListener,
          EmailVerificationListener
        >
    with $Provider<EmailVerificationListener> {
  /// Listens for `login.divine.video` email-verification deep links.
  EmailVerificationListenerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'emailVerificationListenerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$emailVerificationListenerHash();

  @$internal
  @override
  $ProviderElement<EmailVerificationListener> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  EmailVerificationListener create(Ref ref) {
    return emailVerificationListener(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EmailVerificationListener value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EmailVerificationListener>(value),
    );
  }
}

String _$emailVerificationListenerHash() =>
    r'3ddc56da4619f64800573667612a6fa9af75395e';
