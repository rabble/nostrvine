import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nostr_app_bridge_repository/src/models/nostr_app_audit_event.dart';

/// Token returned by [AuditAuthTokenProvider].
class AuditAuthToken {
  /// Creates an auth token wrapper.
  const AuditAuthToken({required this.authorizationHeader});

  /// The value for the HTTP `Authorization` header.
  final String authorizationHeader;
}

/// Callback that produces an auth token for the audit API.
///
/// The host app provides this so the package does not depend on
/// app-level auth services.
typedef AuditAuthTokenProvider =
    Future<AuditAuthToken?> Function({
      required String url,
      required String method,
      required String payload,
    });

/// Queues and uploads bridge audit events to the directory worker.
class NostrAppAuditService {
  /// Creates an audit service.
  NostrAppAuditService({
    required Uri workerBaseUri,
    required AuditAuthTokenProvider authTokenProvider,
    required http.Client httpClient,
  }) : _workerBaseUri = workerBaseUri,
       _authTokenProvider = authTokenProvider,
       _httpClient = httpClient;

  final Uri _workerBaseUri;
  final AuditAuthTokenProvider _authTokenProvider;
  final http.Client _httpClient;
  final List<NostrAppAuditEvent> _queuedEvents = [];
  Future<int>? _activeUpload;

  /// Events waiting to be uploaded.
  UnmodifiableListView<NostrAppAuditEvent> get queuedEvents =>
      UnmodifiableListView(_queuedEvents);

  /// Enqueues an audit event.
  void record(NostrAppAuditEvent event) {
    _queuedEvents.add(event);
  }

  /// Uploads all queued events. Concurrent calls are coalesced.
  Future<int> uploadQueuedEvents() {
    final activeUpload = _activeUpload;
    if (activeUpload != null) {
      return activeUpload;
    }

    final upload = _uploadQueuedEvents();
    _activeUpload = upload;
    unawaited(
      upload.whenComplete(() {
        if (identical(_activeUpload, upload)) {
          _activeUpload = null;
        }
      }),
    );
    return upload;
  }

  Future<int> _uploadQueuedEvents() async {
    var uploadedCount = 0;

    while (_queuedEvents.isNotEmpty) {
      final event = _queuedEvents.first;
      final url = _workerBaseUri.resolve('/v1/audit-events').toString();
      final payload = jsonEncode(event.toUploadJson());

      final token = await _authTokenProvider(
        url: url,
        method: 'POST',
        payload: payload,
      );
      if (token == null) {
        break;
      }

      final response = await _httpClient.post(
        Uri.parse(url),
        headers: {
          'authorization': token.authorizationHeader,
          'content-type': 'application/json; charset=utf-8',
        },
        body: payload,
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        break;
      }

      _queuedEvents.removeAt(0);
      uploadedCount += 1;
    }

    return uploadedCount;
  }
}
