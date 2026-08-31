import 'dart:async';

import 'package:invite_api_client/invite_api_client.dart';
import 'package:openvine/models/invite_availability.dart';
import 'package:unified_logger/unified_logger.dart';

/// Session-scoped source for signup-invite availability.
///
/// Loads invite client config once per app session and combines it with an
/// in-memory developer override. The override never mutates server state.
class InviteAvailabilityRepository {
  InviteAvailabilityRepository({
    required InviteApiClient client,
    InviteAvailabilityState? seed,
  }) : _client = client,
       _state = seed ?? const InviteAvailabilityState();

  final InviteApiClient _client;
  InviteAvailabilityState _state;
  Future<InviteAvailabilityState>? _inFlight;
  final _controller = StreamController<InviteAvailabilityState>.broadcast();

  InviteAvailabilityState get current => _state;

  Stream<InviteAvailabilityState> get changes => _controller.stream;

  /// Loads client config once. Later calls return the cached session value.
  Future<InviteAvailabilityState> loadOnce() {
    if (_state.hasResolved) return Future.value(_state);
    return _inFlight ??= _fetch().whenComplete(() {
      _inFlight = null;
    });
  }

  void setOverride(InviteAvailabilityOverride override) {
    if (_state.developerOverride == override) return;
    _emit(_state.copyWith(developerOverride: override));
  }

  void dispose() {
    _controller.close();
  }

  Future<InviteAvailabilityState> _fetch() async {
    try {
      final config = await _client.getClientConfig();
      _emit(
        _state.copyWith(
          hasResolved: true,
          serverMode: config.mode,
          config: config,
        ),
      );
    } on Object catch (error) {
      Log.warning(
        'Invite client config unavailable; defaulting signup invites off: $error',
        name: 'InviteAvailabilityRepository',
        category: LogCategory.auth,
      );
      _emit(
        _state.copyWith(
          hasResolved: true,
          clearServerMode: true,
          clearConfig: true,
        ),
      );
    }
    return _state;
  }

  void _emit(InviteAvailabilityState next) {
    _state = next;
    if (!_controller.isClosed) {
      _controller.add(next);
    }
  }
}
