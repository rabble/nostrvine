// ABOUTME: Thin bottom-edge line signalling the environment and relay scope.
// ABOUTME: Environment color in non-production; purple on non-Divine relays.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/relay_providers.dart';
import 'package:openvine/services/relay_discovery_service.dart';
import 'package:openvine/utils/relay_url_utils.dart';

/// Resolves the indicator line color for the given [environment] and
/// [configuredRelays], or `null` when the line should be hidden.
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

/// The current indicator line color, or `null` when hidden.
///
/// Recomputes on environment switch and whenever the relay set / connections
/// change (via [relayStatisticsStreamProvider]).
final environmentIndicatorColorProvider = Provider<Color?>((ref) {
  final environment = ref.watch(currentEnvironmentProvider);
  // Watched purely as a change trigger so the line updates when relays are
  // added/removed or NIP-65 discovery runs.
  ref.watch(relayStatisticsStreamProvider);
  // Degrade gracefully: a decorative line must never crash the shell if the
  // Nostr client is transiently uninitialised / in error. No relays known →
  // fall back to environment-only logic.
  List<String> configuredRelays;
  try {
    configuredRelays = ref.watch(nostrServiceProvider).configuredRelays;
  } on Object {
    configuredRelays = const <String>[];
  }
  return environmentIndicatorColor(
    environment: environment,
    configuredRelays: configuredRelays,
    // Relays every account is auto-seeded with (NIP-65 indexers + DM
    // fallbacks). Excluded so only genuinely user-added relays show purple.
    defaultRelayUrls: <String>{
      ...environment.indexerRelays,
      ...IndexerRelayConfig.safeFallbackRelays,
    },
  );
});

/// A ~3px line pinned to the bottom edge of the app, colored by
/// [environmentIndicatorColorProvider]. Decorative (excluded from semantics).
class EnvironmentIndicatorLine extends ConsumerWidget {
  const EnvironmentIndicatorLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = ref.watch(environmentIndicatorColorProvider);
    if (color == null) return const SizedBox.shrink();
    return ExcludeSemantics(
      child: SizedBox(
        height: 3,
        width: double.infinity,
        child: ColoredBox(color: color),
      ),
    );
  }
}
