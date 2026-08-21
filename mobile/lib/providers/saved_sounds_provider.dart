// ABOUTME: Riverpod providers for user-saved reusable sounds.
// ABOUTME: Exposes the account-scoped saved sounds persistence service.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/documents_path_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/saved_sounds_service.dart';

final savedSoundsServiceProvider = Provider<SavedSoundsService>((ref) {
  // Rebuild on sign-in/out and account switch so the service (and the sounds
  // list built from it) always targets the current account's bucket.
  ref.watch(currentAuthStateProvider);
  final pubkeyHex = ref.watch(authServiceProvider).currentPublicKeyHex;
  return SavedSoundsService(
    ref.watch(sharedPreferencesProvider),
    pubkeyHex: pubkeyHex,
    // Draft-local audio is stored relative to the documents directory; iOS
    // rewrites that path on every app update, so it is rebased on load.
    documentsPath: ref.watch(documentsPathProvider),
  );
});
