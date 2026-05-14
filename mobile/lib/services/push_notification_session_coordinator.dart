// ABOUTME: Coordinates push registration and teardown against Nostr readiness.
// ABOUTME: Keeps mutable push-session lifecycle state out of Riverpod wiring.

import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show Event;
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nostr_identity.dart';
import 'package:openvine/services/push_notification_service.dart';
import 'package:unified_logger/unified_logger.dart';

typedef PushReadinessReader = NostrSessionReadiness Function();
typedef PushServiceReader = PushNotificationService? Function();
typedef CleanupClientFactory = NostrClient Function(NostrIdentity identity);

enum _PushRegistrationPhase { beforePushService, mayPublish }

final class _PushRegistrationOperation {
  _PushRegistrationOperation({
    required this.pubkey,
    required this.client,
    required this.pushService,
    required this.identity,
  });

  final String pubkey;
  final NostrClient client;
  final PushNotificationService pushService;
  final NostrIdentity identity;
  Future<void>? future;
  Event? deferredCleanupDeregistrationEvent;
  _PushRegistrationPhase phase = _PushRegistrationPhase.beforePushService;
  bool cleanupScheduled = false;
}

class PushNotificationSessionCoordinator {
  PushNotificationSessionCoordinator({
    required AuthService authService,
    required FirebaseMessaging firebaseMessaging,
    required PushReadinessReader readReadiness,
    required PushServiceReader readPushService,
    required CleanupClientFactory createCleanupClient,
  }) : _authService = authService,
       _firebaseMessaging = firebaseMessaging,
       _readReadiness = readReadiness,
       _readPushService = readPushService,
       _createCleanupClient = createCleanupClient;

  final AuthService _authService;
  final FirebaseMessaging _firebaseMessaging;
  final PushReadinessReader _readReadiness;
  final PushServiceReader _readPushService;
  final CleanupClientFactory _createCleanupClient;

  _PushRegistrationOperation? _activeRegistration;
  String? _lastReadyPubkey;
  NostrClient? _lastReadyClient;
  PushNotificationService? _lastReadyPushService;
  NostrIdentity? _lastReadyIdentity;

  void dispose() {
    _invalidateActiveRegistration();
  }

  void handleAuthStateChange() {
    final pubkey = _lastReadyPubkey;
    if (pubkey != null && _authService.currentIdentity?.pubkey != pubkey) {
      _lastReadyPubkey = null;
      _lastReadyClient = null;
      _lastReadyPushService = null;
      _lastReadyIdentity = null;
      _invalidateActiveRegistration();
    }
  }

  void handleReadiness(NostrSessionReadiness readiness) {
    final readyPubkey = readiness.pubkey;
    if (!readiness.isReadyForActiveClient || readyPubkey == null) {
      _invalidateActiveRegistration();
      if (readyPubkey == null ||
          _authService.currentIdentity?.pubkey != readyPubkey ||
          (_lastReadyPubkey != null && _lastReadyPubkey != readyPubkey)) {
        _lastReadyPubkey = null;
        _lastReadyClient = null;
        _lastReadyPushService = null;
        _lastReadyIdentity = null;
      }
      return;
    }

    if (_authService.currentIdentity?.pubkey != readyPubkey) {
      _lastReadyPubkey = null;
      _lastReadyClient = null;
      _lastReadyPushService = null;
      _lastReadyIdentity = null;
      _invalidateActiveRegistration();
      return;
    }

    final pushService = _readPushService();
    if (pushService == null) return;
    final identity = _authService.currentIdentity;
    if (identity == null || identity.pubkey != readyPubkey) {
      _lastReadyPubkey = null;
      _lastReadyClient = null;
      _lastReadyPushService = null;
      _lastReadyIdentity = null;
      _invalidateActiveRegistration();
      return;
    }

    _lastReadyPubkey = readyPubkey;
    _lastReadyClient = readiness.client;
    _lastReadyPushService = pushService;
    _lastReadyIdentity = identity;
    final operation = _PushRegistrationOperation(
      pubkey: readyPubkey,
      client: readiness.client!,
      pushService: pushService,
      identity: identity,
    );
    _activeRegistration = operation;
    final registrationFuture = _requestPermissionAndRegister(operation);
    operation.future = registrationFuture;
    unawaited(
      registrationFuture.whenComplete(() {
        if (identical(_activeRegistration, operation)) {
          _activeRegistration = null;
        }
      }),
    );
  }

  Future<void> deregisterLastReadyPubkey() async {
    final pubkey = _lastReadyPubkey;
    final client = _lastReadyClient;
    final pushService = _lastReadyPushService;
    final identity = _lastReadyIdentity;
    final operation = _activeRegistration;
    _invalidateActiveRegistration();
    if (pubkey == null || client == null || pushService == null) return;
    pushService.deactivateRegistration();

    final registrationOperation = operation;
    if (registrationOperation != null &&
        registrationOperation.phase == _PushRegistrationPhase.mayPublish) {
      registrationOperation.deferredCleanupDeregistrationEvent ??=
          await _createDeferredCleanupDeregistrationEvent(
            registrationOperation,
          );
    }

    if (operation?.phase != _PushRegistrationPhase.beforePushService) {
      try {
        await operation?.future?.timeout(const Duration(seconds: 4));
      } on TimeoutException catch (e) {
        Log.warning(
          'Timed out waiting for push registration before deregistration: $e',
          name: 'PushNotificationSync',
          category: LogCategory.system,
        );
        if (operation != null &&
            operation.phase == _PushRegistrationPhase.mayPublish) {
          _scheduleDeregisterAfterRegistration(operation);
        }
        return;
      }
    }

    if (!_isOutgoingSessionCurrent(pubkey, client, pushService)) return;

    if (identity == null) {
      await _deregisterCapturedPubkey(pubkey, client, pushService, null, null);
      return;
    }

    final deregistrationEvent = operation?.deferredCleanupDeregistrationEvent;
    if (deregistrationEvent != null) {
      try {
        await _publishDeregistrationWithCleanupClient(
          deregistrationEvent,
          pushService,
          identity,
        );
      } catch (e) {
        Log.warning(
          'Push notification sync listener failed: $e',
          name: 'PushNotificationSync',
          category: LogCategory.system,
        );
      }
      return;
    }

    await _deregisterWithCleanupClient(pubkey, client, pushService, identity);
  }

  void _invalidateActiveRegistration() {
    _activeRegistration = null;
  }

  bool _isRegistrationCurrent(_PushRegistrationOperation operation) {
    if (!identical(_activeRegistration, operation) ||
        _authService.currentIdentity?.pubkey != operation.pubkey) {
      return false;
    }

    final currentReadiness = _readReadiness();
    if (!currentReadiness.isReadyForActiveClient ||
        currentReadiness.pubkey != operation.pubkey ||
        !identical(currentReadiness.client, operation.client)) {
      return false;
    }

    return identical(_readPushService(), operation.pushService);
  }

  Future<void> _requestPermissionAndRegister(
    _PushRegistrationOperation operation,
  ) async {
    try {
      final current = await _firebaseMessaging.getNotificationSettings();
      if (!_isRegistrationCurrent(operation)) return;

      final settings =
          current.authorizationStatus == AuthorizationStatus.notDetermined
          ? await _firebaseMessaging.requestPermission()
          : current;

      if (!_isRegistrationCurrent(operation)) return;

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        Log.info(
          'Push notification permission denied by user',
          name: 'PushNotificationSync',
          category: LogCategory.system,
        );
        return;
      }

      if (!_isRegistrationCurrent(operation)) return;

      operation.phase = _PushRegistrationPhase.mayPublish;
      await operation.pushService.register(
        operation.pubkey,
        isCurrent: () => _isRegistrationCurrent(operation),
      );
    } catch (e) {
      Log.warning(
        'Push notification registration failed: $e',
        name: 'PushNotificationSync',
        category: LogCategory.system,
      );
    }
  }

  bool _isOutgoingSessionCurrent(
    String pubkey,
    NostrClient client,
    PushNotificationService pushService,
  ) {
    final currentReadiness = _readReadiness();
    if (currentReadiness.pubkey != null && currentReadiness.pubkey != pubkey) {
      return false;
    }

    if (currentReadiness.isReadyForActiveClient &&
        !identical(currentReadiness.client, client)) {
      return false;
    }

    return identical(pushService, _lastReadyPushService);
  }

  Future<void> _deregisterCapturedPubkey(
    String pubkey,
    NostrClient client,
    PushNotificationService pushService,
    NostrIdentity? signingIdentity,
    NostrClient? publishClient,
  ) async {
    try {
      await pushService.deregister(
        pubkey,
        isCurrent: publishClient == null
            ? () => _isOutgoingSessionCurrent(pubkey, client, pushService)
            : null,
        signingIdentity: signingIdentity,
        publishClient: publishClient,
      );
    } catch (e) {
      Log.warning(
        'Push notification sync listener failed: $e',
        name: 'PushNotificationSync',
        category: LogCategory.system,
      );
    }
  }

  Future<void> _publishDeregistrationWithCleanupClient(
    Event deregistrationEvent,
    PushNotificationService pushService,
    NostrIdentity identity,
  ) async {
    final cleanupClient = _createCleanupClient(identity);
    try {
      await cleanupClient.initialize();
      await pushService.publishDeregistrationEvent(
        deregistrationEvent,
        publishClient: cleanupClient,
      );
    } finally {
      cleanupClient.dispose();
    }
  }

  Future<void> _deregisterWithCleanupClient(
    String pubkey,
    NostrClient client,
    PushNotificationService pushService,
    NostrIdentity identity,
  ) async {
    try {
      if (!_isOutgoingSessionCurrent(pubkey, client, pushService)) return;
      final deregistrationEvent = await pushService
          .createSignedDeregistrationEvent(pubkey, signingIdentity: identity);
      if (deregistrationEvent == null) return;

      await _publishDeregistrationWithCleanupClient(
        deregistrationEvent,
        pushService,
        identity,
      );
    } catch (e) {
      Log.warning(
        'Push notification sync listener failed: $e',
        name: 'PushNotificationSync',
        category: LogCategory.system,
      );
    }
  }

  Future<Event?> _createDeferredCleanupDeregistrationEvent(
    _PushRegistrationOperation operation,
  ) async {
    try {
      if (!_isOutgoingSessionCurrent(
        operation.pubkey,
        operation.client,
        operation.pushService,
      )) {
        return null;
      }
      return await operation.pushService.createSignedDeregistrationEvent(
        operation.pubkey,
        signingIdentity: operation.identity,
      );
    } catch (e) {
      Log.warning(
        'Push notification sync listener failed: $e',
        name: 'PushNotificationSync',
        category: LogCategory.system,
      );
      return null;
    }
  }

  void _scheduleDeregisterAfterRegistration(
    _PushRegistrationOperation operation,
  ) {
    if (operation.cleanupScheduled) return;
    final registrationFuture = operation.future;
    final deregistrationEvent = operation.deferredCleanupDeregistrationEvent;
    if (registrationFuture == null) return;
    if (deregistrationEvent == null) return;
    operation.cleanupScheduled = true;
    unawaited(
      (() async {
        try {
          await registrationFuture;
          await _publishDeregistrationWithCleanupClient(
            deregistrationEvent,
            operation.pushService,
            operation.identity,
          );
        } catch (e) {
          Log.warning(
            'Push notification deferred cleanup failed: $e',
            name: 'PushNotificationSync',
            category: LogCategory.system,
          );
        }
      })(),
    );
  }
}
