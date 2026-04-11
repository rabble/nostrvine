import 'package:follow_repository/follow_repository.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/services/personal_event_cache_service.dart';

/// Adapter that wraps [PersonalEventCacheService] to implement the
/// package-level [PersonalEventCache] interface used by
/// [FollowRepository].
class PersonalEventCacheAdapter implements PersonalEventCache {
  const PersonalEventCacheAdapter(this._service);

  final PersonalEventCacheService _service;

  @override
  bool get isInitialized => _service.isInitialized;

  @override
  List<Event> getEventsByKind(int kind) => _service.getEventsByKind(kind);

  @override
  void cacheUserEvent(Event event) => _service.cacheUserEvent(event);
}
