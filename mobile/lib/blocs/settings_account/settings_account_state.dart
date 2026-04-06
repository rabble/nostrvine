part of 'settings_account_cubit.dart';

/// Status of the settings account data.
enum SettingsAccountStatus {
  /// No load has been attempted yet.
  initial,

  /// Accounts are being loaded.
  loading,

  /// Accounts have been loaded.
  loaded,

  /// Loading failed.
  failure,
}

/// State for the settings account cubit.
class SettingsAccountState extends Equatable {
  const SettingsAccountState({
    this.status = SettingsAccountStatus.initial,
    this.accounts = const [],
    this.draftCount = 0,
    this.currentPubkey,
  });

  /// The current status.
  final SettingsAccountStatus status;

  /// Known accounts for the current device.
  final List<KnownAccount> accounts;

  /// Number of unsaved drafts for the current user.
  final int draftCount;

  /// The currently signed-in user's public key hex.
  final String? currentPubkey;

  /// Whether there are multiple known accounts.
  bool get hasMultipleAccounts => accounts.length > 1;

  /// Whether there are unsaved drafts.
  bool get hasDrafts => draftCount > 0;

  /// Returns a copy with the given fields replaced.
  SettingsAccountState copyWith({
    SettingsAccountStatus? status,
    List<KnownAccount>? accounts,
    int? draftCount,
    String? currentPubkey,
  }) {
    return SettingsAccountState(
      status: status ?? this.status,
      accounts: accounts ?? this.accounts,
      draftCount: draftCount ?? this.draftCount,
      currentPubkey: currentPubkey ?? this.currentPubkey,
    );
  }

  @override
  List<Object?> get props => [status, accounts, draftCount, currentPubkey];
}
