import 'dart:collection';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:openvine/models/nostr_app_audit_event.dart';
import 'package:openvine/services/nip98_auth_service.dart';

class NostrAppAuditService {
  NostrAppAuditService({
    required Uri workerBaseUri,
    required Nip98AuthService nip98AuthService,
    required http.Client httpClient,
  }) : _workerBaseUri = workerBaseUri,
       _nip98AuthService = nip98AuthService,
       _httpClient = httpClient;

  final Uri _workerBaseUri;
  final Nip98AuthService _nip98AuthService;
  final http.Client _httpClient;
  final List<NostrAppAuditEvent> _queuedEvents = [];
  Future<int>? _activeUpload;

  UnmodifiableListView<NostrAppAuditEvent> get queuedEvents =>
      UnmodifiableListView(_queuedEvents);

  void record(NostrAppAuditEvent event) {
    _queuedEvents.add(event);
  }

  Future<int> uploadQueuedEvents() {
    final activeUpload = _activeUpload;
    if (activeUpload != null) {
      return activeUpload;
    }

    final upload = _uploadQueuedEvents();
    _activeUpload = upload;
    upload.whenComplete(() {
      if (identical(_activeUpload, upload)) {
        _activeUpload = null;
      }
    });
    return upload;
  }

  Future<int> _uploadQueuedEvents() async {
    var uploadedCount = 0;

    while (_queuedEvents.isNotEmpty) {
      final event = _queuedEvents.first;
      final url = _workerBaseUri.resolve('/v1/audit-events').toString();
      final payload = jsonEncode(event.toUploadJson());

      final token = await _nip98AuthService.createAuthToken(
        url: url,
        method: HttpMethod.post,
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
