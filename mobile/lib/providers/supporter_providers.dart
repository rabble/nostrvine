// ABOUTME: Riverpod providers wiring the supporter feature.
// ABOUTME: Selects the store-backed EntitlementValidator on iOS/Android and a
// ABOUTME: stub elsewhere, owned by an account-scoped SupporterRepository.

import 'package:flutter/foundation.dart';
import 'package:iap_repository/iap_repository.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/supporter_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'supporter_providers.g.dart';

/// True when this platform has a real in-app purchase store.
///
/// Mirrors the [hasNativeVideoPlayer] gate: iOS/Android only, web-safe.
bool get hasInAppPurchaseStore =>
    !kIsWeb &&
    defaultTargetPlatform != TargetPlatform.linux &&
    defaultTargetPlatform != TargetPlatform.windows &&
    defaultTargetPlatform != TargetPlatform.macOS;

/// The store-backed [EntitlementValidator] for the current platform.
///
/// Returns an [InAppPurchaseValidator] on iOS/Android and a
/// [StubEntitlementValidator] elsewhere so the rest of the app can treat the
/// supporter feature uniformly.
@Riverpod(keepAlive: true)
EntitlementValidator entitlementValidator(Ref ref) {
  if (!hasInAppPurchaseStore) {
    return StubEntitlementValidator();
  }
  final validator = InAppPurchaseValidator();
  validator.startListening();
  ref.onDispose(validator.dispose);
  return validator;
}

/// The account-scoped [SupporterRepository] that owns the cached entitlement.
@riverpod
SupporterRepository supporterRepository(Ref ref) {
  ref.watch(currentAuthStateProvider);
  final pubkey = ref.watch(authServiceProvider).currentPublicKeyHex;
  final repository = SupporterRepository(
    pubkey: pubkey ?? 'unauthenticated',
    validator: ref.watch(entitlementValidatorProvider),
    prefs: ref.watch(sharedPreferencesProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
}
