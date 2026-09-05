// ABOUTME: Device-scoped provider for the app's LogMessageBatcher
// ABOUTME: Replaces the former lazy-static singleton (#8618)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/utils/log_message_batcher.dart';

/// The app's single [LogMessageBatcher].
///
/// Replaces the former `LogMessageBatcher.instance` singleton (#8618). It is
/// **device-scoped**, not account-scoped: the `debugPrint` override installed
/// in `app_bootstrap` batches into it for the life of the process, so an
/// account swap must not hand the startup coordinator or the lifecycle handler
/// a different instance whose flush timer was never armed. `DeviceScope` pins
/// the bootstrap-owned instance with `overrideWithValue`.
///
/// The fallback is a fresh batcher that no `debugPrint` hook feeds, so it
/// holds nothing and flushes nothing — the same thing a test got from the old
/// singleton before anything was batched. Production always receives the
/// bootstrap-owned instance through `DeviceScope`, which every container is
/// built from.
final logMessageBatcherProvider = Provider<LogMessageBatcher>((ref) {
  final batcher = LogMessageBatcher();
  ref.onDispose(batcher.dispose);
  return batcher;
});
