// ABOUTME: Shared macOS Keychain options for the app's FlutterSecureStorage.
// ABOUTME: Centralizes the macOS-debug data-protection-keychain fallback (#5563).

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// macOS Keychain options for the app's `FlutterSecureStorage` instances.
///
/// macOS debug builds are ad-hoc/linker-signed without a Keychain-Sharing
/// provisioning profile, so the data-protection keychain rejects every
/// read/write with OSStatus `-34018` (`errSecMissingEntitlement`). That blocks
/// the at-rest database cipher-key resolve at startup and surfaces the restart
/// screen. In that case fall back to the file-based keychain, which needs no
/// `keychain-access-groups` entitlement; release builds are properly signed and
/// keep the recommended data-protection keychain.
///
/// Mirrors the `useDataProtectionKeyChain` gate already used by
/// `nostr_key_manager`'s `PlatformSecureStorage`. `accessibility` is
/// intentionally left at the package default (`unlocked`) to preserve the app
/// stores' prior macOS behavior. See #5563.
///
/// Because of this gate, macOS debug and release builds read from *different*
/// keychains on the same Mac. Switching build modes locally won't find the
/// other mode's database cipher key and triggers the dev-only
/// backup-then-recreate key-loss path in `DatabaseEncryptionBootstrap`. This is
/// harmless for end users — who only ever run a single signed release build —
/// but surprising during local development.
///
/// [isDebug] defaults to [kDebugMode] (a compile-time constant) and exists only
/// so tests can exercise the macOS release branch, which `kDebugMode` cannot
/// reach under `flutter test`. Production callers omit it.
MacOsOptions appMacOsSecureStorageOptions({bool isDebug = kDebugMode}) =>
    MacOsOptions(
      useDataProtectionKeyChain:
          defaultTargetPlatform != TargetPlatform.macOS || !isDebug,
    );
