import 'dart:collection';

import 'package:http/http.dart' as http;
import 'package:nostr_apps/nostr_apps.dart' as integrated_apps;
import 'package:openvine/models/nostr_app_audit_event.dart';
import 'package:openvine/services/nip98_auth_service.dart';

class NostrAppAuditService {
  NostrAppAuditService({
    required Uri workerBaseUri,
    required Nip98AuthService nip98AuthService,
    required http.Client httpClient,
  }) : _delegate = integrated_apps.NostrAppAuditService(
         workerBaseUri: workerBaseUri,
         authorizationProvider:
             ({
               required String url,
               required integrated_apps.NostrAppHttpMethod method,
               String? payload,
             }) async {
               final token = await nip98AuthService.createAuthToken(
                 url: url,
                 method: switch (method) {
                   integrated_apps.NostrAppHttpMethod.get => HttpMethod.get,
                   integrated_apps.NostrAppHttpMethod.post => HttpMethod.post,
                   integrated_apps.NostrAppHttpMethod.put => HttpMethod.put,
                   integrated_apps.NostrAppHttpMethod.delete =>
                     HttpMethod.delete,
                   integrated_apps.NostrAppHttpMethod.patch => HttpMethod.patch,
                 },
                 payload: payload,
               );
               return token?.authorizationHeader;
             },
         httpClient: httpClient,
       );

  final integrated_apps.NostrAppAuditService _delegate;

  UnmodifiableListView<NostrAppAuditEvent> get queuedEvents =>
      _delegate.queuedEvents;

  void record(NostrAppAuditEvent event) {
    _delegate.record(event);
  }

  Future<int> uploadQueuedEvents() {
    return _delegate.uploadQueuedEvents();
  }

  integrated_apps.NostrAppAuditService get implementation => _delegate;
}
