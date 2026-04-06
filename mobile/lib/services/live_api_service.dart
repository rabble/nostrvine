import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:openvine/config/app_config.dart';
import 'package:openvine/models/live/live_role.dart';
import 'package:openvine/models/live/live_room.dart';
import 'package:openvine/models/live/live_room_recording.dart';
import 'package:openvine/models/live/live_room_token.dart';
import 'package:openvine/services/api_service.dart';

class LiveApiService {
  LiveApiService({
    http.Client? client,
    String? baseUrl,
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? AppConfig.backendBaseUrl;

  static const Duration _defaultTimeout = Duration(seconds: 20);

  final http.Client _client;
  final String _baseUrl;

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

    final json = await _post(
      '/v1/live/rooms',
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
    await _post(
      '/v1/live/rooms/$roomId/sessions',
      body: <String, dynamic>{'sessionId': sessionId},
      actionLabel: 'start live session',
    );
  }

  Future<LiveRoomToken> fetchJoinToken({
    required String roomId,
    required LiveRole role,
  }) async {
    final json = await _post(
      '/v1/live/rooms/$roomId/join',
      body: <String, dynamic>{'role': role.name},
      actionLabel: 'fetch live room join token',
    );

    return LiveRoomToken.fromJson(json);
  }

  Future<void> endSession({
    required String roomId,
    required String sessionId,
  }) async {
    await _post(
      '/v1/live/rooms/$roomId/sessions/$sessionId/end',
      body: const <String, dynamic>{},
      actionLabel: 'end live session',
    );
  }

  Future<LiveRoomRecording?> fetchRecording({
    required String roomId,
  }) async {
    final uri = _uri('/v1/live/rooms/$roomId/recording');

    try {
      final response = await _client
          .get(uri, headers: _headers())
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

  Future<Map<String, dynamic>> _post(
    String path, {
    required Map<String, dynamic> body,
    required String actionLabel,
  }) async {
    final uri = _uri(path);

    try {
      final response = await _client
          .post(
            uri,
            headers: _headers(),
            body: jsonEncode(body),
          )
          .timeout(_defaultTimeout);

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

  Map<String, String> _headers() => const <String, String>{
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'User-Agent': 'divine-Mobile/1.0',
  };

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  String _capitalize(String value) {
    if (value.isEmpty) {
      return value;
    }

    return '${value[0].toUpperCase()}${value.substring(1)}';
  }
}
