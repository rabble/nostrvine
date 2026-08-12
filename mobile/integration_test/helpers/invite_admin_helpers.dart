// ABOUTME: Host-side admin helpers for flipping invite-service onboardingMode
// ABOUTME: during hermetic local_stack Patrol runs. Never used by app code.

import 'dart:convert';
import 'dart:io';

import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';

import 'constants.dart';

/// Invite-service e2e admin secret (`fastly.toml` / docker config store).
///
/// Public key is `79be667e…f81798`, listed in the e2e image `admin_pubkeys`.
const inviteE2eAdminPrivateKey =
    '0000000000000000000000000000000000000000000000000000000000000001';

/// Public client-config endpoint used by the app.
Uri get inviteClientConfigUri =>
    Uri.parse('http://$localHost:$localInvitePort/v1/client-config');

Uri get _adminConfigUri =>
    Uri.parse('http://$localHost:$localInvitePort/v1/admin/config');

Uri get _adminGenerateUri =>
    Uri.parse('http://$localHost:$localInvitePort/v1/admin/generate');

/// Reads the live invite-service `onboardingMode`.
Future<String> fetchInviteOnboardingMode() async {
  final body = await _httpJson(
    method: 'GET',
    uri: inviteClientConfigUri,
  );
  final mode = body['onboardingMode'] as String?;
  if (mode == null || mode.isEmpty) {
    throw StateError('client-config missing onboardingMode: $body');
  }
  return mode;
}

/// Sets invite-service `onboarding_mode` via the admin API.
///
/// This mutates the shared local stack. Callers must restore `open` in
/// teardown so other e2e suites keep skipping the signup gate.
Future<void> setInviteOnboardingMode(String mode) async {
  await _httpJson(
    method: 'POST',
    uri: _adminConfigUri,
    authorize: true,
    body: {'onboarding_mode': mode},
  );
  final seen = await fetchInviteOnboardingMode();
  if (seen != mode) {
    throw StateError(
      'Failed to set onboarding_mode=$mode (client-config still $seen)',
    );
  }
}

/// Mints one admin-owned invite code on the local invite service.
Future<String> generateAdminInviteCode() async {
  final body = await _httpJson(
    method: 'POST',
    uri: _adminGenerateUri,
    authorize: true,
    body: {'count': 1},
  );
  final codes = (body['codes'] as List<dynamic>?)?.cast<String>();
  if (codes == null || codes.isEmpty) {
    throw StateError('admin generate returned no codes: $body');
  }
  return codes.first;
}

Future<Map<String, dynamic>> _httpJson({
  required String method,
  required Uri uri,
  bool authorize = false,
  Map<String, Object?>? body,
}) async {
  final client = HttpClient();
  try {
    final request = await client.openUrl(method, uri);
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    if (authorize) {
      request.headers.set(HttpHeaders.authorizationHeader, _adminAuthHeader());
    }
    if (body != null) {
      request.write(jsonEncode(body));
    }
    final response = await request.close();
    final raw = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        '$method $uri failed: ${response.statusCode} $raw',
        uri: uri,
      );
    }
    if (raw.isEmpty) return <String, dynamic>{};
    return jsonDecode(raw) as Map<String, dynamic>;
  } finally {
    client.close();
  }
}

/// Admin routes accept kind 27235 without URL binding.
String _adminAuthHeader() {
  final pubkey = getPublicKey(inviteE2eAdminPrivateKey);
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final event = Event(
    pubkey,
    27235,
    [
      ['expiration', '${now + 300}'],
    ],
    '',
    createdAt: now,
  )..sign(inviteE2eAdminPrivateKey);
  final encoded = base64Encode(utf8.encode(jsonEncode(event.toJson())));
  return 'Nostr $encoded';
}
