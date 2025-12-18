// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'likes_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LikesState _$LikesStateFromJson(Map<String, dynamic> json) => _LikesState(
  likedEventIds:
      (json['likedEventIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toSet() ??
      const {},
  eventIdToReactionId:
      (json['eventIdToReactionId'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ) ??
      const {},
  likeCounts:
      (json['likeCounts'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, (e as num).toInt()),
      ) ??
      const {},
  isInitialized: json['isInitialized'] as bool? ?? false,
  isSyncing: json['isSyncing'] as bool? ?? false,
  operationsInProgress:
      (json['operationsInProgress'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toSet() ??
      const {},
  error: json['error'] as String?,
);

Map<String, dynamic> _$LikesStateToJson(_LikesState instance) =>
    <String, dynamic>{
      'likedEventIds': instance.likedEventIds.toList(),
      'eventIdToReactionId': instance.eventIdToReactionId,
      'likeCounts': instance.likeCounts,
      'isInitialized': instance.isInitialized,
      'isSyncing': instance.isSyncing,
      'operationsInProgress': instance.operationsInProgress.toList(),
      'error': instance.error,
    };
