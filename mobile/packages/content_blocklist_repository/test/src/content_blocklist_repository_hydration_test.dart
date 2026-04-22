import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Invariant: ContentBlocklistRepository.currentState must already reflect
// persisted data immediately after construction — no async init step.
// Tests here pin that guarantee so a future refactor cannot accidentally
// break synchronous hydration.
void main() {
  group('ContentBlocklistRepository synchronous hydration invariant', () {
    test(
      'currentState reflects persisted blocks synchronously at construction',
      () async {
        SharedPreferences.setMockInitialValues({
          'blocked_users_list': '["persisted-hex-pubkey"]',
        });
        final prefs = await SharedPreferences.getInstance();
        final repo = ContentBlocklistRepository(prefs: prefs);

        // No await, no pump — currentState must be ready immediately.
        final state = repo.currentState;
        expect(
          state.blockedPubkeys,
          contains('persisted-hex-pubkey'),
          reason:
              'persisted block must appear in currentState without any async '
              'step after construction',
        );
      },
    );

    test('empty prefs yield empty state at construction', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = ContentBlocklistRepository(prefs: prefs);

      final state = repo.currentState;
      expect(
        state.blockedPubkeys,
        isEmpty,
        reason: 'no persisted blocks should produce an empty blocked set',
      );
      expect(state.mutedPubkeys, isEmpty);
      expect(state.pubkeysBlockingUs, isEmpty);
      expect(state.pubkeysMutingUs, isEmpty);
    });
  });
}
