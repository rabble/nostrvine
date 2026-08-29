// ABOUTME: Pins that BookmarkSignerAdapter forwards every member unchanged.
// ABOUTME: A mis-wired member here silently publishes under the wrong key.

import 'package:bookmarks_repository/bookmarks_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/providers/bookmark_signer_adapter.dart';
import 'package:openvine/services/auth/nostr_identity.dart';
import 'package:openvine/services/auth_service.dart';

class _MockAuthService extends Mock implements AuthService {}

void main() {
  group(BookmarkSignerAdapter, () {
    late _MockAuthService authService;
    late BookmarkSignerAdapter adapter;

    setUp(() {
      authService = _MockAuthService();
      adapter = BookmarkSignerAdapter(authService);
    });

    test('is a BookmarkSigner the package can consume', () {
      expect(adapter, isA<BookmarkSigner>());
    });

    test('forwards isAuthenticated', () {
      when(() => authService.isAuthenticated).thenReturn(true);
      expect(adapter.isAuthenticated, isTrue);

      when(() => authService.isAuthenticated).thenReturn(false);
      expect(adapter.isAuthenticated, isFalse);
    });

    test('forwards the hex pubkey, not some other encoding', () {
      const hex =
          '9be8bd90d818407bcf574d11b1c57f104fd5'
          '000000000000000000000000000';
      when(() => authService.currentPublicKeyHex).thenReturn(hex);

      expect(adapter.currentPublicKeyHex, equals(hex));
    });

    test('forwards a null pubkey when signed out', () {
      when(() => authService.currentPublicKeyHex).thenReturn(null);
      expect(adapter.currentPublicKeyHex, isNull);
    });

    test('forwards the very same identity object, not a rebuilt one', () {
      // The private-item path encrypts to the user's own key with this exact
      // object, so handing back a different instance would be a real bug.
      final identity = LocalNostrIdentity(
        keyContainer: SecureKeyContainer.fromPrivateKeyHex(
          generatePrivateKey(),
        ),
      );
      when(() => authService.currentIdentity).thenReturn(identity);

      expect(adapter.currentIdentity, same(identity));
    });

    test('forwards a null identity when signed out', () {
      when(() => authService.currentIdentity).thenReturn(null);
      expect(adapter.currentIdentity, isNull);
    });

    test('forwards every createAndSignEvent argument, createdAt included', () {
      int? seenKind;
      String? seenContent;
      List<List<String>>? seenTags;
      int? seenCreatedAt;

      when(
        () => authService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
          createdAt: any(named: 'createdAt'),
        ),
      ).thenAnswer((invocation) async {
        seenKind = invocation.namedArguments[#kind] as int?;
        seenContent = invocation.namedArguments[#content] as String?;
        seenTags = invocation.namedArguments[#tags] as List<List<String>>?;
        seenCreatedAt = invocation.namedArguments[#createdAt] as int?;
        return null;
      });

      adapter.createAndSignEvent(
        kind: 10003,
        content: 'ciphertext',
        tags: const [
          ['e', 'abc'],
        ],
        createdAt: 1234567890,
      );

      expect(seenKind, equals(10003));
      expect(seenContent, equals('ciphertext'));
      expect(
        seenTags,
        equals(const [
          ['e', 'abc'],
        ]),
      );
      // Dropping this would let two publishes inside one second sign a tie
      // that NIP-01 can resolve against us (#7635).
      expect(seenCreatedAt, equals(1234567890));
    });

    test('returns the signed event the auth stack produced', () async {
      final signed = Event('a' * 64, 10003, const [], '');
      when(
        () => authService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
          createdAt: any(named: 'createdAt'),
        ),
      ).thenAnswer((_) async => signed);

      expect(
        await adapter.createAndSignEvent(kind: 10003, content: ''),
        same(signed),
      );
    });
  });
}
