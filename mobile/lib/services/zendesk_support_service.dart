// ABOUTME: Flutter wrapper for Zendesk Support (native SDK + REST API fallback)
// ABOUTME: Provides ticket creation via native iOS/Android SDKs or REST API for desktop

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:openvine/config/zendesk_config.dart';
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

  /// Set user identity for Zendesk tickets
  ///
  /// Call this after user login to associate tickets with the user.
  /// For Nostr users, we use:
  /// - name: Display name or NIP-05 identifier
  /// - email: NIP-05 identifier (if available) or npub-based email
  /// - npub: User's npub for reference in ticket body
  ///
  /// Returns true if identity was set successfully.
  static Future<bool> setUserIdentity({
    String? displayName,
    String? nip05,
    required String npub,
  }) async {
    // Store for REST API fallback
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
      'Setting Zendesk user identity: $effectiveName ($effectiveEmail)',
      category: LogCategory.system,
    );

    // If native SDK is initialized, set identity there too
    if (_initialized) {
      try {
        final result = await _channel.invokeMethod('setUserIdentity', {
          'name': effectiveName,
          'email': effectiveEmail,
        });

        if (result == true) {
          Log.info(
            '✅ Zendesk user identity set successfully',
            category: LogCategory.system,
          );
          return true;
        } else {
          Log.warning(
            'Failed to set Zendesk user identity via native SDK',
            category: LogCategory.system,
          );
          // Still return true since REST API will use stored values
          return true;
        }
      } on PlatformException catch (e) {
        Log.warning(
          'Platform error setting Zendesk identity: ${e.code} - ${e.message}',
          category: LogCategory.system,
        );
        // Still return true since REST API will use stored values
        return true;
      } catch (e) {
        Log.warning(
          'Error setting Zendesk identity: $e',
          category: LogCategory.system,
        );
        // Still return true since REST API will use stored values
        return true;
      }
    }

    // Native SDK not initialized, but REST API will use stored values
    return true;
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

  /// Format npub for display
  /// CRITICAL: Never truncate Nostr IDs - full npub needed for user identification
  static String _formatNpubForDisplay(String npub) {
    return npub;
  }

  /// Show native Zendesk ticket creation screen
  ///
  /// Presents the native Zendesk UI for creating a support ticket.
  /// Returns true if screen shown, false if Zendesk not initialized.
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
  /// Platform limitations:
  /// - iOS: Full support via RequestProvider API
  /// - Android: Full support via RequestProvider API
  /// - macOS/Windows: Not supported (returns false)
  static Future<bool> createTicket({
    required String subject,
    required String description,
    List<String>? tags,
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
    } on PlatformException catch (e) {
      Log.error(
        'Platform error creating Zendesk ticket: ${e.code} - ${e.message}',
        category: LogCategory.system,
      );
      return false;
    } catch (e) {
      Log.error(
        'Unexpected error creating Zendesk ticket: $e',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Show ticket list (user's support request history)
  ///
  /// Opens the Zendesk ticket list UI showing the user's past support tickets
  /// and allowing them to view responses and continue conversations.
  /// Returns true if ticket list shown successfully, false otherwise.
  static Future<bool> showTicketList() async {
    if (!_initialized) {
      Log.warning(
        'Zendesk not initialized - cannot show ticket list',
        category: LogCategory.system,
      );
      return false;
    }

    try {
      final result = await _channel.invokeMethod('showTicketList');

      if (result == true) {
        Log.info(
          'Zendesk ticket list shown successfully',
          category: LogCategory.system,
        );
        return true;
      } else {
        Log.warning(
          'Failed to show Zendesk ticket list',
          category: LogCategory.system,
        );
        return false;
      }
    } on PlatformException catch (e) {
      Log.error(
        'Platform error showing Zendesk ticket list: ${e.code} - ${e.message}',
        category: LogCategory.system,
      );
      return false;
    } catch (e) {
      Log.error(
        'Unexpected error showing Zendesk ticket list: $e',
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

      // Build the request body
      // Using the Requests API which requires a requester email
      // Default to apiEmail if none provided (for anonymous bug reports)
      final effectiveEmail = requesterEmail ?? ZendeskConfig.apiEmail;
      final effectiveName = requesterName ?? 'Divine App User';

      final requestBody = {
        'request': {
          'subject': subject,
          'comment': {'body': description},
          'requester': {'name': effectiveName, 'email': effectiveEmail},
          if (tags != null && tags.isNotEmpty) 'tags': tags,
        },
      };

      // Zendesk API URL for creating requests (end-user ticket creation)
      final apiUrl = '${ZendeskConfig.zendeskUrl}/api/v2/requests.json';

      // Create Basic Auth header: email/token:api_token
      final credentials =
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
        final ticketId = responseData['request']?['id'];
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

  /// Create a bug report ticket via REST API with full diagnostics
  ///
  /// Formats the bug report data into a Zendesk ticket with proper structure.
  /// Includes device info, logs summary, and error counts.
  static Future<bool> createBugReportTicketViaApi({
    required String reportId,
    required String userDescription,
    required String appVersion,
    required Map<String, dynamic> deviceInfo,
    String? currentScreen,
    String? userPubkey,
    Map<String, int>? errorCounts,
    String? logsSummary,
  }) async {
    // Build comprehensive ticket description
    final buffer = StringBuffer();
    buffer.writeln('## Bug Report');
    buffer.writeln('**Report ID:** $reportId');
    buffer.writeln('**App Version:** $appVersion');
    buffer.writeln('');
    buffer.writeln('### User Description');
    buffer.writeln(userDescription);
    buffer.writeln('');
    buffer.writeln('### Device Information');
    deviceInfo.forEach((key, value) {
      buffer.writeln('- **$key:** $value');
    });
    if (currentScreen != null) {
      buffer.writeln('');
      buffer.writeln('**Current Screen:** $currentScreen');
    }
    // Include user pubkey - use passed value or stored npub
    final effectivePubkey = userPubkey ?? _userNpub;
    if (effectivePubkey != null) {
      buffer.writeln('**User Pubkey:** $effectivePubkey');
    }
    if (errorCounts != null && errorCounts.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('### Recent Error Summary');
      final sortedErrors = errorCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final entry in sortedErrors.take(10)) {
        buffer.writeln('- ${entry.key}: ${entry.value} occurrences');
      }
    }
    if (logsSummary != null && logsSummary.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('### Recent Logs (Summary)');
      buffer.writeln('```');
      buffer.writeln(logsSummary);
      buffer.writeln('```');
    }

    return createTicketViaApi(
      subject: 'Bug Report: $reportId',
      description: buffer.toString(),
      requesterName: _userName,
      requesterEmail: _userEmail,
      tags: ['bug_report', 'divine_app', appVersion],
    );
  }
}
