import 'dart:async';

import 'package:divine_video_player/divine_video_player.dart';

/// In-memory fake of [DivineVideoPlayerController] for unit tests.
///
/// Overrides [state], [stateStream], [initialize], [setSource], and
/// [dispose] so no platform channel calls are made during tests.
class FakeController extends DivineVideoPlayerController {
  FakeController() : super();

  final _streamCtrl = StreamController<DivineVideoPlayerState>.broadcast();
  DivineVideoPlayerState _fakeState = const DivineVideoPlayerState();

  /// Errors thrown by the next [setSource] call.
  Exception? setSourceError;

  /// Last clip passed to [setSource].
  VideoClip? lastSource;

  @override
  DivineVideoPlayerState get state => _fakeState;

  @override
  Stream<DivineVideoPlayerState> get stateStream => _streamCtrl.stream;

  @override
  int get playerId => 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> setSource(VideoClip clip) async {
    lastSource = clip;
    if (setSourceError != null) throw setSourceError!;
  }

  @override
  Future<void> dispose() async {
    await _streamCtrl.close();
  }

  /// Pushes [newState] to the stream and updates [state].
  void pushState(DivineVideoPlayerState newState) {
    _fakeState = newState;
    if (!_streamCtrl.isClosed) _streamCtrl.add(newState);
  }
}
