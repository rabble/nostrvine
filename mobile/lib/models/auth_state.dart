// ABOUTME: Defines the lifecycle states exposed by AuthService.
// ABOUTME: Keeps authentication state independent from service implementation.

/// Authentication state for the user.
enum AuthState {
  unauthenticated,
  awaitingTosAcceptance,
  authenticated,
  checking,
  authenticating,
}
