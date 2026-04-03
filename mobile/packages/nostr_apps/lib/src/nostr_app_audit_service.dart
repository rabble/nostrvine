import 'dart:collection';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:models/models.dart' show NostrAppAuditEvent;

enum NostrAppHttpMethod {
  get('GET'),
  post('POST'),
  put('PUT'),
  delete('DELETE'),
  patch('PATCH')
  ;

  const NostrAppHttpMethod(this.value);

  final String value;
}

typedef NostrAppAuditAuthorizationProvider =
    Future<String?> Function({
      required String url,
      required NostrAppHttpMethod method,
      String? payload,
    });

class NostrAppAuditService {
  NostrAppAuditService({
    required Uri workerBaseUri,
    required NostrAppAuditAuthorizationProvider authorizationProvider,
    required http.Client httpClient,
  }) : _workerBaseUri = workerBaseUri,
       _authorizationProvider = authorizationProvider,
       _httpClient = httpClient;

  final Uri _workerBaseUri;
  final NostrAppAuditAuthorizationProvider _authorizationProvider;
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

      final authorizationHeader = await _authorizationProvider(
        url: url,
        method: NostrAppHttpMethod.post,
        payload: payload,
      );
      if (authorizationHeader == null) {
        break;
      }

      final response = await _httpClient.post(
        Uri.parse(url),
        headers: {
          'authorization': authorizationHeader,
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
