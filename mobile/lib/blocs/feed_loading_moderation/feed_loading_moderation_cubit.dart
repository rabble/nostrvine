// ABOUTME: Drives the deferred moderation-check gate during video loading.
// ABOUTME: Starts a timer and emits restricted when the moderation API
// ABOUTME: confirms the video is blocked, quarantined, or age-restricted.

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/feed_loading_moderation/feed_loading_moderation_state.dart';
import 'package:openvine/services/video_moderation_status_service.dart';

/// Performs a deferred moderation check during the video loading phase.
///
/// After [checkDelay] (default 2 s), fetches the moderation status for the
/// video's sha256. If the content is moderation-restricted (blocked,
/// quarantined, or age-restricted), emits
/// [FeedLoadingModerationStatus.restricted]; otherwise the state remains
/// [FeedLoadingModerationStatus.loading] for the lifetime of the cubit.
///
/// Call [start] immediately after the cubit is constructed. The timer is
/// cancelled automatically in [close].
class FeedLoadingModerationCubit extends Cubit<FeedLoadingModerationState> {
  /// Creates the cubit and resolves the video's sha256 from [explicitSha256]
  /// or [videoUrl]. No timer is started until [start] is called.
  ///
  /// When [VideoModerationStatusService.shouldCheckModeration] returns
  /// `false` for [videoUrl], or when no sha256 can be resolved, [start]
  /// is a no-op and the cubit stays in the [FeedLoadingModerationStatus.loading]
  /// state forever (meaning no moderation overlay is shown).
  FeedLoadingModerationCubit({
    required VideoModerationStatusService service,
    required String? explicitSha256,
    required String? videoUrl,
    Duration checkDelay = const Duration(seconds: 2),
  }) : _service = service,
       _checkDelay = checkDelay,
       _sha256 = VideoModerationStatusService.shouldCheckModeration(videoUrl)
           ? VideoModerationStatusService.resolveSha256(
               explicitSha256: explicitSha256,
               videoUrl: videoUrl,
             )
           : null,
       super(const FeedLoadingModerationState());

  final VideoModerationStatusService _service;
  final Duration _checkDelay;

  /// The resolved, normalised sha256 for this video, or `null` when the
  /// moderation check is not applicable.
  final String? _sha256;

  Timer? _timer;

  /// Starts the deferred moderation check.
  ///
  /// No-ops when there is no resolvable sha256 for this video.
  void start() {
    final sha256 = _sha256;
    if (sha256 == null) return;
    _timer = Timer(_checkDelay, () => _checkModeration(sha256));
  }

  Future<void> _checkModeration(String sha256) async {
    if (isClosed) return;
    try {
      final status = await _service.fetchStatus(sha256);
      if (isClosed) return;
      if (status?.isUnavailableDueToModeration ?? false) {
        emit(state.copyWith(status: FeedLoadingModerationStatus.restricted));
      }
    } catch (e, stackTrace) {
      addError(e, stackTrace);
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
