// ABOUTME: Keycast RPC client implementing NostrSigner interface
// ABOUTME: Provides remote signing via Keycast server for Nostr events

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:nostr_sdk/nostr_sdk.dart';

import '../oauth/oauth_config.dart';
import '../models/keycast_session.dart';
import '../models/exceptions.dart';

class KeycastRpc implements NostrSigner {
  final String nostrApi;
  final String accessToken;
  final http.Client _client;

  KeycastRpc({
    required this.nostrApi,
    required this.accessToken,
    http.Client? httpClient,
  }) : _client = httpClient ?? http.Client();

  factory KeycastRpc.fromSession(OAuthConfig config, KeycastSession session) {
    if (!session.hasRpcAccess) {
      throw SessionExpiredException();
    }
    return KeycastRpc(
      nostrApi: config.nostrApiUrl,
      accessToken: session.accessToken!,
    );
  }

  Future<T> _call<T>(String method, List<dynamic> params,
      T Function(dynamic) fromResult) async {
    print('[Keycast RPC] Calling $method...');
    final stopwatch = Stopwatch()..start();
    final response = await _client.post(
      Uri.parse(nostrApi),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'method': method,
        'params': params,
      }),
    );

    stopwatch.stop();
    print('[Keycast RPC] $method completed in ${stopwatch.elapsedMilliseconds}ms (HTTP ${response.statusCode})');

    if (response.statusCode != 200) {
      print('[Keycast RPC] Error response: ${response.body}');
      throw RpcException(
        'HTTP ${response.statusCode}: ${response.body}',
        method: method,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    if (json.containsKey('error') && json['error'] != null) {
      throw RpcException(json['error'].toString(), method: method);
    }

    if (!json.containsKey('result')) {
      throw RpcException('Missing result in response', method: method);
    }

    return fromResult(json['result']);
  }

  @override
  Future<String?> getPublicKey() async {
    return _call('get_public_key', [], (result) => result as String);
  }

  @override
  Future<Event?> signEvent(Event event) async {
    return _call('sign_event', [event.toJson()],
        (result) => Event.fromJson(result as Map<String, dynamic>));
  }

  @override
  Future<String?> nip44Encrypt(pubkey, plaintext) async {
    return _call(
        'nip44_encrypt', [pubkey, plaintext], (result) => result as String);
  }

  @override
  Future<String?> nip44Decrypt(pubkey, ciphertext) async {
    return _call(
        'nip44_decrypt', [pubkey, ciphertext], (result) => result as String);
  }

  @override
  Future<String?> encrypt(pubkey, plaintext) async {
    return _call(
        'nip04_encrypt', [pubkey, plaintext], (result) => result as String);
  }

  @override
  Future<String?> decrypt(pubkey, ciphertext) async {
    return _call(
        'nip04_decrypt', [pubkey, ciphertext], (result) => result as String);
  }

  @override
  Future<Map?> getRelays() async {
    return null;
  }

  @override
  void close() {
    _client.close();
  }
}
