// ABOUTME: Cubit for fetching and caching invite status from the invite server.
// ABOUTME: Used by settings invites screen and notifications tab.

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:invite_api_client/invite_api_client.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/models/invite_availability.dart';
import 'package:openvine/repositories/invite_availability_repository.dart';

part 'invite_status_state.dart';

/// Account-scoped signing readiness used to coordinate invite status loading.
class InviteStatusAuthSession extends Equatable {
  const InviteStatusAuthSession({
    required this.accountId,
    required this.isSignerReady,
  });

  /// Hex public key of the active account, or null while signed out.
  final String? accountId;

  /// Whether the active account can create a NIP-98 signature now.
  final bool isSignerReady;

  @override
  List<Object?> get props => [accountId, isSignerReady];
}

class InviteStatusCubit extends Cubit<InviteStatusState>
    with CloseGuardedEmit<InviteStatusState> {
  InviteStatusCubit({
    required InviteApiClient inviteApiClient,
    required InviteStatusAuthSession initialAuthSession,
    required Stream<InviteStatusAuthSession> authSessionStream,
    InviteAvailabilityRepository? availabilityRepository,
    Duration authWaitTimeout = const Duration(seconds: 12),
  }) : _inviteApiClient = inviteApiClient,
       _availabilityRepository = availabilityRepository,
       _initialAuthSession = initialAuthSession,
       _authWaitTimeout = authWaitTimeout,
       super(
         InviteStatusState(
           status: _statusBeforeFirstLoad(initialAuthSession),
           accountId: initialAuthSession.accountId,
           isSignerReady: initialAuthSession.isSignerReady,
         ),
       ) {
    _authSessionSubscription = authSessionStream.listen(_onAuthSessionChanged);
    _availabilitySubscription = availabilityRepository?.changes.listen(
      _onAvailabilityChanged,
    );
    if (state.status == InviteStatusLoadingStatus.waitingForAuth) {
      _scheduleAuthWaitTimeout();
    }
  }

  final InviteApiClient _inviteApiClient;
  final InviteAvailabilityRepository? _availabilityRepository;
  final InviteStatusAuthSession _initialAuthSession;
  final Duration _authWaitTimeout;
  late final StreamSubscription<InviteStatusAuthSession>
  _authSessionSubscription;
  StreamSubscription<InviteAvailabilityState>? _availabilitySubscription;
  Timer? _authWaitTimer;
  var _sessionGeneration = 0;

  bool get _canRequestInvites {
    final availability = _availabilityRepository?.current;
    if (availability == null) return true;
    return availability.hasResolved && availability.isEnabled;
  }

  static InviteStatusLoadingStatus _statusBeforeFirstLoad(
    InviteStatusAuthSession session,
  ) {
    if (session.accountId != null && !session.isSignerReady) {
      return InviteStatusLoadingStatus.waitingForAuth;
    }
    return InviteStatusLoadingStatus.initial;
  }

  /// Starts the initial load after the provider has finished constructing.
  void start() {
    unawaited(_onAuthSessionChanged(_initialAuthSession));
  }

  Future<void> load() async {
    if (!_canRequestInvites) {
      _clearInviteData();
      return;
    }
    if (state.status == InviteStatusLoadingStatus.loading) return;
    final requestAccountId = state.accountId;
    if (requestAccountId == null) return;
    if (!state.isSignerReady) {
      _enterWaitingForAuth();
      return;
    }
    final requestGeneration = _sessionGeneration;

    _cancelAuthWaitTimeout();
    emit(state.copyWith(status: InviteStatusLoadingStatus.loading));
    try {
      final inviteStatus = await _inviteApiClient.getInviteStatus();
      if (!_requestStillBelongsTo(requestAccountId, requestGeneration)) return;
      emitIfOpen(
        state.copyWith(
          status: InviteStatusLoadingStatus.loaded,
          inviteStatus: inviteStatus,
        ),
      );
    } on InviteApiException catch (e, stackTrace) {
      _handleInviteApiException(
        requestAccountId: requestAccountId,
        requestGeneration: requestGeneration,
        error: e,
        stackTrace: stackTrace,
      );
    } catch (e, stackTrace) {
      _emitErrorState(
        requestAccountId: requestAccountId,
        requestGeneration: requestGeneration,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> generateInvite() async {
    if (!_canRequestInvites) {
      _clearInviteData();
      return;
    }
    if (state.status == InviteStatusLoadingStatus.loading) return;
    final requestAccountId = state.accountId;
    if (requestAccountId == null) return;
    if (!state.isSignerReady) {
      _enterWaitingForAuth();
      return;
    }
    final requestGeneration = _sessionGeneration;

    _cancelAuthWaitTimeout();
    emit(state.copyWith(status: InviteStatusLoadingStatus.loading));
    try {
      await _inviteApiClient.generateInvite();
      final inviteStatus = await _inviteApiClient.getInviteStatus();
      if (!_requestStillBelongsTo(requestAccountId, requestGeneration)) return;
      emitIfOpen(
        state.copyWith(
          status: InviteStatusLoadingStatus.loaded,
          inviteStatus: inviteStatus,
        ),
      );
    } on InviteApiException catch (e, stackTrace) {
      _handleInviteApiException(
        requestAccountId: requestAccountId,
        requestGeneration: requestGeneration,
        error: e,
        stackTrace: stackTrace,
      );
    } catch (e, stackTrace) {
      _emitErrorState(
        requestAccountId: requestAccountId,
        requestGeneration: requestGeneration,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _onAuthSessionChanged(InviteStatusAuthSession session) async {
    if (isClosed) return;

    final accountChanged = session.accountId != state.accountId;
    final readinessChanged = session.isSignerReady != state.isSignerReady;
    if (accountChanged || readinessChanged) {
      _sessionGeneration++;
    }

    if (accountChanged) {
      _cancelAuthWaitTimeout();
      emit(
        InviteStatusState(
          status: _statusBeforeFirstLoad(session),
          accountId: session.accountId,
          isSignerReady: session.isSignerReady,
        ),
      );
      if (!session.isSignerReady && session.accountId != null) {
        _scheduleAuthWaitTimeout();
      }
    } else if (readinessChanged) {
      if (session.isSignerReady) {
        _cancelAuthWaitTimeout();
      }
      emit(
        state.copyWith(
          status: !session.isSignerReady
              ? InviteStatusLoadingStatus.waitingForAuth
              : state.status,
          isSignerReady: session.isSignerReady,
        ),
      );
      if (!session.isSignerReady) {
        _scheduleAuthWaitTimeout();
      }
    }

    if (session.accountId != null && session.isSignerReady) {
      await load();
    }
  }

  void _onAvailabilityChanged(InviteAvailabilityState availability) {
    if (isClosed) return;
    if (!_canRequestInvites) {
      _clearInviteData();
      return;
    }
    if (state.accountId != null && state.isSignerReady) {
      unawaited(load());
    }
  }

  void _clearInviteData() {
    if (isClosed) return;
    if (state.inviteStatus == null &&
        state.status == InviteStatusLoadingStatus.initial) {
      return;
    }
    _cancelAuthWaitTimeout();
    emitIfOpen(
      InviteStatusState(
        accountId: state.accountId,
        isSignerReady: state.isSignerReady,
      ),
    );
  }

  bool _requestStillBelongsTo(String requestAccountId, int requestGeneration) =>
      !isClosed &&
      state.accountId == requestAccountId &&
      _sessionGeneration == requestGeneration;

  void _enterWaitingForAuth() {
    if (isClosed || state.accountId == null || state.isSignerReady) return;
    if (state.status != InviteStatusLoadingStatus.waitingForAuth) {
      emit(state.copyWith(status: InviteStatusLoadingStatus.waitingForAuth));
    }
    _scheduleAuthWaitTimeout();
  }

  void _scheduleAuthWaitTimeout() {
    _cancelAuthWaitTimeout();
    final waitGeneration = _sessionGeneration;
    _authWaitTimer = Timer(_authWaitTimeout, () {
      if (isClosed ||
          waitGeneration != _sessionGeneration ||
          state.isSignerReady ||
          state.status != InviteStatusLoadingStatus.waitingForAuth) {
        return;
      }
      emitIfOpen(state.copyWith(status: InviteStatusLoadingStatus.error));
    });
  }

  void _cancelAuthWaitTimeout() {
    _authWaitTimer?.cancel();
    _authWaitTimer = null;
  }

  void _handleInviteApiException({
    required String requestAccountId,
    required int requestGeneration,
    required InviteApiException error,
    required StackTrace stackTrace,
  }) {
    if (!_requestStillBelongsTo(requestAccountId, requestGeneration)) return;

    if (error.statusCode == 401) {
      emitIfOpen(state.copyWith(status: InviteStatusLoadingStatus.error));
      return;
    }

    _emitErrorState(
      requestAccountId: requestAccountId,
      requestGeneration: requestGeneration,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void _emitErrorState({
    required String requestAccountId,
    required int requestGeneration,
    required Object error,
    required StackTrace stackTrace,
  }) {
    if (!_requestStillBelongsTo(requestAccountId, requestGeneration)) return;
    addError(error, stackTrace);
    emitIfOpen(state.copyWith(status: InviteStatusLoadingStatus.error));
  }

  @override
  Future<void> close() async {
    _cancelAuthWaitTimeout();
    await _authSessionSubscription.cancel();
    await _availabilitySubscription?.cancel();
    return super.close();
  }
}
