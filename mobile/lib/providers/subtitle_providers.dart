// ABOUTME: Providers for subtitle fetching with triple strategy.
// ABOUTME: Fast path: parse embedded VTT from REST API. Blossom path: fetch VTT
// ABOUTME: from media.divine.video/{sha256}/vtt. Slow path: query relay for
// ABOUTME: Kind 39307 subtitle events.

import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/subtitle_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'subtitle_providers.g.dart';

typedef SubtitlePollDelay = Future<void> Function(Duration duration);

const _maxBlossomPollAttempts = 4;
const _maxBlossomPollWait = Duration(seconds: 15);
const _defaultBlossomRetryAfter = Duration(seconds: 3);
const _subtitleVisibilityPreferenceKey = 'subtitle_visibility_enabled';

final subtitleHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final subtitlePollDelayProvider = Provider<SubtitlePollDelay>(
  (_) => Future<void>.delayed,
);

Duration _parseRetryAfter(Map<String, String> headers) {
  final rawValue = headers['retry-after'];
  if (rawValue == null) return _defaultBlossomRetryAfter;

  final seconds = int.tryParse(rawValue.trim());
  if (seconds == null || seconds <= 0) return _defaultBlossomRetryAfter;

  return Duration(seconds: seconds);
}

Uri? _parseHttpSubtitleUrl(String? textTrackRef) {
  if (textTrackRef == null || textTrackRef.isEmpty) return null;

  final uri = Uri.tryParse(textTrackRef);
  if (uri == null) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  return uri;
}

Future<List<SubtitleCue>?> _fetchBlossomSubtitles({
  required http.Client client,
  required SubtitlePollDelay delay,
  required Uri vttUrl,
}) async {
  var waited = Duration.zero;

  for (var attempt = 0; attempt < _maxBlossomPollAttempts; attempt++) {
    final response = await client.get(vttUrl);

    if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
      return SubtitleService.parseVtt(response.body);
    }

    if (response.statusCode == 202) {
      if (attempt == _maxBlossomPollAttempts - 1) return null;

      final retryAfter = _parseRetryAfter(response.headers);
      if (waited + retryAfter > _maxBlossomPollWait) {
        return null;
      }

      waited += retryAfter;
      await delay(retryAfter);
      continue;
    }

    if (response.statusCode == 404) {
      return null;
    }

    return null;
  }

  return null;
}

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

  final directSubtitleUrl = _parseHttpSubtitleUrl(textTrackRef);
  if (directSubtitleUrl != null) {
    final client = ref.read(subtitleHttpClientProvider);
    try {
      final response = await client.get(directSubtitleUrl);
      if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
        return SubtitleService.parseVtt(response.body);
      }
    } catch (e) {
      developer.log(
        'Direct VTT fetch failed for $directSubtitleUrl: $e',
        name: 'subtitleCues',
      );
    }
  }

  // Blossom path: fetch VTT from media server by sha256
  if (sha256 != null && sha256.isNotEmpty) {
    final vttUrl = Uri.parse('https://media.divine.video/$sha256/vtt');
    final client = ref.read(subtitleHttpClientProvider);
    final delay = ref.read(subtitlePollDelayProvider);
    try {
      final blossomCues = await _fetchBlossomSubtitles(
        client: client,
        delay: delay,
        vttUrl: vttUrl,
      );
      if (blossomCues != null) {
        return blossomCues;
      }
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
  bool build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getBool(_subtitleVisibilityPreferenceKey) ?? true;
  }

  /// Persist a known subtitle visibility state globally.
  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_subtitleVisibilityPreferenceKey, enabled);
  }

  /// Toggle subtitle visibility globally.
  Future<void> toggle() => setEnabled(!state);
}
