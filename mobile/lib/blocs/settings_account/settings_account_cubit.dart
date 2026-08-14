// ABOUTME: Cubit managing account list, draft warnings, and account switching
// ABOUTME: for the settings screen account-switcher bottom sheet.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/services/feature_flag_service.dart';
import 'package:openvine/models/known_account.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
part 'settings_account_state.dart';

/// Manages known accounts, draft count, and account-switch actions.
class SettingsAccountCubit extends Cubit<SettingsAccountState> {
  SettingsAccountCubit({
    required AuthService authService,
    required DraftStorageService draftStorageService,
    required FeatureFlagService featureFlagService,
  }) : _authService = authService,
       _draftStorageService = draftStorageService,
       _featureFlagService = featureFlagService,
       super(const SettingsAccountState());

  final AuthService _authService;
  final DraftStorageService _draftStorageService;
  final FeatureFlagService _featureFlagService;

  bool get _accountSwitchingEnabled =>
      _featureFlagService.isEnabled(FeatureFlag.accountSwitching);

  /// Loads the known accounts list and current draft count.
  Future<void> load() async {
    emit(state.copyWith(status: SettingsAccountStatus.loading));
    try {
      final accounts = await _authService.getKnownAccounts();
      final draftCount = await _draftStorageService.getDraftCount();
      // Neither read can be cancelled, so both can resolve after the account
      // sheet was dismissed and this cubit closed.
      if (isClosed) return;
      emit(
        state.copyWith(
          status: SettingsAccountStatus.loaded,
          accounts: accounts,
          draftCount: draftCount,
          currentPubkey: _authService.currentPublicKeyHex,
        ),
      );
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      if (isClosed) return;
      emit(state.copyWith(status: SettingsAccountStatus.failure));
    }
  }

  /// Signs out to add a new account (no pending switch pubkey).
  ///
  /// Switching *between* already-signed-in accounts no longer goes through the
  /// cubit — it is an in-place container swap (`swapAccount`) triggered from
  /// the UI. Adding a genuinely new account still needs the sign-out → welcome
  /// → sign-in flow, since that account is not yet authenticated on device.
  Future<void> addNewAccount() async {
    if (!_accountSwitchingEnabled) return;
    await _authService.signOut();
  }
}
