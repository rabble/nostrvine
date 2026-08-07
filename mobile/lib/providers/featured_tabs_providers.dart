// ABOUTME: DI for the featured Explore tab repository and its viewer gate.
// ABOUTME: Rebuilds with the Funnelcake client so a relay/env swap propagates.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/repositories/featured_tabs_repository.dart';

/// Repository backing the server-configured featured Explore tab.
///
/// Rebuilds whenever the Funnelcake client identity changes (environment or
/// relay-derived base URL), which drops the cached config with it — the
/// previous host's answer must not survive the swap.
final featuredTabsRepositoryProvider = Provider<FeaturedTabsRepository>((ref) {
  final apiClient = ref.watch(funnelcakeApiClientProvider);
  final repository = FeaturedTabsRepository(apiClient: apiClient);
  ref.onDispose(repository.clearCache);
  return repository;
});

/// Whether the current viewer is gated as a protected minor.
///
/// Reuses the #175 content-lock seam rather than the fail-closed DM seam: a
/// featured tab is ordinary discovery content, so an absent age signal should
/// not withhold it. Tabs still default to hidden for a known minor unless the
/// configuration explicitly opts in.
final featuredTabViewerIsMinorProvider = Provider<bool>((ref) {
  return ref.watch(isProtectedMinorProvider);
});
