import 'package:content_policy/content_policy.dart';
import 'package:test/test.dart';

void main() {
  group(ContentPolicyState, () {
    const me = 'me-pubkey';

    test('empty state has no filtered authors', () {
      final state = ContentPolicyState.empty();
      expect(state.currentUserPubkey, isNull);
      expect(state.isAuthorFiltered('anyone'), isFalse);
      expect(state.isBlockedBy('anyone'), isFalse);
    });

    test('mutedPubkeys filters author', () {
      const state = ContentPolicyState(
        currentUserPubkey: me,
        mutedPubkeys: {'muted'},
        blockedPubkeys: {},
        pubkeysBlockingUs: {},
        pubkeysMutingUs: {},
      );
      expect(state.isAuthorFiltered('muted'), isTrue);
      expect(state.isAuthorFiltered('other'), isFalse);
    });

    test('blockedPubkeys filters author', () {
      const state = ContentPolicyState(
        currentUserPubkey: me,
        mutedPubkeys: {},
        blockedPubkeys: {'blocked'},
        pubkeysBlockingUs: {},
        pubkeysMutingUs: {},
      );
      expect(state.isAuthorFiltered('blocked'), isTrue);
    });

    test('pubkeysBlockingUs filters author and reports blockedBy', () {
      const state = ContentPolicyState(
        currentUserPubkey: me,
        mutedPubkeys: {},
        blockedPubkeys: {},
        pubkeysBlockingUs: {'blocker'},
        pubkeysMutingUs: {},
      );
      expect(state.isAuthorFiltered('blocker'), isTrue);
      expect(state.isBlockedBy('blocker'), isTrue);
      expect(state.isBlockedBy('someone-else'), isFalse);
    });

    test('pubkeysMutingUs filters author and reports blockedBy', () {
      const state = ContentPolicyState(
        currentUserPubkey: me,
        mutedPubkeys: {},
        blockedPubkeys: {},
        pubkeysBlockingUs: {},
        pubkeysMutingUs: {'muter'},
      );
      expect(state.isAuthorFiltered('muter'), isTrue);
      expect(state.isBlockedBy('muter'), isTrue);
    });

    test(
      'isBlockedBy excludes authors that we muted/blocked but not vice versa',
      () {
        const state = ContentPolicyState(
          currentUserPubkey: me,
          mutedPubkeys: {'someone-we-muted'},
          blockedPubkeys: {'someone-we-blocked'},
          pubkeysBlockingUs: {},
          pubkeysMutingUs: {},
        );
        expect(state.isBlockedBy('someone-we-muted'), isFalse);
        expect(state.isBlockedBy('someone-we-blocked'), isFalse);
      },
    );
  });
}
