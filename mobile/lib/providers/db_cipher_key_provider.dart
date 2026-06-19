// ABOUTME: Holds the resolved at-rest DB cipher key for the database provider.
// ABOUTME: Overridden in main.dart after DatabaseEncryptionBootstrap resolves it.

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The 64-hex (raw 32-byte) cipher key for the local database, or `null`
/// when the database should open unencrypted.
///
/// `null` is the default so tests and web fall back to a plaintext connection.
/// This provider MUST be overridden in `ProviderScope` during app startup with
/// the value resolved by `DatabaseEncryptionBootstrap.resolveCipherKey()`. The
/// database provider reads it to choose between an encrypted and a plaintext
/// connection. See `main.dart` and `database_provider.dart`. (#570, finding C2)
final dbCipherKeyProvider = Provider<String?>((ref) => null);
