// ABOUTME: A single long-lived background isolate for NIP-17 gift-wrap
// ABOUTME: decryption on the history-drain path. Spawned once per drain, fed
// ABOUTME: chunks over a port, and killed when the drain ends — so a large
// ABOUTME: backfill pays one isolate spawn instead of one per chunk (#5391
// ABOUTME: review follow-up). The recipient private key crosses the boundary
// ABOUTME: once at spawn and is resident only for the drain's lifetime.

import 'dart:async';
import 'dart:isolate';

import 'package:dm_repository/src/dm_decryption_worker.dart';

/// A long-lived decrypt isolate that unwraps batches of NIP-17 gift wraps
/// (kind 1059) off the main isolate.
///
/// The per-chunk `compute` path spawned a fresh isolate per
/// `DmHistoryDrainConfig.decryptBatchSize`-wrap chunk; a ~1000-wrap backfill
/// therefore paid ~50 isolate spawns. This worker is spawned ONCE (drift-style)
/// at the start of a history drain and fed one chunk per [decryptBatch] call
/// over a [SendPort], so the repeated spawn cost is gone.
///
/// Key-residency trade (see PR #5405 review): a persistent worker holds the
/// recipient private key for its whole lifetime rather than for one transient
/// `compute` isolate. We bound that exposure by scoping the isolate to a single
/// drain — [close] (which the drain calls in its `finally`) kills the isolate
/// and reclaims the key. That window equals the one the main isolate already
/// holds the extracted hex in today's per-chunk path.
/// Minimal worker contract used by the history drain to decrypt batches and
/// release any resident key material when the drain exits.
abstract interface class DmDecryptWorker {
  /// Decrypts [events] and returns one result per input event, in order.
  Future<List<DecryptedRumorResult>> decryptBatch(
    List<Map<String, dynamic>> events,
  );

  /// Releases worker resources and resident key material.
  void close();
}

/// Creates a drain-scoped decrypt worker for [privateKeyHex].
typedef DmDecryptIsolateSpawner =
    Future<DmDecryptWorker> Function(String privateKeyHex);

/// Production [DmDecryptWorker] backed by a long-lived Dart isolate.
class DmDecryptIsolate implements DmDecryptWorker {
  DmDecryptIsolate._({required Isolate isolate, required ReceivePort responses})
    : _isolate = isolate,
      _responses = responses;

  final Isolate _isolate;
  final ReceivePort _responses;

  /// The worker's command port, received during the spawn handshake.
  late final SendPort _commands;

  /// Routes worker responses back to their awaiting [decryptBatch] callers.
  late final StreamSubscription<dynamic> _subscription;

  /// Outstanding requests keyed by id so concurrent / interleaved
  /// [decryptBatch] calls each resolve to their own result.
  final Map<int, Completer<List<DecryptedRumorResult>>> _pending =
      <int, Completer<List<DecryptedRumorResult>>>{};

  int _nextRequestId = 0;
  bool _closed = false;

  /// Spawns the worker and completes once it has reported its command port.
  ///
  /// [privateKeyHex] is the recipient key used for the two-layer NIP-44 ECDH;
  /// it is sent into the isolate once here and never retained on the main side.
  static Future<DmDecryptIsolate> spawn(String privateKeyHex) async {
    final responses = ReceivePort();
    final isolate = await Isolate.spawn(_dmDecryptIsolateEntry, (
      responses.sendPort,
      privateKeyHex,
    ), debugName: 'dm-decrypt-isolate');

    final ready = Completer<SendPort>();
    final instance = DmDecryptIsolate._(isolate: isolate, responses: responses);
    instance._subscription = responses.listen((dynamic message) {
      if (!ready.isCompleted) {
        // First message is the worker's command port (handshake).
        ready.complete(message as SendPort);
        return;
      }
      // Records survive the isolate copy but the list field can widen to
      // List<dynamic>; cast the elements (already DecryptedRumorResult) back.
      final (int id, List<dynamic> raw) = message as (int, List<dynamic>);
      instance._pending.remove(id)?.complete(raw.cast<DecryptedRumorResult>());
    });

    final commandPort = await ready.future;
    instance._commands = commandPort;
    return instance;
  }

  /// Decrypts [events] (a chunk of kind-1059 gift wraps as JSON) and returns
  /// one [DecryptedRumorResult] per event, in order. Never throws for a
  /// per-event crypto failure (the worker maps those to failure entries);
  /// throws [StateError] only if called after [close].
  @override
  Future<List<DecryptedRumorResult>> decryptBatch(
    List<Map<String, dynamic>> events,
  ) {
    if (_closed) {
      throw StateError('DmDecryptIsolate has been closed');
    }
    final id = _nextRequestId++;
    final completer = Completer<List<DecryptedRumorResult>>();
    _pending[id] = completer;
    _commands.send((id, events));
    return completer.future;
  }

  /// Kills the worker (reclaiming the resident private key), stops listening,
  /// and fails any still-pending requests so their awaiters never hang.
  /// Idempotent.
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
          StateError('DmDecryptIsolate closed before the batch completed'),
        );
      }
    }
    _pending.clear();
  }
}

/// Worker entry: handshakes its command port back to the spawner, then
/// decrypts each `(id, events)` request with the resident key and replies
/// `(id, results)`. [decryptGiftWrapBatch] never throws, so the loop is
/// crash-free; the isolate is torn down via [Isolate.kill] from
/// `DmDecryptIsolate.close`.
Future<void> _dmDecryptIsolateEntry((SendPort, String) init) async {
  final (replyTo, privateKeyHex) = init;
  final commands = ReceivePort();
  replyTo.send(commands.sendPort);

  await for (final dynamic message in commands) {
    final (int id, List<dynamic> rawEvents) = message as (int, List<dynamic>);
    final results = await decryptGiftWrapBatch(
      DecryptBatchRequest(
        events: rawEvents.cast<Map<String, dynamic>>(),
        privateKeyHex: privateKeyHex,
      ),
    );
    replyTo.send((id, results));
  }
}
