// ABOUTME: Envelope for the plaintext inside an encrypted sync index event.
// ABOUTME: Carries either an item body or a deletion tombstone.

import 'dart:convert';

import 'package:meta/meta.dart';

/// The decrypted payload of one sync index event.
@immutable
class SyncIndexEntry {
  const SyncIndexEntry._({required this.deleted, this.body});

  /// Creates a live entry carrying [body].
  factory SyncIndexEntry.item({required Map<String, dynamic> body}) =>
      SyncIndexEntry._(deleted: false, body: body);

  /// Creates a deletion tombstone.
  factory SyncIndexEntry.tombstone() => const SyncIndexEntry._(deleted: true);

  /// Parses a payload produced by [toPayloadJson].
  ///
  /// Throws [FormatException] on malformed input, an unknown schema
  /// version, or a live entry missing its body.
  factory SyncIndexEntry.fromPayloadJson(String payload) {
    final Object? decoded;
    try {
      decoded = jsonDecode(payload);
    } on FormatException catch (e) {
      throw FormatException('sync payload is not valid JSON: ${e.message}');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('sync payload is not a JSON object');
    }

    final version = decoded['v'];
    if (version != schemaVersion) {
      throw FormatException(
        'unsupported sync payload version $version, expected $schemaVersion',
      );
    }

    if (decoded['deleted'] == true) return SyncIndexEntry.tombstone();

    final body = decoded['body'];
    if (body is! Map<String, dynamic>) {
      throw const FormatException('live sync payload has no body object');
    }
    return SyncIndexEntry.item(body: body);
  }

  /// Current payload schema version.
  static const int schemaVersion = 1;

  /// Whether this entry marks the item as deleted.
  final bool deleted;

  /// The item's serialized state, or null for a tombstone.
  final Map<String, dynamic>? body;

  /// Serializes this entry for encryption into an event's content.
  String toPayloadJson() => jsonEncode({
    'v': schemaVersion,
    'deleted': deleted,
    if (body != null) 'body': body,
  });
}
