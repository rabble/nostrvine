// ABOUTME: Events for WelcomeBloc
// ABOUTME: Sealed classes for type-safe event handling

part of 'welcome_bloc.dart';

/// Base class for all welcome events.
sealed class WelcomeEvent extends Equatable {
  const WelcomeEvent();
}

/// Load returning-user data from SharedPreferences and SQLite cache.
///
/// If [initialSelectedPubkeyHex] is provided, that account will be
/// pre-selected on the welcome screen instead of the most-recently-used one.
/// Use this when navigating from the account-switcher so the chosen account
/// is highlighted while the previous account remains the fallback for X/close.
final class WelcomeStarted extends WelcomeEvent {
  const WelcomeStarted({this.initialSelectedPubkeyHex});

  /// Optional pubkey to pre-select on load.
  final String? initialSelectedPubkeyHex;

  @override
  List<Object?> get props => [initialSelectedPubkeyHex];
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

/// Cancel an account switch and restore the previous (most-recently-used) account.
///
/// Used by the X/close button on the welcome screen when it was opened from
/// the account-switcher with a pre-selected account. Signs in with
/// [WelcomeState.previousAccounts.first] regardless of [WelcomeState.selectedPubkeyHex].
final class WelcomeCancelSwitchRequested extends WelcomeEvent {
  const WelcomeCancelSwitchRequested();

  @override
  List<Object?> get props => [];
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

/// Internal event: profiles have been hydrated from SQLite cache.
///
/// Fired after [WelcomeStarted] emits the initial account list without
/// profiles. The handler replaces the account list with profile-enriched
/// versions. Ignored if state has moved past [WelcomeStatus.loaded].
final class WelcomeProfilesHydrated extends WelcomeEvent {
  const WelcomeProfilesHydrated(this.accounts);

  final List<PreviousAccount> accounts;

  @override
  List<Object?> get props => [accounts];
}
