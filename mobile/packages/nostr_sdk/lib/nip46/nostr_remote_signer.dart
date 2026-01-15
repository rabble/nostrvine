import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import '../event.dart';
import '../event_kind.dart';
import '../filter.dart';
import '../nip19/nip19.dart';
import '../relay/client_connected.dart';
import '../relay/relay.dart';
import '../relay/relay_base.dart';
import '../relay/relay_isolate.dart';
import '../relay/relay_mode.dart';
import '../relay/relay_status.dart';
import '../signer/local_nostr_signer.dart';
import '../signer/nostr_signer.dart';
import '../utils/string_util.dart';
import 'nostr_remote_request.dart';
import 'nostr_remote_response.dart';
import 'nostr_remote_signer_info.dart';

/// Exception thrown when bunker requires user authentication via URL
class BunkerAuthRequiredException implements Exception {
  final String authUrl;
  final String requestId;

  BunkerAuthRequiredException(this.authUrl, this.requestId);

  @override
  String toString() => 'BunkerAuthRequiredException: $authUrl';
}

class NostrRemoteSigner extends NostrSigner {
  int relayMode;

  NostrRemoteSignerInfo info;

  late LocalNostrSigner localNostrSigner;

  NostrRemoteSigner(this.relayMode, this.info);

  List<Relay> relays = [];

  Map<String, Completer<String?>> callbacks = {};

  /// Stores pending request events that need to be resent after reconnection.
  /// Key is the request ID, value is the signed EVENT message (as JSON array).
  final Map<String, List<dynamic>> _pendingRequestEvents = {};

  /// Callback for when an auth URL is received and needs to be opened
  void Function(String authUrl)? onAuthUrlReceived;

  /// Tracks request IDs for which we've already opened an auth URL
  /// This prevents opening the same auth URL multiple times on reconnection
  final Set<String> _openedAuthUrls = {};

  /// Stores the original `since` timestamp for the subscription filter.
  /// This is set when we first connect and reused for reconnections to ensure
  /// we don't miss events that were created while we were disconnected.
  int? _subscriptionSinceTimestamp;

  Future<String?> connect({bool sendConnectRequest = true}) async {
    log(
      '[NIP46] connect: STARTING - _subscriptionSinceTimestamp=$_subscriptionSinceTimestamp, relays.length=${relays.length}, callbacks=${callbacks.keys.toList()}',
    );

    if (StringUtil.isBlank(info.nsec)) {
      log('[NIP46] connect: nsec is blank, returning null');
      return null;
    }

    localNostrSigner = LocalNostrSigner(Nip19.decode(info.nsec!));
    log('[NIP46] connect: created localNostrSigner');

    for (var remoteRelayAddr in info.relays) {
      var relay = await _connectToRelay(remoteRelayAddr);
      relays.add(relay);
    }

    if (sendConnectRequest) {
      log(
        '[NIP46] connect: relays status after delay: ${relays.map((r) => "${r.relayStatus.addr}=${r.relayStatus.connected}").join(", ")}',
      );

      var request = NostrRemoteRequest("connect", [
        info.remoteSignerPubkey,
        info.optionalSecret ?? "",
        "sign_event,get_relays,get_public_key,nip04_encrypt,nip04_decrypt,nip44_encrypt,nip44_decrypt",
      ]);
      log(
        '[NIP46] connect: sending connect request id=${request.id} to remoteSignerPubkey=${info.remoteSignerPubkey}',
      );
      var result = await sendAndWaitForResult(request, timeout: 120);
      log('[NIP46] connect: result=$result');
      return result;
    }
    return null;
  }

  Future<String?> pullPubkey() async {
    var request = NostrRemoteRequest("get_public_key", []);
    var pubkey = await sendAndWaitForResult(request, timeout: 120);
    info.userPubkey = pubkey;
    return pubkey;
  }

  Future<void> onMessage(Relay relay, List<dynamic> json) async {
    final messageType = json[0];
    if (messageType == 'EVENT') {
      try {
        relay.relayStatus.noteReceive();

        final subscriptionId = json[1];
        final event = Event.fromJson(json[2]);
        log(
          '[NIP46] onMessage: received event subscriptionId=$subscriptionId, kind=${event.kind} from ${event.pubkey}, createdAt=${event.createdAt}',
        );
        if (event.kind == EventKind.nostrRemoteSigning) {
          var response = await NostrRemoteResponse.decrypt(
            event.content,
            localNostrSigner,
            event.pubkey,
          );
          if (response != null) {
            // Check for auth_url challenge - this means user needs to approve
            if (response.result == 'auth_url' && response.error != null) {
              log(
                '[NIP46] onMessage: auth challenge received, URL=${response.error}',
              );
              // Only open the auth URL once per request ID
              // This prevents re-opening the browser on reconnection when
              // historical events are replayed from the relay
              if (_openedAuthUrls.contains(response.id)) {
                log(
                  '[NIP46] onMessage: auth URL already opened for id=${response.id}, ignoring',
                );
                return;
              }
              _openedAuthUrls.add(response.id);

              // Don't remove the callback - we need to wait for the actual response
              // after user approves in the browser
              if (onAuthUrlReceived != null) {
                onAuthUrlReceived!(response.error!);
              }
              return; // Keep waiting for the real response
            }

            var completer = callbacks.remove(response.id);
            // Also remove from pending requests since we got a response
            _pendingRequestEvents.remove(response.id);
            if (completer != null) {
              completer.complete(response.result);
            }
          } else {
            log('[NIP46] onMessage: failed to decrypt response');
          }
        }
      } catch (err) {
        log('[NIP46] onMessage error: $err');
      }
    } else if (messageType == 'EOSE') {
      log('[NIP46] onMessage: EOSE received');
    } else if (messageType == "NOTICE") {
      log('[NIP46] onMessage: NOTICE: ${json.length > 1 ? json[1] : ""}');
    } else if (messageType == "AUTH") {
      log('[NIP46] onMessage: AUTH challenge received');
    } else if (messageType == "OK") {
      log(
        '[NIP46] onMessage: OK received: ${json.length > 1 ? json.sublist(1).join(", ") : ""}',
      );
    }
  }

  Future<Relay> _connectToRelay(String relayAddr) async {
    RelayStatus relayStatus = RelayStatus(relayAddr);
    Relay? relay;
    if (relayMode == RelayMode.baseMode) {
      relay = RelayBase(relayAddr, relayStatus);
    } else {
      relay = RelayIsolate(relayAddr, relayStatus);
    }
    relay.onMessage = onMessage;
    await addPenddingQueryMsg(relay);
    relay.relayStatusCallback = () {
      if (relayStatus.connected == ClientConnected.disconnect) {
        log(
          '[NIP46] relayStatusCallback: relay ${relayStatus.addr} disconnected, attempting reconnect...',
        );
        // Attempt to reconnect automatically when disconnected
        // This is important for auth flows where app goes to background
        _reconnectRelay(relay!);
      }
    };

    await relay.connect();

    return relay;
  }

  /// Attempts to reconnect a relay after disconnection
  /// Uses exponential backoff to avoid hammering the relay
  Future<void> _reconnectRelay(Relay relay) async {
    // Avoid multiple simultaneous reconnection attempts
    if (relay.relayStatus.connected == ClientConnected.connecting) {
      log(
        '[NIP46] _reconnectRelay: already reconnecting to ${relay.relayStatus.addr}',
      );
      return;
    }

    try {
      // Check if still disconnected (might have reconnected via another path)
      if (relay.relayStatus.connected == ClientConnected.connected) {
        log(
          '[NIP46] _reconnectRelay: ${relay.relayStatus.addr} already reconnected',
        );
        return;
      }

      log(
        '[NIP46] _reconnectRelay: reconnecting to ${relay.relayStatus.addr}...',
      );

      // Add subscription query to pending messages before reconnecting
      if (relay.pendingMessages.isEmpty) {
        await addPenddingQueryMsg(relay);
      }

      await relay.connect();
      log(
        '[NIP46] _reconnectRelay: ${relay.relayStatus.addr} reconnected successfully',
      );

      // Resend any pending request events that were waiting for responses
      if (_pendingRequestEvents.isNotEmpty) {
        log(
          '[NIP46] _reconnectRelay: resending ${_pendingRequestEvents.length} pending requests',
        );
        for (var entry in _pendingRequestEvents.entries) {
          log('[NIP46] _reconnectRelay: resending request id=${entry.key}');
          relay.send(entry.value, forceSend: true);
        }
      }
    } catch (e) {
      log(
        '[NIP46] _reconnectRelay: failed to reconnect ${relay.relayStatus.addr}: $e',
      );
    }
  }

  Future<void> addPenddingQueryMsg(Relay relay) async {
    // add a query event
    log(
      '[NIP46] addPenddingQueryMsg: generating REQ for ${relay.relayStatus.addr}',
    );
    var queryMsg = await genQueryMsg();
    if (queryMsg != null) {
      relay.pendingMessages.add(queryMsg);
      log(
        '[NIP46] addPenddingQueryMsg: added REQ to ${relay.relayStatus.addr}, pendingMessages count=${relay.pendingMessages.length}',
      );
      log('[NIP46] addPenddingQueryMsg: REQ message=$queryMsg');
    } else {
      log('[NIP46] addPenddingQueryMsg: genQueryMsg returned null');
    }
  }

  Future<List?> genQueryMsg() async {
    var pubkey = await localNostrSigner.getPublicKey();
    if (pubkey == null) {
      log('[NIP46] genQueryMsg: pubkey is null');
      return null;
    }

    // Use the stored timestamp if available (for reconnections),
    // otherwise create a new one (for initial connection)
    final isFirstCall = _subscriptionSinceTimestamp == null;
    final sinceTimestamp =
        _subscriptionSinceTimestamp ??
        DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Store the timestamp for future reconnections
    _subscriptionSinceTimestamp ??= sinceTimestamp;

    // Use a slightly earlier timestamp to account for clock skew between
    // our device and the bunker server (subtract 30 seconds)
    final adjustedSinceTimestamp = sinceTimestamp - 30;

    var filter = Filter(
      since: adjustedSinceTimestamp,
      p: [pubkey],
      kinds: [EventKind.nostrRemoteSigning],
    );

    final filterJson = filter.toJson();
    log(
      '[NIP46] genQueryMsg: using adjusted since=$adjustedSinceTimestamp (original=$sinceTimestamp)',
    );
    final subscriptionId = StringUtil.rndNameStr(12);
    List<dynamic> queryMsg = ["REQ", subscriptionId];
    queryMsg.add(filterJson);

    log(
      '[NIP46] genQueryMsg: created subscription $subscriptionId [isFirstCall=$isFirstCall]',
    );
    log('[NIP46] genQueryMsg: filter=$filterJson');
    return queryMsg;
  }

  Future<String?> sendAndWaitForResult(
    NostrRemoteRequest request, {
    int timeout = 60,
  }) async {
    // Check and reconnect any disconnected relays before sending
    for (var relay in relays) {
      final status = relay.relayStatus.connected;
      log(
        '[NIP46] sendAndWaitForResult: checking relay ${relay.relayStatus.addr}, status=$status',
      );
      // Only reconnect if truly disconnected, not if connecting or already connected
      if (status == ClientConnected.disconnect) {
        log(
          '[NIP46] sendAndWaitForResult: relay ${relay.relayStatus.addr} disconnected, reconnecting...',
        );
        try {
          await relay.connect();
          // Re-add the subscription query after reconnecting
          await addPenddingQueryMsg(relay);
          log(
            '[NIP46] sendAndWaitForResult: relay ${relay.relayStatus.addr} reconnected',
          );
        } catch (e) {
          log('[NIP46] sendAndWaitForResult: failed to reconnect relay: $e');
        }
      }
    }

    var senderPubkey = await localNostrSigner.getPublicKey();
    log(
      '[NIP46] sendAndWaitForResult: method=${request.method}, senderPubkey=$senderPubkey',
    );
    var content = await request.encrypt(
      localNostrSigner,
      info.remoteSignerPubkey,
    );
    log(
      '[NIP46] sendAndWaitForResult: encrypted content length=${content?.length ?? 0}',
    );
    if (StringUtil.isNotBlank(senderPubkey) && content != null) {
      Event? event = Event(senderPubkey!, EventKind.nostrRemoteSigning, [
        getRemoteSignerPubkeyTags(),
      ], content);
      event = await localNostrSigner.signEvent(event);
      if (event != null) {
        var json = ["EVENT", event.toJson()];
        log(
          '[NIP46] sendAndWaitForResult: sending event id=${event.id} to ${relays.length} relays',
        );

        // set completer to callbacks
        var completer = Completer<String?>();
        callbacks[request.id] = completer;

        // Store the request event for potential resend after reconnection
        _pendingRequestEvents[request.id] = json;

        for (var relay in relays) {
          log(
            '[NIP46] sendAndWaitForResult: sending to ${relay.relayStatus.addr}, connected=${relay.relayStatus.connected}',
          );
          relay.send(json, forceSend: true);
        }

        log(
          '[NIP46] sendAndWaitForResult: waiting for response with timeout=${timeout}s',
        );
        return await completer.future.timeout(
          Duration(seconds: timeout),
          onTimeout: () {
            log('[NIP46] sendAndWaitForResult: TIMEOUT waiting for response');
            return null;
          },
        );
      } else {
        log('[NIP46] sendAndWaitForResult: failed to sign event');
      }
    } else {
      log('[NIP46] sendAndWaitForResult: senderPubkey or content is null');
    }
    return null;
  }

  @override
  Future<String?> decrypt(pubkey, ciphertext) async {
    var request = NostrRemoteRequest("nip04_decrypt", [pubkey, ciphertext]);
    return await sendAndWaitForResult(request);
  }

  @override
  Future<String?> encrypt(pubkey, plaintext) async {
    var request = NostrRemoteRequest("nip04_encrypt", [pubkey, plaintext]);
    return await sendAndWaitForResult(request);
  }

  @override
  Future<String?> getPublicKey() async {
    return info.userPubkey;
  }

  @override
  Future<Map?> getRelays() async {
    var request = NostrRemoteRequest("get_relays", []);
    var result = await sendAndWaitForResult(request);
    if (StringUtil.isNotBlank(result)) {
      return jsonDecode(result!);
    }
    return null;
  }

  @override
  Future<String?> nip44Decrypt(pubkey, ciphertext) async {
    var request = NostrRemoteRequest("nip44_decrypt", [pubkey, ciphertext]);
    return await sendAndWaitForResult(request);
  }

  @override
  Future<String?> nip44Encrypt(pubkey, plaintext) async {
    var request = NostrRemoteRequest("nip44_encrypt", [pubkey, plaintext]);
    return await sendAndWaitForResult(request);
  }

  @override
  Future<Event?> signEvent(Event event) async {
    var eventJsonMap = event.toJson();
    eventJsonMap.remove("id");
    eventJsonMap.remove("pubkey");
    eventJsonMap.remove("sig");
    var eventJsonText = jsonEncode(eventJsonMap);
    // print("eventJsonText");
    // print(eventJsonText);
    var request = NostrRemoteRequest("sign_event", [eventJsonText]);
    var result = await sendAndWaitForResult(request);
    if (StringUtil.isNotBlank(result)) {
      // print("signEventResult");
      // print(result);
      var eventMap = jsonDecode(result!);
      return Event.fromJson(eventMap);
    }

    return null;
  }

  List<String>? _remotePubkeyTags;

  List<String> getRemoteSignerPubkeyTags() {
    _remotePubkeyTags ??= ["p", info.remoteSignerPubkey];
    return _remotePubkeyTags!;
  }

  @override
  void close() {}
}
