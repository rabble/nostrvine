// ABOUTME: Analytics service for tracking video views with user opt-out support
// ABOUTME: Sends anonymous view data to OpenVine analytics backend when enabled

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/video_event.dart';
import '../utils/unified_logger.dart';

/// Service for tracking video analytics with privacy controls
class AnalyticsService extends ChangeNotifier {
  static const String _analyticsEndpoint = 'https://analytics.openvine.co/analytics/view';
  static const String _analyticsEnabledKey = 'analytics_enabled';
  static const Duration _requestTimeout = Duration(seconds: 5);
  
  final http.Client _client;
  bool _analyticsEnabled = true; // Default to enabled
  bool _isInitialized = false;
  
  // Track recent views to prevent duplicate tracking
  final Set<String> _recentlyTrackedViews = {};
  Timer? _cleanupTimer;
  
  AnalyticsService({http.Client? client}) : _client = client ?? http.Client();
  
  /// Initialize the analytics service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Load analytics preference from storage
      final prefs = await SharedPreferences.getInstance();
      _analyticsEnabled = prefs.getBool(_analyticsEnabledKey) ?? true;
      _isInitialized = true;
      
      // Set up periodic cleanup of tracked views
      _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (_) {
        _recentlyTrackedViews.clear();
      });
      
      Log.info('Analytics service initialized (enabled: $_analyticsEnabled)', name: 'AnalyticsService', category: LogCategory.system);
      notifyListeners();
    } catch (e) {
      Log.error('Failed to initialize analytics service: $e', name: 'AnalyticsService', category: LogCategory.system);
      _isInitialized = true; // Mark as initialized even on error
    }
  }
  
  /// Get current analytics enabled state
  bool get analyticsEnabled => _analyticsEnabled;
  
  /// Set analytics enabled state
  Future<void> setAnalyticsEnabled(bool enabled) async {
    if (_analyticsEnabled == enabled) return;
    
    _analyticsEnabled = enabled;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_analyticsEnabledKey, enabled);
      
      debugPrint('📊 Analytics ${enabled ? 'enabled' : 'disabled'} by user');
      notifyListeners();
    } catch (e) {
      Log.error('Failed to save analytics preference: $e', name: 'AnalyticsService', category: LogCategory.system);
    }
  }
  
  /// Track a video view
  Future<void> trackVideoView(VideoEvent video, {String source = 'mobile'}) async {
    // Check if analytics is enabled
    if (!_analyticsEnabled) {
      Log.debug('Analytics disabled - not tracking view', name: 'AnalyticsService', category: LogCategory.system);
      return;
    }
    
    // Don't prevent tracking the same video multiple times - users can rewatch videos!
    
    try {
      // Prepare view data with hashtags and title
      final viewData = {
        'eventId': video.id,
        'source': source,
        'creatorPubkey': video.pubkey,
        'hashtags': video.hashtags.isNotEmpty ? video.hashtags : null,
        'title': video.title,
      };
      
      // Send view tracking request
      final response = await _client.post(
        Uri.parse(_analyticsEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'OpenVine-Mobile/1.0',
        },
        body: jsonEncode(viewData),
      ).timeout(_requestTimeout);
      
      if (response.statusCode == 200) {
        Log.debug('Tracked view for video ${video.id.substring(0, 8)}...', name: 'AnalyticsService', category: LogCategory.system);
      } else if (response.statusCode == 429) {
        Log.warning('Rate limited by analytics service', name: 'AnalyticsService', category: LogCategory.system);
      } else {
        Log.error('Failed to track view: ${response.statusCode}', name: 'AnalyticsService', category: LogCategory.system);
      }
    } catch (e) {
      // Don't crash the app if analytics fails
      Log.error('Analytics tracking error: $e', name: 'AnalyticsService', category: LogCategory.system);
    }
  }
  
  /// Track multiple video views in batch (for feed loading)
  Future<void> trackVideoViews(List<VideoEvent> videos, {String source = 'mobile'}) async {
    if (!_analyticsEnabled || videos.isEmpty) return;
    
    // Track each video view with a small delay between them
    for (final video in videos) {
      trackVideoView(video, source: source);
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }
  
  /// Clear tracked views cache
  void clearTrackedViews() {
    _recentlyTrackedViews.clear();
  }
  
  @override
  void dispose() {
    _cleanupTimer?.cancel();
    _client.close();
    super.dispose();
  }
}