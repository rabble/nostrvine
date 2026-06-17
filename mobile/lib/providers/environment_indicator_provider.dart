// ABOUTME: Provider + color logic for the environment / relay indicator bar.
// ABOUTME: Lives in the provider layer so it can wire the relay service config.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/relay_providers.dart';
import 'package:openvine/services/relay_discovery_service.dart';
import 'package:openvine/utils/relay_url_utils.dart';

/// Resolves the indicator bar color for the given [environment] and
/// [configuredRelays], or `null` when the indicator should be hidden.
///
/// - A user-chosen relay beyond Divine + the app's [defaultRelayUrls] →
///   purple (wins over the environment color).
/// - Otherwise, a non-production environment → its environment color.
/// - Otherwise (production on Divine / default relays) → `null` (hidden).
Color? environmentIndicatorColor({
  required EnvironmentConfig environment,
  required List<String> configuredRelays,
  required Iterable<String> defaultRelayUrls,
}) {
  if (usesUserChosenRelay(
    configuredRelays,
    defaultRelayUrls: defaultRelayUrls,
  )) {
    return VineTheme.accentPurple;
  }
  if (!environment.isProduction) {
    return Color(environment.indicatorColorValue);
  }
  return null;
}

/// The current indicator bar color, or `null` when hidden.
///
/// Sources the active relay set from [relayStatisticsStreamProvider] (keyed by
/// relay URL) rather than the Nostr client, so the always-mounted indicator
/// never forces the client to initialise at shell build. Until relay stats
/// exist, the relay set is empty and the indicator falls back to
/// environment-only logic.
final environmentIndicatorColorProvider = Provider<Color?>((ref) {
  final environment = ref.watch(currentEnvironmentProvider);
  final relayStats = ref.watch(relayStatisticsStreamProvider);
  final activeRelays =
      relayStats.asData?.value.keys.toList() ?? const <String>[];
  return environmentIndicatorColor(
    environment: environment,
    configuredRelays: activeRelays,
    // Relays every account is auto-seeded with (NIP-65 indexers + DM
    // fallbacks). Excluded so only genuinely user-added relays show purple.
    defaultRelayUrls: <String>{
      ...environment.indexerRelays,
      ...IndexerRelayConfig.safeFallbackRelays,
    },
  );
});
