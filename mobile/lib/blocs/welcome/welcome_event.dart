// ABOUTME: Events for WelcomeBloc
// ABOUTME: Sealed classes for type-safe event handling

part of 'welcome_bloc.dart';

/// Base class for all welcome events.
sealed class WelcomeEvent extends Equatable {
  const WelcomeEvent();
}

/// Load returning-user data from SharedPreferences and SQLite cache.
final class WelcomeStarted extends WelcomeEvent {
  const WelcomeStarted();

  @override
  List<Object?> get props => [];
}

/// Dismiss the returning-user variant and show the default welcome screen.
final class WelcomeLastUserDismissed extends WelcomeEvent {
  const WelcomeLastUserDismissed();

  @override
  List<Object?> get props => [];
}

/// Request to log back in with the currently selected account.
///
/// Uses [WelcomeState.selectedAccount] to determine which identity to
/// restore, then calls [AuthService.signInForAccount] with its stored
/// [AuthenticationSource].
final class WelcomeLogBackInRequested extends WelcomeEvent {
  const WelcomeLogBackInRequested();

  @override
  List<Object?> get props => [];
}

/// User picked a different account from the dropdown.
final class WelcomeAccountSelected extends WelcomeEvent {
  const WelcomeAccountSelected({required this.pubkeyHex});

  final String pubkeyHex;

  @override
  List<Object?> get props => [pubkeyHex];
}

/// Request to navigate to the create account screen (email/password sign-up).
///
/// Calls [AuthService.acceptTerms] and signals the UI to navigate.
final class WelcomeCreateAccountRequested extends WelcomeEvent {
  const WelcomeCreateAccountRequested();

  @override
  List<Object?> get props => [];
}

/// Request to navigate to login options (email/bunker/etc).
///
/// Calls [AuthService.acceptTerms] and signals the UI to navigate.
final class WelcomeLoginOptionsRequested extends WelcomeEvent {
  const WelcomeLoginOptionsRequested();

  @override
  List<Object?> get props => [];
}
