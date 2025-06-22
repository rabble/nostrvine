// ABOUTME: Feature flag service for Flutter client
// ABOUTME: Manages gradual rollout and A/B testing on mobile

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Feature flag decision returned by the service
class FeatureFlagDecision {
  final bool enabled;
  final String? variant;
  final String reason;
  final Map<String, dynamic>? metadata;

  const FeatureFlagDecision({
    required this.enabled,
    this.variant,
    required this.reason,
    this.metadata,
  });

  factory FeatureFlagDecision.fromJson(Map<String, dynamic> json) {
    return FeatureFlagDecision(
      enabled: json['enabled'] as bool,
      variant: json['variant'] as String?,
      reason: json['reason'] as String,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// Feature flag configuration
class FeatureFlag {
  final String name;
  final bool enabled;
  final int rolloutPercentage;
  final List<FeatureFlagVariant>? variants;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FeatureFlag({
    required this.name,
    required this.enabled,
    required this.rolloutPercentage,
    this.variants,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FeatureFlag.fromJson(Map<String, dynamic> json) {
    return FeatureFlag(
      name: json['name'] as String,
      enabled: json['enabled'] as bool,
      rolloutPercentage: json['rolloutPercentage'] as int,
      variants: (json['variants'] as List<dynamic>?)
          ?.map((v) => FeatureFlagVariant.fromJson(v as Map<String, dynamic>))
          .toList(),
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

/// Feature flag variant for A/B testing
class FeatureFlagVariant {
  final String name;
  final int percentage;
  final Map<String, dynamic>? metadata;

  const FeatureFlagVariant({
    required this.name,
    required this.percentage,
    this.metadata,
  });

  factory FeatureFlagVariant.fromJson(Map<String, dynamic> json) {
    return FeatureFlagVariant(
      name: json['name'] as String,
      percentage: json['percentage'] as int,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// Feature flag service for Flutter
class FeatureFlagService extends ChangeNotifier {
  final String apiBaseUrl;
  final String? apiKey;
  final String? userId;
  final SharedPreferences prefs;
  
  // Cache for feature flag decisions
  final Map<String, FeatureFlagDecision> _decisionCache = {};
  final Map<String, DateTime> _cacheExpiry = {};
  final Duration _cacheDuration;
  
  // Default flags for offline mode
  static const Map<String, bool> _defaultFlags = {
    'video_caching_system': false,
    'optimized_batch_api': false,
    'prefetch_manager': false,
    'analytics_v2': false,
  };

  FeatureFlagService({
    required this.apiBaseUrl,
    this.apiKey,
    this.userId,
    required this.prefs,
    Duration? cacheDuration,
  }) : _cacheDuration = cacheDuration ?? const Duration(minutes: 5);

  /// Check if a feature is enabled
  Future<bool> isEnabled(
    String flagName, {
    Map<String, dynamic>? attributes,
    bool forceRefresh = false,
  }) async {
    final decision = await getDecision(
      flagName,
      attributes: attributes,
      forceRefresh: forceRefresh,
    );
    return decision.enabled;
  }

  /// Get feature flag decision with variant information
  Future<FeatureFlagDecision> getDecision(
    String flagName, {
    Map<String, dynamic>? attributes,
    bool forceRefresh = false,
  }) async {
    // Check cache first
    if (!forceRefresh && _isCacheValid(flagName)) {
      return _decisionCache[flagName]!;
    }

    try {
      // Make API request
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/feature-flags/$flagName/check'),
        headers: {
          'Content-Type': 'application/json',
          if (apiKey != null) 'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'userId': userId ?? await _getOrCreateUserId(),
          'attributes': attributes,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final decision = FeatureFlagDecision.fromJson(json);
        
        // Cache decision
        _decisionCache[flagName] = decision;
        _cacheExpiry[flagName] = DateTime.now().add(_cacheDuration);
        
        // Persist to local storage for offline mode
        await _persistDecision(flagName, decision);
        
        // Track analytics
        _trackFlagEvaluation(flagName, decision, attributes);
        
        notifyListeners();
        return decision;
      } else {
        debugPrint('Feature flag API error: ${response.statusCode}');
        return _getFallbackDecision(flagName);
      }
    } catch (e) {
      debugPrint('Feature flag error: $e');
      return _getFallbackDecision(flagName);
    }
  }

  /// Get all feature flags (admin only)
  Future<List<FeatureFlag>> getAllFlags() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/feature-flags'),
        headers: {
          if (apiKey != null) 'Authorization': 'Bearer $apiKey',
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final flags = (json['flags'] as List<dynamic>)
            .map((f) => FeatureFlag.fromJson(f as Map<String, dynamic>))
            .toList();
        return flags;
      } else {
        throw Exception('Failed to fetch feature flags: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching all flags: $e');
      rethrow;
    }
  }

  /// Get variant for A/B testing
  String? getVariant(String flagName) {
    return _decisionCache[flagName]?.variant;
  }

  /// Clear cache for a specific flag or all flags
  void clearCache([String? flagName]) {
    if (flagName != null) {
      _decisionCache.remove(flagName);
      _cacheExpiry.remove(flagName);
    } else {
      _decisionCache.clear();
      _cacheExpiry.clear();
    }
    notifyListeners();
  }

  /// Preload feature flags for better performance
  Future<void> preloadFlags(List<String> flagNames) async {
    final futures = flagNames.map((flag) => 
      getDecision(flag, forceRefresh: true)
    );
    await Future.wait(futures);
  }

  /// Get user bucket for local evaluation
  int getUserBucket(String flagName, String userId) {
    final data = '$flagName:$userId';
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    final hash = digest.toString();
    
    // Convert first 8 chars of hash to number and map to 0-100
    final num = int.parse(hash.substring(0, 8), radix: 16);
    return (num % 100) + 1;
  }

  /// Track feature flag usage for analytics
  void trackUsage(String flagName, Map<String, dynamic>? properties) {
    final decision = _decisionCache[flagName];
    if (decision == null) return;

    final event = {
      'event': 'feature_flag_used',
      'flagName': flagName,
      'enabled': decision.enabled,
      'variant': decision.variant,
      'properties': properties,
      'timestamp': DateTime.now().toIso8601String(),
    };

    // Send to analytics service
    _sendAnalytics(event);
  }

  // Private helper methods

  bool _isCacheValid(String flagName) {
    final expiry = _cacheExpiry[flagName];
    return expiry != null && 
           DateTime.now().isBefore(expiry) &&
           _decisionCache.containsKey(flagName);
  }

  Future<String> _getOrCreateUserId() async {
    String? storedUserId = prefs.getString('feature_flag_user_id');
    
    if (storedUserId == null) {
      // Generate random user ID
      final random = Random.secure();
      final values = List<int>.generate(16, (i) => random.nextInt(256));
      storedUserId = base64Url.encode(values);
      await prefs.setString('feature_flag_user_id', storedUserId);
    }
    
    return storedUserId;
  }

  Future<FeatureFlagDecision> _getFallbackDecision(String flagName) async {
    // Try to load from local storage first
    final localDecision = await _loadPersistedDecision(flagName);
    if (localDecision != null) {
      return localDecision;
    }

    // Use default flags
    final enabled = _defaultFlags[flagName] ?? false;
    return FeatureFlagDecision(
      enabled: enabled,
      reason: 'Fallback to default (offline)',
    );
  }

  Future<void> _persistDecision(
    String flagName,
    FeatureFlagDecision decision,
  ) async {
    final key = 'feature_flag_decision_$flagName';
    final data = {
      'enabled': decision.enabled,
      'variant': decision.variant,
      'reason': decision.reason,
      'metadata': decision.metadata,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await prefs.setString(key, jsonEncode(data));
  }

  Future<FeatureFlagDecision?> _loadPersistedDecision(String flagName) async {
    final key = 'feature_flag_decision_$flagName';
    final stored = prefs.getString(key);
    
    if (stored == null) return null;
    
    try {
      final data = jsonDecode(stored) as Map<String, dynamic>;
      final timestamp = DateTime.parse(data['timestamp'] as String);
      
      // Use persisted decision if less than 24 hours old
      if (DateTime.now().difference(timestamp).inHours < 24) {
        return FeatureFlagDecision(
          enabled: data['enabled'] as bool,
          variant: data['variant'] as String?,
          reason: '${data['reason']} (cached)',
          metadata: data['metadata'] as Map<String, dynamic>?,
        );
      }
    } catch (e) {
      debugPrint('Error loading persisted decision: $e');
    }
    
    return null;
  }

  void _trackFlagEvaluation(
    String flagName,
    FeatureFlagDecision decision,
    Map<String, dynamic>? attributes,
  ) {
    final event = {
      'event': 'feature_flag_evaluated',
      'flagName': flagName,
      'enabled': decision.enabled,
      'variant': decision.variant,
      'reason': decision.reason,
      'attributes': attributes,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    _sendAnalytics(event);
  }

  Future<void> _sendAnalytics(Map<String, dynamic> event) async {
    // Queue analytics events to send in batch
    // This would integrate with your analytics service
    debugPrint('Feature flag analytics: ${jsonEncode(event)}');
  }

  @override
  void dispose() {
    _decisionCache.clear();
    _cacheExpiry.clear();
    super.dispose();
  }
}

/// Extension for easy feature flag checks
extension FeatureFlagExtension on BuildContext {
  bool isFeatureEnabled(String flagName) {
    // This would be used with a provider/inherited widget
    // Example: context.read<FeatureFlagService>().isEnabled(flagName)
    return false; // Placeholder
  }
}