// ABOUTME: HTTP helpers for E2E integration tests
// ABOUTME: Call keycast API endpoints for email verification and password reset

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
