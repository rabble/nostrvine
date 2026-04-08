import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:openvine/config/app_config.dart';
import 'package:openvine/models/live/live_role.dart';
import 'package:openvine/models/live/live_room.dart';
import 'package:openvine/models/live/live_room_recording.dart';
import 'package:openvine/models/live/live_room_token.dart';
import 'package:openvine/services/api_service.dart';
import 'package:openvine/services/nip98_auth_service.dart';

class LiveApiService {
  LiveApiService({
    http.Client? client,
    String? baseUrl,
    Nip98AuthService? nip98AuthService,
  }) : _client = client ?? http.Client(),
       _baseUrl = (baseUrl ?? AppConfig.liveApiBaseUrl).replaceFirst(
         RegExp(r'/+$'),
         '',
       ),
       _nip98AuthService = nip98AuthService;

  static const Duration _defaultTimeout = Duration(seconds: 20);

  final http.Client _client;
  final String _baseUrl;
  final Nip98AuthService? _nip98AuthService;

  Future<LiveRoom> createRoomDraft({
    required String title,
    required String summary,
    String? imageUrl,
    List<String> relays = const <String>[],
  }) async {
    final payload = <String, dynamic>{
      'title': title,
      'summary': summary,
    };
    if (imageUrl != null && imageUrl.isNotEmpty) {
      payload['imageUrl'] = imageUrl;
    }
    payload['relays'] = relays;

    final json = await _sendJson(
      '/v1/live/rooms',
      method: HttpMethod.post,
      body: payload,
      actionLabel: 'create live room draft',
    );

    return LiveRoom(
      id: json['id'] as String? ?? '',
      hostPubkey:
          json['hostPubkey'] as String? ?? json['host_pubkey'] as String? ?? '',
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? json['image_url'] as String?,
      relays: (json['relays'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<String>()
          .toList(growable: false),
      visibility: LiveRoomVisibility.fromNostrStatus(
        json['visibility'] as String? ?? json['status'] as String?,
      ),
    );
  }

  Future<void> startSession({
    required String roomId,
    required String sessionId,
  }) async {
    await _sendJson(
      '/v1/live/rooms/$roomId/sessions',
      method: HttpMethod.post,
      body: <String, dynamic>{'sessionId': sessionId},
      actionLabel: 'start live session',
    );
  }

  Future<LiveRoomToken> fetchJoinToken({
    required String roomId,
    required LiveRole role,
  }) async {
    final json = await _sendJson(
      '/v1/live/rooms/$roomId/join',
      method: HttpMethod.post,
      body: <String, dynamic>{'role': role.name},
      actionLabel: 'fetch live room join token',
    );

    return LiveRoomToken.fromJson(json);
  }

  Future<void> endSession({
    required String roomId,
    required String sessionId,
  }) async {
    await _sendJson(
      '/v1/live/rooms/$roomId/sessions/$sessionId/end',
      method: HttpMethod.post,
      body: const <String, dynamic>{},
      actionLabel: 'end live session',
    );
  }

  Future<void> setParticipantRole({
    required String roomId,
    required String pubkey,
    required LiveRole role,
  }) async {
    await _sendJson(
      '/v1/live/rooms/$roomId/participants/$pubkey/role',
      method: HttpMethod.put,
      body: <String, dynamic>{'role': role.name},
      actionLabel: 'update live participant role',
    );
  }

  Future<LiveRoomRecording?> fetchRecording({
    required String roomId,
  }) async {
    final uri = _uri('/v1/live/rooms/$roomId/recording');

    try {
      final response = await _client
          .get(uri, headers: await _headers())
          .timeout(_defaultTimeout);

      if (response.statusCode == 204 || response.statusCode == 404) {
        return null;
      }

      if (response.statusCode != 200) {
        throw ApiException(
          'Failed to fetch live room recording',
          statusCode: response.statusCode,
          responseBody: response.body,
        );
      }

      if (response.body.isEmpty) {
        return null;
      }

      final json = _decodeBody(response.body);
      return LiveRoomRecording.fromJson(json);
    } on TimeoutException {
      throw const ApiException('Live room recording request timed out');
    } catch (error) {
      if (error is ApiException) {
        rethrow;
      }
      throw ApiException('Failed to fetch live room recording: $error');
    }
  }

  Future<Map<String, dynamic>> _sendJson(
    String path, {
    required HttpMethod method,
    required Map<String, dynamic> body,
    required String actionLabel,
  }) async {
    final uri = _uri(path);
    final payload = jsonEncode(body);

    try {
      final headers = await _headers(
        url: uri.toString(),
        method: method,
        payload: payload,
        requiresAuth: true,
      );
      final response = switch (method) {
        HttpMethod.post =>
          await _client
              .post(
                uri,
                headers: headers,
                body: payload,
              )
              .timeout(_defaultTimeout),
        HttpMethod.put =>
          await _client
              .put(
                uri,
                headers: headers,
                body: payload,
              )
              .timeout(_defaultTimeout),
        HttpMethod.get ||
        HttpMethod.delete ||
        HttpMethod.patch => throw ApiException(
          'Unsupported live API method for $actionLabel: ${method.value}',
        ),
      };

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          'Failed to $actionLabel',
          statusCode: response.statusCode,
          responseBody: response.body,
        );
      }

      if (response.body.isEmpty) {
        return const <String, dynamic>{};
      }

      return _decodeBody(response.body);
    } on TimeoutException {
      throw ApiException('${_capitalize(actionLabel)} timed out');
    } catch (error) {
      if (error is ApiException) {
        rethrow;
      }
      throw ApiException('Failed to $actionLabel: $error');
    }
  }

  Map<String, dynamic> _decodeBody(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    throw const ApiException('Live API returned an invalid response body');
  }

  Future<Map<String, String>> _headers({
    String? url,
    HttpMethod method = HttpMethod.get,
    String? payload,
    bool requiresAuth = false,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': 'divine-Mobile/1.0',
    };

    if (!requiresAuth) {
      return headers;
    }

    final nip98AuthService = _nip98AuthService;
    if (url == null ||
        nip98AuthService == null ||
        !nip98AuthService.canCreateTokens) {
      throw const ApiException(
        'Live API request requires NIP-98 authentication',
      );
    }

    final authToken = await nip98AuthService.createAuthToken(
      url: url,
      method: method,
      payload: payload,
    );
    if (authToken == null) {
      throw const ApiException(
        'Failed to create NIP-98 auth token for live API request',
      );
    }

    headers['Authorization'] = authToken.authorizationHeader;
    return headers;
  }

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  String _capitalize(String value) {
    if (value.isEmpty) {
      return value;
    }

    return '${value[0].toUpperCase()}${value.substring(1)}';
  }
}
