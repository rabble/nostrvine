// ABOUTME: Manages pool of Nostr relay connections for subscribing and querying events.
// ABOUTME: Handles relay lifecycle, message routing, authentication, and event filtering.

import 'dart:async';
import 'dart:collection';
import 'dart:developer';

import 'package:nostr_sdk/utils/relay_addr_util.dart';

import '../count_response.dart';
import '../event.dart';
import '../event_kind.dart';
import '../filter.dart';
import '../nostr.dart';
import '../subscription.dart';
import '../utils/string_util.dart';
import 'client_connected.dart';
import 'event_filter.dart';
import 'event_verify_isolate.dart';
import 'publish_outcome.dart';
import 'relay.dart';
import 'relay_base.dart';
import 'relay_type.dart';

class RelayPool {
  // avoid to send these events to cache relay
  static List<int> cacheAvoidEvents = [
    EventKind.nostrRemoteSigning,
    EventKind.groupMetadata,
    EventKind.groupAdmins,
    EventKind.groupMembers,
    EventKind.groupChatMessage,
    EventKind.groupNote,
    EventKind.comment,
  ];

  /// Per-relay cap inside [_sendCollect]'s sequential fan-out.
  ///
  /// Exposed as part of the public API so callers that wrap publish calls
  /// in their own outer guard can size that guard against the worst-case
  /// fan-out duration (`perRelaySendTimeout * configuredRelays.length`)
  /// rather than duplicating the literal. See
  /// `mobile/lib/services/video_event_publisher.dart` for the canonical
  /// caller-side derivation.
  static const Duration perRelaySendTimeout = Duration(seconds: 5);

  Nostr localNostr;

  final Map<String, Relay> _tempRelays = {};

  final Map<String, Relay> _relays = {};

  final Map<String, Relay> _cacheRelays = {};

  /// Optional off-main signature-verify worker (#5863). When set, the fresh
  /// Schnorr verify for a not-yet-trusted inbound event runs on a background
  /// isolate instead of the main/UI isolate. When null, verify runs inline on
  /// the main isolate exactly as before (the default, and every existing test).
  /// Wired by the app to an [EventVerifyIsolate]; injectable for tests.
  EventVerifyWorker? _verifyWorker;

  set eventVerifyWorker(EventVerifyWorker? worker) => _verifyWorker = worker;

  /// Per-relay serial tail used to keep EVENT/EOSE frames in order once verify
  /// becomes asynchronous (an EOSE must not complete a query before its
  /// preceding events finish verifying). One entry per relay url; only used
  /// when [_verifyWorker] is set.
  final Map<String, Future<void>> _orderedFrameTails = {};

  // subscription
  final Map<String, Subscription> _subscriptions = {};

  // init query
  final Map<String, Subscription> _initQuery = {};

  final Map<String, Function> _queryCompleteCallbacks = {};

  /// Tracks which relays have sent EOSE for each subscription.
  /// Used to determine when all relays have finished sending stored events.
  final Map<String, Set<String>> _subscriptionEoseRelays = {};

  List<EventFilter> eventFilters;

  Function(String, String)? onNotice;

  // Track pending AUTH events to match with OK responses
  final Map<String, String> _pendingAuthEvents = {};

  /// Track publishes awaiting OK confirmations (per event id).
  final Map<String, PublishTracker> _pendingPublishes = {};

  Relay Function(String) tempRelayGener;

  RelayPool(
    this.localNostr,
    this.eventFilters,
    this.tempRelayGener, {
    this.onNotice,
  });

  List<Subscription> _subscriptionsSnapshot() =>
      _subscriptions.values.toList(growable: false);

  List<Subscription> _initQueriesSnapshot() =>
      _initQuery.values.toList(growable: false);

  List<Relay> _relaysSnapshot() => _relays.values.toList(growable: false);

  List<Relay> _tempRelaysSnapshot() =>
      _tempRelays.values.toList(growable: false);

  List<Relay> _cacheRelaysSnapshot() =>
      _cacheRelays.values.toList(growable: false);

  List<String> _relayKeysSnapshot() => _relays.keys.toList(growable: false);

  List<MapEntry<String, Relay>> _relayEntriesSnapshot() =>
      _relays.entries.toList(growable: false);

  List<MapEntry<String, Relay>> _tempRelayEntriesSnapshot() =>
      _tempRelays.entries.toList(growable: false);

  List<MapEntry<String, Relay>> _cacheRelayEntriesSnapshot() =>
      _cacheRelays.entries.toList(growable: false);

  int? _eventKindFromMessage(List<dynamic> message) {
    if (message.length < 2 || message[0] != 'EVENT' || message[1] is! Map) {
      return null;
    }
    final kind = (message[1] as Map)['kind'];
    if (kind is int) return kind;
    if (kind is num) return kind.toInt();
    return null;
  }

  String? _eventIdFromMessage(List<dynamic> message) {
    if (message.length < 2 || message[0] != 'EVENT' || message[1] is! Map) {
      return null;
    }
    final id = (message[1] as Map)['id'];
    return id is String ? id : null;
  }

  void _logPublishDiagnostic(String diagnosticTag, String message) {
    log('$diagnosticTag relay diagnostic: $message');
  }

  Future<bool> add(
    Relay relay, {
    bool autoSubscribe = false,
    bool init = false,
    int relayType = RelayType.normal,
  }) async {
    if (relayType == RelayType.normal) {
      if (_relays.containsKey(relay.url)) {
        return true;
      } else {
        _relays[relay.url] = relay;
      }
    } else if (relayType == RelayType.cache) {
      if (_cacheRelays.containsKey(relay.url)) {
        return true;
      } else {
        _cacheRelays[relay.url] = relay;
      }
    }

    relay.onMessage = _onEvent;

    if (await relay.connect()) {
      if (autoSubscribe) {
        final msg =
            '🔄 autoSubscribe: re-sending ${_subscriptions.length} '
            'subscriptions to ${relay.url}';
        log(msg);
        for (final subscription in _subscriptionsSnapshot()) {
          // Save the subscription to the relay so that after AUTH completes
          // the relay can re-send it. Without this, autoSubscribe sends the
          // subscription once but it dies if the relay requires AUTH —
          // relay.getSubscriptions() would return empty after AUTH success.
          relay.saveSubscription(subscription);
          log('🔄 autoSubscribe: sending ${subscription.id} to ${relay.url}');
          await relay.send(subscription.toJson());
        }
      }
      if (init) {
        for (final subscription in _initQueriesSnapshot()) {
          relayDoQuery(relay, subscription, false);
        }
      }

      return true;
    } else {
      log("relay connect fail! ${relay.url}");
    }

    relay.relayStatus.onError();
    return false;
  }

  List<Relay> activeRelays() {
    List<Relay> list = [];
    final it = _relaysSnapshot();
    for (var relay in it) {
      if (relay.relayStatus.connected == ClientConnected.connected) {
        list.add(relay);
      }
    }
    return list;
  }

  void removeAll() {
    final keys = _relayKeysSnapshot();
    for (var url in keys) {
      _relays[url]?.disconnect();
      _relays[url]?.dispose();
    }
    _relays.clear();
  }

  void remove(String url, {int relayType = RelayType.normal}) {
    log('Removing $url');
    if (relayType == RelayType.normal) {
      _relays[url]?.disconnect();
      _relays[url]?.dispose();
      _relays.remove(url);
    } else if (relayType == RelayType.cache) {
      _cacheRelays[url]?.disconnect();
      _cacheRelays[url]?.dispose();
      _cacheRelays.remove(url);
    }
  }

  Relay? getRelay(String url) {
    return _relays[url];
  }

  Future<bool> relayDoQuery(
    Relay relay,
    Subscription subscription,
    bool sendAfterAuth, {
    bool runBeforeConnected = false,
  }) async {
    if (!relay.relayStatus.readAccess) {
      return false;
    }

    relay.relayStatus.onQuery();

    try {
      var message = subscription.toJson();
      if ((sendAfterAuth || relay.relayStatus.alwaysAuth) &&
          !relay.relayStatus.authed) {
        // For vine.hol.is, send the query to trigger AUTH challenge
        if (relay.url.contains('vine.hol.is')) {
          log('🔐 vine.hol.is query - sending to trigger AUTH challenge');
          final result = await relay
              .send(message, forceSend: true)
              .timeout(perRelaySendTimeout, onTimeout: () => false);
          if (result) {
            relay.saveQuery(subscription);
            return true;
          }
        } else {
          // Save query before — message will be sent after auth completes
          relay.saveQuery(subscription);
          relay.pendingAuthedMessages.add(message);
          return true;
        }
      } else {
        // Skip reconnect during query fan-out to avoid blocking
        // other relays while one dead relay tries exponential backoff.
        final result = await relay
            .send(message, skipReconnect: true)
            .timeout(perRelaySendTimeout, onTimeout: () => false);
        if (result) {
          relay.saveQuery(subscription);
        }
        return result;
      }
    } catch (err) {
      log(err.toString());
      relay.relayStatus.onError();
    }

    return false;
  }

  void _broadcaseToCache(Map<String, dynamic> event) {
    for (final relay in _cacheRelaysSnapshot()) {
      relay.send(["EVENT", event]);
    }
  }

  String? _stringAt(Relay relay, List<dynamic> frame, int index, String field) {
    if (frame.length <= index || frame[index] is! String) {
      log(
        'Malformed relay frame from ${relay.url}: expected $field '
        'as String at index $index: $frame',
      );
      return null;
    }
    return frame[index] as String;
  }

  String? _optionalStringAt(
    Relay relay,
    List<dynamic> frame,
    int index,
    String field, {
    required String defaultValue,
  }) {
    if (frame.length <= index) {
      return defaultValue;
    }
    return _stringAt(relay, frame, index, field);
  }

  bool? _boolAt(Relay relay, List<dynamic> frame, int index, String field) {
    if (frame.length <= index || frame[index] is! bool) {
      log(
        'Malformed relay frame from ${relay.url}: expected $field '
        'as bool at index $index: $frame',
      );
      return null;
    }
    return frame[index] as bool;
  }

  Map<String, dynamic>? _mapAt(
    Relay relay,
    List<dynamic> frame,
    int index,
    String field,
  ) {
    if (frame.length <= index) {
      log(
        'Malformed relay frame from ${relay.url}: missing $field '
        'at index $index: $frame',
      );
      return null;
    }

    final value = frame[index];
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      try {
        return Map<String, dynamic>.from(value);
      } catch (_) {
        // Fall through to the malformed-frame log below.
      }
    }

    log(
      'Malformed relay frame from ${relay.url}: expected $field '
      'as object at index $index: $frame',
    );
    return null;
  }

  int? _intPayloadField(
    Relay relay,
    List<dynamic> frame,
    Map<String, dynamic> payload,
    String field,
  ) {
    final value = payload[field];
    if (value is int) {
      return value;
    }

    log(
      'Malformed relay frame from ${relay.url}: expected payload.$field '
      'as int: $frame',
    );
    return null;
  }

  bool? _optionalBoolPayloadField(
    Relay relay,
    List<dynamic> frame,
    Map<String, dynamic> payload,
    String field, {
    required bool defaultValue,
  }) {
    final value = payload[field];
    if (value == null) {
      return defaultValue;
    }
    if (value is bool) {
      return value;
    }

    log(
      'Malformed relay frame from ${relay.url}: expected payload.$field '
      'as bool: $frame',
    );
    return null;
  }

  /// Session-scoped, insertion-ordered set of `"id:sig"` keys whose Schnorr
  /// signature has already been verified on this isolate. The same event
  /// arriving again from another relay skips the ~0.3ms secp256k1 verify that
  /// otherwise dominates cold start (signature verification was ~42% of
  /// startup CPU in profiling). Eviction is oldest-inserted-first (FIFO); a
  /// duplicate hit is not moved to most-recent, so it is not a true LRU — for
  /// a bounded seen-set that distinction is immaterial.
  ///
  /// The signature is part of the key because a Nostr event id commits to
  /// the event body only, *not* to `sig` — a relay can replay a known id
  /// carrying a different, invalid signature. Keying by id alone would let
  /// that copy skip verification; keying by `(id, sig)` forces a re-verify
  /// whenever the signature differs. Only fresh network verifications are
  /// recorded here, so a known/duplicate hit never masks an unverified copy.
  static const int _verifiedEventKeysCap = 20000;
  final LinkedHashSet<String> _verifiedEventKeys = LinkedHashSet<String>();

  /// Optional lookup for `(event id, signature)` pairs already verified in a
  /// *previous* session.
  ///
  /// Relays re-send events the app already downloaded and persisted, so on
  /// every cold start those events arrive again and would be re-verified. The
  /// app injects a lookup backed by its local event store (every persisted
  /// event was verified before being written), letting [_onEvent] skip the
  /// expensive Schnorr verify for a known id **only when the incoming
  /// signature matches the one that was persisted** — the id alone does not
  /// commit to `sig`. Must be a cheap, synchronous, side-effect-free test.
  bool Function(String eventId, String signature)? isKnownVerifiedEvent;

  /// Diagnostic counters for how [_onEvent] treated each incoming event's
  /// signature. Read-only; read by the dedup tests to assert that the skip
  /// branches actually fire. There is no production reader by design — the
  /// periodic verify-stats log was removed to keep the hot path quiet; wire
  /// these into a diagnostics surface if on-device skip-rate visibility is
  /// ever needed.
  int get verifiesPerformed => _verifiesPerformed;
  int get verifiesSkippedKnown => _verifiesSkippedKnown;
  int get verifiesSkippedSessionDup => _verifiesSkippedSessionDup;
  int _verifiesPerformed = 0;
  int _verifiesSkippedKnown = 0;
  int _verifiesSkippedSessionDup = 0;

  /// Records [key] (an `"id:sig"` pair) as verified, evicting the oldest once
  /// the cap is hit.
  void _markEventVerified(String key) {
    _verifiedEventKeys
      ..remove(key)
      ..add(key);
    if (_verifiedEventKeys.length > _verifiedEventKeysCap) {
      _verifiedEventKeys.remove(_verifiedEventKeys.first);
    }
  }

  /// Verifies [event]'s Schnorr signature, off the main isolate when a verify
  /// worker is wired (#5863), else inline via [Event.isSigned]. The caller has
  /// already run [Event.isValid] (id recompute), so only the signature is
  /// checked here. On any worker failure (isolate closed / died) it degrades
  /// to the inline check so a verify never hangs and correctness is preserved.
  Future<bool> _verifySignatureOffMain(
    Event event,
    Map<String, dynamic> eventJson,
  ) async {
    final worker = _verifyWorker;
    if (worker == null) return event.isSigned;
    try {
      return await worker.verify(eventJson);
    } catch (_) {
      return event.isSigned;
    }
  }

  /// Runs [work] after the previous EVENT/EOSE frame from the same relay,
  /// preserving per-relay in-order delivery once verify is asynchronous. Errors
  /// are swallowed on the retained tail so one bad frame can't wedge the chain;
  /// the returned future still surfaces them to the immediate caller.
  Future<void> _enqueueOrdered(Relay relay, Future<void> Function() work) {
    final key = relay.url;
    final prev = _orderedFrameTails[key] ?? Future<void>.value();
    final next = prev.then((_) => work());
    _orderedFrameTails[key] = next.catchError((Object _) {});
    return next;
  }

  Future<void> _onEvent(Relay relay, List<dynamic> json) async {
    final messageType = _stringAt(relay, json, 0, 'message type');
    if (messageType == null) return;

    // Log message type + sub ID (full json is too verbose for non-DM events)
    if (json.length >= 2) {
      final msgSubId = json.length >= 2 ? json[1] : '';
      if (msgSubId == 'dm_inbox' ||
          messageType == 'AUTH' ||
          messageType == 'CLOSED' ||
          messageType == 'NOTICE') {
        log('📡 Raw message from ${relay.url}: $json');
      } else {
        log(
          '📡 ${relay.url}: $messageType '
          '${json.length >= 2 ? json[1] : ""}',
        );
      }
    } else {
      log('📡 Raw message from ${relay.url}: $json');
    }

    // #5863: when an off-main verify worker is wired, serialize EVENT/EOSE
    // per relay so the asynchronous verify preserves in-order delivery — an
    // EOSE must not complete a query before its preceding events finish
    // verifying. With no worker the original synchronous path runs unchanged.
    if (_verifyWorker != null &&
        (messageType == 'EVENT' || messageType == 'EOSE')) {
      return _enqueueOrdered(
        relay,
        () => _dispatchTypedFrame(relay, json, messageType),
      );
    }
    return _dispatchTypedFrame(relay, json, messageType);
  }

  Future<void> _dispatchTypedFrame(
    Relay relay,
    List<dynamic> json,
    String messageType,
  ) async {
    if (messageType == 'EVENT') {
      try {
        final subId = _stringAt(relay, json, 1, 'EVENT subscription id');
        if (subId == null) return;

        final eventJson = _mapAt(relay, json, 2, 'EVENT payload');
        if (eventJson == null) return;

        final event = Event.fromJson(eventJson);

        // Cheap integrity check first: [Event.isValid] recomputes the
        // sha256 id from the event's own content, so a tampered payload is
        // rejected here without touching the expensive EC verifier.
        if (!event.isValid) {
          log(
            'Dropping relay event with invalid id '
            'from ${relay.url}: eventId=${event.id}',
          );
          return;
        }

        // Skip the expensive Schnorr verify when this exact `(id, sig)` pair
        // is already trusted. The event id commits to the body but not to
        // `sig`, so trust is keyed by both — a replayed id carrying a
        // different signature falls through to a full verify below.
        //  - Pairs verified in a previous session (known to the injected
        //    [isKnownVerifiedEvent] store) skip re-verify on cold start.
        //  - Pairs verified earlier this session (a duplicate delivery of the
        //    same event from another relay) skip re-verify.
        // Only fresh network verifications are recorded in [_verifiedEventKeys]
        // so a known/duplicate hit never masks an unverified network copy.
        final verifyKey = '${event.id}:${event.sig}';
        if (_verifiedEventKeys.contains(verifyKey)) {
          _verifiesSkippedSessionDup++;
        } else if (isKnownVerifiedEvent?.call(event.id, event.sig) ?? false) {
          _verifiesSkippedKnown++;
        } else if (await _verifySignatureOffMain(event, eventJson)) {
          _markEventVerified(verifyKey);
          _verifiesPerformed++;
        } else {
          log(
            'Dropping relay event with invalid signature '
            'from ${relay.url}: eventId=${event.id}',
          );
          return;
        }

        if ((relay.relayStatus.relayType != RelayType.cache)) {
          var event = Map<String, dynamic>.from(eventJson);
          var kind = event["kind"];
          if (!cacheAvoidEvents.contains(kind)) {
            event["sources"] = [relay.url];
            _broadcaseToCache(event);
          }
        }

        if (event.kind == EventKind.giftWrap) {
          log(
            '🎁 Kind 1059 gift wrap received! subId=$subId '
            'from ${relay.url}, eventId=${event.id}',
          );
        }

        // add some statistics
        relay.relayStatus.noteReceive();

        // check block pubkey
        for (var eventFilter in eventFilters) {
          if (eventFilter.check(event)) {
            if (event.kind == EventKind.giftWrap) {
              log(
                '🎁 Kind 1059 BLOCKED by eventFilter! '
                'eventId=${event.id}',
              );
            }
            return;
          }
        }

        if (relay.relayStatus.relayType == RelayType.cache) {
          // local message read source from json
          var sources = eventJson["sources"];
          if (sources != null && sources is List) {
            for (var source in sources) {
              event.sources.add(source);
            }
          }
          // mark this event is from local relay.
          event.cacheEvent = true;
        } else {
          event.sources.add(relay.url);
        }
        var subscription = _subscriptions[subId];

        if (subscription != null) {
          subscription.onEvent(event);
        } else {
          subscription = relay.getRequestSubscription(subId);
          subscription?.onEvent(event);
        }
      } catch (err) {
        log(err.toString());
      }
    } else if (messageType == 'EOSE') {
      final subId = _stringAt(relay, json, 1, 'EOSE subscription id');
      if (subId == null) return;
      if (subId == 'dm_inbox') {
        log('📬 EOSE received for dm_inbox from ${relay.url}');
      }
      var isQuery = await relay.checkAndCompleteQuery(subId);
      if (isQuery) {
        // is Query find if need to callback
        var callback = _queryCompleteCallbacks[subId];
        if (callback != null) {
          // need to callback, check if all relay complete query
          final list = [
            ..._relaysSnapshot(),
            ..._tempRelaysSnapshot(),
            ..._cacheRelaysSnapshot(),
          ];
          bool completeQuery = true;
          for (var r in list) {
            if (r.checkQuery(subId)) {
              // this relay hadn't compltete query
              completeQuery = false;
              break;
            }
          }
          if (completeQuery) {
            callback();
            _queryCompleteCallbacks.remove(subId);
          }
        }
      } else {
        // Handle EOSE for long-running subscriptions
        final subscription = _subscriptions[subId];
        if (subscription != null && subscription.onEose != null) {
          // Track which relays have sent EOSE for this subscription
          _subscriptionEoseRelays.putIfAbsent(subId, () => <String>{});
          _subscriptionEoseRelays[subId]!.add(relay.url);

          // Check if all relays that have this subscription have sent EOSE
          final activeRelays = _getRelaysWithSubscription(subId);
          if (_subscriptionEoseRelays[subId]!.length >= activeRelays.length) {
            subscription.onEose!();
            _subscriptionEoseRelays.remove(subId);
          }
        }
      }
    } else if (messageType == "OK") {
      log('📡 OK response from ${relay.url}: $json');

      // Check if this OK is for an AUTH event
      final eventId = _stringAt(relay, json, 1, 'OK event id');
      if (eventId == null) return;
      final success = _boolAt(relay, json, 2, 'OK success');
      if (success == null) return;
      final message = _optionalStringAt(
        relay,
        json,
        3,
        'OK message',
        defaultValue: '',
      );
      if (message == null) return;

      // Check if this OK is for a publish we are awaiting.
      final publishTracker = _pendingPublishes[eventId];
      if (publishTracker != null) {
        if (success) {
          publishTracker.onAccepted(relay.url);
          final diagnosticTag = publishTracker.diagnosticTag;
          if (diagnosticTag != null) {
            _logPublishDiagnostic(
              diagnosticTag,
              'OK accepted kind=${publishTracker.eventKind} '
              'eventId=$eventId relay=${relay.url}',
            );
          }
        } else {
          publishTracker.onRejected(relay.url, message);
          final diagnosticTag = publishTracker.diagnosticTag;
          if (diagnosticTag != null) {
            _logPublishDiagnostic(
              diagnosticTag,
              'OK rejected kind=${publishTracker.eventKind} '
              'eventId=$eventId relay=${relay.url} reason=$message',
            );
          }
        }
      }

      // Check if this is responding to our AUTH event
      if (_pendingAuthEvents.containsKey(eventId)) {
        _pendingAuthEvents.remove(eventId);

        if (success) {
          relay.relayStatus.authed = true;
          log('🔐 AUTH succeeded for ${relay.url}');

          // Send pending messages
          for (var message in relay.pendingAuthedMessages) {
            relay.send(message);
          }
          relay.pendingAuthedMessages.clear();

          // Send subscriptions
          if (relay.hasSubscription()) {
            var subs = relay.getSubscriptions();
            log(
              '🔐 AUTH post-auth: re-sending ${subs.length} '
              'subscriptions to ${relay.url}',
            );
            for (var subscription in subs) {
              log(
                '🔐 AUTH post-auth: sending ${subscription.id} '
                '${relay.url}',
              );
              relay.send(subscription.toJson());
            }
          } else {
            log(
              '🔐 AUTH post-auth: NO subscriptions saved for '
              '${relay.url}',
            );
          }
        } else {
          relay.relayStatus.authed = false;
          log('🔐 AUTH failed for ${relay.url}: $message');
        }
      }
    } else if (messageType == "NOTICE") {
      log('📡 NOTICE from ${relay.url}: $json');
      final message = _stringAt(relay, json, 1, 'NOTICE message');
      if (message == null) return;

      // notice save, TODO maybe should change code
      if (onNotice != null) {
        onNotice!(relay.url, message);
      }
    } else if (messageType == "AUTH") {
      try {
        // auth needed
        log('🔐 AUTH challenge received from ${relay.url}');
        final challenge = _stringAt(relay, json, 1, 'AUTH challenge');
        if (challenge == null) return;
        final challengePreview = challenge.length > 16
            ? challenge.substring(0, 16)
            : challenge;
        log('🔐 Challenge: $challengePreview...');
        var tags = [
          ["relay", relay.url],
          ["challenge", challenge],
        ];
        // Guard against empty cached pubkey: this path is triggered by
        // the relay, not a user action, and can race with sign-out,
        // initial signer load, and account-switch. Refresh from the
        // signer on demand; StateError falls through to the catch below
        // and the AUTH response is skipped.
        final pk = await localNostr.ensurePublicKey();
        Event? event = Event(pk, EventKind.authentication, tags, "");
        event = await localNostr.nostrSigner.signEvent(event);
        if (event != null) {
          log('🔐 Sending AUTH response for challenge: $challengePreview...');

          // Track this AUTH event to match with OK response
          _pendingAuthEvents[event.id] = relay.url;

          relay.send(["AUTH", event.toJson()], forceSend: true);
          log('🔐 AUTH response sent, waiting for relay confirmation...');

          if (relay.pendingAuthedMessages.isNotEmpty) {
            log(
              '🔐 Pending ${relay.pendingAuthedMessages.length} messages for after auth confirmation',
            );
          }
        }
      } catch (err, stackTrace) {
        log('🔐 AUTH handling failed for ${relay.url}: $err\n$stackTrace');
      }
    } else if (messageType == 'COUNT') {
      // NIP-45 COUNT response
      final subscriptionId = _stringAt(relay, json, 1, 'COUNT subscription id');
      if (subscriptionId == null) return;
      final payload = _mapAt(relay, json, 2, 'COUNT payload');
      if (payload == null) return;
      final count = _intPayloadField(relay, json, payload, 'count');
      if (count == null) return;
      final approximate = _optionalBoolPayloadField(
        relay,
        json,
        payload,
        'approximate',
        defaultValue: false,
      );
      if (approximate == null) return;

      log('📊 COUNT response: $count (approximate: $approximate)');

      final response = CountResponse(count: count, approximate: approximate);

      relay.completeCountQuery(subscriptionId, response);
    } else if (messageType == 'CLOSED') {
      // Handle CLOSED messages - check if it's for a COUNT query
      final subscriptionId = _stringAt(
        relay,
        json,
        1,
        'CLOSED subscription id',
      );
      if (subscriptionId == null) return;
      final reason = _optionalStringAt(
        relay,
        json,
        2,
        'CLOSED reason',
        defaultValue: 'Unknown reason',
      );
      if (reason == null) return;

      log('📡 CLOSED from ${relay.url}: $subscriptionId - $reason');
      // Check if this is a COUNT query being refused
      if (relay.hasCountQuery(subscriptionId)) {
        relay.failCountQuery(subscriptionId, reason);
      }
    }
  }

  void addInitQuery(
    List<Map<String, dynamic>> filters,
    Function(Event) onEvent, {
    String? id,
    Function? onComplete,
  }) {
    if (filters.isEmpty) {
      throw ArgumentError("No filters given", "filters");
    }

    final Subscription subscription = Subscription(filters, onEvent, id: id);
    _initQuery[subscription.id] = subscription;
    if (onComplete != null) {
      _queryCompleteCallbacks[subscription.id] = onComplete;
    }
  }

  /// subscribe shoud be a long time filter search.
  /// like: subscribe the newest event、notice.
  /// subscribe info will hold in reply pool and close in reply pool.
  /// subscribe can be subscribe when new relay put into pool.
  String subscribe(
    List<Map<String, dynamic>> filters,
    Function(Event) onEvent, {
    String? id,
    List<String>? tempRelays,
    List<String>? targetRelays,
    List<int> relayTypes = RelayType.all,
    bool sendAfterAuth =
        false, // if relay not connected, it will send after auth
    void Function()? onEose,
  }) {
    if (filters.isEmpty) {
      throw ArgumentError("No filters given", "filters");
    }

    tempRelays = handleAddrList(tempRelays);
    targetRelays = handleAddrList(targetRelays);

    final Subscription subscription = Subscription(
      filters,
      onEvent,
      id: id,
      onEose: onEose,
    );
    _subscriptions[subscription.id] = subscription;
    log(
      '📋 subscribe: id=${subscription.id}, '
      'relays=${_relays.length}, filters=$filters',
    );
    // tempRelay, only query those relay which has bean provide
    if (tempRelays != null &&
        tempRelays.isNotEmpty &&
        relayTypes.contains(RelayType.temp)) {
      for (var tempRelayAddr in tempRelays) {
        // check if normal relays has this temp relay, try to get relay from normal relays
        Relay? relay = _relays[tempRelayAddr];
        relay ??= checkAndGenTempRelay(tempRelayAddr);

        relayDoSubscribe(
          relay,
          subscription,
          sendAfterAuth,
          runBeforeConnected: true,
        );
      }
    }

    // normal relay, usually will query all the normal relays, but if targetRelays has provide, it only query from the provided querys.
    if (relayTypes.contains(RelayType.normal)) {
      for (final entry in _relayEntriesSnapshot()) {
        var relayAddr = entry.key;
        var relay = entry.value;

        if (targetRelays != null) {
          if (!targetRelays.contains(relayAddr)) {
            continue;
          }
        }

        relayDoSubscribe(relay, subscription, sendAfterAuth);
      }
    }

    // cache relay
    if (relayTypes.contains(RelayType.cache)) {
      for (final relay in _cacheRelaysSnapshot()) {
        relayDoSubscribe(relay, subscription, sendAfterAuth);
      }
    }

    return subscription.id;
  }

  Future<bool> relayDoSubscribe(
    Relay relay,
    Subscription subscription,
    bool sendAfterAuth, {
    bool runBeforeConnected = false,
  }) async {
    if (!relay.relayStatus.readAccess) {
      return false;
    }

    relay.relayStatus.onQuery();

    try {
      relay.saveSubscription(subscription);

      var message = subscription.toJson();
      final subscribeMsg =
          '📤 relayDoSubscribe: ${subscription.id} → ${relay.url} '
          '(authed=${relay.relayStatus.authed}, '
          'readAccess=${relay.relayStatus.readAccess}, '
          'connected=${relay.relayStatus.connected})';
      log(subscribeMsg);
      if ((sendAfterAuth || relay.relayStatus.alwaysAuth) &&
          !relay.relayStatus.authed) {
        // For vine.hol.is, send the subscription to trigger AUTH challenge
        if (relay.url.contains('vine.hol.is')) {
          log(
            '🔐 vine.hol.is subscription - sending to trigger AUTH challenge',
          );
          var result = await relay.send(message, forceSend: true);
          if (result) {
            return true;
          }
        } else {
          relay.pendingAuthedMessages.add(message);
          return true;
        }
      } else {
        var result = await relay.send(message, skipReconnect: true);
        log('📤 relayDoSubscribe: ${subscription.id} send result=$result');
        return result;
      }
    } catch (err) {
      log(err.toString());
      relay.relayStatus.onError();
    }

    return false;
  }

  bool tempRelayHasSubscription(String relayAddr) {
    var relay = _tempRelays[relayAddr];
    if (relay != null) {
      return relay.hasSubscription();
    }

    return false;
  }

  void unsubscribe(String id) {
    final subscription = _subscriptions.remove(id);
    // Clean up EOSE tracking for this subscription
    _subscriptionEoseRelays.remove(id);
    if (subscription != null) {
      // check query and send close
      var it = _relaysSnapshot();
      for (var relay in it) {
        relay.checkAndCompleteSubscription(id);
      }

      it = _tempRelaysSnapshot();
      for (var relay in it) {
        relay.checkAndCompleteSubscription(id);
      }

      it = _cacheRelaysSnapshot();
      for (var relay in it) {
        relay.checkAndCompleteSubscription(id);
      }
    } else {
      // check query and send close
      var it = _relaysSnapshot();
      for (var relay in it) {
        relay.checkAndCompleteQuery(id);
      }

      it = _tempRelaysSnapshot();
      for (var relay in it) {
        relay.checkAndCompleteQuery(id);
      }

      it = _cacheRelaysSnapshot();
      for (var relay in it) {
        relay.checkAndCompleteQuery(id);
      }
    }
  }

  // different relay use different filter
  String queryByFilters(
    Map<String, List<Map<String, dynamic>>> filtersMap,
    Function(Event) onEvent, {
    String? id,
    Function? onComplete,
  }) {
    if (filtersMap.isEmpty) {
      throw ArgumentError("No filters given", "filters");
    }
    id ??= StringUtil.rndNameStr(16);
    if (onComplete != null) {
      _queryCompleteCallbacks[id] = onComplete;
    }
    var entries = filtersMap.entries;
    for (var entry in entries) {
      var url = entry.key;
      var filters = entry.value;

      var relay = _relays[url];
      if (relay != null) {
        Subscription subscription = Subscription(filters, onEvent, id: id);
        relayDoQuery(relay, subscription, false);
      }
    }
    return id;
  }

  List<String>? handleAddrList(List<String>? addrList) {
    if (addrList == null) return null;
    return addrList.map(RelayAddrUtil.handle).toList();
  }

  /// query should be a one time filter search.
  /// like: query metadata, query old event.
  /// query info will hold in relay and close in relay when EOSE message be received.
  /// if onlyTempRelays is true and tempRelays is not empty, it will only query throw tempRelays.
  /// if onlyTempRelays is false and tempRelays is not empty, it will query bath myRelays and tempRelays.
  Future<String> query(
    List<Map<String, dynamic>> filters,
    Function(Event) onEvent, {
    String? id,
    Function? onComplete,
    List<String>? tempRelays,
    List<String>? targetRelays,
    List<int> relayTypes = RelayType.all,
    bool sendAfterAuth =
        false, // if relay not connected, it will send after auth
  }) async {
    if (filters.isEmpty) {
      throw ArgumentError("No filters given", "filters");
    }

    tempRelays = handleAddrList(tempRelays);
    targetRelays = handleAddrList(targetRelays);

    Subscription subscription = Subscription(filters, onEvent, id: id);
    if (onComplete != null) {
      _queryCompleteCallbacks[subscription.id] = onComplete;
    }

    // Collect futures so we can await them before the early-completion
    // check. Each relayDoQuery call only resolves after relay.send()
    // and saveQuery(), which is fast with skipReconnect: true.
    final queryFutures = <Future<bool>>[];

    // tempRelay, only query those relay which has bean provide
    if (tempRelays != null &&
        tempRelays.isNotEmpty &&
        relayTypes.contains(RelayType.temp)) {
      for (var tempRelayAddr in tempRelays) {
        // check if normal relays has this temp relay, try to get relay from normal relays
        Relay? relay = _relays[tempRelayAddr];
        relay ??= checkAndGenTempRelay(tempRelayAddr);

        queryFutures.add(
          relayDoQuery(
            relay,
            subscription,
            sendAfterAuth,
            runBeforeConnected: true,
          ),
        );
      }
    }

    // normal relay, usually will query all the normal relays, but if targetRelays has provide, it only query from the provided querys.
    if (relayTypes.contains(RelayType.normal)) {
      for (final entry in _relayEntriesSnapshot()) {
        var relayAddr = entry.key;
        var relay = entry.value;

        if (targetRelays != null) {
          if (!targetRelays.contains(relayAddr)) {
            continue;
          }
        }

        queryFutures.add(relayDoQuery(relay, subscription, sendAfterAuth));
      }
    }

    // cache relay
    if (relayTypes.contains(RelayType.cache)) {
      for (final relay in _cacheRelaysSnapshot()) {
        queryFutures.add(relayDoQuery(relay, subscription, sendAfterAuth));
      }
    }

    // Wait for all sends to complete (and saveQuery to run) before
    // checking whether any relay accepted the query.
    await Future.wait(queryFutures);

    // If no relay accepted the query (all sends failed), fire onComplete
    // immediately so callers don't wait for the full timeout.
    if (onComplete != null) {
      final list = [
        ..._relaysSnapshot(),
        ..._tempRelaysSnapshot(),
        ..._cacheRelaysSnapshot(),
      ];
      final anyPending = list.any((r) => r.checkQuery(subscription.id));
      if (!anyPending) {
        _queryCompleteCallbacks.remove(subscription.id);
        onComplete();
      }
    }

    return subscription.id;
  }

  /// send message to relay
  /// there are tempRelays, it also send to tempRelays too.
  Future<bool> send(
    List<dynamic> message, {
    List<String>? tempRelays,
    List<String>? targetRelays,
  }) async {
    final sentTo = await _sendCollect(
      message,
      tempRelays: tempRelays,
      targetRelays: targetRelays,
    );
    return sentTo.isNotEmpty;
  }

  /// Same as [send] but returns the list of relay URLs the message reached.
  ///
  /// An entry in the returned list means the relay's WebSocket accepted the
  /// frame (or it was queued for pending-auth delivery). It does NOT mean the
  /// relay accepted the event at the protocol level — use
  /// [sendEventAwaitOk] for that guarantee.
  ///
  /// Sends use `skipReconnect: true` so that a single disconnected relay
  /// cannot block the sequential fan-out by triggering a multi-minute
  /// exponential-backoff reconnect (mirrors the query fan-out paths above).
  /// Reconnection is driven by the relay manager's heartbeat, not by
  /// outbound publishes.
  ///
  /// Each individual `relay.send` is also wrapped in [perRelaySendTimeout]
  /// as a belt-and-suspenders backstop. `skipReconnect: true` already short-
  /// circuits the disconnected-state path inside `WebSocketConnectionManager`,
  /// but it does not bypass the `connecting`-state wait nor protect against
  /// a relay whose underlying socket is wedged after a successful handshake
  /// (TCP backpressure, slow peer). The per-relay timeout caps any single
  /// relay's contribution to the sequential fan-out, so the outer publish
  /// flow stays responsive even on degraded networks. Callers that wrap
  /// the publish call in their own outer guard should size that guard
  /// against `perRelaySendTimeout * configuredRelays.length` plus a small
  /// scheduling buffer.
  Future<List<String>> _sendCollect(
    List<dynamic> message, {
    List<String>? tempRelays,
    List<String>? targetRelays,
    DateTime? deadline,
    String? diagnosticTag,
    void Function(String relayUrl)? onSent,
  }) async {
    final sentTo = <String>[];
    final attemptedRelayUrls = <String>{};
    final eventKind = _eventKindFromMessage(message);
    final eventId = _eventIdFromMessage(message);

    void logDiagnostic(String message) {
      if (diagnosticTag == null) return;
      _logPublishDiagnostic(diagnosticTag, message);
    }

    Duration sendTimeout() {
      final remaining = deadline?.difference(DateTime.now());
      if (remaining == null || remaining > perRelaySendTimeout) {
        return perRelaySendTimeout;
      }
      if (remaining.isNegative || remaining == Duration.zero) {
        return Duration.zero;
      }
      return remaining;
    }

    bool deadlineExpired() {
      return deadline != null && !DateTime.now().isBefore(deadline);
    }

    void removeExpiredTempRelay(Relay relay) {
      if (!deadlineExpired()) return;
      unawaited(relay.disconnect());
      removeTempRelay(relay.url);
    }

    logDiagnostic(
      'send start kind=$eventKind eventId=$eventId '
      'targetRelays=$targetRelays tempRelays=$tempRelays',
    );

    for (final relay in _relaysSnapshot()) {
      final timeout = sendTimeout();
      if (timeout == Duration.zero) break;

      if (message[0] == "EVENT") {
        if (!relay.relayStatus.writeAccess) {
          logDiagnostic(
            'send skipped kind=$eventKind eventId=$eventId relay=${relay.url} '
            'reason=writeAccessDisabled',
          );
          continue;
        }
      }

      if (targetRelays != null && targetRelays.isNotEmpty) {
        if (!targetRelays.contains(relay.url)) {
          // not contain this relay
          continue;
        }
      }

      try {
        // Check if relay requires authentication
        if (relay.relayStatus.alwaysAuth && !relay.relayStatus.authed) {
          log(
            '🔐 Relay ${relay.url} requires auth (alwaysAuth=${relay.relayStatus.alwaysAuth}, authed=${relay.relayStatus.authed})',
          );

          // For vine.hol.is, we need to send one message to trigger AUTH challenge
          // Many relays only send AUTH challenges when they receive a message that needs auth
          if (relay.url.contains('vine.hol.is')) {
            log(
              '🔐 vine.hol.is detected - sending message to trigger AUTH challenge',
            );
            // Auth-trigger path intentionally does NOT pass skipReconnect:
            // the AUTH handshake requires a real send. Per-relay timeout
            // still applies so a stuck auth-trigger send cannot block the
            // rest of the fan-out.
            var timedOut = false;
            var result = await relay
                .send(
                  message,
                  forceSend: true,
                  queueIfFailed: deadline == null,
                  deadline: deadline,
                )
                .timeout(
                  timeout,
                  onTimeout: () {
                    timedOut = true;
                    log(
                      '⏱️ Per-relay auth-trigger send timeout for ${relay.url} '
                      '(connected=${relay.relayStatus.connected}, '
                      'authed=${relay.relayStatus.authed})',
                    );
                    return false;
                  },
                );
            if (result || timedOut || deadlineExpired()) {
              attemptedRelayUrls.add(relay.url);
            }
            if (result) {
              sentTo.add(relay.url);
              onSent?.call(relay.url);
            }
            logDiagnostic(
              'auth-trigger send kind=$eventKind eventId=$eventId '
              'relay=${relay.url} sent=$result',
            );
            // Don't queue this message since we're sending it
          } else {
            // Deadline-bound sends intentionally do not queue for AUTH: a queued
            // frame could publish after the caller already returned failure.
            if (deadline == null) {
              log('🔐 Queueing message for authentication: ${message[0]}');
              relay.pendingAuthedMessages.add(message);
              sentTo.add(relay.url);
              attemptedRelayUrls.add(relay.url);
              onSent?.call(relay.url);
              logDiagnostic(
                'queued for auth kind=$eventKind eventId=$eventId relay=${relay.url}',
              );
            } else {
              logDiagnostic(
                'auth queue skipped kind=$eventKind eventId=$eventId relay=${relay.url} '
                'reason=deadlineBoundSend',
              );
            }
          }
          log(
            '🔐 Pending authed messages count: ${relay.pendingAuthedMessages.length}',
          );
        } else {
          log(
            '🔐 Relay ${relay.url} sending immediately (alwaysAuth=${relay.relayStatus.alwaysAuth}, authed=${relay.relayStatus.authed})',
          );
          // Skip reconnect during fan-out to avoid blocking other relays
          // while one dead relay tries exponential backoff (can hang the
          // publish for many minutes). Same convention as relayDoQuery /
          // relayDoSubscribe above.
          var timedOut = false;
          var result = await relay
              .send(
                message,
                skipReconnect: true,
                queueIfFailed: deadline == null,
                deadline: deadline,
              )
              .timeout(
                timeout,
                onTimeout: () {
                  timedOut = true;
                  log(
                    '⏱️ Per-relay send timeout for ${relay.url} '
                    '(connected=${relay.relayStatus.connected}, '
                    'authed=${relay.relayStatus.authed})',
                  );
                  return false;
                },
              );
          if (result || timedOut || deadlineExpired()) {
            attemptedRelayUrls.add(relay.url);
          }
          if (result) {
            sentTo.add(relay.url);
            onSent?.call(relay.url);
          }
          logDiagnostic(
            'send kind=$eventKind eventId=$eventId relay=${relay.url} sent=$result',
          );
        }
      } catch (err) {
        logDiagnostic(
          'send error kind=$eventKind eventId=$eventId relay=${relay.url} error=$err',
        );
        log(err.toString());
        relay.relayStatus.onError();
      }
    }

    if (tempRelays != null) {
      for (var tempRelayAddr in tempRelays) {
        if (attemptedRelayUrls.contains(tempRelayAddr)) {
          continue;
        }
        attemptedRelayUrls.add(tempRelayAddr);
        final timeout = sendTimeout();
        if (timeout == Duration.zero) break;

        var tempRelay = checkAndGenTempRelay(tempRelayAddr);
        // Same skipReconnect rationale as the main loop above: a fresh
        // tempRelay whose initial connection is still in-flight must not
        // block the publish.
        var result = await tempRelay
            .send(
              message,
              skipReconnect: true,
              queueIfFailed: false,
              deadline: deadline,
            )
            .timeout(
              timeout,
              onTimeout: () {
                log(
                  '⏱️ Per-relay send timeout for tempRelay ${tempRelay.url} '
                  '(connected=${tempRelay.relayStatus.connected})',
                );
                removeExpiredTempRelay(tempRelay);
                return false;
              },
            );
        if (!result) {
          removeExpiredTempRelay(tempRelay);
        }
        if (result) {
          sentTo.add(tempRelay.url);
          onSent?.call(tempRelay.url);
        }
        logDiagnostic(
          'temp send kind=$eventKind eventId=$eventId relay=${tempRelay.url} sent=$result',
        );
      }
    }

    logDiagnostic(
      'send complete kind=$eventKind eventId=$eventId sentTo=$sentTo',
    );

    return sentTo;
  }

  /// Send an `EVENT` message and wait for `OK` confirmations from relays.
  ///
  /// Registers a [PublishTracker] keyed on the event id. The returned future
  /// completes when either:
  ///  * at least one relay has confirmed acceptance (`OK true`), OR
  ///  * every targeted relay has responded (accept or reject), OR
  ///  * [timeout] elapses.
  ///
  /// If no relay received the message at the WebSocket level, the tracker
  /// completes immediately with an empty [PublishOutcome] (all in
  /// `noResponseFrom`). Callers must inspect [PublishOutcome.confirmed] to
  /// decide whether the publish succeeded.
  Future<PublishOutcome> sendEventAwaitOk(
    List<dynamic> message, {
    required String eventId,
    int? eventKind,
    List<String>? tempRelays,
    List<String>? targetRelays,
    Duration timeout = const Duration(seconds: 15),
    String? diagnosticTag,
  }) async {
    // Register tracker BEFORE sending so a fast relay can't respond with OK
    // before we start listening.
    final existing = _pendingPublishes[eventId];
    if (existing != null) {
      return existing.future;
    }
    final tracker = PublishTracker(
      eventId: eventId,
      eventKind: eventKind ?? _eventKindFromMessage(message),
      diagnosticTag: diagnosticTag,
      expectedRelays: <String>{},
      timeout: timeout,
    );
    _pendingPublishes[eventId] = tracker;

    final sentTo = await _sendCollect(
      message,
      tempRelays: tempRelays,
      targetRelays: targetRelays,
      deadline: DateTime.now().add(timeout),
      diagnosticTag: diagnosticTag,
      onSent: (relayUrl) => tracker.expectedRelays.add(relayUrl),
    );

    if (sentTo.isEmpty) {
      tracker.cancel();
    }

    unawaited(
      tracker.future
          .then((outcome) {
            final diagnosticTag = tracker.diagnosticTag;
            if (diagnosticTag != null) {
              _logPublishDiagnostic(
                diagnosticTag,
                'OK outcome kind=${tracker.eventKind} eventId=$eventId '
                'acceptedBy=${outcome.acceptedBy} rejectedBy=${outcome.rejectedBy} '
                'noResponseFrom=${outcome.noResponseFrom}',
              );
            }
          })
          .whenComplete(() => _pendingPublishes.remove(eventId)),
    );
    return tracker.future;
  }

  void reconnect() {
    for (final relay in _relaysSnapshot()) {
      relay.connect();
    }
  }

  Relay checkAndGenTempRelay(String addr) {
    var tempRelay = _tempRelays[addr];
    if (tempRelay != null && _shouldReplaceTempRelay(tempRelay)) {
      _tempRelays.remove(addr);
      unawaited(tempRelay.disconnect());
      tempRelay.dispose();
      tempRelay = null;
    }
    if (tempRelay == null) {
      tempRelay = tempRelayGener(addr);
      tempRelay.onMessage = _onEvent;
      tempRelay.connect();
      _tempRelays[addr] = tempRelay;
    }

    return tempRelay;
  }

  bool _shouldReplaceTempRelay(Relay relay) {
    if (relay.relayStatus.connected == ClientConnected.disconnect) {
      return true;
    }
    return relay.relayStatus.connected == ClientConnected.connected &&
        relay is RelayBase &&
        !relay.checkHealth();
  }

  List<String> getExtralReadableRelays(
    List<String> extralRelays,
    int maxRelayNum,
  ) {
    List<String> list = [];

    int sameNum = 0;
    for (var extralRelay in extralRelays) {
      extralRelay = RelayAddrUtil.handle(extralRelay);

      var relay = _relays[extralRelay];
      if (relay == null || !relay.relayStatus.readAccess) {
        // not contains or can't readable
        list.add(extralRelay);
      } else {
        sameNum++;
      }
    }

    var needExtralNum = maxRelayNum - sameNum;
    if (needExtralNum <= 0) {
      return [];
    }

    if (list.length < needExtralNum) {
      return list;
    }

    return list.sublist(0, needExtralNum);
  }

  void removeTempRelay(String addr) {
    var relay = _tempRelays.remove(addr);
    if (relay != null) {
      relay.disconnect();
    }
  }

  Relay? getTempRelay(String url) {
    return _tempRelays[url];
  }

  bool readable() {
    for (final relay in _relaysSnapshot()) {
      if (relay.relayStatus.connected == ClientConnected.connected &&
          relay.relayStatus.readAccess) {
        return true;
      }
    }

    return false;
  }

  /// Configure a relay to always require authentication
  void setRelayAlwaysAuth(String relayUrl, bool alwaysAuth) {
    var relay = _relays[relayUrl];
    if (relay != null) {
      relay.relayStatus.alwaysAuth = alwaysAuth;
    }
  }

  /// Configure multiple relays with authentication requirements
  void configureRelayAuth(Map<String, bool> relayAuthConfig) {
    relayAuthConfig.forEach((url, alwaysAuth) {
      setRelayAlwaysAuth(url, alwaysAuth);
    });
  }

  /// Get current authentication configuration for all relays
  Map<String, bool> getRelayAuthConfig() {
    Map<String, bool> config = {};
    for (final entry in _relayEntriesSnapshot()) {
      final url = entry.key;
      final relay = entry.value;
      config[url] = relay.relayStatus.alwaysAuth;
    }
    return config;
  }

  bool writable() {
    for (final relay in _relaysSnapshot()) {
      if (relay.relayStatus.connected == ClientConnected.connected &&
          relay.relayStatus.writeAccess) {
        return true;
      }
    }

    return false;
  }

  /// Convenience method for searching events using NIP-50.
  ///
  /// Performs a full-text search across event content on NIP-50 compatible relays.
  ///
  /// Parameters:
  /// - [query]: The search query string
  /// - [kinds]: Optional list of event kinds to filter
  /// - [authors]: Optional list of author public keys
  /// - [since]: Optional start time for the search range
  /// - [until]: Optional end time for the search range
  /// - [limit]: Maximum number of results to return (default: 100)
  /// - [timeout]: How long to wait for results (default: 5 seconds)
  /// - [relayUrls]: Optional specific relays to query (uses all connected relays if not specified)
  ///
  /// Returns a list of [Event] objects matching the search criteria.
  /// Results are automatically deduplicated by event ID.
  Future<List<Event>> searchEvents(
    String query, {
    List<int>? kinds,
    List<String>? authors,
    DateTime? since,
    DateTime? until,
    int? limit,
    Duration? timeout,
    List<String>? relayUrls,
  }) async {
    // Create filter with search parameter
    final filter = Filter(
      search: query,
      kinds: kinds,
      authors: authors,
      since: since != null ? since.millisecondsSinceEpoch ~/ 1000 : null,
      until: until != null ? until.millisecondsSinceEpoch ~/ 1000 : null,
      limit: limit ?? 100,
    );

    // Collect events
    final eventMap = <String, Event>{};

    // Set up timeout and EOSE-based early completion
    final timeoutDuration = timeout ?? const Duration(seconds: 5);
    final completer = Completer<List<Event>>();
    String? subscriptionId;

    void completeSearch() {
      if (completer.isCompleted) return;
      if (subscriptionId != null) {
        unsubscribe(subscriptionId);
      }
      completer.complete(eventMap.values.toList());
    }

    // Subscribe with EOSE callback for early completion
    subscriptionId = subscribe(
      [filter.toJson()],
      (event) {
        // Deduplicate by event ID
        eventMap[event.id] = event;
      },
      targetRelays: relayUrls,
      onEose: completeSearch,
    );

    // Timeout fallback in case not all relays send EOSE
    Timer(timeoutDuration, completeSearch);

    return completer.future;
  }

  /// Sends a COUNT query (NIP-45) to relays and returns the count.
  ///
  /// Unlike [query], this returns a count rather than events.
  /// Throws [CountNotSupportedException] if no relay supports NIP-45.
  ///
  /// Parameters:
  /// - [filters]: The filters to count events for (same format as REQ)
  /// - [id]: Optional subscription ID
  /// - [tempRelays]: Optional list of temporary relays to query
  /// - [relayTypes]: Types of relays to query (default: all)
  /// - [timeout]: How long to wait for a response (default: 5 seconds)
  Future<CountResponse> count(
    List<Map<String, dynamic>> filters, {
    String? id,
    List<String>? tempRelays,
    List<int> relayTypes = RelayType.all,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (filters.isEmpty) {
      throw ArgumentError('No filters given', 'filters');
    }

    tempRelays = handleAddrList(tempRelays);

    final subscriptionId = id ?? StringUtil.rndNameStr(16);

    // Collect all relays to try
    final relaysToTry = <Relay>[];

    // Add temp relays first
    if (tempRelays != null &&
        tempRelays.isNotEmpty &&
        relayTypes.contains(RelayType.temp)) {
      for (var tempRelayAddr in tempRelays) {
        Relay? relay = _relays[tempRelayAddr];
        relay ??= checkAndGenTempRelay(tempRelayAddr);
        relaysToTry.add(relay);
      }
    }

    // Add normal relays
    if (relayTypes.contains(RelayType.normal)) {
      for (final relay in _relaysSnapshot()) {
        if (!relaysToTry.contains(relay)) {
          relaysToTry.add(relay);
        }
      }
    }

    // Add cache relays
    if (relayTypes.contains(RelayType.cache)) {
      for (final relay in _cacheRelaysSnapshot()) {
        if (!relaysToTry.contains(relay)) {
          relaysToTry.add(relay);
        }
      }
    }

    // Send COUNT to all relays in parallel, return the largest count.
    // Different relays may have different subsets of data, so the highest
    // count is the most accurate.
    final eligibleRelays = relaysToTry
        .where((r) => r.relayStatus.readAccess)
        .toList();

    if (eligibleRelays.isEmpty) {
      throw CountNotSupportedException('No relay responded to COUNT');
    }

    final futures = <Future<CountResponse?>>[];
    for (var i = 0; i < eligibleRelays.length; i++) {
      final relay = eligibleRelays[i];
      // Use index as suffix to avoid hashCode collisions between URLs
      final relaySubId = '${subscriptionId}_$i';
      final relayMessage = ['COUNT', relaySubId, ...filters];

      futures.add(() async {
        try {
          final sent = await relay.send(relayMessage, skipReconnect: true);
          if (!sent) return null;

          // Only register after successful send to avoid orphaned completers
          final responseFuture = relay.registerCountQuery(relaySubId);
          log('📊 COUNT request sent to ${relay.url}');
          return await responseFuture.timeout(
            timeout,
            onTimeout: () {
              // Clean up the completer on timeout
              if (relay.hasCountQuery(relaySubId)) {
                relay.failCountQuery(relaySubId, 'Timeout');
              }
              throw CountNotSupportedException('Timeout');
            },
          );
        } catch (e) {
          log('📊 COUNT failed on ${relay.url}: $e');
          // Clean up if the completer is still pending
          if (relay.hasCountQuery(relaySubId)) {
            relay.failCountQuery(relaySubId, e.toString());
          }
          return null;
        }
      }());
    }

    final responses = await Future.wait(futures);
    final best = responses.whereType<CountResponse>().fold<CountResponse?>(
      null,
      (a, b) => a == null || b.count > a.count ? b : a,
    );

    if (best == null) {
      throw CountNotSupportedException('No relay responded to COUNT');
    }

    return best;
  }

  /// Returns the set of relay URLs that have the given subscription active.
  ///
  /// This is used to determine when all relays have sent EOSE for a subscription.
  /// Only counts relays that actually received the subscription, not relays with
  /// unrelated subscriptions.
  Set<String> _getRelaysWithSubscription(String subscriptionId) {
    final relays = <String>{};

    // Check normal relays
    for (final entry in _relayEntriesSnapshot()) {
      if (entry.value.hasSubscriptionById(subscriptionId)) {
        relays.add(entry.key);
      }
    }

    // Check temp relays
    for (final entry in _tempRelayEntriesSnapshot()) {
      if (entry.value.hasSubscriptionById(subscriptionId)) {
        relays.add(entry.key);
      }
    }

    // Check cache relays
    for (final entry in _cacheRelayEntriesSnapshot()) {
      if (entry.value.hasSubscriptionById(subscriptionId)) {
        relays.add(entry.key);
      }
    }

    return relays;
  }
}
