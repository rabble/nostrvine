// ABOUTME: Cubit for fetching and caching invite status from the invite server.
// ABOUTME: Used by settings invites screen and notifications tab.

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:invite_api_client/invite_api_client.dart';

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

class InviteStatusCubit extends Cubit<InviteStatusState> {
  InviteStatusCubit({
    required InviteApiClient inviteApiClient,
    required InviteStatusAuthSession initialAuthSession,
    required Stream<InviteStatusAuthSession> authSessionStream,
  }) : _inviteApiClient = inviteApiClient,
       _initialAuthSession = initialAuthSession,
       super(
         InviteStatusState(
           status: _statusBeforeFirstLoad(initialAuthSession),
           accountId: initialAuthSession.accountId,
           isSignerReady: initialAuthSession.isSignerReady,
         ),
       ) {
    _authSessionSubscription = authSessionStream.listen(_onAuthSessionChanged);
  }

  final InviteApiClient _inviteApiClient;
  final InviteStatusAuthSession _initialAuthSession;
  late final StreamSubscription<InviteStatusAuthSession>
  _authSessionSubscription;
  var _sessionGeneration = 0;

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
    if (state.status == InviteStatusLoadingStatus.loading) return;
    final requestAccountId = state.accountId;
    if (requestAccountId == null || !state.isSignerReady) return;
    final requestGeneration = _sessionGeneration;

    emit(state.copyWith(status: InviteStatusLoadingStatus.loading));
    try {
      final inviteStatus = await _inviteApiClient.getInviteStatus();
      if (!_requestStillBelongsTo(requestAccountId, requestGeneration)) return;
      _emitIfOpen(
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
    if (state.status == InviteStatusLoadingStatus.loading) return;
    final requestAccountId = state.accountId;
    if (requestAccountId == null || !state.isSignerReady) return;
    final requestGeneration = _sessionGeneration;

    emit(state.copyWith(status: InviteStatusLoadingStatus.loading));
    try {
      await _inviteApiClient.generateInvite();
      final inviteStatus = await _inviteApiClient.getInviteStatus();
      if (!_requestStillBelongsTo(requestAccountId, requestGeneration)) return;
      _emitIfOpen(
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
      emit(
        InviteStatusState(
          status: _statusBeforeFirstLoad(session),
          accountId: session.accountId,
          isSignerReady: session.isSignerReady,
        ),
      );
    } else if (readinessChanged) {
      emit(
        state.copyWith(
          status: !session.isSignerReady
              ? InviteStatusLoadingStatus.waitingForAuth
              : state.status,
          isSignerReady: session.isSignerReady,
        ),
      );
    }

    if (session.accountId != null && session.isSignerReady) {
      await load();
    }
  }

  bool _requestStillBelongsTo(
    String requestAccountId,
    int requestGeneration,
  ) =>
      !isClosed &&
      state.accountId == requestAccountId &&
      _sessionGeneration == requestGeneration;

  void _emitIfOpen(InviteStatusState nextState) {
    if (isClosed) return;
    emit(nextState);
  }

  void _handleInviteApiException({
    required String requestAccountId,
    required int requestGeneration,
    required InviteApiException error,
    required StackTrace stackTrace,
  }) {
    if (!_requestStillBelongsTo(requestAccountId, requestGeneration)) return;

    if (error.statusCode == 401) {
      _emitIfOpen(state.copyWith(status: InviteStatusLoadingStatus.error));
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
    _emitIfOpen(state.copyWith(status: InviteStatusLoadingStatus.error));
  }

  @override
  Future<void> close() async {
    await _authSessionSubscription.cancel();
    return super.close();
  }
}
