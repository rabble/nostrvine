// ABOUTME: Publishes the user's configured relay set as NIP-65 kind:10002.
// ABOUTME: Keeps relay-list event construction and retry state out of UI/BLoC.

import 'dart:async';

import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/services/relay_discovery_service.dart';
import 'package:openvine/utils/relay_url_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

const _relayListSignTimeout = Duration(seconds: 10);
const _dirtyRelayListPublishPrefix = 'relay_list_publish_dirty_';

enum RelayListPublishStatus {
  published,
  skippedNoKeys,
  skippedNonProduction,
  skippedNotDirty,
  failed,
}

class RelayListPublishResult {
  const RelayListPublishResult._({
    required this.status,
    this.error,
    this.stackTrace,
  });

  const RelayListPublishResult.published()
    : this._(status: RelayListPublishStatus.published);

  const RelayListPublishResult.skippedNoKeys()
    : this._(status: RelayListPublishStatus.skippedNoKeys);

  const RelayListPublishResult.skippedNonProduction()
    : this._(status: RelayListPublishStatus.skippedNonProduction);

  const RelayListPublishResult.skippedNotDirty()
    : this._(status: RelayListPublishStatus.skippedNotDirty);

  const RelayListPublishResult.failed(Object error, StackTrace stackTrace)
    : this._(
        status: RelayListPublishStatus.failed,
        error: error,
        stackTrace: stackTrace,
      );

  final RelayListPublishStatus status;
  final Object? error;
  final StackTrace? stackTrace;

  bool get synced => status == RelayListPublishStatus.published;
  bool get localOnly => switch (status) {
    RelayListPublishStatus.skippedNoKeys ||
    RelayListPublishStatus.failed => true,
    RelayListPublishStatus.published ||
    RelayListPublishStatus.skippedNonProduction ||
    RelayListPublishStatus.skippedNotDirty => false,
  };
}

class RelayListRepository {
  RelayListRepository({
    required NostrClient nostrClient,
    required EnvironmentConfig environment,
    required RelayDiscoveryService relayDiscoveryService,
    required SharedPreferences sharedPreferences,
    required List<DiscoveredRelay> Function() discoveredRelays,
  }) : _nostrClient = nostrClient,
       _environment = environment,
       _relayDiscoveryService = relayDiscoveryService,
       _sharedPreferences = sharedPreferences,
       _discoveredRelays = discoveredRelays;

  final NostrClient _nostrClient;
  final EnvironmentConfig _environment;
  final RelayDiscoveryService _relayDiscoveryService;
  final SharedPreferences _sharedPreferences;
  final List<DiscoveredRelay> Function() _discoveredRelays;

  Future<RelayListPublishResult> publishConfiguredRelayList() async {
    final pubkey = _nostrClient.publicKey;
    if (!_nostrClient.hasKeys || pubkey.isEmpty) {
      return const RelayListPublishResult.skippedNoKeys();
    }

    if (!_environment.isProduction) {
      Log.info(
        'Skipping kind:10002 publish outside production so environment-locked '
        'relay lists do not replace a user production list (#3183)',
        name: 'RelayListRepository',
        category: LogCategory.relay,
      );
      return const RelayListPublishResult.skippedNonProduction();
    }

    try {
      final result = await _publishForPubkey(pubkey);
      if (result.synced) {
        await _clearDirty(pubkey);
      } else if (result.localOnly) {
        await _markDirty(pubkey);
      }
      return result;
    } catch (e, stackTrace) {
      await _markDirty(pubkey);
      Log.error(
        'kind:10002 relay-list publish failed: $e',
        name: 'RelayListRepository',
        category: LogCategory.relay,
        error: e,
        stackTrace: stackTrace,
      );
      return RelayListPublishResult.failed(e, stackTrace);
    }
  }

  Future<RelayListPublishResult> retryDirtyPublish() async {
    final pubkey = _nostrClient.publicKey;
    if (!_nostrClient.hasKeys || pubkey.isEmpty) {
      return const RelayListPublishResult.skippedNoKeys();
    }
    // Nothing pending is a no-op, not a failed sync — reporting it as
    // localOnly would make the retry bridge warn about a publish it never
    // attempted.
    if (!isDirty(pubkey)) return const RelayListPublishResult.skippedNotDirty();
    return publishConfiguredRelayList();
  }

  bool isDirty(String pubkey) =>
      _sharedPreferences.getBool(_dirtyKey(pubkey)) ?? false;

  Future<RelayListPublishResult> _publishForPubkey(String pubkey) async {
    final unsigned = Event(
      pubkey,
      EventKind.relayListMetadata,
      _buildRelayTags(_nostrClient.configuredRelays),
      '',
    );

    final Event? signed;
    try {
      signed = await _nostrClient.signer
          .signEvent(unsigned)
          .timeout(_relayListSignTimeout);
    } on TimeoutException catch (e, stackTrace) {
      Log.warning(
        'kind:10002 relay-list publish signer timed out after '
        '${_relayListSignTimeout.inSeconds}s: $e',
        name: 'RelayListRepository',
        category: LogCategory.relay,
      );
      return RelayListPublishResult.failed(e, stackTrace);
    }

    if (signed == null || signed.sig.isEmpty) {
      return RelayListPublishResult.failed(
        StateError('Signer returned an unsigned kind:10002 event'),
        StackTrace.current,
      );
    }

    final targetRelays = _publishTargets();
    final outcome = await _nostrClient.publishEventAwaitOk(
      signed,
      targetRelays: targetRelays,
      diagnosticTag: 'relay-list-kind-10002',
    );
    final acceptedByIndexer = outcome.acceptedBy.any(
      _environment.indexerRelays.contains,
    );
    if (!acceptedByIndexer) {
      return RelayListPublishResult.failed(
        StateError('kind:10002 accepted by no indexer: ${outcome.summary}'),
        StackTrace.current,
      );
    }

    final npub = Nip19.encodePubKey(pubkey);
    await _relayDiscoveryService.clearCache(npub);
    Log.info(
      'Published kind:10002 relay list for $pubkey to an indexer',
      name: 'RelayListRepository',
      category: LogCategory.relay,
    );
    return const RelayListPublishResult.published();
  }

  List<List<String>> _buildRelayTags(List<String> configuredRelays) {
    final discovered = _discoveredRelays();
    return configuredRelays
        .map((relayUrl) {
          final marker = _markerFor(relayUrl, discovered);
          if (marker == null) return <String>['r', relayUrl];
          return <String>['r', relayUrl, marker];
        })
        .toList(growable: false);
  }

  String? _markerFor(String relayUrl, List<DiscoveredRelay> discovered) {
    for (final relay in discovered) {
      if (!relayUrlsEquivalent(relay.url, relayUrl)) continue;
      if (relay.read && !relay.write) return 'read';
      if (!relay.read && relay.write) return 'write';
      return null;
    }
    return null;
  }

  List<String> _publishTargets() {
    final targets = <String>{}
      ..addAll(_nostrClient.configuredRelays)
      ..addAll(_environment.indexerRelays);
    return targets.toList(growable: false);
  }

  Future<void> _markDirty(String pubkey) =>
      _sharedPreferences.setBool(_dirtyKey(pubkey), true);

  Future<void> _clearDirty(String pubkey) =>
      _sharedPreferences.remove(_dirtyKey(pubkey));

  String _dirtyKey(String pubkey) => '$_dirtyRelayListPublishPrefix$pubkey';
}
