import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:invite_api_client/src/invite_api_exception.dart';
import 'package:invite_api_client/src/invite_models.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

enum InviteRequestMethod { get, post, put, patch }

extension on InviteRequestMethod {
  String get value => name.toUpperCase();
}

typedef InviteAuthHeaderProvider =
    Future<String?> Function({
      required String url,
      required InviteRequestMethod method,
      String? payload,
    });

typedef InviteWarningLogger = void Function(String message);

class InviteApiClient {
  InviteApiClient({
    required String baseUrl,
    http.Client? client,
    InviteAuthHeaderProvider? authHeaderProvider,
    InviteWarningLogger? warningLogger,
    bool forceOpenOnboarding = false,
  }) : _baseUrl = baseUrl,
       _client = client ?? http.Client(),
       _authHeaderProvider = authHeaderProvider,
       _warningLogger = warningLogger,
       _forceOpenOnboarding = forceOpenOnboarding;

  static const Duration _defaultTimeout = Duration(seconds: 20);

  final String _baseUrl;
  final http.Client _client;
  final InviteAuthHeaderProvider? _authHeaderProvider;
  final InviteWarningLogger? _warningLogger;
  final bool _forceOpenOnboarding;

  static String normalizeCode(String raw) {
    final alphanumericOnly = raw.replaceAll(RegExp('[^A-Za-z0-9]'), '');
    final uppercased = alphanumericOnly.toUpperCase();

    if (uppercased.length <= 4) {
      return uppercased;
    }

    final prefix = uppercased.substring(0, 4);
    final suffixEnd = uppercased.length > 8 ? 8 : uppercased.length;
    final suffix = uppercased.substring(4, suffixEnd);
    return '$prefix-$suffix';
  }

  static bool looksLikeInviteCode(String raw) {
    final normalized = normalizeCode(raw);
    return RegExp(r'^[A-Z0-9]{4}-[A-Z0-9]{4}$').hasMatch(normalized);
  }

  Future<InviteClientConfig> getClientConfig() async {
    final uri = Uri.parse('$_baseUrl/v1/client-config');

    try {
      final response = await _client
          .get(uri, headers: await _headers(url: uri.toString()))
          .timeout(_defaultTimeout);

      if (response.statusCode != 200) {
        throw _requestFailed(
          message: 'Failed to load invite configuration',
          response: response,
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final config = InviteClientConfig.fromJson(json);
      if (!_forceOpenOnboarding) {
        return config;
      }

      return InviteClientConfig(
        mode: OnboardingMode.open,
        supportEmail: config.supportEmail,
      );
    } on TimeoutException {
      throw const InviteApiException('Invite configuration request timed out');
    } catch (error) {
      if (error is InviteApiException) rethrow;
      throw InviteApiException('Failed to load invite configuration: $error');
    }
  }

  Future<InviteValidationResult> validateCode(String code) async {
    final normalizedCode = normalizeCode(code);
    final uri = Uri.parse('$_baseUrl/v1/validate');

    try {
      final response = await _client
          .post(
            uri,
            headers: await _headers(
              url: uri.toString(),
              method: InviteRequestMethod.post,
            ),
            body: jsonEncode({'code': normalizedCode}),
          )
          .timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return InviteValidationResult.fromJson(json);
      }

      if (_isValidationRejection(response.statusCode)) {
        return _parseValidationRejection(
          body: response.body,
          fallbackCode: normalizedCode,
        );
      }

      throw _requestFailed(
        message: 'Failed to validate invite code',
        response: response,
      );
    } on TimeoutException {
      throw const InviteApiException('Invite code validation timed out');
    } catch (error) {
      if (error is InviteApiException) rethrow;
      throw InviteApiException('Failed to validate invite code: $error');
    }
  }

  Future<WaitlistJoinResult> joinWaitlist({
    required String contact,
    String? pubkey,
    String? sourceSlug,
  }) async {
    final uri = Uri.parse('$_baseUrl/v1/waitlist');
    final payload = <String, dynamic>{'contact': contact};
    if (pubkey != null && pubkey.isNotEmpty) {
      payload['pubkey'] = pubkey;
    }
    if (sourceSlug != null && sourceSlug.isNotEmpty) {
      payload['source_slug'] = sourceSlug;
    }

    try {
      final response = await _client
          .post(
            uri,
            headers: await _headers(
              url: uri.toString(),
              method: InviteRequestMethod.post,
            ),
            body: jsonEncode(payload),
          )
          .timeout(_defaultTimeout);

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw _requestFailed(
          message: 'Failed to join waitlist',
          response: response,
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return WaitlistJoinResult.fromJson(json);
    } on TimeoutException {
      throw const InviteApiException('Waitlist request timed out');
    } catch (error) {
      if (error is InviteApiException) rethrow;
      throw InviteApiException('Failed to join waitlist: $error');
    }
  }

  Future<InviteConsumeResult> consumeInvite(String code) async {
    return _consumeInvite(code: code);
  }

  Future<InviteConsumeResult> consumeInviteWithKeyContainer({
    required String code,
    required SecureKeyContainer keyContainer,
  }) async {
    late final LocalNostrSigner signer;
    keyContainer.withPrivateKey<void>((privateKeyHex) {
      signer = LocalNostrSigner(privateKeyHex);
    });

    try {
      return _consumeInvite(code: code, signer: signer);
    } finally {
      signer.close();
    }
  }

  Future<InviteConsumeResult> consumeInviteWithSession({
    required String code,
    required OAuthConfig oauthConfig,
    required KeycastSession session,
  }) async {
    final signer = KeycastRpc.fromSession(oauthConfig, session);
    try {
      return _consumeInvite(code: code, signer: signer);
    } finally {
      signer.close();
    }
  }

  Future<InviteConsumeResult> _consumeInvite({
    required String code,
    NostrSigner? signer,
  }) async {
    final normalizedCode = normalizeCode(code);
    final uri = Uri.parse('$_baseUrl/v1/consume-invite');
    final payload = jsonEncode({'code': normalizedCode});

    try {
      final response = await _client
          .post(
            uri,
            headers: await _headers(
              url: uri.toString(),
              method: InviteRequestMethod.post,
              payload: payload,
              requiresAuth: signer == null,
              signer: signer,
            ),
            body: payload,
          )
          .timeout(_defaultTimeout);

      if (response.statusCode != 200) {
        final alreadyJoined =
            _parseErrorCode(response.body) == 'user_already_joined';
        if (alreadyJoined) {
          return InviteConsumeResult.fromJson({
            'result': 'user_already_joined',
            'code': normalizedCode,
          });
        }

        throw _requestFailed(
          message: 'Failed to activate invite code',
          response: response,
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return InviteConsumeResult.fromJson(json);
    } on TimeoutException {
      throw const InviteApiException('Invite activation timed out');
    } catch (error) {
      if (error is InviteApiException) rethrow;
      throw InviteApiException('Failed to activate invite code: $error');
    }
  }

  Future<InviteStatus> getInviteStatus() async {
    final uri = Uri.parse('$_baseUrl/v1/invite-status');

    try {
      final response = await _client
          .get(
            uri,
            headers: await _headers(url: uri.toString(), requiresAuth: true),
          )
          .timeout(_defaultTimeout);

      if (response.statusCode != 200) {
        throw _requestFailed(
          message: 'Failed to fetch invite status',
          response: response,
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return InviteStatus.fromJson(json);
    } on TimeoutException {
      throw const InviteApiException('Invite status request timed out');
    } catch (error) {
      if (error is InviteApiException) rethrow;
      throw InviteApiException('Failed to fetch invite status: $error');
    }
  }

  Future<GenerateInviteResult> generateInvite() async {
    final uri = Uri.parse('$_baseUrl/v1/generate-invite');

    try {
      final response = await _client
          .post(
            uri,
            headers: await _headers(
              url: uri.toString(),
              method: InviteRequestMethod.post,
              requiresAuth: true,
            ),
          )
          .timeout(_defaultTimeout);

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw _requestFailed(
          message: 'Failed to generate invite code',
          response: response,
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return GenerateInviteResult.fromJson(json);
    } on TimeoutException {
      throw const InviteApiException('Generate invite request timed out');
    } catch (error) {
      if (error is InviteApiException) rethrow;
      throw InviteApiException('Failed to generate invite code: $error');
    }
  }

  void dispose() {
    _client.close();
  }

  Future<Map<String, String>> _headers({
    required String url,
    InviteRequestMethod method = InviteRequestMethod.get,
    String? payload,
    bool requiresAuth = false,
    NostrSigner? signer,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': 'divine-Mobile/1.0',
    };

    if (signer != null) {
      headers['Authorization'] = await _createAuthorizationHeader(
        signer: signer,
        url: url,
        method: method,
        payload: payload,
      );
    } else if (requiresAuth && _authHeaderProvider != null) {
      final header = await _authHeaderProvider(
        url: url,
        method: method,
        payload: payload,
      );

      if (header != null) {
        headers['Authorization'] = header;
      } else {
        _warningLogger?.call('Failed to attach invite auth token');
      }
    }

    return headers;
  }

  Future<String> _createAuthorizationHeader({
    required NostrSigner signer,
    required String url,
    required InviteRequestMethod method,
    String? payload,
  }) async {
    final normalizedUrl = url.contains('#')
        ? url.substring(0, url.indexOf('#'))
        : url;
    final publicKeyHex = await signer.getPublicKey();

    if (publicKeyHex == null || publicKeyHex.isEmpty) {
      throw const InviteApiException('Failed to authenticate invite request');
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final tags = <List<String>>[
      ['u', normalizedUrl],
      ['method', method.value],
      ['created_at', timestamp.toString()],
    ];

    if (method == InviteRequestMethod.post ||
        method == InviteRequestMethod.put ||
        method == InviteRequestMethod.patch) {
      final payloadHash = sha256.convert(utf8.encode(payload ?? ''));
      tags.add(['payload', payloadHash.toString()]);
    }

    final event = Event(publicKeyHex, 27235, tags, '', createdAt: timestamp);
    final signedEvent = await signer.signEvent(event);

    if (signedEvent == null || !signedEvent.isSigned) {
      throw const InviteApiException('Failed to authenticate invite request');
    }

    final eventJson = jsonEncode(signedEvent.toJson());
    return 'Nostr ${base64Encode(utf8.encode(eventJson))}';
  }

  InviteApiException _requestFailed({
    required String message,
    required http.Response response,
  }) {
    final errorCode = _parseErrorCode(response.body);
    final creatorSlug = _extractString(response.body, [
      'creatorSlug',
      'creator_slug',
    ]);
    final creatorDisplayName = _extractString(response.body, [
      'creatorDisplayName',
      'creator_display_name',
    ]);

    return InviteApiException(
      _extractErrorMessage(response.body) ?? message,
      statusCode: response.statusCode,
      responseBody: response.body,
      code: errorCode,
      creatorSlug: creatorSlug,
      creatorDisplayName: creatorDisplayName,
    );
  }

  bool _isValidationRejection(int statusCode) {
    return statusCode == 400 ||
        statusCode == 403 ||
        statusCode == 404 ||
        statusCode == 409;
  }

  InviteValidationResult _parseValidationRejection({
    required String body,
    required String fallbackCode,
  }) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return InviteValidationResult.fromJson({
          'valid': decoded['valid'] ?? false,
          'used': decoded['used'] ?? false,
          'available': decoded['available'],
          'code': decoded['code'] ?? fallbackCode,
          'errorCode': decoded['errorCode'] ?? decoded['code'],
          'creatorSlug': decoded['creatorSlug'] ?? decoded['creator_slug'],
          'creatorDisplayName':
              decoded['creatorDisplayName'] ?? decoded['creator_display_name'],
          'remaining': decoded['remaining'],
        });
      }
    } on Object catch (_) {
      // Fall back to a generic invalid result if the server body is malformed.
    }

    return InviteValidationResult(
      valid: false,
      used: false,
      code: fallbackCode,
    );
  }

  String? _extractErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded['error'] as String? ?? decoded['message'] as String?;
      }
    } on Object catch (_) {
      // Ignore malformed bodies and fall back to the caller's default message.
    }
    return null;
  }

  String? _parseErrorCode(String body) {
    return _extractString(body, ['code', 'errorCode', 'error_code']);
  }

  String? _extractString(String body, List<String> keys) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        for (final key in keys) {
          final value = decoded[key];
          if (value is String && value.isNotEmpty) {
            return value;
          }
        }
      }
    } on Object catch (_) {
      // Ignore malformed bodies and fall back to null.
    }
    return null;
  }
}
