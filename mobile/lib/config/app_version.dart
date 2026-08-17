// ABOUTME: Synchronous app-version source for headers and diagnostics.
// ABOUTME: Populated once at startup from PackageInfo, before providers run.

/// Holds the shipped app version (for example `1.0.20`) for code that needs
/// it synchronously, such as the shared Funnelcake User-Agent builder.
///
/// `main()` sets [current] from `PackageInfo` during bootstrap. Until then it
/// reads `unknown`, which is what tests and early startup send.
class AppVersion {
  AppVersion._();

  /// The current app version; `unknown` until bootstrap sets the real value.
  static String current = 'unknown';
}
