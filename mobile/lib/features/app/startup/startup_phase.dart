// ABOUTME: Defines startup phases for progressive app initialization
// ABOUTME: Enables prioritized loading of critical services first

/// Phases of application startup in priority order
enum StartupPhase implements Comparable<StartupPhase> {
  /// Must initialize before app can function
  /// Examples: Auth, key storage, core platform services
  critical(0, 'Critical services'),

  /// Required for basic UI interaction
  /// Examples: Navigation, theme, basic UI state
  essential(1, 'Essential UI'),

  /// Important but not blocking
  /// Examples: User profiles, video feed, social features
  standard(2, 'Standard features'),

  /// Can be loaded after UI is responsive
  /// Examples: Analytics, caching, optimization services
  deferred(3, 'Deferred services')
  ;

  final int priority;
  final String description;

  const StartupPhase(this.priority, this.description);

  @override
  int compareTo(StartupPhase other) => priority.compareTo(other.priority);

  /// Get phases that must complete before this phase
  List<StartupPhase> get dependencies {
    final deps = <StartupPhase>[];
    for (final phase in StartupPhase.values) {
      if (phase.priority < priority) {
        deps.add(phase);
      }
    }
    return deps;
  }

  /// Check if this phase depends on another
  bool dependsOn(StartupPhase other) => other.priority < priority;
}
