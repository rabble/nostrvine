// ABOUTME: A single long-lived, KEY-LESS background isolate that runs NIP-17
// ABOUTME: gift-wrap id + Schnorr verification off the main isolate on the
// ABOUTME: remote-signer history drain. The decrypt for remote signers
// ABOUTME: (Keycast RPC / Amber IPC / NIP-46) must stay on the main isolate
// ABOUTME: (the signer cannot cross a SendPort), but the pure verification
// ABOUTME: can — and needs no private key, so nothing secret is ever sent in.
// ABOUTME: Spawned once per drain, fed events over a port, killed when the
// ABOUTME: drain ends. See #5424 (sibling of #5412's DmDecryptIsolate).

import 'dart:async';
import 'dart:isolate';

import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/nip59/gift_wrap_util.dart';

/// Minimal worker contract used by the history drain to verify gift-wrap-layer
/// events off the main isolate and release the worker when the drain exits.
abstract interface class DmVerifyWorker {
  /// Returns `true` iff [event] recomputes its own id (sha256) and carries a
  /// valid Schnorr signature ([verifyGiftWrapPart]). Never throws for a
  /// verification result; throws [StateError] only if called after [close].
  Future<bool> verifyPart(Event event);

  /// Releases worker resources. Idempotent.
  void close();
}

/// Creates a drain-scoped verify worker.
typedef DmVerifyIsolateSpawner = Future<DmVerifyWorker> Function();

/// Production [DmVerifyWorker] backed by a long-lived, KEY-LESS Dart isolate.
///
/// Mirrors `DmDecryptIsolate` but for the remote-signer history drain, whose
/// per-event validation otherwise runs on the main isolate inside
/// `GiftWrapUtil.getRumorEvent`. The decrypt must stay on the main isolate (a
/// remote signer's RPC/IPC cannot cross a `SendPort`); only the pure id +
/// Schnorr verification moves here. Unlike the decrypt worker this needs NO
/// private key — verification reads only the event's own fields — so the
/// key-residency trade that scopes the decrypt isolate to one drain does not
/// apply. Spawned once per drain and killed in the drain's `finally`.
class DmVerifyIsolate implements DmVerifyWorker {
  DmVerifyIsolate._({required Isolate isolate, required ReceivePort responses})
    : _isolate = isolate,
      _responses = responses;

  final Isolate _isolate;
  final ReceivePort _responses;

  /// The worker's command port, received during the spawn handshake.
  late final SendPort _commands;

  /// Routes worker responses back to their awaiting [verifyPart] callers.
  late final StreamSubscription<dynamic> _subscription;

  /// Outstanding requests keyed by id so concurrent / interleaved [verifyPart]
  /// calls (the drain runs many wraps in flight) each resolve to their own
  /// result.
  final Map<int, Completer<bool>> _pending = <int, Completer<bool>>{};

  int _nextRequestId = 0;
  bool _closed = false;

  /// Spawns the worker and completes once it has reported its command port.
  /// No key or other secret crosses the boundary.
  static Future<DmVerifyIsolate> spawn() async {
    final responses = ReceivePort();
    final isolate = await Isolate.spawn(
      _dmVerifyIsolateEntry,
      responses.sendPort,
      debugName: 'dm-verify-isolate',
    );

    final ready = Completer<SendPort>();
    final instance = DmVerifyIsolate._(isolate: isolate, responses: responses);
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
  Future<bool> verifyPart(Event event) {
    if (_closed) {
      throw StateError('DmVerifyIsolate has been closed');
    }
    final id = _nextRequestId++;
    final completer = Completer<bool>();
    _pending[id] = completer;
    _commands.send((id, event.toJson()));
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
          StateError('DmVerifyIsolate closed before the verify completed'),
        );
      }
    }
    _pending.clear();
  }
}

/// Worker entry: handshakes its command port back to the spawner, then verifies
/// each `(id, eventJson)` request with [verifyGiftWrapPartJson] and replies
/// `(id, result)`. The helper never throws (malformed JSON → `false`), so the
/// loop is crash-free; the isolate is torn down via [Isolate.kill] from
/// [DmVerifyIsolate.close].
Future<void> _dmVerifyIsolateEntry(SendPort replyTo) async {
  final commands = ReceivePort();
  replyTo.send(commands.sendPort);

  await for (final dynamic message in commands) {
    final (int id, Map<dynamic, dynamic> rawEvent) =
        message as (int, Map<dynamic, dynamic>);
    final result = verifyGiftWrapPartJson(Map<String, dynamic>.from(rawEvent));
    replyTo.send((id, result));
  }
}
