// ABOUTME: Providers for subtitle fetching with dual strategy.
// ABOUTME: Fast path: parse embedded VTT from REST API. Slow path: query relay
// ABOUTME: for Kind 39307 subtitle events.
//
// NOTE: Subtitle generation is temporarily disabled due to Android build issues
// with whisper_ggml_plus v1.3.1. See: https://github.com/divinevideo/divine-mobile/issues/1568

import 'package:nostr_sdk/filter.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
// import 'package:openvine/services/subtitle_generation_service.dart';
import 'package:openvine/services/subtitle_service.dart';
// import 'package:openvine/services/whisper_transcription_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'subtitle_providers.g.dart';

/// Fetches subtitle cues for a video, using the fastest available path.
///
/// 1. If [textTrackContent] is present (REST API embedded the VTT), parse it
///    directly — zero network cost.
/// 2. If [textTrackRef] is present (addressable coordinates like
///    `39307:<pubkey>:subtitles:<d-tag>`), query the relay for the subtitle
///    event and parse its content.
/// 3. Otherwise returns an empty list (no subtitles available).
@riverpod
Future<List<SubtitleCue>> subtitleCues(
  Ref ref, {
  required String videoId,
  String? textTrackRef,
  String? textTrackContent,
}) async {
  // Fast path: REST API already embedded the VTT content
  if (textTrackContent != null && textTrackContent.isNotEmpty) {
    return SubtitleService.parseVtt(textTrackContent);
  }

  // No ref at all → no subtitles
  if (textTrackRef == null || textTrackRef.isEmpty) return [];

  // Parse addressable coordinates: "39307:<pubkey>:<d-tag>"
  final parts = textTrackRef.split(':');
  // Need at least kind:pubkey:d-tag (3 parts minimum)
  if (parts.length < 3) return [];

  final kind = int.tryParse(parts[0]);
  if (kind == null) return [];

  final pubkey = parts[1];
  // d-tag may contain colons (e.g. "subtitles:my-vine-id")
  final dTag = parts.sublist(2).join(':');

  // Slow path: query relay for the subtitle event
  final nostrClient = ref.read(nostrServiceProvider);
  final events = await nostrClient.queryEvents(
    [
      Filter(kinds: [kind], authors: [pubkey], d: [dTag], limit: 1),
    ],
    tempRelays: ['wss://relay.divine.video'],
  );

  if (events.isEmpty) return [];
  return SubtitleService.parseVtt(events.first.content);
}

/// Tracks per-video subtitle visibility (CC on/off).
///
/// State is a map of video IDs to visibility booleans.
/// Videos not in the map default to subtitles hidden.
@riverpod
class SubtitleVisibility extends _$SubtitleVisibility {
  @override
  Map<String, bool> build() => {};

  /// Toggle subtitle visibility for a specific video.
  void toggle(String videoId) {
    final current = state[videoId] ?? false;
    state = {...state, videoId: !current};
  }

  /// Check if subtitles are visible for a specific video.
  bool isVisible(String videoId) => state[videoId] ?? false;
}

/// Provider for the SubtitleGenerationService.
/// Requires authentication.
// @riverpod
// SubtitleGenerationService subtitleGenerationService(Ref ref) {
//   final whisperService = WhisperTranscriptionService();
//   final authService = ref.watch(authServiceProvider);
//   final eventPublisher = ref.watch(videoEventPublisherProvider);
//   final nostrClient = ref.watch(nostrServiceProvider);

//   return SubtitleGenerationService(
//     whisperService: whisperService,
//     authService: authService,
//     eventPublisher: eventPublisher,
//     nostrClient: nostrClient,
//   );
// }
