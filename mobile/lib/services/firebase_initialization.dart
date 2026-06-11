// ABOUTME: Shared Firebase initialization guard for app and background isolates.
// ABOUTME: Reuses native auto-initialized default apps to avoid duplicate-app errors.

import 'package:firebase_core/firebase_core.dart';
import 'package:openvine/firebase_options.dart';

/// Ensures the default Firebase app exists exactly once.
///
/// Android can auto-create the default app before Dart startup via the
/// google-services plugin. Calling [Firebase.initializeApp] again in that state
/// throws `[core/duplicate-app]`, which disables downstream Firebase services.
Future<void> ensureDefaultFirebaseInitialized({
  FirebaseOptions? options,
}) async {
  if (Firebase.apps.isNotEmpty) return;

  await Firebase.initializeApp(
    options: options ?? DefaultFirebaseOptions.currentPlatform,
  );
}
