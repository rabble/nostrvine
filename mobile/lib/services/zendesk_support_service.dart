// ABOUTME: Flutter wrapper for Zendesk Support (native SDK + REST API fallback)
// ABOUTME: Provides ticket creation via native iOS/Android SDKs or REST API for desktop

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:openvine/config/zendesk_config.dart';
import 'package:openvine/services/nip98_auth_service.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Service for interacting with Zendesk Support SDK
class ZendeskSupportService {
  static const MethodChannel _channel = MethodChannel(
    'com.openvine/zendesk_support',
  );

  static bool _initialized = false;

  /// Check if Zendesk is available (credentials configured and initialized)
  static bool get isAvailable => _initialized;

  /// Current user identity info (for REST API fallback)
  static String? _userName;
  static String? _userEmail;
  static String? _userNpub;

  /// Public accessors for user identity (used by reserved username requests)
  static String? get userName => _userName;
  static String? get userEmail => _userEmail;
  static String? get userNpub => _userNpub;

  /// Reset all static state. Only for use in tests.
  @visibleForTesting
  static void resetForTesting() {
    _initialized = false;
    _userName = null;
    _userEmail = null;
    _userNpub = null;
  }

  /// Initialize Zendesk SDK
  ///
  /// Call once at app startup. Returns true if initialization successful.
  /// Returns false if credentials missing or initialization fails.
  /// App continues to work with email fallback when returns false.
  static Future<bool> initialize({
    required String appId,
    required String clientId,
    required String zendeskUrl,
  }) async {
    // Skip if credentials missing
    if (appId.isEmpty || clientId.isEmpty || zendeskUrl.isEmpty) {
      Log.info(
        'Zendesk credentials not configured - bug reports will use email fallback',
        category: LogCategory.system,
      );
      return false;
    }

    try {
      final result = await _channel.invokeMethod('initialize', {
        'appId': appId,
        'clientId': clientId,
        'zendeskUrl': zendeskUrl,
      });

      _initialized = (result == true);

      if (_initialized) {
        Log.info(
          '✅ Zendesk initialized successfully',
          category: LogCategory.system,
        );
      } else {
        Log.warning(
          'Zendesk initialization failed - bug reports will use email fallback',
          category: LogCategory.system,
        );
      }

      return _initialized;
    } on PlatformException catch (e) {
      Log.error(
        'Zendesk initialization failed: ${e.code} - ${e.message}',
        category: LogCategory.system,
      );
      _initialized = false;
      return false;
    } catch (e) {
      Log.error(
        'Unexpected error initializing Zendesk: $e',
        category: LogCategory.system,
      );
      _initialized = false;
      return false;
    }
  }

  /// Store user identity for Zendesk tickets.
  ///
  /// Call this after user login. Stores name/email/npub locally.
  /// After calling this, call setAnonymousIdentityWithUserInfo() to set
  /// the native SDK identity, then setJwtIdentity() to upgrade to
  /// authenticated identity. See zendeskIdentitySync provider.
  ///
  /// Returns true always (local storage only).
  static bool setUserIdentity({
    required String npub,
    String? displayName,
    String? nip05,
  }) {
    _userNpub = npub;

    // Determine display name: prefer displayName, fall back to NIP-05, then npub
    final effectiveName = displayName?.isNotEmpty == true
        ? displayName!
        : nip05?.isNotEmpty == true
        ? nip05!
        : _formatNpubForDisplay(npub);

    // Determine email: use NIP-05 if it looks like an email, otherwise create synthetic email
    // NIP-05 format is user@domain which works as email identifier
    // Full npub (63 chars) is within RFC 5321 local-part limit (64 chars)
    final effectiveEmail = nip05?.isNotEmpty == true && nip05!.contains('@')
        ? nip05
        : '$npub@divine.video';

    _userName = effectiveName;
    _userEmail = effectiveEmail;

    Log.info(
      'Zendesk user info stored',
      category: LogCategory.system,
    );

    return true;
  }

  /// Set anonymous identity on native SDK with user info.
  ///
  /// This provides a baseline identity so createTicket() works immediately
  /// after login without a network call. JWT identity upgrade happens
  /// asynchronously afterward and overrides this when successful.
  static Future<bool> setAnonymousIdentityWithUserInfo() async {
    if (!_initialized) return false;
    if (_userName == null || _userEmail == null) return false;

    try {
      await _channel.invokeMethod('setUserIdentity', {
        'name': _userName,
        'email': _userEmail,
      });
      Log.info(
        'Zendesk SDK: anonymous identity set with user info',
        category: LogCategory.system,
      );
      return true;
    } catch (e) {
      Log.warning(
        'Zendesk SDK: failed to set anonymous identity: $e',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Clear user identity (call on logout)
  static Future<void> clearUserIdentity() async {
    _userName = null;
    _userEmail = null;
    _userNpub = null;
    if (_initialized) {
      try {
        await _channel.invokeMethod('clearUserIdentity');
        Log.info('Zendesk user identity cleared', category: LogCategory.system);
      } catch (e) {
        Log.warning(
          'Error clearing Zendesk identity: $e',
          category: LogCategory.system,
        );
      }
    }
  }

  /// Set anonymous identity (for non-logged-in users)
  ///
  /// Sets a plain anonymous identity without name/email so Zendesk widget works.
  /// Should be called before showing ticket screens if user is not logged in.
  static Future<void> setAnonymousIdentity() async {
    if (_initialized) {
      try {
        await _channel.invokeMethod('setAnonymousIdentity');
        Log.info(
          'Zendesk anonymous identity set',
          category: LogCategory.system,
        );
      } catch (e) {
        Log.warning(
          'Error setting Zendesk anonymous identity: $e',
          category: LogCategory.system,
        );
      }
    }
  }

  // ==========================================================================
  // JWT Authentication (for native SDK ticket history)
  // ==========================================================================

  /// Fetches a pre-auth token from relay-manager by proving identity via NIP-98.
  ///
  /// The token is HMAC-signed and nonce-bound — it replaces the raw npub
  /// as the Zendesk SDK user_token to prevent impersonation.
  ///
  /// Throws [Exception] if the pre-auth request fails.
  static Future<String> fetchPreAuthToken({
    required Nip98AuthService nip98Service,
    required String relayManagerUrl,
  }) async {
    final url = '$relayManagerUrl/api/zendesk/pre-auth';

    // Clear NIP-98 cache to avoid reusing a token with a stale timestamp.
    // The server requires created_at within 60s, but tokens are cached 10min.
    nip98Service.clearTokenCache();

    final authToken = await nip98Service.createAuthToken(
      url: url,
      method: HttpMethod.post,
    );

    if (authToken == null) {
      throw Exception('Failed to create NIP-98 auth token');
    }

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': authToken.authorizationHeader,
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      Log.error(
        'Pre-auth token request failed: ${response.statusCode}',
        category: LogCategory.api,
      );
      throw Exception('Pre-auth request failed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['success'] != true || data['token'] == null) {
      throw Exception('Pre-auth response missing token');
    }

    Log.debug(
      'Pre-auth token obtained successfully',
      category: LogCategory.api,
    );

    return data['token'] as String;
  }

  /// Set JWT identity using a pre-auth token obtained via NIP-98.
  ///
  /// Fetches a pre-auth token from relay-manager (proving identity with
  /// the user's private key), then passes it to the Zendesk SDK.
  ///
  /// Returns true if identity was set successfully.
  static Future<bool> setJwtIdentity({
    required Nip98AuthService nip98Service,
    required String relayManagerUrl,
  }) async {
    if (!_initialized) {
      Log.warning(
        'Zendesk JWT: SDK not initialized',
        category: LogCategory.system,
      );
      return false;
    }

    try {
      final preAuthToken = await fetchPreAuthToken(
        nip98Service: nip98Service,
        relayManagerUrl: relayManagerUrl,
      );

      final result = await _channel.invokeMethod('setJwtIdentity', {
        'userToken': preAuthToken,
      });

      if (result == true) {
        Log.info(
          'Zendesk JWT: Identity set with pre-auth token',
          category: LogCategory.system,
        );
        return true;
      }
      return false;
    } on PlatformException catch (e) {
      Log.error(
        'Zendesk JWT: Platform error - ${e.code}: ${e.message}',
        category: LogCategory.system,
      );
      return false;
    } catch (e) {
      Log.error(
        'Zendesk JWT: Error setting identity - $e',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Format npub for display
  /// CRITICAL: Never truncate Nostr IDs - full npub needed for user identification
  static String _formatNpubForDisplay(String npub) {
    return npub;
  }

  /// Show native Zendesk ticket creation screen
  ///
  /// Presents the native Zendesk UI for creating a support ticket.
  /// Returns true if screen shown, false if Zendesk not initialized.
  ///
  /// If the native SDK returns a `NO_IDENTITY` error, this method
  /// automatically falls back to anonymous identity and retries once.
  static Future<bool> showNewTicketScreen({
    String? subject,
    String? description,
    List<String>? tags,
  }) async {
    if (!_initialized) {
      Log.warning(
        'Zendesk not initialized - cannot show ticket screen',
        category: LogCategory.system,
      );
      return false;
    }

    try {
      await _channel.invokeMethod('showNewTicket', {
        'subject': subject,
        'description': description,
        'tags': tags,
      });

      Log.info('Zendesk ticket screen shown', category: LogCategory.system);
      return true;
    } on PlatformException catch (e) {
      Log.error(
        'Failed to show Zendesk ticket screen: ${e.code} - ${e.message}',
        category: LogCategory.system,
      );

      // NO_IDENTITY: fall back to anonymous identity and retry once.
      if (e.code == 'NO_IDENTITY') {
        Log.info(
          'Retrying ticket screen with anonymous identity fallback',
          category: LogCategory.system,
        );
        final identitySet = await setAnonymousIdentityWithUserInfo();
        if (identitySet) {
          try {
            await _channel.invokeMethod('showNewTicket', {
              'subject': subject,
              'description': description,
              'tags': tags,
            });
            return true;
          } catch (retryError) {
            Log.error(
              'Retry with anonymous identity also failed: $retryError',
              category: LogCategory.system,
            );
          }
        }
      }
      return false;
    } catch (e) {
      Log.error(
        'Unexpected error showing Zendesk screen: $e',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Show user's ticket list (support history)
  ///
  /// Presents the native Zendesk UI showing all tickets from this user.
  /// Returns true if screen shown, false if Zendesk not initialized.
  ///
  /// If the native SDK returns a `NO_IDENTITY` error, this method
  /// automatically falls back to anonymous identity and retries once.
  static Future<bool> showTicketListScreen() async {
    if (!_initialized) {
      Log.warning(
        'Zendesk not initialized - cannot show ticket list',
        category: LogCategory.system,
      );
      return false;
    }

    try {
      await _channel.invokeMethod('showTicketList');
      Log.info('Zendesk ticket list shown', category: LogCategory.system);
      return true;
    } on PlatformException catch (e) {
      Log.error(
        'Failed to show Zendesk ticket list: ${e.code} - ${e.message}',
        category: LogCategory.system,
      );

      // NO_IDENTITY means the native SDK has no identity set.
      // Fall back to anonymous identity and retry once before giving up.
      if (e.code == 'NO_IDENTITY') {
        Log.info(
          'Retrying ticket list with anonymous identity fallback',
          category: LogCategory.system,
        );
        final identitySet = await setAnonymousIdentityWithUserInfo();
        if (identitySet) {
          try {
            await _channel.invokeMethod('showTicketList');
            return true;
          } catch (retryError) {
            Log.error(
              'Retry with anonymous identity also failed: $retryError',
              category: LogCategory.system,
            );
          }
        }
      }
      return false;
    } catch (e) {
      Log.error(
        'Unexpected error showing ticket list: $e',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Create a Zendesk ticket programmatically (no UI)
  ///
  /// Creates a support ticket silently in the background without showing any UI.
  /// Useful for automatic content reporting or system-generated tickets.
  /// Returns true if ticket created successfully, false otherwise.
  ///
  /// Platform support:
  /// - iOS: Full support via RequestProvider API (with custom fields)
  /// - Android: Full support via RequestProvider API (with custom fields)
  /// - macOS/Windows: Falls back to REST API
  ///
  /// Custom fields format: [{'id': 12345, 'value': 'some_value'}, ...]
  static Future<bool> createTicket({
    required String subject,
    required String description,
    List<String>? tags,
    int? ticketFormId,
    List<Map<String, dynamic>>? customFields,
  }) async {
    if (!_initialized) {
      Log.warning(
        'Zendesk not initialized - cannot create ticket',
        category: LogCategory.system,
      );
      return false;
    }

    try {
      final result = await _channel.invokeMethod('createTicket', {
        'subject': subject,
        'description': description,
        'tags': tags ?? [],
        'ticketFormId': ?ticketFormId,
        if (customFields != null && customFields.isNotEmpty)
          'customFields': customFields,
      });

      if (result == true) {
        Log.info(
          'Zendesk ticket created successfully: $subject',
          category: LogCategory.system,
        );
        return true;
      } else {
        Log.warning(
          'Failed to create Zendesk ticket: $subject',
          category: LogCategory.system,
        );
        return false;
      }
    } on MissingPluginException {
      // Native SDK not available (macOS, Windows, Web)
      // Fall back to REST API
      Log.info(
        'Native createTicket not available, falling back to REST API',
        category: LogCategory.system,
      );
      return createTicketViaApi(
        subject: subject,
        description: description,
        requesterName: _userName,
        requesterEmail: _userEmail,
        tags: tags,
      );
    } on PlatformException catch (e) {
      Log.error(
        '❌ Zendesk SDK error: ${e.code} - ${e.message}',
        category: LogCategory.system,
      );

      // JWT pre-auth tokens expire after 5 minutes. If the user reports
      // content later than that, the SDK's JWT callback will fail with
      // "unauthorized". Fall back to anonymous identity (already has
      // name/email from login) and retry before trying the REST API.
      if (e.code == 'CREATE_FAILED' &&
          e.message != null &&
          e.message!.toLowerCase().contains('unauthorized')) {
        Log.info(
          '🔄 JWT expired, retrying with anonymous identity',
          category: LogCategory.system,
        );
        try {
          final anonymousSet = await setAnonymousIdentityWithUserInfo();
          if (anonymousSet) {
            final retryResult = await _channel.invokeMethod('createTicket', {
              'subject': subject,
              'description': description,
              'tags': tags ?? [],
              'ticketFormId': ?ticketFormId,
              if (customFields != null && customFields.isNotEmpty)
                'customFields': customFields,
            });
            if (retryResult == true) {
              Log.info(
                'Zendesk ticket created on retry with anonymous identity',
                category: LogCategory.system,
              );
              return true;
            }
          }
        } catch (retryError) {
          Log.warning(
            'Anonymous identity retry also failed: $retryError',
            category: LogCategory.system,
          );
        }
      }

      // Fall back to REST API on SDK error
      Log.info(
        '🔄 Falling back to REST API after SDK error',
        category: LogCategory.system,
      );
      return createTicketViaApi(
        subject: subject,
        description: description,
        requesterName: _userName,
        requesterEmail: _userEmail,
        tags: tags,
      );
    } catch (e) {
      Log.error(
        'Unexpected error creating Zendesk ticket: $e',
        category: LogCategory.system,
      );
      return false;
    }
  }

  // ========================================================================
  // REST API Methods (for platforms without native SDK: macOS, Windows, Web)
  // ========================================================================

  /// Check if REST API is available (for platforms without native SDK)
  static bool get isRestApiAvailable => ZendeskConfig.isRestApiConfigured;

  /// Build requester object with optional external_id for JWT identity linking
  static Map<String, dynamic> _buildRequester({String? name, String? email}) {
    final requester = <String, dynamic>{
      'name': name ?? _userName ?? 'Divine App User',
      'email': email ?? _userEmail ?? ZendeskConfig.apiEmail,
    };
    if (_userNpub != null) {
      requester['external_id'] = _userNpub;
    }
    return requester;
  }

  /// Create a Zendesk ticket via REST API (no native SDK required)
  ///
  /// This works on ALL platforms including macOS, Windows, and Web.
  /// Uses the Zendesk Support API with token authentication.
  /// Returns true if ticket created successfully, false otherwise.
  static Future<bool> createTicketViaApi({
    required String subject,
    required String description,
    String? requesterEmail,
    String? requesterName,
    List<String>? tags,
  }) async {
    if (!ZendeskConfig.isRestApiConfigured) {
      Log.error(
        '❌ Zendesk REST API not configured - ZENDESK_API_TOKEN not set in build',
        category: LogCategory.system,
      );
      return false;
    }

    try {
      Log.info(
        'Creating Zendesk ticket via REST API: $subject',
        category: LogCategory.system,
      );

      final requestBody = {
        'ticket': {
          'subject': subject,
          'comment': {'body': description},
          'requester': _buildRequester(
            name: requesterName,
            email: requesterEmail,
          ),
          if (tags != null && tags.isNotEmpty) 'tags': tags,
        },
      };

      // Use /api/v2/tickets (agent API) instead of /api/v2/requests (end-user API)
      // to avoid Zendesk's anonymous request email verification (Mar 2026 rollout)
      const apiUrl = '${ZendeskConfig.zendeskUrl}/api/v2/tickets.json';

      // Create Basic Auth header: email/token:api_token
      const credentials =
          '${ZendeskConfig.apiEmail}/token:${ZendeskConfig.apiToken}';
      final encodedCredentials = base64Encode(utf8.encode(credentials));

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic $encodedCredentials',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final ticketId = responseData['ticket']?['id'];
        Log.info(
          '✅ Zendesk ticket created via API: #$ticketId - $subject',
          category: LogCategory.system,
        );
        return true;
      } else {
        Log.error(
          'Zendesk API error: ${response.statusCode} - ${response.body}',
          category: LogCategory.system,
        );
        return false;
      }
    } catch (e, stackTrace) {
      Log.error(
        'Exception creating Zendesk ticket via API: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Create a structured bug report with user-provided fields
  ///
  /// This method submits bug reports via native SDK (iOS/Android) or REST API
  /// (desktop). Using SDK ensures tickets are linked to the user's identity
  /// and visible in "View Past Messages".
  ///
  /// Custom field IDs (configured in Zendesk):
  /// - 14772963437071: ticket_form_id (Bug Report form)
  /// - 14332953477519: Ticket Type (incident)
  /// - 14884176561807: Platform (ios/android/macos/etc)
  /// - 14884157556111: OS Version
  /// - 14884184890511: Build Number
  /// - 14677364166031: Steps to Reproduce
  /// - 14677341431695: Expected Behavior
  static Future<bool> createStructuredBugReport({
    required String subject,
    required String description,
    required String reportId,
    required String appVersion,
    required Map<String, dynamic> deviceInfo,
    String? stepsToReproduce,
    String? expectedBehavior,
    String? currentScreen,
    String? userPubkey,
    Map<String, int>? errorCounts,
    String? logsSummary,
  }) async {
    Log.info(
      'Creating structured Zendesk bug report: $reportId',
      category: LogCategory.system,
    );

    // Extract platform info for custom fields
    final platform =
        deviceInfo['platform']?.toString().toLowerCase() ?? 'unknown';
    final osVersion =
        deviceInfo['version']?.toString() ??
        deviceInfo['systemVersion']?.toString() ??
        'unknown';
    // appVersion format is "1.2.3+456" - extract build number after +
    final buildNumber = appVersion.contains('+')
        ? appVersion.split('+').last
        : appVersion;

    // Build comprehensive ticket description
    // Lead with subject so Zendesk SDK ticket list preview is recognizable
    // (SDK shows first line of description body, not the subject field)
    final effectiveSubject = subject.isNotEmpty
        ? subject
        : 'Bug Report: $reportId';
    final buffer = StringBuffer();
    buffer.writeln(effectiveSubject);
    buffer.writeln();
    buffer.writeln(description);
    buffer.writeln();
    buffer.writeln('App Version: $appVersion');
    buffer.writeln();
    if (stepsToReproduce != null && stepsToReproduce.isNotEmpty) {
      buffer.writeln('### Steps to Reproduce');
      buffer.writeln(stepsToReproduce);
      buffer.writeln();
    }
    if (expectedBehavior != null && expectedBehavior.isNotEmpty) {
      buffer.writeln('### Expected Behavior');
      buffer.writeln(expectedBehavior);
      buffer.writeln();
    }
    buffer.writeln('### Device Information');
    deviceInfo.forEach((key, value) {
      buffer.writeln('- **$key:** $value');
    });
    if (currentScreen != null) {
      buffer.writeln();
      buffer.writeln('**Current Screen:** $currentScreen');
    }
    final effectivePubkey = userPubkey ?? _userNpub;
    if (effectivePubkey != null) {
      buffer.writeln('**User Pubkey:** $effectivePubkey');
    }
    if (errorCounts != null && errorCounts.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('### Recent Error Summary');
      final sortedErrors = errorCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final entry in sortedErrors.take(10)) {
        buffer.writeln('- ${entry.key}: ${entry.value} occurrences');
      }
    }
    if (logsSummary != null && logsSummary.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('### Recent Logs (Summary)');
      buffer.writeln('```');
      buffer.writeln(logsSummary);
      buffer.writeln('```');
    }

    final tags = ['bug_report', 'divine_app', 'mobile', platform];

    // Build custom fields list for SDK
    final customFields = <Map<String, dynamic>>[
      {'id': 14332953477519, 'value': 'incident'}, // Ticket Type
      {'id': 14884176561807, 'value': platform}, // Platform
      {'id': 14884157556111, 'value': osVersion}, // OS Version
      {'id': 14884184890511, 'value': buildNumber}, // Build Number
    ];

    // Add optional text fields if provided
    if (stepsToReproduce != null && stepsToReproduce.isNotEmpty) {
      customFields.add({
        'id': 14677364166031,
        'value': stepsToReproduce,
      }); // Steps to Reproduce
    }
    if (expectedBehavior != null && expectedBehavior.isNotEmpty) {
      customFields.add({
        'id': 14677341431695,
        'value': expectedBehavior,
      }); // Expected Behavior
    }

    // Try native SDK first (iOS/Android) - this links tickets to user identity
    if (_initialized) {
      Log.info(
        '🎫 Using native SDK for bug report (enables View Past Messages)',
        category: LogCategory.system,
      );
      return createTicket(
        subject: effectiveSubject,
        description: buffer.toString(),
        tags: tags,
        ticketFormId: 14772963437071,
        customFields: customFields,
      );
    }

    // Fall back to REST API for desktop platforms
    Log.info(
      '🎫 Native SDK not available, using REST API fallback',
      category: LogCategory.system,
    );
    return _createTicketWithFormViaApi(
      subject: effectiveSubject,
      description: buffer.toString(),
      tags: tags,
      customFields: customFields,
      ticketFormId: 14772963437071,
      label: 'bug report',
    );
  }

  /// Internal: Create ticket via REST API with form and custom fields
  static Future<bool> _createTicketWithFormViaApi({
    required String subject,
    required String description,
    required List<String> tags,
    required List<Map<String, dynamic>> customFields,
    required int ticketFormId,
    required String label,
  }) async {
    if (!ZendeskConfig.isRestApiConfigured) {
      Log.error(
        '❌ Zendesk REST API not configured - ZENDESK_API_TOKEN not set',
        category: LogCategory.system,
      );
      return false;
    }

    try {
      final requestBody = {
        'ticket': {
          'subject': subject,
          'comment': {'body': description},
          'requester': _buildRequester(),
          'ticket_form_id': ticketFormId,
          'tags': tags,
          'custom_fields': customFields,
        },
      };

      const apiUrl = '${ZendeskConfig.zendeskUrl}/api/v2/tickets.json';
      const credentials =
          '${ZendeskConfig.apiEmail}/token:${ZendeskConfig.apiToken}';
      final encodedCredentials = base64Encode(utf8.encode(credentials));

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic $encodedCredentials',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final ticketId = responseData['ticket']?['id'];
        Log.info(
          '✅ Zendesk $label created via API: #$ticketId',
          category: LogCategory.system,
        );
        return true;
      } else {
        Log.error(
          'Zendesk API error: ${response.statusCode} - ${response.body}',
          category: LogCategory.system,
        );
        return false;
      }
    } catch (e, stackTrace) {
      Log.error(
        'Exception creating Zendesk $label via API: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  // ==========================================================================
  // Feature Requests
  // ==========================================================================

  /// Create a feature request ticket
  ///
  /// Custom field IDs (configured in Zendesk):
  /// - 15081095878799: ticket_form_id (Feature Request form)
  /// - 15081108558863: How would this be useful for you?
  /// - 15081142424847: When would you use this?
  static Future<bool> createFeatureRequest({
    required String subject,
    required String description,
    String? usefulness,
    String? whenToUse,
    String? userPubkey,
  }) async {
    Log.info(
      '💡 Creating Zendesk feature request',
      category: LogCategory.system,
    );

    // Build ticket description
    // Lead with subject so Zendesk SDK ticket list preview is recognizable
    // (SDK shows first line of description body, not the subject field)
    final effectiveSubject = subject.isNotEmpty ? subject : 'Feature Request';
    final buffer = StringBuffer();
    buffer.writeln(effectiveSubject);
    buffer.writeln();
    buffer.writeln(description);
    if (usefulness != null && usefulness.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('### How would this be useful for you?');
      buffer.writeln(usefulness);
    }
    if (whenToUse != null && whenToUse.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('### When would you use this?');
      buffer.writeln(whenToUse);
    }
    final effectivePubkey = userPubkey ?? _userNpub;
    if (effectivePubkey != null) {
      buffer.writeln();
      buffer.writeln('**User Pubkey:** $effectivePubkey');
    }

    final tags = ['feature_request', 'divine_app', 'mobile'];

    // Build custom fields list
    final customFields = <Map<String, dynamic>>[];
    if (usefulness != null && usefulness.isNotEmpty) {
      customFields.add({
        'id': 15081108558863,
        'value': usefulness,
      }); // How would this be useful for you?
    }
    if (whenToUse != null && whenToUse.isNotEmpty) {
      customFields.add({
        'id': 15081142424847,
        'value': whenToUse,
      }); // When would you use this?
    }

    // Try native SDK first (iOS/Android) - this links tickets to user identity
    if (_initialized) {
      Log.info(
        '💡 Using native SDK for feature request (enables View Past Messages)',
        category: LogCategory.system,
      );
      return createTicket(
        subject: effectiveSubject,
        description: buffer.toString(),
        tags: tags,
        ticketFormId: 15081095878799,
        customFields: customFields,
      );
    }

    // Fall back to REST API for desktop platforms
    Log.info(
      '💡 Native SDK not available, using REST API fallback',
      category: LogCategory.system,
    );
    return _createTicketWithFormViaApi(
      subject: effectiveSubject,
      description: buffer.toString(),
      tags: tags,
      customFields: customFields,
      ticketFormId: 15081095878799,
      label: 'feature request',
    );
  }
}
