import 'dart:async';
import 'dart:developer' as developer;

import 'package:nostr_app_bridge_repository/src/models/nostr_app_audit_event.dart';
import 'package:nostr_app_bridge_repository/src/models/nostr_app_directory_entry.dart';
import 'package:nostr_app_bridge_repository/src/nostr_app_audit_service.dart';
import 'package:nostr_app_bridge_repository/src/nostr_app_bridge_policy.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';

/// Callback that prompts the user about a bridge permission request.
typedef BridgePermissionPrompter =
    Future<bool> Function(
      BridgePermissionRequest request,
    );

/// Factory that produces a [NostrSigner] for cryptographic
/// operations.
typedef NostrAppSignerFactory = NostrSigner Function();

/// Describes a pending permission request to show the user.
class BridgePermissionRequest {
  /// Creates a permission request descriptor.
  const BridgePermissionRequest({
    required this.app,
    required this.origin,
    required this.method,
    required this.capability,
    this.eventKind,
  });

  /// The app that made the request.
  final NostrAppDirectoryEntry app;

  /// The origin URI.
  final Uri origin;

  /// The NIP-07 method name.
  final String method;

  /// The capability string.
  final String capability;

  /// The Nostr event kind, if applicable.
  final int? eventKind;
}

/// The result of a bridge request.
class BridgeResult {
  /// Creates a result.
  const BridgeResult({
    required this.success,
    this.data,
    this.errorCode,
    this.errorMessage,
  });

  /// Creates a successful result.
  const BridgeResult.success(this.data)
    : success = true,
      errorCode = null,
      errorMessage = null;

  /// Creates an error result.
  const BridgeResult.error(
    this.errorCode, {
    this.errorMessage,
  }) : success = false,
       data = null;

  /// Whether the request succeeded.
  final bool success;

  /// The result payload.
  final Object? data;

  /// A machine-readable error code.
  final String? errorCode;

  /// A human-readable error message.
  final String? errorMessage;
}

/// Minimal interface for authentication operations needed by the
/// bridge service.
///
/// The host app implements this (e.g. by wrapping its AuthService).
abstract class BridgeAuthProvider {
  /// The current user's hex public key, or null if not
  /// authenticated.
  String? get currentPublicKeyHex;

  /// The user's relay list for relay discovery.
  List<BridgeRelay> get userRelays;

  /// Creates and signs a Nostr event.
  Future<BridgeSignedEvent?> createAndSignEvent({
    required int kind,
    required String content,
    required List<List<String>> tags,
    int? createdAt,
  });
}

/// A relay entry returned by [BridgeAuthProvider.userRelays].
class BridgeRelay {
  /// Creates a relay descriptor.
  const BridgeRelay({
    required this.url,
    this.read = true,
    this.write = true,
  });

  /// The relay WebSocket URL.
  final String url;

  /// Whether the relay is used for reading.
  final bool read;

  /// Whether the relay is used for writing.
  final bool write;
}

/// A signed event returned by
/// [BridgeAuthProvider.createAndSignEvent].
class BridgeSignedEvent {
  /// Creates a signed event wrapper.
  const BridgeSignedEvent({required this.json});

  /// The full signed event as a JSON-serializable map.
  final Map<String, dynamic> json;
}

/// Handles NIP-07 bridge requests from third-party Nostr web
/// apps running inside the host application.
class NostrAppBridgeService {
  /// Creates the bridge service.
  NostrAppBridgeService({
    required BridgeAuthProvider authProvider,
    required NostrAppBridgePolicy policy,
    required NostrAppSignerFactory signerFactory,
    NostrAppAuditService? auditService,
    String defaultRelayUrl = 'wss://relay.divine.video',
  }) : _authProvider = authProvider,
       _policy = policy,
       _auditService = auditService,
       _signerFactory = signerFactory,
       _defaultRelayUrl = defaultRelayUrl;

  final BridgeAuthProvider _authProvider;
  final NostrAppBridgePolicy _policy;
  final NostrAppAuditService? _auditService;
  final NostrAppSignerFactory _signerFactory;
  final String _defaultRelayUrl;

  static const _supportedMethods = {
    'getPublicKey',
    'getRelays',
    'signEvent',
    'nip44.encrypt',
    'nip44.decrypt',
  };

  /// Handles an incoming NIP-07 bridge request.
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
        decision: _auditDecisionForBlockedReason(
          result.errorCode,
        ),
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
    final pubkey = _authProvider.currentPublicKeyHex;
    if (pubkey == null || pubkey.isEmpty) {
      return const BridgeResult.error('unauthenticated');
    }
    return BridgeResult.success(pubkey);
  }

  Future<BridgeResult> _handleGetRelays() async {
    final relayMap = <String, Map<String, bool>>{};

    for (final relay in _authProvider.userRelays) {
      relayMap[relay.url] = {
        'read': relay.read,
        'write': relay.write,
      };
    }

    if (relayMap.isEmpty) {
      final signerRelays = await _signerFactory().getRelays();
      if (signerRelays case final Map<dynamic, dynamic> relays) {
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

  Future<BridgeResult> _handleSignEvent(
    Map<String, dynamic> args,
  ) async {
    final eventData = _readRecord(args['event'], fieldName: 'event');
    final kind = _readRequiredInt(
      eventData['kind'],
      fieldName: 'event.kind',
    );
    final content = _readRequiredString(
      eventData['content'],
      fieldName: 'event.content',
    );
    final tags = _readTags(eventData['tags']);
    final createdAt = _readOptionalInt(eventData['created_at']);

    final signedEvent = await _authProvider.createAndSignEvent(
      kind: kind,
      content: content,
      tags: tags,
      createdAt: createdAt,
    );

    if (signedEvent == null) {
      return const BridgeResult.error('sign_failed');
    }

    return BridgeResult.success(signedEvent.json);
  }

  Future<BridgeResult> _handleNip44Encrypt(
    Map<String, dynamic> args,
  ) async {
    final signer = _signerFactory();
    final pubkey = _readRequiredString(
      args['pubkey'],
      fieldName: 'pubkey',
    );
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

  Future<BridgeResult> _handleNip44Decrypt(
    Map<String, dynamic> args,
  ) async {
    final signer = _signerFactory();
    final pubkey = _readRequiredString(
      args['pubkey'],
      fieldName: 'pubkey',
    );
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
    if (event is! Map) return null;
    final value = event['kind'];
    if (value is int) return value;
    if (value is num) return value.toInt();
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
      throw ArgumentError(
        '$fieldName must be a non-empty string',
      );
    }
    return value;
  }

  static int _readRequiredInt(
    dynamic value, {
    required String fieldName,
  }) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    throw ArgumentError('$fieldName must be an integer');
  }

  static int? _readOptionalInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  static List<List<String>> _readTags(dynamic value) {
    if (value == null) return const [];
    if (value is! List) {
      throw ArgumentError('event.tags must be an array');
    }

    return value
        .map<List<String>>((dynamic tag) {
          if (tag is! List) {
            throw ArgumentError(
              'event.tags must only contain arrays',
            );
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
    final userPubkey = _authProvider.currentPublicKeyHex;
    final appId = int.tryParse(app.id);
    if (auditService == null || userPubkey == null || userPubkey.isEmpty) {
      return;
    }
    if (appId == null) {
      developer.log(
        'Skipping sandbox audit for non-numeric app id '
        '${app.id}',
        name: 'NostrAppBridgeService',
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
