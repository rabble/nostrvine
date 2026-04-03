// ABOUTME: Cubit managing account list, draft warnings, and account switching
// ABOUTME: for the settings screen account-switcher bottom sheet.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/models/known_account.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
part 'settings_account_state.dart';

/// Manages known accounts, draft count, and account-switch actions.
class SettingsAccountCubit extends Cubit<SettingsAccountState> {
  SettingsAccountCubit({
    required AuthService authService,
    required DraftStorageService draftStorageService,
  }) : _authService = authService,
       _draftStorageService = draftStorageService,
       super(const SettingsAccountState());

  final AuthService _authService;
  final DraftStorageService _draftStorageService;

  /// Loads the known accounts list and current draft count.
  Future<void> load() async {
    emit(state.copyWith(status: SettingsAccountStatus.loading));
    try {
      final accounts = await _authService.getKnownAccounts();
      final draftCount = await _draftStorageService.getDraftCount();
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
      emit(state.copyWith(status: SettingsAccountStatus.failure));
    }
  }

  /// Switches to an existing account by signing out and setting the pending
  /// account switch pubkey so WelcomeBloc pre-selects it.
  void switchToAccount(String pubkeyHex) {
    if (pubkeyHex == state.currentPubkey) return;
    _authService.pendingAccountSwitchPubkey = pubkeyHex;
    _authService.signOut();
  }

  /// Signs out to add a new account (no pending switch pubkey).
  void addNewAccount() {
    _authService.signOut();
  }
}
