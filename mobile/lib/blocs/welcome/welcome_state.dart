// ABOUTME: State for WelcomeBloc
// ABOUTME: Immutable state with list-based multi-account support

part of 'welcome_bloc.dart';

/// Status of welcome screen operations.
enum WelcomeStatus {
  /// Initial state, data not yet loaded.
  initial,

  /// Returning-user data loaded (or confirmed absent).
  loaded,

  /// An auth action (log back in / create account) is in progress.
  accepting,

  /// An auth action failed.
  error,

  /// Transient: navigate to login options, then auto-resets to [loaded].
  navigatingToLoginOptions,

  /// Transient: navigate to create account, then auto-resets to [loaded].
  navigatingToCreateAccount,
}

/// A previously used account with its cached profile data.
class PreviousAccount extends Equatable {
  const PreviousAccount({
    required this.pubkeyHex,
    required this.authSource,
    this.profile,
  });

  /// Full 64-character hex public key.
  final String pubkeyHex;

  /// Which authentication method was used for this identity.
  final AuthenticationSource authSource;

  /// Cached profile from SQLite, if available.
  final UserProfile? profile;

  @override
  List<Object?> get props => [pubkeyHex, authSource, profile];
}

/// State for the welcome BLoC.
final class WelcomeState extends Equatable {
  const WelcomeState({
    this.status = WelcomeStatus.initial,
    this.previousAccounts = const [],
    this.selectedPubkeyHex,
    this.signingInPubkeyHex,
    this.error,
  });

  /// Current status of welcome operations.
  final WelcomeStatus status;

  /// List of previously used accounts, sorted by most recently used first.
  final List<PreviousAccount> previousAccounts;

  /// The pubkey of the currently selected account in the dropdown.
  /// Defaults to the most recently used account (first in list).
  final String? selectedPubkeyHex;

  /// The pubkey of the account currently being signed into (for loading state).
  final String? signingInPubkeyHex;

  /// Error message from the last failed operation.
  final String? error;

  /// Whether any returning users were detected.
  bool get hasReturningUsers => previousAccounts.isNotEmpty;

  /// The currently selected account, or null if none selected.
  PreviousAccount? get selectedAccount {
    if (previousAccounts.isEmpty) return null;
    if (selectedPubkeyHex == null) return previousAccounts.first;
    return previousAccounts
            .where((a) => a.pubkeyHex == selectedPubkeyHex)
            .firstOrNull ??
        previousAccounts.first;
  }

  /// Whether an auth action is in progress.
  bool get isAccepting => status == WelcomeStatus.accepting;

  /// Creates a copy of this state with the given fields replaced.
  WelcomeState copyWith({
    WelcomeStatus? status,
    List<PreviousAccount>? previousAccounts,
    String? selectedPubkeyHex,
    String? signingInPubkeyHex,
    String? error,
    bool clearAccounts = false,
    bool clearError = false,
    bool clearSigningIn = false,
    bool clearSelectedPubkey = false,
  }) {
    return WelcomeState(
      status: status ?? this.status,
      previousAccounts: clearAccounts
          ? const []
          : (previousAccounts ?? this.previousAccounts),
      selectedPubkeyHex: clearSelectedPubkey
          ? null
          : (selectedPubkeyHex ?? this.selectedPubkeyHex),
      signingInPubkeyHex: clearSigningIn
          ? null
          : (signingInPubkeyHex ?? this.signingInPubkeyHex),
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
    status,
    previousAccounts,
    selectedPubkeyHex,
    signingInPubkeyHex,
    error,
  ];
}
