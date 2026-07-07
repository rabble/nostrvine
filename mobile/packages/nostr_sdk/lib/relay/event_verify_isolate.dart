// ABOUTME: A single long-lived, KEY-LESS background isolate that runs inbound
// ABOUTME: relay-event id (sha256) + Schnorr signature verification off the
// ABOUTME: main isolate (#5863). Feed relays (RelayBase) decode + verify every
// ABOUTME: EVENT frame on the main/UI isolate today; a cold-start backfill
// ABOUTME: burst of ~6.5ms/verify blocks frame callbacks. Verification reads
// ABOUTME: only the event's own public fields and needs no private key, so it
// ABOUTME: moves here safely — nothing secret ever crosses the SendPort.
// ABOUTME: Persistent (spawned once, reused for the app's lifetime), unlike the
// ABOUTME: drain-scoped DmVerifyIsolate it mirrors.

import 'dart:async';
import 'dart:isolate';

import '../event.dart';

/// Verifies inbound relay events (id recompute + Schnorr) off the main isolate.
///
/// Implementations must never leave a [verify] future hanging: a failure
/// (isolate death, malformed payload) resolves to an error or `false`, never a
/// stuck future, so the caller can fall back to inline verification.
abstract interface class EventVerifyWorker {
  /// Returns `true` iff the raw event [eventJson] recomputes its own id
  /// (sha256 over the NIP-01 serialization) and carries a valid Schnorr
  /// signature. Throws [StateError] only if called after [close].
  Future<bool> verify(Map<String, dynamic> eventJson);

  /// Releases the worker. Idempotent. Any still-pending [verify] futures
  /// complete with an error so their awaiters can fall back rather than hang.
  void close();
}

/// Spawns an [EventVerifyWorker]. Injected into `RelayPool` so tests can swap in
/// a synchronous fake and the app wires the real isolate.
typedef EventVerifyWorkerSpawner = Future<EventVerifyWorker> Function();

/// Production [EventVerifyWorker] backed by a long-lived, KEY-LESS Dart isolate.
///
/// Mirrors `dm_repository`'s `DmVerifyIsolate` (same handshake + `_pending`
/// request/response protocol) but is persistent rather than drain-scoped, and
/// verifies generic relay events (`Event.isValid && Event.isSigned`) instead of
/// gift-wrap parts. Verification needs no private key, so — unlike a decrypt
/// isolate — nothing secret is sent across the port.
class EventVerifyIsolate implements EventVerifyWorker {
  EventVerifyIsolate._({
    required Isolate isolate,
    required ReceivePort responses,
  }) : _isolate = isolate,
       _responses = responses;

  final Isolate _isolate;
  final ReceivePort _responses;

  /// The worker's command port, received during the spawn handshake.
  late final SendPort _commands;

  /// Routes worker responses back to their awaiting [verify] callers.
  late final StreamSubscription<dynamic> _subscription;

  /// Outstanding requests keyed by id so concurrent / interleaved [verify]
  /// calls each resolve to their own result.
  final Map<int, Completer<bool>> _pending = <int, Completer<bool>>{};

  int _nextRequestId = 0;
  bool _closed = false;

  /// Spawns the worker and completes once it has reported its command port.
  /// No key or other secret crosses the boundary.
  static Future<EventVerifyIsolate> spawn() async {
    final responses = ReceivePort();
    final isolate = await Isolate.spawn(
      _eventVerifyIsolateEntry,
      responses.sendPort,
      debugName: 'event-verify-isolate',
    );

    final ready = Completer<SendPort>();
    final instance = EventVerifyIsolate._(
      isolate: isolate,
      responses: responses,
    );
    instance._subscription = responses.listen((dynamic message) {
      if (!ready.isCompleted) {
        // First message is the worker's command port (handshake).
        ready.complete(message as SendPort);
        return;
      }
      final (int id, bool result) = message as (int, bool);
      instance._pending.remove(id)?.complete(result);
    });

    final commandPort = await ready.future;
    instance._commands = commandPort;
    return instance;
  }

  @override
  Future<bool> verify(Map<String, dynamic> eventJson) {
    if (_closed) {
      throw StateError('EventVerifyIsolate has been closed');
    }
    final id = _nextRequestId++;
    final completer = Completer<bool>();
    _pending[id] = completer;
    _commands.send((id, eventJson));
    return completer.future;
  }

  /// Kills the worker, stops listening, and fails any still-pending requests so
  /// their awaiters never hang. Idempotent.
  @override
  void close() {
    if (_closed) return;
    _closed = true;
    unawaited(_subscription.cancel());
    _responses.close();
    _isolate.kill(priority: Isolate.immediate);
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('EventVerifyIsolate closed before the verify completed'),
        );
      }
    }
    _pending.clear();
  }
}

/// Worker entry: handshakes its command port back to the spawner, then verifies
/// each `(id, eventJson)` request and replies `(id, result)`. The body never
/// throws (malformed payload → `false`), so the loop is crash-free; the isolate
/// is torn down via [Isolate.kill] from [EventVerifyIsolate.close].
Future<void> _eventVerifyIsolateEntry(SendPort replyTo) async {
  final commands = ReceivePort();
  replyTo.send(commands.sendPort);

  await for (final dynamic message in commands) {
    final (int id, Map<dynamic, dynamic> rawEvent) =
        message as (int, Map<dynamic, dynamic>);
    var result = false;
    try {
      final event = Event.fromJson(Map<String, dynamic>.from(rawEvent));
      result = event.isValid && event.isSigned;
    } catch (_) {
      result = false;
    }
    replyTo.send((id, result));
  }
}
