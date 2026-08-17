// ABOUTME: Abstract relay class defining the Nostr relay interface.
// ABOUTME: Manages subscriptions, queries, COUNT queries, and pending messages.

import 'dart:async';
import 'dart:collection';
import 'dart:developer';

import '../count_response.dart';
import '../subscription.dart';
import 'client_connected.dart';
import 'relay_info.dart';
import 'relay_info_util.dart';
import 'relay_status.dart';

enum WriteAccess { readOnly, writeOnly, readWrite, nothing }

abstract class Relay {
  static const int _recentSentEventLimit = 64;

  final String url;

  RelayStatus relayStatus;

  RelayInfo? info;

  // to hold the message when the ws haven't connected and should be send after connected.
  List<List<dynamic>> pendingMessages = [];

  // to hold the message when the ws haven't authed and should be send after auth.
  List<List<dynamic>> pendingAuthedMessages = [];

  Function(Relay, List<dynamic>)? onMessage;

  // subscriptions
  final Map<String, Subscription> _subscriptions = {};

  // queries
  final Map<String, Subscription> _queries = {};

  final LinkedHashMap<String, List<dynamic>> _recentSentEvents =
      LinkedHashMap<String, List<dynamic>>();

  // NIP-45 COUNT queries
  final Map<String, Completer<CountResponse>> _countQueries = {};

  Relay(this.url, this.relayStatus);

  /// The method to call connect function by framework.
  Future<bool> connect() async {
    try {
      relayStatus.authed = false;
      var result = await doConnect();
      if (result) {
        try {
          onConnected(source: 'connect()');
        } catch (e) {
          log("onConnected exception.");
          log('$e');
        }
      }
      return result;
    } catch (e) {
      log("connect fail");
      disconnect();
      return false;
    }
  }

  /// The method implement by different relays to do some real when it connecting.
  Future<bool> doConnect();

  /// Whether the socket this [onConnected] runs on is a new one.
  ///
  /// [connect] short-circuits when the connection is already live, so it can
  /// reach [onConnected] without anything having been cycled. Such a socket
  /// still holds every REQ it was sent, and re-issuing them would only make
  /// the relay replay its stored window again.
  bool get connectionIsFresh => true;

  /// The medhod called after relay connect success.
  ///
  /// Flushes whatever was queued while the socket was down, then — when the
  /// connection is actually new — re-issues every saved subscription and
  /// pending one-shot query. The re-issue is what makes a reconnect
  /// recoverable: a REQ written to a socket that later died is gone, and the
  /// relay keeps no record of it, so without this a live subscription goes
  /// permanently silent after any reconnect and its caller can only fall back
  /// to a timeout. Mirrors the post-AUTH replay and the zombie reconnect in
  /// `RelayPool`.
  Future onConnected({String? source}) async {
    final saved = connectionIsFresh
        ? [..._subscriptions.values, ..._queries.values]
        : const <Subscription>[];
    await _flushPendingMessages(source, {for (final s in saved) s.id});
    await _reissueSavedRequests(source, saved);
  }

  /// Sends the frames that failed while the socket was down.
  ///
  /// REQ frames naming one of [reissuedIds] are dropped instead of sent: the
  /// saved subscription carries the same REQ and is re-issued right after, and
  /// sending both makes the relay replay its whole stored window twice.
  Future<void> _flushPendingMessages(
    String? source,
    Set<String> reissuedIds,
  ) async {
    log(
      '[Relay] onConnected[${source ?? "unknown"}]: ${relayStatus.addr} - sending ${pendingMessages.length} pending messages',
    );
    if (pendingMessages.isEmpty) {
      log(
        '[Relay] onConnected[${source ?? "unknown"}]: ${relayStatus.addr} - NO pending messages to send!',
      );
      return;
    }
    final messagesToSend = List<List<dynamic>>.from(pendingMessages);
    pendingMessages.clear();

    for (var message in messagesToSend) {
      if (_isReqNaming(message, reissuedIds)) continue;
      try {
        final result = await send(message, queueIfFailed: false);
        if (!result) {
          pendingMessages.add(message);
          log("message send fail onConnected");
        } else {
          log(
            '[Relay] onConnected[${source ?? "unknown"}]: sent pending message type=${message.isNotEmpty ? message[0] : "unknown"}',
          );
        }
      } catch (e) {
        pendingMessages.add(message);
        log("message send exception onConnected");
        log('$e');
      }
    }
    log(
      '[Relay] onConnected[${source ?? "unknown"}]: ${relayStatus.addr} - replay complete, remaining pending messages=${pendingMessages.length}',
    );
  }

  bool _isReqNaming(List<dynamic> message, Set<String> ids) =>
      message.length > 1 && message[0] == 'REQ' && ids.contains(message[1]);

  void retainSentEvent(String eventId, List<dynamic> message) {
    _recentSentEvents.remove(eventId);
    _recentSentEvents[eventId] = List<dynamic>.from(message);
    while (_recentSentEvents.length > _recentSentEventLimit) {
      _recentSentEvents.remove(_recentSentEvents.keys.first);
    }
  }

  List<dynamic>? takeSentEvent(String eventId) =>
      _recentSentEvents.remove(eventId);

  void forgetSentEvent(String eventId) {
    _recentSentEvents.remove(eventId);
  }

  bool hasRetainedSentEvent(String eventId) =>
      _recentSentEvents.containsKey(eventId);

  /// Re-sends every REQ this relay is still holding on the fresh socket.
  ///
  /// `skipReconnect` matches how these REQs were sent the first time
  /// (`RelayPool.relayDoSubscribe`): re-issuing onto a socket that dies again
  /// must queue the frame, not drive a nested reconnect out of the reconnect
  /// handler that is already running.
  Future<void> _reissueSavedRequests(
    String? source,
    List<Subscription> saved,
  ) async {
    if (saved.isEmpty) return;
    log(
      '[Relay] onConnected[${source ?? "unknown"}]: ${relayStatus.addr} - re-issuing ${saved.length} saved REQs',
    );
    for (final subscription in saved) {
      try {
        await send(subscription.toJson(), skipReconnect: true);
      } catch (e) {
        log('subscription re-issue exception onConnected');
        log('$e');
      }
    }
  }

  Future<void> getRelayInfo(String url) async {
    info ??= await RelayInfoUtil.get(url);
  }

  /// Sends [message] to this relay.
  ///
  /// [deadline] is a hard send deadline: implementations must not write or
  /// queue the message after it has expired.
  Future<bool> send(
    List<dynamic> message, {
    bool queueIfFailed = true,
    bool skipReconnect = false,
    DateTime? deadline,
  });

  Future<void> disconnect();

  void onError(String errMsg, {bool reconnect = false}) {
    log("relay error $errMsg");
    relayStatus.onError();
    relayStatus.connected = ClientConnected.disconnect;
    if (relayStatusCallback != null) {
      relayStatusCallback!();
    }
    // Note: reconnection is now handled by WebSocketConnectionManager
  }

  List<Subscription> getSubscriptions() {
    return _subscriptions.values.toList();
  }

  void saveSubscription(Subscription subscription) {
    _subscriptions[subscription.id] = subscription;
  }

  bool checkAndCompleteSubscription(String id) {
    // all subscription should be close
    var sub = _subscriptions.remove(id);
    if (sub != null) {
      send(["CLOSE", id]);
      return true;
    }
    return false;
  }

  bool hasSubscription() {
    return _subscriptions.isNotEmpty;
  }

  bool hasSubscriptionById(String id) {
    return _subscriptions.containsKey(id);
  }

  void saveQuery(Subscription subscription) {
    _queries[subscription.id] = subscription;
  }

  /// The one-shot queries still awaiting EOSE on this relay.
  ///
  /// Unlike [getSubscriptions], these are closed when their EOSE arrives.
  /// The pool replays them after a forced reconnect so the REQ is re-issued
  /// on the fresh socket and the query can still EOSE instead of only
  /// resolving via the caller's timeout.
  List<Subscription> getQueries() {
    return _queries.values.toList();
  }

  Future<bool> checkAndCompleteQuery(String id) async {
    // all subscription should be close
    var sub = _queries.remove(id);
    if (sub != null) {
      await send(["CLOSE", id]);
      return true;
    }
    return false;
  }

  /// Drops a pending one-shot query without sending `CLOSE`.
  ///
  /// Used when the relay itself ended the subscription (a `CLOSED` frame), so
  /// echoing a `CLOSE` back would name a subscription the relay has already
  /// forgotten. Returns whether [id] named a pending query.
  bool discardQuery(String id) => _queries.remove(id) != null;

  bool checkQuery(String id) {
    return _queries[id] != null;
  }

  Subscription? getRequestSubscription(String id) {
    return _queries[id];
  }

  // NIP-45 COUNT query methods

  /// Register a COUNT query and return a future that completes with the response
  Future<CountResponse> registerCountQuery(String id) {
    final completer = Completer<CountResponse>();
    _countQueries[id] = completer;
    return completer.future;
  }

  /// Check if a COUNT query exists for this ID
  bool hasCountQuery(String id) {
    return _countQueries.containsKey(id);
  }

  /// Complete a COUNT query with the response
  void completeCountQuery(String id, CountResponse response) {
    final completer = _countQueries.remove(id);
    completer?.complete(response);
  }

  /// Complete a COUNT query with an error (e.g., CLOSED response)
  void failCountQuery(String id, String reason) {
    final completer = _countQueries.remove(id);
    completer?.completeError(CountNotSupportedException(reason));
  }

  Function? relayStatusCallback;

  void dispose() {}
}
