// ABOUTME: Shared subtitle fetch chain used by the display provider and the
// ABOUTME: editor's load path. Ordered fallback: embedded content → each
// ABOUTME: text-track ref (http or 39307 relay) → Blossom {sha256}/vtt.

import 'package:http/http.dart' as http;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/subtitle_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// Callback type for delaying between Blossom poll attempts.
typedef SubtitlePollDelay = Future<void> Function(Duration duration);

const _maxBlossomPollAttempts = 4;
const _maxBlossomPollWait = Duration(seconds: 15);
const _defaultBlossomRetryAfter = Duration(seconds: 3);

Duration _parseRetryAfter(Map<String, String> headers) {
  final rawValue = headers['retry-after'];
  if (rawValue == null) return _defaultBlossomRetryAfter;

  final seconds = int.tryParse(rawValue.trim());
  if (seconds == null || seconds <= 0) return _defaultBlossomRetryAfter;

  return Duration(seconds: seconds);
}

Uri? _parseHttpSubtitleUrl(String ref) {
  if (ref.isEmpty) return null;

  final uri = Uri.tryParse(ref);
  if (uri == null) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  return uri;
}

Future<List<SubtitleCue>?> _fetchHttp(http.Client client, Uri url) async {
  try {
    final response = await client.get(url);
    if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
      return SubtitleService.parseVtt(response.body);
    }
  } catch (e) {
    Log.warning(
      'Direct VTT fetch failed for $url: $e',
      name: 'fetchSubtitleCues',
      category: LogCategory.video,
    );
  }
  return null;
}

Future<List<SubtitleCue>?> _fetchRelay(
  NostrClient nostrClient,
  String ref,
) async {
  final parts = ref.split(':');
  if (parts.length < 3) return null;

  final kind = int.tryParse(parts[0]);
  if (kind == null) return null;

  final pubkey = parts[1];
  // d-tag may contain colons (e.g. "subtitles:my-vine-id")
  final dTag = parts.sublist(2).join(':');

  final events = await nostrClient.queryEvents(
    [
      Filter(kinds: [kind], authors: [pubkey], d: [dTag], limit: 1),
    ],
    tempRelays: ['wss://relay.divine.video'],
  );

  if (events.isEmpty) return null;
  return SubtitleService.parseVtt(events.first.content);
}

Future<List<SubtitleCue>?> _fetchBlossom({
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
      if (waited + retryAfter > _maxBlossomPollWait) return null;

      waited += retryAfter;
      await delay(retryAfter);
      continue;
    }

    return null;
  }

  return null;
}

/// Resolves subtitle cues with ordered fallback.
///
/// Strategy (first success wins):
/// 1. If [textTrackContent] is non-empty, parse it directly (zero network).
/// 2. For each ref in [textTrackRefs], try HTTP fetch (http/https) or relay
///    query (Nostr NIP coords). [nostrClient] may be null; relay refs are
///    skipped when it is.
/// 3. If [sha256] is present, fetch from Blossom at
///    `https://media.divine.video/{sha256}/vtt`, polling on 202.
///
/// Returns `[]` when no source yields cues.
Future<List<SubtitleCue>> fetchSubtitleCues({
  required http.Client httpClient,
  required NostrClient? nostrClient,
  required SubtitlePollDelay delay,
  String? textTrackContent,
  List<String> textTrackRefs = const [],
  String? sha256,
}) async {
  if (textTrackContent != null && textTrackContent.isNotEmpty) {
    return SubtitleService.parseVtt(textTrackContent);
  }

  for (final ref in textTrackRefs) {
    final httpUrl = _parseHttpSubtitleUrl(ref);
    if (httpUrl != null) {
      final cues = await _fetchHttp(httpClient, httpUrl);
      if (cues != null) return cues;
      continue;
    }

    if (nostrClient != null) {
      try {
        final cues = await _fetchRelay(nostrClient, ref);
        if (cues != null) return cues;
      } catch (e) {
        Log.warning(
          'Relay VTT fetch failed for $ref: $e',
          name: 'fetchSubtitleCues',
          category: LogCategory.video,
        );
      }
    }
  }

  if (sha256 != null && sha256.isNotEmpty) {
    final vttUrl = Uri.parse('https://media.divine.video/$sha256/vtt');
    try {
      final cues = await _fetchBlossom(
        client: httpClient,
        delay: delay,
        vttUrl: vttUrl,
      );
      if (cues != null) return cues;
    } catch (e) {
      Log.warning(
        'Blossom VTT fetch failed for $sha256: $e',
        name: 'fetchSubtitleCues',
        category: LogCategory.video,
      );
    }
  }

  return [];
}
