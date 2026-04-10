// ABOUTME: BLoC for welcome screen returning-user state
// ABOUTME: Loads known accounts list for multi-account sign-in support

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:db_client/db_client.dart';
import 'package:equatable/equatable.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:models/models.dart';
import 'package:openvine/models/known_account.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:unified_logger/unified_logger.dart';

part 'welcome_event.dart';
part 'welcome_state.dart';

/// BLoC for managing the welcome screen state.
///
/// Handles:
/// - Loading known accounts from the AuthService registry + SQLite cache
/// - Selecting which account to sign back in with
/// - Removing accounts from the known list
/// - Triggering auth actions (log back in, create new account, login options)
class WelcomeBloc extends Bloc<WelcomeEvent, WelcomeState> {
  WelcomeBloc({
    required UserProfilesDao userProfilesDao,
    required AuthService authService,
  }) : _userProfilesDao = userProfilesDao,
       _authService = authService,
       super(const WelcomeState()) {
    on<WelcomeStarted>(_onStarted, transformer: droppable());
    on<WelcomeLastUserDismissed>(
      _onLastUserDismissed,
      transformer: droppable(),
    );
    on<WelcomeLogBackInRequested>(_onLogBackIn, transformer: droppable());
    on<WelcomeCancelSwitchRequested>(
      _onCancelSwitch,
      transformer: droppable(),
    );
    on<WelcomeAccountSelected>(_onAccountSelected);
    on<WelcomeCreateAccountRequested>(
      _onCreateAccountRequested,
      transformer: droppable(),
    );
    on<WelcomeLoginOptionsRequested>(
      _onLoginOptionsRequested,
      transformer: droppable(),
    );
    on<WelcomeProfilesHydrated>(_onProfilesHydrated);
  }

  final UserProfilesDao _userProfilesDao;
  final AuthService _authService;

  Future<void> _onStarted(
    WelcomeStarted event,
    Emitter<WelcomeState> emit,
  ) async {
    Log.info(
      'WelcomeBloc: loading known accounts...',
      name: 'WelcomeBloc',
      category: LogCategory.auth,
    );

    // Consume any pending account-switch selection set before sign-out.
    final pendingPubkey = _authService.pendingAccountSwitchPubkey;
    _authService.pendingAccountSwitchPubkey = null;

    // Load known accounts from the registry
    final knownAccounts = await _authService.getKnownAccounts();

    if (knownAccounts.isEmpty) {
      Log.info(
        'WelcomeBloc: no known accounts — showing fresh welcome',
        name: 'WelcomeBloc',
        category: LogCategory.auth,
      );
      emit(state.copyWith(status: WelcomeStatus.loaded));
      return;
    }

    Log.info(
      'WelcomeBloc: found ${knownAccounts.length} known account(s)',
      name: 'WelcomeBloc',
      category: LogCategory.auth,
    );

    // Emit accounts immediately WITHOUT profiles so the screen renders fast.
    final accountsWithoutProfiles = knownAccounts
        .map(
          (known) => PreviousAccount(
            pubkeyHex: known.pubkeyHex,
            authSource: known.authSource,
          ),
        )
        .toList();

    emit(
      state.copyWith(
        status: WelcomeStatus.loaded,
        previousAccounts: accountsWithoutProfiles,
        selectedPubkeyHex: pendingPubkey ?? event.initialSelectedPubkeyHex,
      ),
    );

    // Hydrate profiles from SQLite in parallel, then update state.
    _hydrateProfiles(knownAccounts);
  }

  /// Loads cached profiles for each known account in parallel and fires
  /// [WelcomeProfilesHydrated] to update the account list.
  Future<void> _hydrateProfiles(List<KnownAccount> knownAccounts) async {
    final futures = <Future<PreviousAccount>>[];
    for (final known in knownAccounts) {
      futures.add(_hydrateAccount(known));
    }
    final results = await Future.wait(futures);

    final withProfiles = results.where((a) => a.profile != null).length;
    Log.info(
      'WelcomeBloc: hydrated ${results.length} account(s) '
      '($withProfiles with cached profiles)',
      name: 'WelcomeBloc',
      category: LogCategory.auth,
    );

    // Only update if any profiles were actually found.
    if (withProfiles > 0) {
      add(WelcomeProfilesHydrated(results));
    }
  }

  Future<PreviousAccount> _hydrateAccount(KnownAccount known) async {
    UserProfile? profile;
    try {
      profile = await _userProfilesDao.getProfile(known.pubkeyHex);
    } catch (e) {
      Log.warning(
        'Failed to load cached profile for ${known.pubkeyHex}: $e',
        name: 'WelcomeBloc',
        category: LogCategory.auth,
      );
    }
    return PreviousAccount(
      pubkeyHex: known.pubkeyHex,
      authSource: known.authSource,
      profile: profile,
    );
  }

  void _onLastUserDismissed(
    WelcomeLastUserDismissed event,
    Emitter<WelcomeState> emit,
  ) {
    emit(
      state.copyWith(
        status: WelcomeStatus.loaded,
        clearAccounts: true,
        clearSelectedPubkey: true,
      ),
    );
  }

  Future<void> _onLogBackIn(
    WelcomeLogBackInRequested event,
    Emitter<WelcomeState> emit,
  ) async {
    final account = state.selectedAccount;
    if (account == null) {
      Log.warning(
        'WelcomeBloc: log back in requested but no account selected',
        name: 'WelcomeBloc',
        category: LogCategory.auth,
      );
      return;
    }

    Log.info(
      'WelcomeBloc: logging back in as '
      'pubkey=${account.pubkeyHex}, '
      'source=${account.authSource.name}',
      name: 'WelcomeBloc',
      category: LogCategory.auth,
    );

    emit(
      state.copyWith(
        status: WelcomeStatus.accepting,
        signingInPubkeyHex: account.pubkeyHex,
        clearError: true,
      ),
    );

    try {
      await _authService.signInForAccount(
        account.pubkeyHex,
        account.authSource,
      );
      Log.info(
        'WelcomeBloc: sign-in completed for ${account.pubkeyHex}',
        name: 'WelcomeBloc',
        category: LogCategory.auth,
      );
    } on SessionExpiredException {
      Log.warning(
        'WelcomeBloc: session expired for ${account.pubkeyHex} '
        '— redirecting to login options',
        name: 'WelcomeBloc',
        category: LogCategory.auth,
      );
      emit(
        state.copyWith(
          status: WelcomeStatus.error,
          error: 'Your session has expired. Please sign in again.',
          clearSigningIn: true,
        ),
      );
      // Session cannot be restored silently — redirect to full login flow.
      await _authService.acceptTerms();
      emit(state.copyWith(status: WelcomeStatus.navigatingToLoginOptions));
      emit(state.copyWith(status: WelcomeStatus.loaded, clearError: true));
    } catch (e) {
      Log.error(
        'WelcomeBloc: failed to log back in as ${account.pubkeyHex}: $e',
        name: 'WelcomeBloc',
        category: LogCategory.auth,
      );
      emit(
        state.copyWith(
          status: WelcomeStatus.error,
          error: 'Failed to continue: $e',
          clearSigningIn: true,
        ),
      );
    }
  }

  /// Cancels an account switch and restores the previous (most-recently-used)
  /// account — i.e. [WelcomeState.previousAccounts.first], regardless of
  /// [WelcomeState.selectedPubkeyHex].
  Future<void> _onCancelSwitch(
    WelcomeCancelSwitchRequested event,
    Emitter<WelcomeState> emit,
  ) async {
    final previous = state.previousAccounts.firstOrNull;
    if (previous == null) return;

    Log.info(
      'WelcomeBloc: cancel switch — restoring previous account '
      'pubkey=${previous.pubkeyHex}',
      name: 'WelcomeBloc',
      category: LogCategory.auth,
    );

    emit(
      state.copyWith(
        status: WelcomeStatus.accepting,
        signingInPubkeyHex: previous.pubkeyHex,
        clearError: true,
      ),
    );

    try {
      await _authService.signInForAccount(
        previous.pubkeyHex,
        previous.authSource,
      );
    } on SessionExpiredException {
      await _authService.acceptTerms();
      emit(state.copyWith(status: WelcomeStatus.navigatingToLoginOptions));
      emit(state.copyWith(status: WelcomeStatus.loaded, clearError: true));
    } catch (e) {
      emit(
        state.copyWith(
          status: WelcomeStatus.error,
          error: 'Failed to restore previous account: $e',
          clearSigningIn: true,
        ),
      );
    }
  }

  void _onAccountSelected(
    WelcomeAccountSelected event,
    Emitter<WelcomeState> emit,
  ) {
    Log.debug(
      'WelcomeBloc: account selected — pubkey=${event.pubkeyHex}',
      name: 'WelcomeBloc',
      category: LogCategory.auth,
    );
    emit(state.copyWith(selectedPubkeyHex: event.pubkeyHex));
  }

  Future<void> _onCreateAccountRequested(
    WelcomeCreateAccountRequested event,
    Emitter<WelcomeState> emit,
  ) async {
    Log.info(
      'WelcomeBloc: create account requested — accepting terms and '
      'navigating',
      name: 'WelcomeBloc',
      category: LogCategory.auth,
    );
    await _authService.acceptTerms();
    emit(state.copyWith(status: WelcomeStatus.navigatingToCreateAccount));
    emit(state.copyWith(status: WelcomeStatus.loaded));
  }

  Future<void> _onLoginOptionsRequested(
    WelcomeLoginOptionsRequested event,
    Emitter<WelcomeState> emit,
  ) async {
    Log.info(
      'WelcomeBloc: login options requested — accepting terms and '
      'navigating',
      name: 'WelcomeBloc',
      category: LogCategory.auth,
    );
    await _authService.acceptTerms();
    emit(state.copyWith(status: WelcomeStatus.navigatingToLoginOptions));
    emit(state.copyWith(status: WelcomeStatus.loaded));
  }

  void _onProfilesHydrated(
    WelcomeProfilesHydrated event,
    Emitter<WelcomeState> emit,
  ) {
    // Only update if we're still on the loaded screen — don't clobber
    // an in-progress sign-in or navigation.
    if (state.status != WelcomeStatus.loaded) return;

    emit(state.copyWith(previousAccounts: event.accounts));
  }
}
