import 'dart:async';

import 'package:models/models.dart'
    show NostrAppAuditDecision, NostrAppAuditEvent, NostrAppDirectoryEntry;

import 'package:nostr_apps/src/nostr_app_audit_service.dart';
import 'package:nostr_apps/src/nostr_app_bridge_policy.dart';

typedef BridgePermissionPrompter =
    Future<bool> Function(BridgePermissionRequest request);

class NostrAppRelay {
  const NostrAppRelay({
    required this.url,
    this.read = true,
    this.write = true,
  });

  final String url;
  final bool read;
  final bool write;
}

abstract interface class NostrAppBridgeGateway {
  String? get currentPublicKeyHex;
  List<NostrAppRelay> get userRelays;

  Future<Map<String, dynamic>?> signEvent({
    required int kind,
    required String content,
    required List<List<String>> tags,
    int? createdAt,
  });

  Future<Map<dynamic, dynamic>?> getFallbackRelays();

  Future<String?> nip44Encrypt(String pubkey, String plaintext);

  Future<String?> nip44Decrypt(String pubkey, String ciphertext);
}

class BridgePermissionRequest {
  const BridgePermissionRequest({
    required this.app,
    required this.origin,
    required this.method,
    required this.capability,
    this.eventKind,
  });

  final NostrAppDirectoryEntry app;
  final Uri origin;
  final String method;
  final String capability;
  final int? eventKind;
}

class BridgeResult {
  const BridgeResult({
    required this.success,
    this.data,
    this.errorCode,
    this.errorMessage,
  });

  const BridgeResult.success(this.data)
    : success = true,
      errorCode = null,
      errorMessage = null;

  const BridgeResult.error(
    this.errorCode, {
    this.errorMessage,
  }) : success = false,
       data = null;

  final bool success;
  final Object? data;
  final String? errorCode;
  final String? errorMessage;
}

class NostrAppBridgeService {
  NostrAppBridgeService({
    required NostrAppBridgeGateway bridgeGateway,
    required NostrAppBridgePolicy policy,
    String defaultRelayUrl = 'wss://relay.divine.video',
    NostrAppAuditService? auditService,
  }) : _bridgeGateway = bridgeGateway,
       _policy = policy,
       _defaultRelayUrl = defaultRelayUrl,
       _auditService = auditService;

  static const Set<String> _supportedMethods = {
    'getPublicKey',
    'getRelays',
    'signEvent',
    'nip44.encrypt',
    'nip44.decrypt',
  };

  final NostrAppBridgeGateway _bridgeGateway;
  final NostrAppBridgePolicy _policy;
  final String _defaultRelayUrl;
  final NostrAppAuditService? _auditService;

  Future<BridgeResult> handleRequest({
    required NostrAppDirectoryEntry app,
    required Uri origin,
    required String method,
    required Map<String, dynamic> args,
    BridgePermissionPrompter? promptForPermission,
  }) async {
    if (!_supportedMethods.contains(method)) {
      const result = BridgeResult.error('unsupported_method');
      _recordAudit(
        app: app,
        origin: origin,
        method: method,
        eventKind: null,
        decision: NostrAppAuditDecision.blocked,
        errorCode: result.errorCode,
      );
      return result;
    }

    final eventKind = switch (method) {
      'signEvent' => _readEventKind(args),
      _ => null,
    };

    final evaluation = _policy.evaluate(
      app: app,
      origin: origin,
      method: method,
      eventKind: eventKind,
    );

    if (evaluation.decision == BridgeDecision.deny) {
      final result = BridgeResult.error(
        evaluation.reasonCode ?? 'request_denied',
      );
      _recordAudit(
        app: app,
        origin: origin,
        method: method,
        eventKind: eventKind,
        decision: _auditDecisionForBlockedReason(result.errorCode),
        errorCode: result.errorCode,
      );
      return result;
    }

    var auditDecision = NostrAppAuditDecision.allowed;
    if (evaluation.decision == BridgeDecision.prompt) {
      final promptResult =
          await promptForPermission?.call(
            BridgePermissionRequest(
              app: app,
              origin: origin,
              method: method,
              capability: evaluation.capability,
              eventKind: eventKind,
            ),
          ) ??
          false;

      if (!promptResult) {
        const result = BridgeResult.error('permission_denied');
        _recordAudit(
          app: app,
          origin: origin,
          method: method,
          eventKind: eventKind,
          decision: NostrAppAuditDecision.promptDenied,
          errorCode: result.errorCode,
        );
        return result;
      }

      await _policy.rememberGrant(
        app: app,
        origin: origin,
        capability: evaluation.capability,
      );
      auditDecision = NostrAppAuditDecision.promptAllowed;
    }

    late final BridgeResult result;
    switch (method) {
      case 'getPublicKey':
        result = _handleGetPublicKey();
      case 'getRelays':
        result = await _handleGetRelays();
      case 'signEvent':
        result = await _handleSignEvent(args);
      case 'nip44.encrypt':
        result = await _handleNip44Encrypt(args);
      case 'nip44.decrypt':
        result = await _handleNip44Decrypt(args);
    }

    _recordAudit(
      app: app,
      origin: origin,
      method: method,
      eventKind: eventKind,
      decision: auditDecision,
      errorCode: result.success ? null : result.errorCode,
    );
    return result;
  }

  BridgeResult _handleGetPublicKey() {
    final pubkey = _bridgeGateway.currentPublicKeyHex;
    if (pubkey == null || pubkey.isEmpty) {
      return const BridgeResult.error('unauthenticated');
    }
    return BridgeResult.success(pubkey);
  }

  Future<BridgeResult> _handleGetRelays() async {
    final relayMap = <String, Map<String, bool>>{};

    for (final relay in _bridgeGateway.userRelays) {
      relayMap[relay.url] = {
        'read': relay.read,
        'write': relay.write,
      };
    }

    if (relayMap.isEmpty) {
      final signerRelays = await _bridgeGateway.getFallbackRelays();
      if (signerRelays case final Map relays) {
        for (final entry in relays.entries) {
          final key = entry.key;
          final value = entry.value;
          if (key is! String || value is! Map) {
            continue;
          }

          final read = value['read'];
          final write = value['write'];
          relayMap[key] = {
            'read': read is! bool || read,
            'write': write is! bool || write,
          };
        }
      }
    }

    if (relayMap.isEmpty) {
      relayMap[_defaultRelayUrl] = const {
        'read': true,
        'write': true,
      };
    }

    return BridgeResult.success(relayMap);
  }

  Future<BridgeResult> _handleSignEvent(Map<String, dynamic> args) async {
    final eventData = _readRecord(args['event'], fieldName: 'event');
    final kind = _readRequiredInt(eventData['kind'], fieldName: 'event.kind');
    final content = _readRequiredString(
      eventData['content'],
      fieldName: 'event.content',
    );
    final tags = _readTags(eventData['tags']);
    final createdAt = _readOptionalInt(eventData['created_at']);

    final signedEvent = await _bridgeGateway.signEvent(
      kind: kind,
      content: content,
      tags: tags,
      createdAt: createdAt,
    );

    if (signedEvent == null) {
      return const BridgeResult.error('sign_failed');
    }

    return BridgeResult.success(signedEvent);
  }

  Future<BridgeResult> _handleNip44Encrypt(Map<String, dynamic> args) async {
    final pubkey = _readRequiredString(args['pubkey'], fieldName: 'pubkey');
    final plaintext = _readRequiredString(
      args['plaintext'],
      fieldName: 'plaintext',
    );
    final ciphertext = await _bridgeGateway.nip44Encrypt(pubkey, plaintext);
    if (ciphertext == null || ciphertext.isEmpty) {
      return const BridgeResult.error('encrypt_failed');
    }
    return BridgeResult.success(ciphertext);
  }

  Future<BridgeResult> _handleNip44Decrypt(Map<String, dynamic> args) async {
    final pubkey = _readRequiredString(args['pubkey'], fieldName: 'pubkey');
    final ciphertext = _readRequiredString(
      args['ciphertext'],
      fieldName: 'ciphertext',
    );
    final plaintext = await _bridgeGateway.nip44Decrypt(pubkey, ciphertext);
    if (plaintext == null || plaintext.isEmpty) {
      return const BridgeResult.error('decrypt_failed');
    }
    return BridgeResult.success(plaintext);
  }

  static int? _readEventKind(Map<String, dynamic> args) {
    final event = args['event'];
    if (event is! Map) {
      return null;
    }
    final value = event['kind'];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
  }

  static Map<String, dynamic> _readRecord(
    dynamic value, {
    required String fieldName,
  }) {
    if (value is! Map) {
      throw ArgumentError('$fieldName must be an object');
    }

    return value.map(
      (key, nestedValue) => MapEntry(key.toString(), nestedValue),
    );
  }

  static String _readRequiredString(
    dynamic value, {
    required String fieldName,
  }) {
    if (value is! String || value.isEmpty) {
      throw ArgumentError('$fieldName must be a non-empty string');
    }
    return value;
  }

  static int _readRequiredInt(
    dynamic value, {
    required String fieldName,
  }) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    throw ArgumentError('$fieldName must be an integer');
  }

  static int? _readOptionalInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
  }

  static List<List<String>> _readTags(dynamic value) {
    if (value == null) {
      return const [];
    }
    if (value is! List) {
      throw ArgumentError('event.tags must be an array');
    }

    return value
        .map<List<String>>((dynamic tag) {
          if (tag is! List) {
            throw ArgumentError('event.tags must only contain arrays');
          }
          return tag.map((item) => item.toString()).toList(growable: false);
        })
        .toList(growable: false);
  }

  void _recordAudit({
    required NostrAppDirectoryEntry app,
    required Uri origin,
    required String method,
    required int? eventKind,
    required NostrAppAuditDecision decision,
    String? errorCode,
  }) {
    final auditService = _auditService;
    final userPubkey = _bridgeGateway.currentPublicKeyHex;
    final appId = int.tryParse(app.id);
    if (auditService == null || userPubkey == null || userPubkey.isEmpty) {
      return;
    }
    if (appId == null) {
      return;
    }

    auditService.record(
      NostrAppAuditEvent(
        appId: appId,
        origin: origin,
        userPubkey: userPubkey,
        method: method,
        eventKind: eventKind,
        decision: decision,
        errorCode: errorCode,
        createdAt: DateTime.now().toUtc(),
      ),
    );
    unawaited(auditService.uploadQueuedEvents());
  }

  static NostrAppAuditDecision _auditDecisionForBlockedReason(
    String? errorCode,
  ) {
    return switch (errorCode) {
      'unauthenticated' || 'request_denied' => NostrAppAuditDecision.denied,
      _ => NostrAppAuditDecision.blocked,
    };
  }
}
