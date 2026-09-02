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

/// Whether age-restricted featured tabs should be gated for the current viewer
/// (#7675).
///
/// Age-restricted tabs are curated tabs an operator did NOT mark minor-safe, so
/// this seam takes the fail-CLOSED conditional posture of the #176 DM and #182
/// key-management surfaces — [isDmRestrictedProvider] — rather than the
/// fail-OPEN #175 content lock. An unresolved Keycast check therefore hides
/// age-restricted tabs where a Keycast verdict could plausibly apply (OAuth
/// accounts, previously-Keycast self-custody), closing the gap where a
/// non-Keycast minor would otherwise be shown them. Pure self-custody accounts,
/// which Keycast can never produce a verdict for, stay permissive so adults are
/// not blocked by an unanswerable check.
///
/// The value therefore means "treat as minor-gated for this surface", not
/// strictly "is a minor" — matching the unknown-is-restricted posture #176/#182
/// already use.
final featuredTabViewerIsMinorProvider = Provider<bool>((ref) {
  return ref.watch(isDmRestrictedProvider);
});
