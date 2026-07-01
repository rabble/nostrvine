// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Secure key storage service (foundational service)

@ProviderFor(secureKeyStorage)
final secureKeyStorageProvider = SecureKeyStorageProvider._();

/// Secure key storage service (foundational service)

final class SecureKeyStorageProvider
    extends
        $FunctionalProvider<
          SecureKeyStorage,
          SecureKeyStorage,
          SecureKeyStorage
        >
    with $Provider<SecureKeyStorage> {
  /// Secure key storage service (foundational service)
  SecureKeyStorageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'secureKeyStorageProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$secureKeyStorageHash();

  @$internal
  @override
  $ProviderElement<SecureKeyStorage> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SecureKeyStorage create(Ref ref) {
    return secureKeyStorage(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SecureKeyStorage value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SecureKeyStorage>(value),
    );
  }
}

String _$secureKeyStorageHash() => r'853547d439994307884d2f47f3d9769daa0a1e96';

@ProviderFor(oauthConfig)
final oauthConfigProvider = OauthConfigProvider._();

final class OauthConfigProvider
    extends $FunctionalProvider<OAuthConfig, OAuthConfig, OAuthConfig>
    with $Provider<OAuthConfig> {
  OauthConfigProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'oauthConfigProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$oauthConfigHash();

  @$internal
  @override
  $ProviderElement<OAuthConfig> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  OAuthConfig create(Ref ref) {
    return oauthConfig(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OAuthConfig value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OAuthConfig>(value),
    );
  }
}

String _$oauthConfigHash() => r'2078bce919b9216a65dedc105d471568ba510a52';

@ProviderFor(flutterSecureStorage)
final flutterSecureStorageProvider = FlutterSecureStorageProvider._();

final class FlutterSecureStorageProvider
    extends
        $FunctionalProvider<
          FlutterSecureStorage,
          FlutterSecureStorage,
          FlutterSecureStorage
        >
    with $Provider<FlutterSecureStorage> {
  FlutterSecureStorageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'flutterSecureStorageProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$flutterSecureStorageHash();

  @$internal
  @override
  $ProviderElement<FlutterSecureStorage> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FlutterSecureStorage create(Ref ref) {
    return flutterSecureStorage(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FlutterSecureStorage value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FlutterSecureStorage>(value),
    );
  }
}

String _$flutterSecureStorageHash() =>
    r'8abafc8e21f68ced2b337c0e5040ab0d6cdb9eeb';

@ProviderFor(secureKeycastStorage)
final secureKeycastStorageProvider = SecureKeycastStorageProvider._();

final class SecureKeycastStorageProvider
    extends
        $FunctionalProvider<
          SecureKeycastStorage,
          SecureKeycastStorage,
          SecureKeycastStorage
        >
    with $Provider<SecureKeycastStorage> {
  SecureKeycastStorageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'secureKeycastStorageProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$secureKeycastStorageHash();

  @$internal
  @override
  $ProviderElement<SecureKeycastStorage> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SecureKeycastStorage create(Ref ref) {
    return secureKeycastStorage(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SecureKeycastStorage value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SecureKeycastStorage>(value),
    );
  }
}

String _$secureKeycastStorageHash() =>
    r'c57c0ec02e36cd1a0cc8b850c450af2eb4c496b3';

@ProviderFor(pendingVerificationService)
final pendingVerificationServiceProvider =
    PendingVerificationServiceProvider._();

final class PendingVerificationServiceProvider
    extends
        $FunctionalProvider<
          PendingVerificationService,
          PendingVerificationService,
          PendingVerificationService
        >
    with $Provider<PendingVerificationService> {
  PendingVerificationServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pendingVerificationServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pendingVerificationServiceHash();

  @$internal
  @override
  $ProviderElement<PendingVerificationService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PendingVerificationService create(Ref ref) {
    return pendingVerificationService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PendingVerificationService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PendingVerificationService>(value),
    );
  }
}

String _$pendingVerificationServiceHash() =>
    r'9b524b7d7fd20c98b2e0942e9ea6358419dc9dd4';

@ProviderFor(oauthClient)
final oauthClientProvider = OauthClientProvider._();

final class OauthClientProvider
    extends $FunctionalProvider<KeycastOAuth, KeycastOAuth, KeycastOAuth>
    with $Provider<KeycastOAuth> {
  OauthClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'oauthClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$oauthClientHash();

  @$internal
  @override
  $ProviderElement<KeycastOAuth> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  KeycastOAuth create(Ref ref) {
    return oauthClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(KeycastOAuth value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<KeycastOAuth>(value),
    );
  }
}

String _$oauthClientHash() => r'0cc53348fbc3c769c81e52dd200c0efc6c20de3c';

@ProviderFor(passwordResetListener)
final passwordResetListenerProvider = PasswordResetListenerProvider._();

final class PasswordResetListenerProvider
    extends
        $FunctionalProvider<
          PasswordResetListener,
          PasswordResetListener,
          PasswordResetListener
        >
    with $Provider<PasswordResetListener> {
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

@ProviderFor(emailVerificationListener)
final emailVerificationListenerProvider = EmailVerificationListenerProvider._();

final class EmailVerificationListenerProvider
    extends
        $FunctionalProvider<
          EmailVerificationListener,
          EmailVerificationListener,
          EmailVerificationListener
        >
    with $Provider<EmailVerificationListener> {
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

/// Web authentication service (for web platform only)

@ProviderFor(webAuthService)
final webAuthServiceProvider = WebAuthServiceProvider._();

/// Web authentication service (for web platform only)

final class WebAuthServiceProvider
    extends $FunctionalProvider<WebAuthService, WebAuthService, WebAuthService>
    with $Provider<WebAuthService> {
  /// Web authentication service (for web platform only)
  WebAuthServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'webAuthServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$webAuthServiceHash();

  @$internal
  @override
  $ProviderElement<WebAuthService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  WebAuthService create(Ref ref) {
    return webAuthService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WebAuthService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WebAuthService>(value),
    );
  }
}

String _$webAuthServiceHash() => r'53411c0f6a62bb9b59f90a0d7fc738a553a0b575';

/// Authentication service

@ProviderFor(authService)
final authServiceProvider = AuthServiceProvider._();

/// Authentication service

final class AuthServiceProvider
    extends $FunctionalProvider<AuthService, AuthService, AuthService>
    with $Provider<AuthService> {
  /// Authentication service
  AuthServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authServiceHash();

  @$internal
  @override
  $ProviderElement<AuthService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AuthService create(Ref ref) {
    return authService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthService>(value),
    );
  }
}

String _$authServiceHash() => r'f92bfcd639fa7dcef969befb2fb50db08e2aba14';

/// Provider that returns current auth state and rebuilds when it changes.
/// Widgets should watch this instead of authService.authState directly
/// to get automatic rebuilds when authentication state changes.

@ProviderFor(currentAuthState)
final currentAuthStateProvider = CurrentAuthStateProvider._();

/// Provider that returns current auth state and rebuilds when it changes.
/// Widgets should watch this instead of authService.authState directly
/// to get automatic rebuilds when authentication state changes.

final class CurrentAuthStateProvider
    extends $FunctionalProvider<AuthState, AuthState, AuthState>
    with $Provider<AuthState> {
  /// Provider that returns current auth state and rebuilds when it changes.
  /// Widgets should watch this instead of authService.authState directly
  /// to get automatic rebuilds when authentication state changes.
  CurrentAuthStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentAuthStateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentAuthStateHash();

  @$internal
  @override
  $ProviderElement<AuthState> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AuthState create(Ref ref) {
    return currentAuthState(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthState>(value),
    );
  }
}

String _$currentAuthStateHash() => r'41c987ffc8f661555bab3ebec9078180411f66eb';

/// Provider that returns current RPC capability and rebuilds on changes.
///
/// Widgets and repositories should watch this instead of polling
/// [AuthService.authRpcCapability] directly.

@ProviderFor(currentAuthRpcCapability)
final currentAuthRpcCapabilityProvider = CurrentAuthRpcCapabilityProvider._();

/// Provider that returns current RPC capability and rebuilds on changes.
///
/// Widgets and repositories should watch this instead of polling
/// [AuthService.authRpcCapability] directly.

final class CurrentAuthRpcCapabilityProvider
    extends
        $FunctionalProvider<
          AuthRpcCapability,
          AuthRpcCapability,
          AuthRpcCapability
        >
    with $Provider<AuthRpcCapability> {
  /// Provider that returns current RPC capability and rebuilds on changes.
  ///
  /// Widgets and repositories should watch this instead of polling
  /// [AuthService.authRpcCapability] directly.
  CurrentAuthRpcCapabilityProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentAuthRpcCapabilityProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentAuthRpcCapabilityHash();

  @$internal
  @override
  $ProviderElement<AuthRpcCapability> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AuthRpcCapability create(Ref ref) {
    return currentAuthRpcCapability(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthRpcCapability value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthRpcCapability>(value),
    );
  }
}

String _$currentAuthRpcCapabilityHash() =>
    r'cb273f3377e25d0c88104df14a38d2b502c3f7de';

/// Provider that fetches the list of known accounts from the auth service.
///
/// Invalidate this provider after sign-in or sign-out to refresh the list.

@ProviderFor(knownAccounts)
final knownAccountsProvider = KnownAccountsProvider._();

/// Provider that fetches the list of known accounts from the auth service.
///
/// Invalidate this provider after sign-in or sign-out to refresh the list.

final class KnownAccountsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<KnownAccount>>,
          List<KnownAccount>,
          FutureOr<List<KnownAccount>>
        >
    with
        $FutureModifier<List<KnownAccount>>,
        $FutureProvider<List<KnownAccount>> {
  /// Provider that fetches the list of known accounts from the auth service.
  ///
  /// Invalidate this provider after sign-in or sign-out to refresh the list.
  KnownAccountsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'knownAccountsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$knownAccountsHash();

  @$internal
  @override
  $FutureProviderElement<List<KnownAccount>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<KnownAccount>> create(Ref ref) {
    return knownAccounts(ref);
  }
}

String _$knownAccountsHash() => r'8e9753265420cf092af04aa07686c98cdaa8eb1e';

/// Provider that sets Zendesk user identity when auth state changes
/// Watch this provider at app startup to keep Zendesk identity in sync with auth

@ProviderFor(zendeskIdentitySync)
final zendeskIdentitySyncProvider = ZendeskIdentitySyncProvider._();

/// Provider that sets Zendesk user identity when auth state changes
/// Watch this provider at app startup to keep Zendesk identity in sync with auth

final class ZendeskIdentitySyncProvider
    extends $FunctionalProvider<void, void, void>
    with $Provider<void> {
  /// Provider that sets Zendesk user identity when auth state changes
  /// Watch this provider at app startup to keep Zendesk identity in sync with auth
  ZendeskIdentitySyncProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'zendeskIdentitySyncProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$zendeskIdentitySyncHash();

  @$internal
  @override
  $ProviderElement<void> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  void create(Ref ref) {
    return zendeskIdentitySync(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$zendeskIdentitySyncHash() =>
    r'e49d4f9cedf56ec4131b30a6f1d9d45dada68bed';

/// Provider for [VerifierClient] pointed at the current environment's
/// verifier base URL. Stateless — every call hits the network.

@ProviderFor(verifierClient)
final verifierClientProvider = VerifierClientProvider._();

/// Provider for [VerifierClient] pointed at the current environment's
/// verifier base URL. Stateless — every call hits the network.

final class VerifierClientProvider
    extends $FunctionalProvider<VerifierClient, VerifierClient, VerifierClient>
    with $Provider<VerifierClient> {
  /// Provider for [VerifierClient] pointed at the current environment's
  /// verifier base URL. Stateless — every call hits the network.
  VerifierClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'verifierClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$verifierClientHash();

  @$internal
  @override
  $ProviderElement<VerifierClient> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  VerifierClient create(Ref ref) {
    return verifierClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VerifierClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VerifierClient>(value),
    );
  }
}

String _$verifierClientHash() => r'1d6966c5483814cd7fa203e7e9e198dc5c9c232d';

/// Provider for [IdentityClaimsRepository] composing the verifier client
/// with NIP-39 i tag parsing.

@ProviderFor(identityClaimsRepository)
final identityClaimsRepositoryProvider = IdentityClaimsRepositoryProvider._();

/// Provider for [IdentityClaimsRepository] composing the verifier client
/// with NIP-39 i tag parsing.

final class IdentityClaimsRepositoryProvider
    extends
        $FunctionalProvider<
          IdentityClaimsRepository,
          IdentityClaimsRepository,
          IdentityClaimsRepository
        >
    with $Provider<IdentityClaimsRepository> {
  /// Provider for [IdentityClaimsRepository] composing the verifier client
  /// with NIP-39 i tag parsing.
  IdentityClaimsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'identityClaimsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$identityClaimsRepositoryHash();

  @$internal
  @override
  $ProviderElement<IdentityClaimsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  IdentityClaimsRepository create(Ref ref) {
    return identityClaimsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IdentityClaimsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IdentityClaimsRepository>(value),
    );
  }
}

String _$identityClaimsRepositoryHash() =>
    r'451c65b551cddcf8cf2ef3d23ac862ab0ae1441d';

/// NIP-98 authentication service

@ProviderFor(nip98AuthService)
final nip98AuthServiceProvider = Nip98AuthServiceProvider._();

/// NIP-98 authentication service

final class Nip98AuthServiceProvider
    extends
        $FunctionalProvider<
          Nip98AuthService,
          Nip98AuthService,
          Nip98AuthService
        >
    with $Provider<Nip98AuthService> {
  /// NIP-98 authentication service
  Nip98AuthServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nip98AuthServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nip98AuthServiceHash();

  @$internal
  @override
  $ProviderElement<Nip98AuthService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Nip98AuthService create(Ref ref) {
    return nip98AuthService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Nip98AuthService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Nip98AuthService>(value),
    );
  }
}

String _$nip98AuthServiceHash() => r'cfc2e0a65e1dbd9c559886929257fa66a7afb1c6';

/// Account Deletion Service for NIP-62 Request to Vanish

@ProviderFor(accountDeletionService)
final accountDeletionServiceProvider = AccountDeletionServiceProvider._();

/// Account Deletion Service for NIP-62 Request to Vanish

final class AccountDeletionServiceProvider
    extends
        $FunctionalProvider<
          AccountDeletionService,
          AccountDeletionService,
          AccountDeletionService
        >
    with $Provider<AccountDeletionService> {
  /// Account Deletion Service for NIP-62 Request to Vanish
  AccountDeletionServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountDeletionServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountDeletionServiceHash();

  @$internal
  @override
  $ProviderElement<AccountDeletionService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AccountDeletionService create(Ref ref) {
    return accountDeletionService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccountDeletionService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccountDeletionService>(value),
    );
  }
}

String _$accountDeletionServiceHash() =>
    r'659c0ee712559ba34e462dc9b236c40c80651240';
