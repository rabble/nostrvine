// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'social_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SocialState _$SocialStateFromJson(Map<String, dynamic> json) => _SocialState(
  repostedEventIds:
      (json['repostedEventIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toSet() ??
      const {},
  repostEventIdToRepostId:
      (json['repostEventIdToRepostId'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ) ??
      const {},
  followingPubkeys:
      (json['followingPubkeys'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  followerStats:
      (json['followerStats'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, Map<String, int>.from(e as Map)),
      ) ??
      const {},
  currentUserContactListEvent: json['currentUserContactListEvent'] == null
      ? null
      : Event.fromJson(
          json['currentUserContactListEvent'] as Map<String, dynamic>,
        ),
  isLoading: json['isLoading'] as bool? ?? false,
  isInitialized: json['isInitialized'] as bool? ?? false,
  error: json['error'] as String?,
  repostsInProgress:
      (json['repostsInProgress'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toSet() ??
      const {},
  followsInProgress:
      (json['followsInProgress'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toSet() ??
      const {},
);

Map<String, dynamic> _$SocialStateToJson(_SocialState instance) =>
    <String, dynamic>{
      'repostedEventIds': instance.repostedEventIds.toList(),
      'repostEventIdToRepostId': instance.repostEventIdToRepostId,
      'followingPubkeys': instance.followingPubkeys,
      'followerStats': instance.followerStats,
      'currentUserContactListEvent': instance.currentUserContactListEvent,
      'isLoading': instance.isLoading,
      'isInitialized': instance.isInitialized,
      'error': instance.error,
      'repostsInProgress': instance.repostsInProgress.toList(),
      'followsInProgress': instance.followsInProgress.toList(),
    };
