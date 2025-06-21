// ABOUTME: Service for showing user notifications about upload status and publishing
// ABOUTME: Handles local notifications and in-app messages for video processing updates

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Types of notifications
enum NotificationType {
  uploadComplete,
  videoPublished,
  uploadFailed,
  processingStarted,
}

/// Notification data structure
class AppNotification {
  final String title;
  final String body;
  final NotificationType type;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  AppNotification({
    required this.title,
    required this.body,
    required this.type,
    this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create notification for successful video publishing
  factory AppNotification.videoPublished({
    required String videoTitle,
    required String nostrEventId,
    String? videoUrl,
  }) {
    return AppNotification(
      title: 'Video Published!',
      body: videoTitle.isEmpty ? 'Your vine is now live on Nostr' : '"$videoTitle" is now live on Nostr',
      type: NotificationType.videoPublished,
      data: {
        'event_id': nostrEventId,
        'video_url': videoUrl,
        'action': 'open_feed',
      },
    );
  }

  /// Create notification for upload completion
  factory AppNotification.uploadComplete({
    required String videoTitle,
  }) {
    return AppNotification(
      title: 'Upload Complete',
      body: videoTitle.isEmpty ? 'Your video is processing' : '"$videoTitle" is being processed',
      type: NotificationType.uploadComplete,
      data: {
        'action': 'open_uploads',
      },
    );
  }

  /// Create notification for upload failure
  factory AppNotification.uploadFailed({
    required String videoTitle,
    required String reason,
  }) {
    return AppNotification(
      title: 'Upload Failed',
      body: videoTitle.isEmpty ? 'Video upload failed: $reason' : '"$videoTitle" failed: $reason',
      type: NotificationType.uploadFailed,
      data: {
        'action': 'retry_upload',
        'reason': reason,
      },
    );
  }

  /// Create notification for processing start
  factory AppNotification.processingStarted({
    required String videoTitle,
  }) {
    return AppNotification(
      title: 'Processing Started',
      body: videoTitle.isEmpty ? 'Your video is being processed' : 'Processing "$videoTitle"',
      type: NotificationType.processingStarted,
      data: {
        'action': 'show_progress',
      },
    );
  }
}

/// Service for managing app notifications
class NotificationService extends ChangeNotifier {
  static NotificationService? _instance;
  
  /// Singleton instance
  static NotificationService get instance {
    if (_instance == null || _instance!._disposed) {
      _instance = NotificationService._();
    }
    return _instance!;
  }
  
  /// Factory constructor that returns the singleton instance
  factory NotificationService() => instance;
  
  NotificationService._();

  final List<AppNotification> _notifications = [];
  bool _permissionsGranted = false;
  bool _disposed = false;
  
  /// List of recent notifications
  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  
  /// Check if notification permissions are granted
  bool get hasPermissions => _permissionsGranted;

  /// Initialize notification service
  Future<void> initialize() async {
    debugPrint('🔔 Initializing NotificationService');
    
    try {
      // Request notification permissions
      await _requestPermissions();
      
      debugPrint('✅ NotificationService initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize notifications: $e');
    }
  }

  /// Show a notification
  Future<void> show(AppNotification notification) async {
    debugPrint('🔔 Showing notification: ${notification.title}');
    
    // Add to internal list
    _addNotification(notification);
    
    try {
      if (_permissionsGranted) {
        // Show platform notification
        await _showPlatformNotification(notification);
      } else {
        // Show in-app notification only
        debugPrint('⚠️ No notification permissions, showing in-app only');
      }
    } catch (e) {
      debugPrint('❌ Failed to show notification: $e');
    }
  }

  /// Show notification for video publishing success
  Future<void> showVideoPublished({
    required String videoTitle,
    required String nostrEventId,
    String? videoUrl,
  }) async {
    final notification = AppNotification.videoPublished(
      videoTitle: videoTitle,
      nostrEventId: nostrEventId,
      videoUrl: videoUrl,
    );
    
    await show(notification);
  }

  /// Show notification for upload completion
  Future<void> showUploadComplete({required String videoTitle}) async {
    final notification = AppNotification.uploadComplete(videoTitle: videoTitle);
    await show(notification);
  }

  /// Show notification for upload failure
  Future<void> showUploadFailed({
    required String videoTitle,
    required String reason,
  }) async {
    final notification = AppNotification.uploadFailed(
      videoTitle: videoTitle,
      reason: reason,
    );
    
    await show(notification);
  }

  /// Clear all notifications
  void clearAll() {
    _notifications.clear();
    notifyListeners();
    debugPrint('🗑️ Cleared all notifications');
  }

  /// Clear notifications older than specified duration
  void clearOlderThan(Duration duration) {
    final cutoff = DateTime.now().subtract(duration);
    final initialCount = _notifications.length;
    
    _notifications.removeWhere((notification) => 
        notification.timestamp.isBefore(cutoff));
    
    final removedCount = initialCount - _notifications.length;
    if (removedCount > 0) {
      notifyListeners();
      debugPrint('🗑️ Cleared $removedCount old notifications');
    }
  }

  /// Get notifications by type
  List<AppNotification> getNotificationsByType(NotificationType type) {
    return _notifications.where((n) => n.type == type).toList();
  }

  /// Request notification permissions from platform
  Future<void> _requestPermissions() async {
    try {
      // TODO: Implement proper notification permissions
      // For now, simulate granted permissions
      _permissionsGranted = true;
      debugPrint('✅ Notification permissions granted (simulated)');
    } catch (e) {
      _permissionsGranted = false;
      debugPrint('❌ Failed to get notification permissions: $e');
    }
  }

  /// Show platform-specific notification
  Future<void> _showPlatformNotification(AppNotification notification) async {
    try {
      // TODO: Implement actual platform notifications
      // This would use flutter_local_notifications or similar
      debugPrint('📱 Platform notification: ${notification.title} - ${notification.body}');
      
      // Simulate haptic feedback for important notifications
      if (notification.type == NotificationType.videoPublished) {
        HapticFeedback.mediumImpact();
      } else if (notification.type == NotificationType.uploadFailed) {
        HapticFeedback.heavyImpact();
      }
      
    } catch (e) {
      debugPrint('❌ Failed to show platform notification: $e');
    }
  }

  /// Add notification to internal list
  void _addNotification(AppNotification notification) {
    _notifications.insert(0, notification); // Add to beginning (newest first)
    
    // Keep only recent notifications to avoid memory issues
    if (_notifications.length > 100) {
      _notifications.removeRange(100, _notifications.length);
    }
    
    notifyListeners();
  }

  /// Get notification statistics
  Map<String, int> get stats {
    final stats = <String, int>{};
    
    for (final type in NotificationType.values) {
      stats[type.name] = getNotificationsByType(type).length;
    }
    
    return stats;
  }

  @override
  void dispose() {
    // Check if already disposed to prevent double disposal
    if (_disposed) return;
    
    _disposed = true;
    _notifications.clear();
    super.dispose();
  }
  
  /// Check if this service is still mounted/active
  bool get mounted => !_disposed;
}