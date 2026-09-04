// ABOUTME: Maps provider names to the startup phase they belong to
// ABOUTME: Split out when the unused StartupProfiler was removed (#4743)

import 'package:openvine/features/app/startup/startup_phase.dart';

/// Maps provider types to appropriate startup phases
class StartupPhaseMapper {
  static StartupPhase getPhaseForProvider(String providerName) {
    // Blocking work before runApp should stay extremely small.
    if (providerName.contains('Environment')) {
      return StartupPhase.critical;
    }

    // Core identity/auth services should start as soon as the first frame
    // exists, but they no longer need to gate first paint.
    if (providerName.contains('Auth') ||
        providerName.contains('KeyStorage') ||
        providerName.contains('SecureKey')) {
      return StartupPhase.essential;
    }

    // Standard services improve app readiness but shouldn't block paint.
    if (providerName.contains('ConnectionStatus') ||
        providerName.contains('VideoVisibility') ||
        providerName.contains('NostrService')) {
      return StartupPhase.standard;
    }

    // Deferred services - can load after UI is responsive
    if (providerName.contains('Analytics') ||
        providerName.contains('Notification') ||
        providerName.contains('Curation') ||
        providerName.contains('ContentReporting') ||
        providerName.contains('ContentDeletion') ||
        providerName.contains('WebAuth')) {
      return StartupPhase.deferred;
    }

    // Standard services - everything else
    return StartupPhase.standard;
  }

  /// Get dependencies for a provider
  static List<String> getDependencies(String providerName) {
    final deps = <String>[];

    // Services that depend on auth
    if (providerName.contains('Social') ||
        providerName.contains('VideoEventPublisher') ||
        providerName.contains('CuratedList')) {
      deps.add('AuthService');
    }

    // Services that depend on Nostr
    if (providerName.contains('VideoEvent') ||
        providerName.contains('UserProfile') ||
        providerName.contains('Social') ||
        providerName.contains('Subscription')) {
      deps.add('NostrService');
    }

    // Services that depend on key storage
    if (providerName.contains('Auth')) {
      deps.add('SecureKeyStorage');
    }

    return deps;
  }
}
