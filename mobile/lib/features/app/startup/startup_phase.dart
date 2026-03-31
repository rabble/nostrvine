// ABOUTME: Defines startup phases for progressive app initialization
// ABOUTME: Enables prioritized loading of critical services first

/// Phases of application startup in priority order
enum StartupPhase {
  /// Must complete before `runApp()` so the first route can build safely.
  critical(0, 'Critical services'),

  /// Starts right after the first frame to unblock auth/core readiness.
  essential(1, 'Essential UI'),

  /// Background startup work that improves later interactions.
  standard(2, 'Standard features'),

  /// Nice-to-have warmups and observability that should stay off first paint.
  deferred(3, 'Deferred services')
  ;

  final int priority;
  final String description;

  const StartupPhase(this.priority, this.description);
}
