// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'analytics_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AnalyticsStateImpl _$$AnalyticsStateImplFromJson(Map<String, dynamic> json) =>
    _$AnalyticsStateImpl(
      analyticsEnabled: json['analyticsEnabled'] as bool? ?? true,
      isInitialized: json['isInitialized'] as bool? ?? false,
      isLoading: json['isLoading'] as bool? ?? false,
      lastEvent: json['lastEvent'] as String?,
      error: json['error'] as String?,
    );

Map<String, dynamic> _$$AnalyticsStateImplToJson(
        _$AnalyticsStateImpl instance) =>
    <String, dynamic>{
      'analyticsEnabled': instance.analyticsEnabled,
      'isInitialized': instance.isInitialized,
      'isLoading': instance.isLoading,
      'lastEvent': instance.lastEvent,
      'error': instance.error,
    };
