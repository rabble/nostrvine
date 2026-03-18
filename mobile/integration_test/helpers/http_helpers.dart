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
