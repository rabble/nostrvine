// ABOUTME: Pins the BookmarkSigner contract the app layer must satisfy.
// ABOUTME: createdAt is load-bearing: kind 10003 is replaceable (#7635).

import 'package:bookmarks_repository/bookmarks_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

class _RecordingSigner implements BookmarkSigner {
  int? capturedCreatedAt;
  List<List<String>>? capturedTags;
  String? capturedContent;
  int? capturedKind;

  @override
  bool get isAuthenticated => true;

  @override
  String? get currentPublicKeyHex => 'a' * 64;

  @override
  NostrSigner? get currentIdentity => null;

  @override
  Future<Event?> createAndSignEvent({
    required int kind,
    required String content,
    List<List<String>>? tags,
    int? createdAt,
  }) async {
    capturedKind = kind;
    capturedContent = content;
    capturedTags = tags;
    capturedCreatedAt = createdAt;
    return null;
  }
}

void main() {
  group(BookmarkSigner, () {
    late _RecordingSigner signer;

    setUp(() {
      signer = _RecordingSigner();
    });

    test('carries createdAt through to the implementation', () async {
      await signer.createAndSignEvent(
        kind: 10003,
        content: '',
        tags: const [
          ['e', 'abc'],
        ],
        createdAt: 1234567890,
      );

      // Kind 10003 is replaceable: a publish has to supersede the revision it
      // replaces, so an implementation that ignored createdAt would let two
      // publishes inside one second sign a tie (#7629, #7635).
      expect(signer.capturedCreatedAt, equals(1234567890));
    });

    test('carries kind, content and tags through unchanged', () async {
      await signer.createAndSignEvent(
        kind: 10003,
        content: 'ciphertext',
        tags: const [
          ['e', 'abc', 'wss://relay.example'],
        ],
      );

      expect(signer.capturedKind, equals(10003));
      expect(signer.capturedContent, equals('ciphertext'));
      expect(
        signer.capturedTags,
        equals(const [
          ['e', 'abc', 'wss://relay.example'],
        ]),
      );
      expect(signer.capturedCreatedAt, isNull);
    });

    test('exposes the identity used for private-item crypto', () {
      // currentIdentity is typed NostrSigner rather than the app's sealed
      // NostrIdentity, which is what lets this contract live in a package.
      expect(signer.currentIdentity, isNull);
      expect(signer.isAuthenticated, isTrue);
      expect(signer.currentPublicKeyHex, hasLength(64));
    });
  });
}
