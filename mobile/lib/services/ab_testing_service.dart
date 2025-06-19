// ABOUTME: A/B testing framework for gradual video system migration and feature rollout
// ABOUTME: Provides controlled rollout, experiment tracking, and statistical analysis

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A/B testing service for controlled feature rollouts
/// 
/// This service enables safe gradual migration from legacy video system to new
/// TDD-driven system by providing user bucketing, experiment tracking, and
/// statistical analysis capabilities.
class ABTestingService extends ChangeNotifier {
  static ABTestingService? _instance;
  late SharedPreferences _prefs;
  final Map<String, ExperimentConfig> _experiments = {};
  final Map<String, UserAssignment> _userAssignments = {};
  final List<ExperimentEvent> _events = [];
  bool _initialized = false;
  
  // Remote config simulation (in production, use Firebase Remote Config)
  final Map<String, dynamic> _remoteConfig = {
    'video_system_rollout_percentage': 0,
    'video_system_experiment_enabled': true,
    'performance_monitoring_rollout': 50,
    'new_ui_components_rollout': 25,
  };
  
  ABTestingService._();
  
  /// Singleton instance
  static ABTestingService get instance {
    _instance ??= ABTestingService._();
    return _instance!;
  }
  
  /// Initialize the A/B testing service
  Future<void> initialize() async {
    if (_initialized) return;
    
    _prefs = await SharedPreferences.getInstance();
    await _loadExperiments();
    await _loadUserAssignments();
    _initialized = true;
    
    debugPrint('ABTestingService: Initialized with ${_experiments.length} experiments');
  }
  
  /// Register a new experiment
  void registerExperiment(ExperimentConfig experiment) {
    _experiments[experiment.id] = experiment;
    _saveExperiments();
    
    debugPrint('ABTestingService: Registered experiment ${experiment.id}');
    notifyListeners();
  }
  
  /// Check if user should be in treatment group for an experiment
  bool isUserInTreatment(String experimentId, {String? userId}) {
    if (!_initialized) {
      debugPrint('ABTestingService: Not initialized, defaulting to control');
      return false;
    }
    
    final experiment = _experiments[experimentId];
    if (experiment == null) {
      debugPrint('ABTestingService: Unknown experiment $experimentId');
      return false;
    }
    
    if (!experiment.enabled) {
      return false;
    }
    
    final effectiveUserId = userId ?? _getDeviceUserId();
    final assignment = _getUserAssignment(experimentId, effectiveUserId, experiment);
    
    // Track assignment event
    _trackEvent(ExperimentEvent(
      experimentId: experimentId,
      userId: effectiveUserId,
      variant: assignment.variant,
      eventType: EventType.assignment,
      timestamp: DateTime.now(),
    ));
    
    return assignment.variant == ExperimentVariant.treatment;
  }
  
  /// Get the variant for a user in an experiment
  ExperimentVariant getUserVariant(String experimentId, {String? userId}) {
    if (!_initialized) return ExperimentVariant.control;
    
    final experiment = _experiments[experimentId];
    if (experiment == null || !experiment.enabled) {
      return ExperimentVariant.control;
    }
    
    final effectiveUserId = userId ?? _getDeviceUserId();
    final assignment = _getUserAssignment(experimentId, effectiveUserId, experiment);
    
    return assignment.variant;
  }
  
  /// Track a custom event for an experiment
  void trackEvent(String experimentId, String eventName, {
    String? userId,
    Map<String, dynamic>? properties,
  }) {
    if (!_initialized) return;
    
    final effectiveUserId = userId ?? _getDeviceUserId();
    final assignment = _userAssignments['${experimentId}_$effectiveUserId'];
    
    if (assignment == null) return;
    
    _trackEvent(ExperimentEvent(
      experimentId: experimentId,
      userId: effectiveUserId,
      variant: assignment.variant,
      eventType: EventType.custom,
      eventName: eventName,
      properties: properties,
      timestamp: DateTime.now(),
    ));
  }
  
  /// Track conversion event
  void trackConversion(String experimentId, String conversionType, {
    String? userId,
    double? value,
    Map<String, dynamic>? properties,
  }) {
    trackEvent(experimentId, 'conversion', userId: userId, properties: {
      'conversion_type': conversionType,
      'value': value,
      ...?properties,
    });
  }
  
  /// Get experiment results and statistics
  ExperimentResults getExperimentResults(String experimentId) {
    final events = _events.where((e) => e.experimentId == experimentId).toList();
    
    final controlEvents = events.where((e) => e.variant == ExperimentVariant.control).toList();
    final treatmentEvents = events.where((e) => e.variant == ExperimentVariant.treatment).toList();
    
    final controlUsers = controlEvents.map((e) => e.userId).toSet();
    final treatmentUsers = treatmentEvents.map((e) => e.userId).toSet();
    
    // Calculate conversion rates
    final controlConversions = controlEvents.where((e) => e.eventName == 'conversion').length;
    final treatmentConversions = treatmentEvents.where((e) => e.eventName == 'conversion').length;
    
    final controlConversionRate = controlUsers.isNotEmpty ? controlConversions / controlUsers.length : 0.0;
    final treatmentConversionRate = treatmentUsers.isNotEmpty ? treatmentConversions / treatmentUsers.length : 0.0;
    
    // Calculate statistical significance
    final significance = _calculateStatisticalSignificance(
      controlUsers.length,
      treatmentUsers.length,
      controlConversions,
      treatmentConversions,
    );
    
    return ExperimentResults(
      experimentId: experimentId,
      controlUsers: controlUsers.length,
      treatmentUsers: treatmentUsers.length,
      controlConversions: controlConversions,
      treatmentConversions: treatmentConversions,
      controlConversionRate: controlConversionRate,
      treatmentConversionRate: treatmentConversionRate,
      lift: treatmentConversionRate - controlConversionRate,
      liftPercentage: controlConversionRate > 0 
          ? ((treatmentConversionRate - controlConversionRate) / controlConversionRate) * 100
          : 0.0,
      pValue: significance.pValue,
      isSignificant: significance.isSignificant,
      confidence: significance.confidence,
    );
  }
  
  /// Export experiment data for analysis
  Map<String, dynamic> exportExperimentData(String experimentId) {
    final events = _events.where((e) => e.experimentId == experimentId).toList();
    final results = getExperimentResults(experimentId);
    
    return {
      'experiment_id': experimentId,
      'experiment_config': _experiments[experimentId]?.toJson(),
      'results': results.toJson(),
      'events': events.map((e) => e.toJson()).toList(),
      'export_timestamp': DateTime.now().toIso8601String(),
    };
  }
  
  /// Clear experiment data (for testing)
  void clearExperimentData(String experimentId) {
    _events.removeWhere((e) => e.experimentId == experimentId);
    _userAssignments.removeWhere((key, _) => key.startsWith('${experimentId}_'));
    _saveUserAssignments();
    notifyListeners();
  }
  
  /// Get all active experiments
  List<ExperimentConfig> getActiveExperiments() {
    return _experiments.values.where((e) => e.enabled).toList();
  }
  
  /// Update remote config (simulation)
  void updateRemoteConfig(String key, dynamic value) {
    _remoteConfig[key] = value;
    notifyListeners();
  }
  
  // Private methods
  
  UserAssignment _getUserAssignment(String experimentId, String userId, ExperimentConfig experiment) {
    final key = '${experimentId}_$userId';
    
    if (_userAssignments.containsKey(key)) {
      return _userAssignments[key]!;
    }
    
    // Calculate hash for consistent assignment
    final hash = _calculateUserHash(userId, experimentId);
    final bucket = hash % 100;
    
    final variant = bucket < experiment.treatmentPercentage 
        ? ExperimentVariant.treatment 
        : ExperimentVariant.control;
    
    final assignment = UserAssignment(
      experimentId: experimentId,
      userId: userId,
      variant: variant,
      assignedAt: DateTime.now(),
    );
    
    _userAssignments[key] = assignment;
    _saveUserAssignments();
    
    return assignment;
  }
  
  int _calculateUserHash(String userId, String experimentId) {
    final combined = '$userId:$experimentId';
    return combined.hashCode.abs();
  }
  
  String _getDeviceUserId() {
    // In production, use a proper device ID or user ID
    return _prefs.getString('device_user_id') ?? _generateDeviceUserId();
  }
  
  String _generateDeviceUserId() {
    final random = Random();
    final userId = 'device_${random.nextInt(1000000)}';
    _prefs.setString('device_user_id', userId);
    return userId;
  }
  
  void _trackEvent(ExperimentEvent event) {
    _events.add(event);
    
    // Keep only recent events to manage memory
    if (_events.length > 10000) {
      _events.removeRange(0, _events.length - 5000);
    }
    
    // In production, send to analytics service
    debugPrint('ABTestingService: Event tracked - ${event.experimentId}:${event.eventName}');
  }
  
  StatisticalSignificance _calculateStatisticalSignificance(
    int controlSize,
    int treatmentSize,
    int controlConversions,
    int treatmentConversions,
  ) {
    if (controlSize == 0 || treatmentSize == 0) {
      return StatisticalSignificance(pValue: 1.0, isSignificant: false, confidence: 0.0);
    }
    
    final p1 = controlConversions / controlSize;
    final p2 = treatmentConversions / treatmentSize;
    final pPooled = (controlConversions + treatmentConversions) / (controlSize + treatmentSize);
    
    final standardError = sqrt(pPooled * (1 - pPooled) * (1/controlSize + 1/treatmentSize));
    
    if (standardError == 0) {
      return StatisticalSignificance(pValue: 1.0, isSignificant: false, confidence: 0.0);
    }
    
    final zScore = (p2 - p1) / standardError;
    final pValue = _calculatePValue(zScore.abs());
    
    return StatisticalSignificance(
      pValue: pValue,
      isSignificant: pValue < 0.05,
      confidence: (1 - pValue) * 100,
    );
  }
  
  double _calculatePValue(double zScore) {
    // Simplified p-value calculation using normal distribution approximation
    if (zScore > 2.576) return 0.01;   // 99% confidence
    if (zScore > 1.96) return 0.05;    // 95% confidence
    if (zScore > 1.645) return 0.1;    // 90% confidence
    return 0.5;
  }
  
  Future<void> _loadExperiments() async {
    final experimentsJson = _prefs.getString('ab_experiments');
    if (experimentsJson != null) {
      final experimentsData = jsonDecode(experimentsJson) as Map<String, dynamic>;
      for (final entry in experimentsData.entries) {
        _experiments[entry.key] = ExperimentConfig.fromJson(entry.value);
      }
    }
    
    // Register default experiments
    _registerDefaultExperiments();
  }
  
  Future<void> _saveExperiments() async {
    final experimentsData = <String, dynamic>{};
    for (final entry in _experiments.entries) {
      experimentsData[entry.key] = entry.value.toJson();
    }
    await _prefs.setString('ab_experiments', jsonEncode(experimentsData));
  }
  
  Future<void> _loadUserAssignments() async {
    final assignmentsJson = _prefs.getString('ab_user_assignments');
    if (assignmentsJson != null) {
      final assignmentsData = jsonDecode(assignmentsJson) as Map<String, dynamic>;
      for (final entry in assignmentsData.entries) {
        _userAssignments[entry.key] = UserAssignment.fromJson(entry.value);
      }
    }
  }
  
  Future<void> _saveUserAssignments() async {
    final assignmentsData = <String, dynamic>{};
    for (final entry in _userAssignments.entries) {
      assignmentsData[entry.key] = entry.value.toJson();
    }
    await _prefs.setString('ab_user_assignments', jsonEncode(assignmentsData));
  }
  
  void _registerDefaultExperiments() {
    // Video System Migration Experiment
    registerExperiment(ExperimentConfig(
      id: 'video_system_migration_v2',
      name: 'Video System Migration to TDD Architecture',
      description: 'Gradual migration from legacy dual-list to new TDD video manager',
      treatmentPercentage: _remoteConfig['video_system_rollout_percentage'] ?? 0,
      enabled: _remoteConfig['video_system_experiment_enabled'] ?? false,
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 30)),
    ));
    
    // Performance Monitoring Experiment
    registerExperiment(ExperimentConfig(
      id: 'performance_monitoring_rollout',
      name: 'Performance Monitoring Dashboard',
      description: 'Enable performance monitoring and analytics dashboard',
      treatmentPercentage: _remoteConfig['performance_monitoring_rollout'] ?? 50,
      enabled: true,
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 60)),
    ));
    
    // New UI Components Experiment
    registerExperiment(ExperimentConfig(
      id: 'new_ui_components_v1',
      name: 'New Video UI Components',
      description: 'Test new video player UI components and controls',
      treatmentPercentage: _remoteConfig['new_ui_components_rollout'] ?? 25,
      enabled: true,
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 45)),
    ));
  }
}

// Data classes

class ExperimentConfig {
  final String id;
  final String name;
  final String description;
  final int treatmentPercentage;
  final bool enabled;
  final DateTime startDate;
  final DateTime endDate;
  final Map<String, dynamic> metadata;
  
  const ExperimentConfig({
    required this.id,
    required this.name,
    required this.description,
    required this.treatmentPercentage,
    required this.enabled,
    required this.startDate,
    required this.endDate,
    this.metadata = const {},
  });
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'treatmentPercentage': treatmentPercentage,
      'enabled': enabled,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'metadata': metadata,
    };
  }
  
  factory ExperimentConfig.fromJson(Map<String, dynamic> json) {
    return ExperimentConfig(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      treatmentPercentage: json['treatmentPercentage'],
      enabled: json['enabled'],
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      metadata: json['metadata'] ?? {},
    );
  }
}

class UserAssignment {
  final String experimentId;
  final String userId;
  final ExperimentVariant variant;
  final DateTime assignedAt;
  
  const UserAssignment({
    required this.experimentId,
    required this.userId,
    required this.variant,
    required this.assignedAt,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'experimentId': experimentId,
      'userId': userId,
      'variant': variant.name,
      'assignedAt': assignedAt.toIso8601String(),
    };
  }
  
  factory UserAssignment.fromJson(Map<String, dynamic> json) {
    return UserAssignment(
      experimentId: json['experimentId'],
      userId: json['userId'],
      variant: ExperimentVariant.values.firstWhere(
        (v) => v.name == json['variant'],
        orElse: () => ExperimentVariant.control,
      ),
      assignedAt: DateTime.parse(json['assignedAt']),
    );
  }
}

class ExperimentEvent {
  final String experimentId;
  final String userId;
  final ExperimentVariant variant;
  final EventType eventType;
  final String? eventName;
  final Map<String, dynamic>? properties;
  final DateTime timestamp;
  
  const ExperimentEvent({
    required this.experimentId,
    required this.userId,
    required this.variant,
    required this.eventType,
    this.eventName,
    this.properties,
    required this.timestamp,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'experimentId': experimentId,
      'userId': userId,
      'variant': variant.name,
      'eventType': eventType.name,
      'eventName': eventName,
      'properties': properties,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class ExperimentResults {
  final String experimentId;
  final int controlUsers;
  final int treatmentUsers;
  final int controlConversions;
  final int treatmentConversions;
  final double controlConversionRate;
  final double treatmentConversionRate;
  final double lift;
  final double liftPercentage;
  final double pValue;
  final bool isSignificant;
  final double confidence;
  
  const ExperimentResults({
    required this.experimentId,
    required this.controlUsers,
    required this.treatmentUsers,
    required this.controlConversions,
    required this.treatmentConversions,
    required this.controlConversionRate,
    required this.treatmentConversionRate,
    required this.lift,
    required this.liftPercentage,
    required this.pValue,
    required this.isSignificant,
    required this.confidence,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'experimentId': experimentId,
      'controlUsers': controlUsers,
      'treatmentUsers': treatmentUsers,
      'controlConversions': controlConversions,
      'treatmentConversions': treatmentConversions,
      'controlConversionRate': controlConversionRate,
      'treatmentConversionRate': treatmentConversionRate,
      'lift': lift,
      'liftPercentage': liftPercentage,
      'pValue': pValue,
      'isSignificant': isSignificant,
      'confidence': confidence,
    };
  }
}

class StatisticalSignificance {
  final double pValue;
  final bool isSignificant;
  final double confidence;
  
  const StatisticalSignificance({
    required this.pValue,
    required this.isSignificant,
    required this.confidence,
  });
}

// Enums
enum ExperimentVariant { control, treatment }
enum EventType { assignment, custom, conversion }