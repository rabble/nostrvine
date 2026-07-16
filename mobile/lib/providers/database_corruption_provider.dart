// ABOUTME: Holds the app-lifetime DatabaseCorruptionService for the database
// ABOUTME: provider and the restart prompt. Overridden in main.dart.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/services/database_corruption_service.dart';

/// The runtime database-corruption sink, or `null` when corruption reporting is
/// not wired.
///
/// `null` is the default so widget tests and web get a plain, uninstrumented
/// connection. `main.dart` overrides it in `ProviderScope` with the instance it
/// also hands to `DatabaseEncryptionBootstrap`, so the interceptor's reports and
/// the next launch's recovery decision read the same flag. See
/// `database_provider.dart` and `database_corruption_gate.dart`.
final databaseCorruptionServiceProvider = Provider<DatabaseCorruptionService?>(
  (ref) => null,
);
