import 'dart:async';

import 'package:nostr_sdk/signer/nostr_signer.dart';
import 'package:openvine/models/nostr_app_audit_event.dart';
import 'package:openvine/models/nostr_app_directory_entry.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/auth_service_signer.dart';
import 'package:openvine/services/nostr_app_audit_service.dart';
import 'package:openvine/services/nostr_app_bridge_policy.dart';
import 'package:openvine/utils/unified_logger.dart';

typedef BridgePermissionPrompter =
    Future<bool> Function(BridgePermissionRequest request);
typedef NostrAppSignerFactory = NostrSigner Function(AuthService authService);

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
    required AuthService authService,
    required NostrAppBridgePolicy policy,
    NostrAppSignerFactory? signerFactory,
    NostrAppAuditService? auditService,
  }) : _authService = authService,
       _policy = policy,
       _auditService = auditService,
       _signerFactory =
           signerFactory ??
           ((authService) =>
               authService.rpcSigner ??
               AuthServiceSigner(authService.currentKeyContainer));

  static const Set<String> _supportedMethods = {
    'getPublicKey',
    'signEvent',
    'nip44.encrypt',
    'nip44.decrypt',
  };

  final AuthService _authService;
  final NostrAppBridgePolicy _policy;
  final NostrAppAuditService? _auditService;
  final NostrAppSignerFactory _signerFactory;

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
    final pubkey = _authService.currentPublicKeyHex;
    if (pubkey == null || pubkey.isEmpty) {
      return const BridgeResult.error('unauthenticated');
    }
    return BridgeResult.success(pubkey);
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

    final signedEvent = await _authService.createAndSignEvent(
      kind: kind,
      content: content,
      tags: tags,
      createdAt: createdAt,
    );

    if (signedEvent == null) {
      return const BridgeResult.error('sign_failed');
    }

    return BridgeResult.success(signedEvent.toJson());
  }

  Future<BridgeResult> _handleNip44Encrypt(Map<String, dynamic> args) async {
    final signer = _signerFactory(_authService);
    final pubkey = _readRequiredString(args['pubkey'], fieldName: 'pubkey');
    final plaintext = _readRequiredString(
      args['plaintext'],
      fieldName: 'plaintext',
    );
    final ciphertext = await signer.nip44Encrypt(pubkey, plaintext);
    if (ciphertext == null || ciphertext.isEmpty) {
      return const BridgeResult.error('encrypt_failed');
    }
    return BridgeResult.success(ciphertext);
  }

  Future<BridgeResult> _handleNip44Decrypt(Map<String, dynamic> args) async {
    final signer = _signerFactory(_authService);
    final pubkey = _readRequiredString(args['pubkey'], fieldName: 'pubkey');
    final ciphertext = _readRequiredString(
      args['ciphertext'],
      fieldName: 'ciphertext',
    );
    final plaintext = await signer.nip44Decrypt(pubkey, ciphertext);
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
    final userPubkey = _authService.currentPublicKeyHex;
    final appId = int.tryParse(app.id);
    if (auditService == null || userPubkey == null || userPubkey.isEmpty) {
      return;
    }
    if (appId == null) {
      Log.warning(
        'Skipping sandbox audit for non-numeric app id ${app.id}',
        name: 'NostrAppBridgeService',
        category: LogCategory.system,
      );
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
