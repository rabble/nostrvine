// ABOUTME: Service for managing FCM push notification registration and lifecycle.
// ABOUTME: Handles token registration via NIP-44 encrypted Nostr events, deregistration,
// ABOUTME: preference updates, and foreground message display.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/models/notification_preferences.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nostr_identity.dart';
import 'package:openvine/services/notification_service.dart';
import 'package:openvine/utils/nostr_timestamp.dart';
import 'package:unified_logger/unified_logger.dart';

/// Manages FCM push notification registration and lifecycle via Nostr events.
///
/// Token registration and deregistration are sent as NIP-44 encrypted Nostr
/// events to the divine push service. This ensures the FCM token is only
/// visible to the push service's key pair.
///
/// Event kinds:
/// - 3079: Registration — encrypted FCM token sent to push service
/// - 3080: Deregistration — removes device from push service
/// - 3083: Preferences — encrypted notification kind preferences
class PushNotificationService {
  /// Nostr event kind for FCM token registration.
  static const pushRegistrationKind = 3079;

  /// Nostr event kind for FCM token deregistration.
  static const pushDeregistrationKind = 3080;

  /// Nostr event kind for notification preferences update.
  static const pushPreferencesKind = 3083;

  /// App bundle identifier used in registration events.
  static const pushAppIdentifier = 'co.openvine.app';

  /// Number of days until a registration event expires.
  static const pushTokenExpirationDays = 90;

  PushNotificationService({
    required AuthService authService,
    required NostrClient nostrClient,
    required NotificationService notificationService,
    required EnvironmentConfig environmentConfig,
    required Future<String?> Function() getToken,
    FutureOr<bool> Function()? isCurrent,
  }) : _authService = authService,
       _nostrClient = nostrClient,
       _notificationService = notificationService,
       _environmentConfig = environmentConfig,
       _getToken = getToken,
       _isCurrent = isCurrent;

  final AuthService _authService;
  final NostrClient _nostrClient;
  final NotificationService _notificationService;
  final EnvironmentConfig _environmentConfig;
  final Future<String?> Function() _getToken;
  final FutureOr<bool> Function()? _isCurrent;
  bool _acceptsRegistration = true;

  /// Prevents future token registration publishes for this session.
  ///
  /// Teardown cleanup may still use the captured identity to deregister the
  /// outgoing token, but active registration and token refresh must stop once
  /// sign-out or account-switch cleanup begins.
  void deactivateRegistration() {
    _acceptsRegistration = false;
  }

  /// Registers this device with the divine push service.
  ///
  /// Gets the current FCM token, NIP-44 encrypts it, and publishes a kind
  /// [pushRegistrationKind] Nostr event to the push service pubkey.
  ///
  /// Does nothing on web ([kIsWeb] is true).
  Future<void> register(
    String userPubkey, {
    FutureOr<bool> Function()? isCurrent,
  }) async {
    if (kIsWeb) return;

    final pushServicePubkey = _configuredPushServicePubkey();
    if (pushServicePubkey == null) return;
    if (!await _isPublishCurrent(isCurrent)) return;

    final token = await _getToken();
    if (!await _isPublishCurrent(isCurrent)) return;
    if (token == null) {
      Log.warning(
        'FCM token is null — skipping push notification registration',
        name: 'PushNotificationService',
        category: LogCategory.system,
      );
      return;
    }

    await _publishRegistration(
      token,
      pushServicePubkey,
      isCurrent: isCurrent,
    );
  }

  Future<void> registerToken(
    String userPubkey,
    String token, {
    FutureOr<bool> Function()? isCurrent,
  }) async {
    if (kIsWeb) return;
    if (userPubkey != _authService.currentIdentity?.pubkey) return;

    final pushServicePubkey = _configuredPushServicePubkey();
    if (pushServicePubkey == null) return;
    if (!await _isPublishCurrent(isCurrent)) return;

    await _publishRegistration(
      token,
      pushServicePubkey,
      isCurrent: isCurrent,
    );
  }

  /// Deregisters this device from the divine push service.
  ///
  /// Publishes a kind [pushDeregistrationKind] Nostr event to the push
  /// service pubkey, signalling that notifications should no longer be
  /// delivered to this device.
  ///
  /// If [signingIdentity] is provided, deregistration signs with that captured
  /// outgoing identity instead of the live auth session. This is used by
  /// teardown cleanup that may finish after AuthService clears current identity.
  ///
  /// Does nothing on web ([kIsWeb] is true).
  Future<void> deregister(
    String userPubkey, {
    FutureOr<bool> Function()? isCurrent,
    NostrIdentity? signingIdentity,
    NostrClient? publishClient,
  }) async {
    if (kIsWeb) return;

    final pushServicePubkey = _configuredPushServicePubkey();
    if (pushServicePubkey == null) return;
    if (!await _isPublishCurrent(
      isCurrent,
      checkServiceCurrent: signingIdentity == null,
    )) {
      return;
    }

    final event = signingIdentity == null
        ? await _authService.createAndSignEvent(
            kind: pushDeregistrationKind,
            content: '',
            tags: _deregistrationTags(pushServicePubkey),
          )
        : await createSignedDeregistrationEvent(
            userPubkey,
            signingIdentity: signingIdentity,
            isCurrent: isCurrent,
          );
    if (!await _isPublishCurrent(
      isCurrent,
      checkServiceCurrent: signingIdentity == null,
    )) {
      return;
    }

    if (event == null) {
      Log.error(
        'Failed to sign deregistration event',
        name: 'PushNotificationService',
        category: LogCategory.system,
      );
      return;
    }
    if (!await _isPublishCurrent(
      isCurrent,
      checkServiceCurrent: signingIdentity == null,
    )) {
      return;
    }

    await publishDeregistrationEvent(event, publishClient: publishClient);
  }

  Future<Event?> createSignedDeregistrationEvent(
    String userPubkey, {
    required NostrIdentity signingIdentity,
    FutureOr<bool> Function()? isCurrent,
  }) async {
    if (kIsWeb) return null;
    if (userPubkey != signingIdentity.pubkey) return null;

    final pushServicePubkey = _configuredPushServicePubkey();
    if (pushServicePubkey == null) return null;
    if (!await _isPublishCurrent(isCurrent, checkServiceCurrent: false)) {
      return null;
    }

    final event = await _createAndSignEventWithIdentity(
      signingIdentity,
      kind: pushDeregistrationKind,
      content: '',
      tags: _deregistrationTags(pushServicePubkey),
    );
    if (!await _isPublishCurrent(isCurrent, checkServiceCurrent: false)) {
      return null;
    }
    return event;
  }

  Future<void> publishDeregistrationEvent(
    Event event, {
    NostrClient? publishClient,
  }) async {
    final published = await (publishClient ?? _nostrClient).publishEvent(event);
    final failureReason = published.failureReason;
    if (failureReason != null) {
      Log.error(
        'Failed to publish deregistration event: $failureReason',
        name: 'PushNotificationService',
        category: LogCategory.system,
      );
    } else {
      Log.info(
        'Push notification deregistration published',
        name: 'PushNotificationService',
        category: LogCategory.system,
      );
    }
  }

  List<List<String>> _deregistrationTags(String pushServicePubkey) => [
    ['p', pushServicePubkey],
    ['app', pushAppIdentifier],
  ];

  /// Updates notification preferences on the divine push service.
  ///
  /// NIP-44 encrypts the list of enabled Nostr event kinds and publishes a
  /// kind [pushPreferencesKind] event to the push service pubkey.
  ///
  /// Does nothing on web ([kIsWeb] is true).
  Future<bool> updatePreferences(NotificationPreferences prefs) async {
    if (kIsWeb) return false;

    final pushServicePubkey = _configuredPushServicePubkey();
    if (pushServicePubkey == null) return false;
    if (!await _isPublishCurrent(null)) return false;
    final kinds = prefs.toKindsList();
    final plaintext = jsonEncode({'kinds': kinds});

    final encrypted = await _nostrClient.signer.nip44Encrypt(
      pushServicePubkey,
      plaintext,
    );
    if (!await _isPublishCurrent(null)) return false;

    if (encrypted == null) {
      Log.error(
        'NIP-44 encryption failed for preferences update',
        name: 'PushNotificationService',
        category: LogCategory.system,
      );
      return false;
    }

    final event = await _authService.createAndSignEvent(
      kind: pushPreferencesKind,
      content: encrypted,
      tags: [
        ['p', pushServicePubkey],
        ['app', pushAppIdentifier],
      ],
    );
    if (!await _isPublishCurrent(null)) return false;

    if (event == null) {
      Log.error(
        'Failed to sign preferences event',
        name: 'PushNotificationService',
        category: LogCategory.system,
      );
      return false;
    }
    if (!await _isPublishCurrent(null)) return false;

    final published = await _nostrClient.publishEvent(event);
    final failureReason = published.failureReason;
    if (failureReason != null) {
      Log.error(
        'Failed to publish preferences event: $failureReason',
        name: 'PushNotificationService',
        category: LogCategory.system,
      );
      return false;
    } else {
      Log.info(
        'Push notification preferences updated',
        name: 'PushNotificationService',
        category: LogCategory.system,
      );
      return true;
    }
  }

  /// Handles a foreground FCM message by displaying a local notification.
  ///
  /// Extracts `title` and `body` from [data]. Falls back to `'diVine'` as
  /// the title when absent. Skips display when `body` is missing.
  Future<void> handleForegroundMessage(Map<String, dynamic> data) async {
    final body = data['body'] as String?;
    if (body == null) {
      Log.warning(
        'Foreground message missing body — skipping local notification',
        name: 'PushNotificationService',
        category: LogCategory.system,
      );
      return;
    }

    final title = (data['title'] as String?) ?? 'diVine';

    await _notificationService.sendLocal(title: title, body: body);
  }

  /// Releases resources held by this service.
  void dispose() {}

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<void> _publishRegistration(
    String token,
    String pushServicePubkey, {
    FutureOr<bool> Function()? isCurrent,
  }) async {
    if (!await _isPublishCurrent(isCurrent)) return;

    final plaintext = jsonEncode({'token': token});

    final encrypted = await _nostrClient.signer.nip44Encrypt(
      pushServicePubkey,
      plaintext,
    );
    if (!await _isPublishCurrent(isCurrent)) return;

    if (encrypted == null) {
      Log.error(
        'NIP-44 encryption failed for token registration',
        name: 'PushNotificationService',
        category: LogCategory.system,
      );
      return;
    }

    final expirationTimestamp =
        DateTime.now()
            .add(const Duration(days: pushTokenExpirationDays))
            .millisecondsSinceEpoch ~/
        1000;

    final event = await _authService.createAndSignEvent(
      kind: pushRegistrationKind,
      content: encrypted,
      tags: [
        ['p', pushServicePubkey],
        ['app', pushAppIdentifier],
        ['expiration', expirationTimestamp.toString()],
      ],
    );
    if (!await _isPublishCurrent(isCurrent)) return;

    if (event == null) {
      Log.error(
        'Failed to sign registration event',
        name: 'PushNotificationService',
        category: LogCategory.system,
      );
      return;
    }
    if (!await _isPublishCurrent(isCurrent)) return;

    final published = await _nostrClient.publishEvent(event);
    final failureReason = published.failureReason;
    if (failureReason != null) {
      Log.error(
        'Failed to publish registration event: $failureReason',
        name: 'PushNotificationService',
        category: LogCategory.system,
      );
    } else {
      Log.info(
        'Push notification registration published',
        name: 'PushNotificationService',
        category: LogCategory.system,
      );
    }
  }

  Future<Event?> _createAndSignEventWithIdentity(
    NostrIdentity identity, {
    required int kind,
    required String content,
    required List<List<String>> tags,
  }) async {
    try {
      final driftTolerance = NostrTimestamp.getDriftToleranceForKind(kind);
      final event = Event(
        identity.pubkey,
        kind,
        List<List<String>>.from(tags),
        content,
        createdAt: NostrTimestamp.now(driftTolerance: driftTolerance),
      );
      final signedEvent = await identity.signEvent(event);
      if (signedEvent == null ||
          !signedEvent.isSigned ||
          !signedEvent.isValid) {
        Log.error(
          'Failed to sign deregistration event with captured identity',
          name: 'PushNotificationService',
          category: LogCategory.system,
        );
        return null;
      }
      return signedEvent;
    } catch (e) {
      Log.error(
        'Failed to create or sign deregistration event: $e',
        name: 'PushNotificationService',
        category: LogCategory.system,
      );
      return null;
    }
  }

  Future<bool> _isPublishCurrent(
    FutureOr<bool> Function()? isCurrent, {
    bool checkServiceCurrent = true,
  }) async {
    if (checkServiceCurrent && !_acceptsRegistration) {
      return false;
    }
    if (checkServiceCurrent && _isCurrent != null && !await _isCurrent()) {
      return false;
    }
    return isCurrent == null || await isCurrent();
  }

  String? _configuredPushServicePubkey() {
    final pushServicePubkey = _environmentConfig.pushServicePubkey;
    final isPlaceholder = pushServicePubkey.startsWith('TODO_');
    final isValidHex = NostrHexUtils.isValidPubkey(pushServicePubkey);

    if (!isPlaceholder && isValidHex) {
      return pushServicePubkey;
    }

    Log.warning(
      'Push service pubkey is not configured for ${_environmentConfig.displayName} '
      '— skipping push notification sync',
      name: 'PushNotificationService',
      category: LogCategory.system,
    );
    return null;
  }
}
