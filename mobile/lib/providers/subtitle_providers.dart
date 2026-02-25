// ABOUTME: Providers for subtitle fetching with triple strategy.
// ABOUTME: Fast path: parse embedded VTT from REST API. Blossom path: fetch VTT
// ABOUTME: from media.divine.video/{sha256}/vtt. Slow path: query relay for
// ABOUTME: Kind 39307 subtitle events.

import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/services/subtitle_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'subtitle_providers.g.dart';

/// Fetches subtitle cues for a video, using the fastest available path.
///
/// 1. If [textTrackContent] is present (REST API embedded the VTT), parse it
///    directly — zero network cost.
/// 2. If [sha256] is present, fetch VTT from the Blossom server at
///    `https://media.divine.video/{sha256}/vtt`. Returns empty list on 404
///    (VTT not yet generated). Non-blocking.
/// 3. If [textTrackRef] is present (addressable coordinates like
///    `39307:<pubkey>:subtitles:<d-tag>`), query the relay for the subtitle
///    event and parse its content.
/// 4. Otherwise returns an empty list (no subtitles available).
@riverpod
Future<List<SubtitleCue>> subtitleCues(
  Ref ref, {
  required String videoId,
  String? textTrackRef,
  String? textTrackContent,
  String? sha256,
}) async {
  // Fast path: REST API already embedded the VTT content
  if (textTrackContent != null && textTrackContent.isNotEmpty) {
    return SubtitleService.parseVtt(textTrackContent);
  }

  // Blossom path: fetch VTT from media server by sha256
  if (sha256 != null && sha256.isNotEmpty) {
    final vttUrl = Uri.parse('https://media.divine.video/$sha256/vtt');
    try {
      final response = await http.get(vttUrl);
      if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
        return SubtitleService.parseVtt(response.body);
      }
      // 404 or empty = VTT not yet generated, fall through silently
    } catch (e) {
      developer.log(
        'Blossom VTT fetch failed for $sha256: $e',
        name: 'subtitleCues',
      );
      // Network error — fall through to relay path
    }
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

/// Tracks global subtitle visibility (CC on/off).
///
/// When enabled, subtitles are shown on all videos that have them.
/// This acts as an app-wide preference - toggling on one video
/// applies to all videos.
@riverpod
class SubtitleVisibility extends _$SubtitleVisibility {
  @override
  bool build() => false;

  /// Toggle subtitle visibility globally.
  void toggle() {
    state = !state;
  }
}
