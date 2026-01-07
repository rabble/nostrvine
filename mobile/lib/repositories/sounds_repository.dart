// ABOUTME: Repository for fetching and caching Kind 1063 audio events from Nostr relays.
// ABOUTME: Provides methods to query sounds (trending, by creator, by usage count) for audio reuse.

import 'dart:async';

import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/models/audio_event.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:rxdart/rxdart.dart';

/// Repository for managing audio events (Kind 1063) for audio reuse.
///
/// Responsibilities:
/// - Fetching Kind 1063 audio events from Nostr relays
/// - In-memory caching of audio events
/// - Providing methods to query sounds (trending, by creator, by usage count)
/// - Supporting the Sounds Browser UI with reactive streams
///
/// Exposes a stream for reactive updates to the sounds list.
class SoundsRepository {
  SoundsRepository({required NostrClient nostrClient})
    : _nostrClient = nostrClient;

  final NostrClient _nostrClient;

  /// BehaviorSubject replays last value to late subscribers
  final _soundsSubject = BehaviorSubject<List<AudioEvent>>.seeded(const []);

  /// Stream of cached audio events for reactive UI updates
  Stream<List<AudioEvent>> get soundsStream => _soundsSubject.stream;

  /// In-memory cache of audio events by event ID
  final Map<String, AudioEvent> _cache = {};

  /// Active subscription for real-time updates
  StreamSubscription<Event>? _subscription;
  String? _subscriptionId;

  bool _isInitialized = false;

  /// Whether the repository has been initialized
  bool get isInitialized => _isInitialized;

  /// Get all cached sounds as an unmodifiable list
  List<AudioEvent> get cachedSounds =>
      List.unmodifiable(_cache.values.toList());

  /// Get count of cached sounds
  int get cachedSoundCount => _cache.length;

  /// Emit current cache state to stream
  void _emitSounds() {
    if (!_soundsSubject.isClosed) {
      final sounds = _cache.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _soundsSubject.add(List.unmodifiable(sounds));
    }
  }

  /// Initialize the repository and start fetching sounds.
  ///
  /// Call this before using the repository to ensure sounds are loaded.
  Future<void> initialize() async {
    if (_isInitialized) return;

    Log.debug(
      'Initializing SoundsRepository',
      name: 'SoundsRepository',
      category: LogCategory.system,
    );

    try {
      // Fetch initial trending sounds
      await fetchTrendingSounds();

      // Subscribe for real-time updates
      _subscribeToAudioEvents();

      _isInitialized = true;

      Log.info(
        'SoundsRepository initialized: ${_cache.length} sounds cached',
        name: 'SoundsRepository',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'SoundsRepository initialization error: $e',
        name: 'SoundsRepository',
        category: LogCategory.system,
      );
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _subscription?.cancel();
    if (_subscriptionId != null) {
      await _nostrClient.unsubscribe(_subscriptionId!);
      _subscriptionId = null;
    }
    await _soundsSubject.close();
    _cache.clear();
  }

  /// Fetch trending/recent sounds from relays.
  ///
  /// Returns a list of [AudioEvent]s sorted by creation time (newest first).
  /// Results are cached for future use.
  Future<List<AudioEvent>> fetchTrendingSounds({int limit = 50}) async {
    Log.debug(
      'Fetching trending sounds (limit: $limit)',
      name: 'SoundsRepository',
      category: LogCategory.api,
    );

    try {
      final events = await _nostrClient.queryEvents([
        Filter(kinds: const [audioEventKind], limit: limit),
      ]);

      final audioEvents = _processAndCacheEvents(events);

      Log.debug(
        'Fetched ${audioEvents.length} trending sounds',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );

      return audioEvents;
    } catch (e) {
      Log.error(
        'Error fetching trending sounds: $e',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );
      rethrow;
    }
  }

  /// Fetch sounds by a specific creator pubkey.
  ///
  /// Returns a list of [AudioEvent]s created by the specified user.
  /// Results are cached for future use.
  Future<List<AudioEvent>> fetchSoundsByCreator(
    String pubkey, {
    int limit = 50,
  }) async {
    if (pubkey.isEmpty) {
      Log.debug(
        'Empty pubkey provided to fetchSoundsByCreator',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );
      return [];
    }

    Log.debug(
      'Fetching sounds by creator: $pubkey',
      name: 'SoundsRepository',
      category: LogCategory.api,
    );

    try {
      final events = await _nostrClient.queryEvents([
        Filter(authors: [pubkey], kinds: const [audioEventKind], limit: limit),
      ]);

      final audioEvents = _processAndCacheEvents(events);

      Log.debug(
        'Fetched ${audioEvents.length} sounds by creator',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );

      return audioEvents;
    } catch (e) {
      Log.error(
        'Error fetching sounds by creator: $e',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );
      rethrow;
    }
  }

  /// Fetch a specific sound by event ID.
  ///
  /// First checks the cache, then falls back to network query.
  /// Returns null if the sound is not found.
  Future<AudioEvent?> fetchSoundById(String eventId) async {
    if (eventId.isEmpty) {
      Log.debug(
        'Empty eventId provided to fetchSoundById',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );
      return null;
    }

    // Check cache first
    final cached = _cache[eventId];
    if (cached != null) {
      Log.debug(
        'Sound found in cache: $eventId',
        name: 'SoundsRepository',
        category: LogCategory.storage,
      );
      return cached;
    }

    Log.debug(
      'Fetching sound by ID: $eventId',
      name: 'SoundsRepository',
      category: LogCategory.api,
    );

    try {
      final event = await _nostrClient.fetchEventById(eventId);

      if (event == null) {
        Log.debug(
          'Sound not found: $eventId',
          name: 'SoundsRepository',
          category: LogCategory.api,
        );
        return null;
      }

      // Verify it's a Kind 1063 event
      if (event.kind != audioEventKind) {
        Log.warning(
          'Event $eventId is not a Kind $audioEventKind audio event '
          '(got Kind ${event.kind})',
          name: 'SoundsRepository',
          category: LogCategory.api,
        );
        return null;
      }

      final audioEvent = AudioEvent.fromNostrEvent(event);
      _cacheSound(audioEvent);

      return audioEvent;
    } catch (e) {
      Log.error(
        'Error fetching sound by ID: $e',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );
      rethrow;
    }
  }

  /// Get a sound from the cache without making a network request.
  ///
  /// Returns null if the sound is not in the cache.
  AudioEvent? getSoundFromCache(String eventId) {
    return _cache[eventId];
  }

  /// Fetch the count of videos using a specific sound.
  ///
  /// Uses NIP-45 COUNT if the relay supports it, otherwise falls back to
  /// fetching events and counting client-side.
  ///
  /// The count is based on Kind 34236 video events that reference the
  /// audio event ID in their tags.
  Future<int> fetchVideosUsingSoundCount(String audioEventId) async {
    if (audioEventId.isEmpty) {
      Log.debug(
        'Empty audioEventId provided to fetchVideosUsingSoundCount',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );
      return 0;
    }

    Log.debug(
      'Fetching video count for audio: $audioEventId',
      name: 'SoundsRepository',
      category: LogCategory.api,
    );

    try {
      // Query for Kind 34236 video events that reference this audio event
      final result = await _nostrClient.countEvents([
        Filter(
          kinds: const [34236], // Video event kind
          e: [audioEventId], // Events referencing this audio
        ),
      ]);

      Log.debug(
        'Video count for audio $audioEventId: ${result.count}'
        '${result.approximate ? ' (approximate)' : ''}',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );

      return result.count;
    } catch (e) {
      Log.error(
        'Error fetching video count for audio: $e',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );
      return 0;
    }
  }

  /// Fetch videos that use a specific sound.
  ///
  /// Returns a list of video event IDs that reference the audio event.
  Future<List<String>> fetchVideosUsingSound(
    String audioEventId, {
    int limit = 50,
  }) async {
    if (audioEventId.isEmpty) {
      return [];
    }

    Log.debug(
      'Fetching videos using audio: $audioEventId',
      name: 'SoundsRepository',
      category: LogCategory.api,
    );

    try {
      final events = await _nostrClient.queryEvents([
        Filter(
          kinds: const [34236], // Video event kind
          e: [audioEventId],
          limit: limit,
        ),
      ]);

      final videoIds = events.map((e) => e.id).toList();

      Log.debug(
        'Found ${videoIds.length} videos using audio',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );

      return videoIds;
    } catch (e) {
      Log.error(
        'Error fetching videos using audio: $e',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );
      rethrow;
    }
  }

  /// Subscribe to real-time audio event updates.
  void _subscribeToAudioEvents() {
    Log.debug(
      'Subscribing to audio events',
      name: 'SoundsRepository',
      category: LogCategory.relay,
    );

    _subscriptionId = 'sounds_repo_audio_events';

    final eventStream = _nostrClient.subscribe([
      Filter(kinds: const [audioEventKind], limit: 100),
    ], subscriptionId: _subscriptionId);

    _subscription = eventStream.listen(
      (event) {
        if (event.kind == audioEventKind) {
          _processAndCacheEvent(event);
        }
      },
      onError: (error) {
        Log.error(
          'Audio events subscription error: $error',
          name: 'SoundsRepository',
          category: LogCategory.relay,
        );
      },
    );
  }

  /// Process and cache a single Nostr event as an AudioEvent.
  void _processAndCacheEvent(Event event) {
    try {
      final audioEvent = AudioEvent.fromNostrEvent(event);
      _cacheSound(audioEvent);
    } catch (e) {
      Log.warning(
        'Failed to parse audio event: $e',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );
    }
  }

  /// Process and cache multiple Nostr events.
  ///
  /// Returns a list of successfully parsed [AudioEvent]s sorted by creation
  /// time (newest first).
  List<AudioEvent> _processAndCacheEvents(List<Event> events) {
    final audioEvents = <AudioEvent>[];

    for (final event in events) {
      if (event.kind != audioEventKind) continue;

      try {
        final audioEvent = AudioEvent.fromNostrEvent(event);
        _cache[audioEvent.id] = audioEvent;
        audioEvents.add(audioEvent);
      } catch (e) {
        Log.warning(
          'Failed to parse audio event: $e',
          name: 'SoundsRepository',
          category: LogCategory.api,
        );
      }
    }

    // Sort by creation time (newest first)
    audioEvents.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (audioEvents.isNotEmpty) {
      _emitSounds();
    }

    return audioEvents;
  }

  /// Cache a single audio event and emit updated list.
  void _cacheSound(AudioEvent audioEvent) {
    final isNew = !_cache.containsKey(audioEvent.id);
    _cache[audioEvent.id] = audioEvent;

    if (isNew) {
      _emitSounds();
    }
  }

  /// Clear all cached sounds.
  ///
  /// Useful for debugging or forcing a refresh.
  void clearCache() {
    _cache.clear();
    _emitSounds();
  }

  /// Refresh sounds by clearing cache and fetching fresh data.
  Future<void> refresh({int limit = 50}) async {
    clearCache();
    await fetchTrendingSounds(limit: limit);
  }
}
