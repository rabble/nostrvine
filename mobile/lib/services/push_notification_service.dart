// ABOUTME: Service for managing FCM push notification registration and lifecycle.
// ABOUTME: Handles token registration via NIP-44 encrypted Nostr events, deregistration,
// ABOUTME: preference updates, and foreground message display.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/models/notification_preferences.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/notification_service.dart';
import 'package:openvine/utils/unified_logger.dart';

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
    required Stream<String> onTokenRefresh,
  }) : _authService = authService,
       _nostrClient = nostrClient,
       _notificationService = notificationService,
       _environmentConfig = environmentConfig,
       _getToken = getToken {
    _tokenRefreshSubscription = onTokenRefresh.listen(_onTokenRefreshed);
  }

  final AuthService _authService;
  final NostrClient _nostrClient;
  final NotificationService _notificationService;
  final EnvironmentConfig _environmentConfig;
  final Future<String?> Function() _getToken;
  StreamSubscription<String>? _tokenRefreshSubscription;

  /// Registers this device with the divine push service.
  ///
  /// Gets the current FCM token, NIP-44 encrypts it, and publishes a kind
  /// [pushRegistrationKind] Nostr event to the push service pubkey.
  ///
  /// Does nothing on web ([kIsWeb] is true).
  Future<void> register(String userPubkey) async {
    if (kIsWeb) return;

    final pushServicePubkey = _configuredPushServicePubkey();
    if (pushServicePubkey == null) return;

    final token = await _getToken();
    if (token == null) {
      Log.warning(
        'FCM token is null — skipping push notification registration',
        name: 'PushNotificationService',
        category: LogCategory.system,
      );
      return;
    }

    await _publishRegistration(token, pushServicePubkey);
  }

  /// Deregisters this device from the divine push service.
  ///
  /// Publishes a kind [pushDeregistrationKind] Nostr event to the push
  /// service pubkey, signalling that notifications should no longer be
  /// delivered to this device.
  ///
  /// Does nothing on web ([kIsWeb] is true).
  Future<void> deregister(String userPubkey) async {
    if (kIsWeb) return;

    final pushServicePubkey = _configuredPushServicePubkey();
    if (pushServicePubkey == null) return;

    final event = await _authService.createAndSignEvent(
      kind: pushDeregistrationKind,
      content: '',
      tags: [
        ['p', pushServicePubkey],
        ['app', pushAppIdentifier],
      ],
    );

    if (event == null) {
      Log.error(
        'Failed to sign deregistration event',
        name: 'PushNotificationService',
        category: LogCategory.system,
      );
      return;
    }

    final published = await _nostrClient.publishEvent(event);
    if (published == null) {
      Log.error(
        'Failed to publish deregistration event',
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

  /// Updates notification preferences on the divine push service.
  ///
  /// NIP-44 encrypts the list of enabled Nostr event kinds and publishes a
  /// kind [pushPreferencesKind] event to the push service pubkey.
  ///
  /// Does nothing on web ([kIsWeb] is true).
  Future<void> updatePreferences(NotificationPreferences prefs) async {
    if (kIsWeb) return;

    final pushServicePubkey = _configuredPushServicePubkey();
    if (pushServicePubkey == null) return;
    final kinds = prefs.toKindsList();
    final plaintext = jsonEncode({'kinds': kinds});

    final encrypted = await _nostrClient.signer.nip44Encrypt(
      pushServicePubkey,
      plaintext,
    );

    if (encrypted == null) {
      Log.error(
        'NIP-44 encryption failed for preferences update',
        name: 'PushNotificationService',
        category: LogCategory.system,
      );
      return;
    }

    final event = await _authService.createAndSignEvent(
      kind: pushPreferencesKind,
      content: encrypted,
      tags: [
        ['p', pushServicePubkey],
        ['app', pushAppIdentifier],
      ],
    );

    if (event == null) {
      Log.error(
        'Failed to sign preferences event',
        name: 'PushNotificationService',
        category: LogCategory.system,
      );
      return;
    }

    final published = await _nostrClient.publishEvent(event);
    if (published == null) {
      Log.error(
        'Failed to publish preferences event',
        name: 'PushNotificationService',
        category: LogCategory.system,
      );
    } else {
      Log.info(
        'Push notification preferences updated',
        name: 'PushNotificationService',
        category: LogCategory.system,
      );
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
  ///
  /// Cancels the FCM token refresh subscription. The service should not be
  /// used after [dispose] is called.
  void dispose() {
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<void> _publishRegistration(
    String token,
    String pushServicePubkey,
  ) async {
    final plaintext = jsonEncode({'token': token});

    final encrypted = await _nostrClient.signer.nip44Encrypt(
      pushServicePubkey,
      plaintext,
    );

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

    if (event == null) {
      Log.error(
        'Failed to sign registration event',
        name: 'PushNotificationService',
        category: LogCategory.system,
      );
      return;
    }

    final published = await _nostrClient.publishEvent(event);
    if (published == null) {
      Log.error(
        'Failed to publish registration event',
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

  void _onTokenRefreshed(String newToken) {
    Log.info(
      'FCM token refreshed — re-registering',
      name: 'PushNotificationService',
      category: LogCategory.system,
    );
    final pushServicePubkey = _configuredPushServicePubkey();
    if (pushServicePubkey == null) return;

    // Fire-and-forget: errors are logged inside _publishRegistration
    _publishRegistration(newToken, pushServicePubkey);
  }

  String? _configuredPushServicePubkey() {
    final pushServicePubkey = _environmentConfig.pushServicePubkey;
    final isPlaceholder = pushServicePubkey.startsWith('TODO_');
    final isValidHex = RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(pushServicePubkey);

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
