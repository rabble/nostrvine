// ABOUTME: First-party product analytics ingest client.
// ABOUTME: POSTs product event batches to /api/analytics/events with NIP-98 auth.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:openvine/services/nip98_auth_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// User-visible surface where a product analytics event occurred.
enum AnalyticsSurface {
  app('app'),
  auth('auth'),
  camera('camera'),
  comments('comments'),
  feed('feed'),
  notifications('notifications'),
  onboarding('onboarding'),
  profile('profile'),
  search('search'),
  settings('settings'),
  unknown('unknown');

  const AnalyticsSurface(this.wireName);

  final String wireName;

  static AnalyticsSurface fromWireName(String raw) {
    for (final surface in AnalyticsSurface.values) {
      if (surface.wireName == raw) return surface;
    }
    return AnalyticsSurface.unknown;
  }
}

/// Product analytics event payload matching the v0 event contract.
class ProductAnalyticsEvent {
  const ProductAnalyticsEvent({
    required this.eventId,
    required this.eventName,
    required this.occurredAt,
    required this.userPubkey,
    required this.anonymousId,
    required this.sessionId,
    required this.platform,
    required this.appVersion,
    required this.buildNumber,
    required this.surface,
    this.targetId,
    this.props = const {},
    this.propsNum = const {},
    this.schemaVersion = 1,
  });

  final String eventId;
  final String eventName;
  final DateTime occurredAt;
  final String userPubkey;
  final String anonymousId;
  final String sessionId;
  final String platform;
  final String appVersion;
  final String buildNumber;
  final AnalyticsSurface surface;
  final String? targetId;
  final Map<String, String> props;
  final Map<String, double> propsNum;
  final int schemaVersion;

  Map<String, Object?> toJson() {
    final properties = <String, Object?>{
      ...props,
      for (final entry in propsNum.entries) entry.key: entry.value,
      if (targetId != null && targetId!.isNotEmpty) 'target_id': targetId,
    };

    String stringProp(String key) => props[key] ?? '';
    double doubleProp(String key) => propsNum[key] ?? 0;
    int intProp(String key) => doubleProp(key).round();

    return {
      'event_id': eventId,
      'occurred_at': occurredAt.toUtc().toIso8601String(),
      'user_pubkey': userPubkey,
      'anonymous_id': anonymousId,
      'session_id': sessionId,
      'platform': platform,
      'app_version': appVersion,
      'build_number': buildNumber,
      'surface': surface.wireName,
      'event_name': eventName,
      'entry_point': stringProp('entry_point'),
      'flow_name': stringProp('flow_name'),
      'step_name': stringProp('step_name'),
      'result': stringProp('result'),
      'reason_code': stringProp('reason_code'),
      'content_id': props['content_id'] ?? targetId ?? '',
      'creator_pubkey': stringProp('creator_pubkey'),
      'feed_algorithm': stringProp('feed_algorithm'),
      'traffic_source': stringProp('traffic_source'),
      'feature_key': stringProp('feature_key'),
      'experiment_key': stringProp('experiment_key'),
      'variant_key': stringProp('variant_key'),
      'variation_id': intProp('variation_id'),
      'duration_ms': intProp('duration_ms'),
      'position_ms': intProp('position_ms'),
      'loop_count': intProp('loop_count'),
      'value': doubleProp('value'),
      'schema_version': schemaVersion,
      'properties': properties,
    };
  }

  String toPayloadJson() => jsonEncode(toJson());

  static ProductAnalyticsEvent fromPayloadJson(String payloadJson) {
    final decoded = jsonDecode(payloadJson) as Map<String, dynamic>;
    final properties =
        (decoded['properties'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final props = <String, String>{};
    final propsNum = <String, double>{};
    for (final entry in properties.entries) {
      final value = entry.value;
      if (value is num) {
        propsNum[entry.key] = value.toDouble();
      } else if (value != null) {
        props[entry.key] = value.toString();
      }
    }

    return ProductAnalyticsEvent(
      eventId: decoded['event_id'] as String,
      eventName: decoded['event_name'] as String,
      occurredAt: DateTime.parse(decoded['occurred_at'] as String),
      userPubkey: decoded['user_pubkey'] as String? ?? '',
      anonymousId: decoded['anonymous_id'] as String,
      sessionId: decoded['session_id'] as String,
      platform: decoded['platform'] as String? ?? '',
      appVersion: decoded['app_version'] as String? ?? '',
      buildNumber: decoded['build_number'] as String? ?? '',
      surface: AnalyticsSurface.fromWireName(
        decoded['surface'] as String? ?? '',
      ),
      targetId: properties['target_id'] as String?,
      props: props,
      propsNum: propsNum,
      schemaVersion: decoded['schema_version'] as int? ?? 1,
    );
  }
}

sealed class AnalyticsIngestResult {
  const AnalyticsIngestResult();
}

final class AnalyticsIngestAccepted extends AnalyticsIngestResult {
  const AnalyticsIngestAccepted();
}

final class AnalyticsIngestRejected extends AnalyticsIngestResult {
  const AnalyticsIngestRejected({
    required this.statusCode,
    required this.reason,
  });

  final int statusCode;
  final String reason;
}

final class AnalyticsIngestTransientFailure extends AnalyticsIngestResult {
  const AnalyticsIngestTransientFailure(this.reason);

  final String reason;
}

class AnalyticsIngestClient {
  AnalyticsIngestClient({
    required http.Client httpClient,
    required Nip98AuthService nip98AuthService,
    required String Function() apiBaseUrl,
    Duration timeout = const Duration(seconds: 15),
  }) : _httpClient = httpClient,
       _nip98 = nip98AuthService,
       _apiBaseUrl = apiBaseUrl,
       _timeout = timeout;

  static const eventsPath = '/api/analytics/events';
  static const _logName = 'AnalyticsIngestClient';

  final http.Client _httpClient;
  final Nip98AuthService _nip98;
  final String Function() _apiBaseUrl;
  final Duration _timeout;

  String get publishUrl {
    final base = _apiBaseUrl();
    final trimmed = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    return '$trimmed$eventsPath';
  }

  Future<AnalyticsIngestResult> publishBatch(
    List<ProductAnalyticsEvent> events,
  ) async {
    if (events.isEmpty) return const AnalyticsIngestAccepted();

    final url = publishUrl;
    final body = jsonEncode({
      'events': events.map((event) => event.toJson()).toList(),
    });
    final token = await _nip98.createAuthToken(
      url: url,
      method: HttpMethod.post,
      payload: body,
    );
    if (token == null) {
      return const AnalyticsIngestTransientFailure('nip98_token_unavailable');
    }

    final http.Response response;
    try {
      response = await _httpClient
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': token.authorizationHeader,
            },
            body: body,
          )
          .timeout(_timeout);
    } on TimeoutException {
      return const AnalyticsIngestTransientFailure('timeout');
    } catch (e) {
      return AnalyticsIngestTransientFailure('network_error: $e');
    }

    return _classify(response);
  }

  AnalyticsIngestResult _classify(http.Response response) {
    final status = response.statusCode;
    if (status == 200 || status == 202) {
      try {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        if (decoded['accepted'] == true) {
          return const AnalyticsIngestAccepted();
        }
        return AnalyticsIngestTransientFailure(
          'not_accepted: ${response.body}',
        );
      } catch (e) {
        return AnalyticsIngestTransientFailure('invalid_response: $e');
      }
    }

    if (status == 400 || status == 401 || status == 403 || status == 422) {
      Log.error(
        'Product analytics ingest rejected ($status): ${response.body}',
        name: _logName,
        category: LogCategory.system,
      );
      return AnalyticsIngestRejected(
        statusCode: status,
        reason: response.body,
      );
    }

    return AnalyticsIngestTransientFailure('http_$status');
  }
}
