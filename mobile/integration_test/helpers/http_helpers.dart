// ABOUTME: HTTP helpers for E2E integration tests
// ABOUTME: Call keycast and Funnelcake API endpoints for tests

import 'dart:convert';
import 'dart:io';

import 'constants.dart';

/// Call keycast's verify-email endpoint directly via HTTP.
///
/// This marks the email as verified in keycast's database. The app's polling
/// cubit will detect verification on its next 3s poll cycle and complete the
/// OAuth flow automatically.
Future<void> callVerifyEmail(String token) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(
      Uri.parse('http://$localHost:$localKeycastPort/api/auth/verify-email'),
    );
    request.headers.set('Content-Type', 'application/json');
    request.write(jsonEncode({'token': token}));
    final response = await request.close();

    final body = await response.transform(utf8.decoder).join();

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'verify-email failed: ${response.statusCode} $body',
      );
    }
  } finally {
    client.close();
  }
}

/// Query the Funnelcake REST API for videos by a specific author.
///
/// Calls `GET /api/users/{pubkey}/videos` via the funnelcake-proxy on the
/// relay port — the proxy routes `/api/*` to the API service, matching
/// how the app resolves its API base URL from the relay.
Future<List<dynamic>> queryFunnelcakeVideos(String pubkey) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(
      Uri.parse(
        'http://$localHost:$localRelayPort/api/users/$pubkey/videos'
        '?limit=100&nsfw=show&moderation_profile=default',
      ),
    );
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();

    if (response.statusCode != 200) {
      throw Exception(
        'Funnelcake API failed: ${response.statusCode} $body',
      );
    }
    return jsonDecode(body) as List<dynamic>;
  } finally {
    client.close();
  }
}

/// Wait for a video by [pubkey] to appear in the Funnelcake REST API.
///
/// Polls every second until videos are returned or [maxSeconds] elapses.
/// Returns true if videos were found, false on timeout.
Future<bool> waitForFunnelcakeVideo(
  String pubkey, {
  int maxSeconds = 30,
}) async {
  for (var i = 0; i < maxSeconds; i++) {
    final videos = await queryFunnelcakeVideos(pubkey);
    if (videos.isNotEmpty) return true;
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  return false;
}

/// Wait for at least [minCount] videos by [pubkey] to appear in the
/// Funnelcake REST API.
///
/// Polls every second until `queryFunnelcakeVideos(pubkey).length >= minCount`
/// or [maxSeconds] elapses. Use this instead of [waitForFunnelcakeVideo]
/// when the caller has published more than one video and must assert on a
/// specific count — [waitForFunnelcakeVideo] returns on the first indexed
/// video and does NOT guarantee subsequent ones are indexed yet, so a
/// follow-up `expect(videos.length, >= N)` flakes under indexer load.
///
/// Returns true if at least [minCount] videos were found, false on timeout.
Future<bool> waitForFunnelcakeVideoCount(
  String pubkey, {
  required int minCount,
  int maxSeconds = 30,
}) async {
  for (var i = 0; i < maxSeconds; i++) {
    final videos = await queryFunnelcakeVideos(pubkey);
    if (videos.length >= minCount) return true;
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  return false;
}

/// Probe the Funnelcake notifications endpoint for a given [pubkey].
///
/// Hits `GET /api/users/{pubkey}/notifications?limit=1` through the relay
/// proxy and returns the HTTP status code (or -1 on network failure).
///
/// Use this in place of a generic `/api/videos` probe when the goal is to
/// catch a regression in the *notifications* routing path specifically. A
/// generic videos probe would pass even if `/api/users/.../notifications`
/// were broken or missing from the upstream router.
///
/// Accepted as "routing works" by callers: any status code that proves the
/// endpoint exists and responded — 200, 401 (auth required), 403. Reject
/// 404 (route missing) and 5xx (upstream failure).
Future<int> probeFunnelcakeNotificationsStatus(String pubkey) async {
  final client = HttpClient();
  try {
    final uri = Uri.parse(
      'http://$localHost:$localRelayPort'
      '/api/users/$pubkey/notifications?limit=1',
    );
    final request = await client.getUrl(uri);
    final response = await request.close();
    await response.drain<void>();
    return response.statusCode;
  } on Exception {
    return -1;
  } finally {
    client.close();
  }
}

/// Wait for videos by [pubkey] to disappear from the Funnelcake REST API.
///
/// Polls every second until the API returns an empty list or [maxSeconds]
/// elapses. Used after publishing a kind 5 deletion event to confirm
/// Funnelcake has processed it.
Future<bool> waitForFunnelcakeVideoGone(
  String pubkey, {
  int maxSeconds = 30,
}) async {
  for (var i = 0; i < maxSeconds; i++) {
    final videos = await queryFunnelcakeVideos(pubkey);
    if (videos.isEmpty) return true;
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  return false;
}

/// Call keycast's forgot-password endpoint to trigger a reset email.
///
/// This creates a password_reset_token in the users table that can be
/// extracted via [getPasswordResetToken] in db_helpers.dart.
Future<void> callForgotPassword(String email) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(
      Uri.parse(
        'http://$localHost:$localKeycastPort/api/auth/forgot-password',
      ),
    );
    request.headers.set('Content-Type', 'application/json');
    request.write(jsonEncode({'email': email}));
    final response = await request.close();

    final body = await response.transform(utf8.decoder).join();

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'forgot-password failed: ${response.statusCode} $body',
      );
    }
  } finally {
    client.close();
  }
}
