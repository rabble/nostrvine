// ABOUTME: Interface for Nostr services to ensure compatibility across platforms
// ABOUTME: Provides common contract for NostrService implementations

import 'dart:async';
import 'package:nostr/nostr.dart';
import 'package:flutter/foundation.dart';
import '../models/nip94_metadata.dart';
import 'nostr_key_manager.dart';

/// Result of broadcasting an event to relays
class NostrBroadcastResult {
  final Event event;
  final int successCount;
  final int totalRelays;
  final Map<String, bool> results;
  final Map<String, String> errors;
  
  const NostrBroadcastResult({
    required this.event,
    required this.successCount,
    required this.totalRelays,
    required this.results,
    required this.errors,
  });
  
  bool get isSuccessful => successCount > 0;
  bool get isCompleteSuccess => successCount == totalRelays;
  double get successRate => totalRelays > 0 ? successCount / totalRelays : 0.0;
  
  List<String> get successfulRelays => 
    results.entries.where((e) => e.value).map((e) => e.key).toList();
  
  List<String> get failedRelays =>
    results.entries.where((e) => !e.value).map((e) => e.key).toList();
  
  @override
  String toString() {
    return 'NostrBroadcastResult('
           'success: $successCount/$totalRelays, '
           'rate: ${(successRate * 100).toStringAsFixed(1)}%'
           ')';
  }
}

/// Common interface for Nostr service implementations
abstract class INostrService extends ChangeNotifier {
  // Getters
  bool get isInitialized;
  bool get isDisposed;
  List<String> get connectedRelays;
  String? get publicKey;
  bool get hasKeys;
  NostrKeyManager get keyManager;
  int get relayCount;
  int get connectedRelayCount;
  
  // Methods
  Future<void> initialize({List<String>? customRelays});
  Stream<Event> subscribeToEvents({required List<Filter> filters});
  Future<NostrBroadcastResult> broadcastEvent(Event event);
  Future<NostrBroadcastResult> publishFileMetadata({
    required NIP94Metadata metadata,
    required String content,
    List<String> hashtags = const [],
  });
  
  @override
  void dispose();
}