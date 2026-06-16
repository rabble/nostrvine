// ABOUTME: Small bottom indicator pill signalling the environment / relay scope.
// ABOUTME: Environment color in non-production; purple on user-added relays.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/relay_providers.dart';
import 'package:openvine/services/relay_discovery_service.dart';
import 'package:openvine/utils/relay_url_utils.dart';

/// Resolves the indicator pill color for the given [environment] and
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

/// The current indicator pill color, or `null` when hidden.
///
/// Sources the active relay set from [relayStatisticsStreamProvider] (keyed by
/// relay URL) rather than the Nostr client, so this always-mounted indicator
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

/// A small rounded pill, centered just above the bottom nav, colored by
/// [environmentIndicatorColorProvider]. Inset so it never reaches the
/// rounded corners. Decorative (excluded from semantics).
class EnvironmentIndicatorLine extends ConsumerWidget {
  const EnvironmentIndicatorLine({super.key});

  static const double _height = 4;
  static const double _width = 72;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = ref.watch(environmentIndicatorColorProvider);
    if (color == null) return const SizedBox.shrink();
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_height / 2),
            child: SizedBox(
              height: _height,
              width: _width,
              child: ColoredBox(color: color),
            ),
          ),
        ),
      ),
    );
  }
}
