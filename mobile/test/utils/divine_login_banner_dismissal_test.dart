import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/divine_login_banner_dismissal.dart';
import 'package:openvine/utils/local_content_owner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const pubkey = 'test_pubkey_hex';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  Future<DivineLoginBannerDismissalStore> storeFor(String userIdHex) async {
    return DivineLoginBannerDismissalStore(
      prefs: await SharedPreferences.getInstance(),
      userIdHex: userIdHex,
    );
  }

  group(DivineLoginBannerDismissalStore, () {
    test('dismissal remains active within 30 days', () async {
      final store = await storeFor(pubkey);

      await store.dismiss(now: DateTime(2026, 3, 22));

      expect(store.isDismissed(now: DateTime(2026, 4, 20)), isTrue);
    });

    test('dismissal expires after 30 days', () async {
      final store = await storeFor(pubkey);

      await store.dismiss(now: DateTime(2026, 3, 22));

      expect(store.isDismissed(now: DateTime(2026, 4, 22)), isFalse);
    });

    test('returns false when no dismissal stored', () async {
      final store = await storeFor(pubkey);

      expect(store.isDismissed(), isFalse);
    });

    test('returns false when the stored value is not a timestamp', () async {
      SharedPreferences.setMockInitialValues({
        DivineLoginBannerDismissalStore.keyFor(pubkey): 'corrupted',
      });
      final store = await storeFor(pubkey);

      expect(store.isDismissed(), isFalse);
    });

    test('clear removes the key', () async {
      final store = await storeFor(pubkey);

      await store.dismiss();
      expect(store.isDismissed(), isTrue);

      await store.clear();
      expect(store.isDismissed(), isFalse);
    });

    test('key includes the user pubkey', () async {
      final store = await storeFor(pubkey);

      expect(store.key, equals('dismissed_divine_login_banner_$pubkey'));
      expect(store.key, equals(DivineLoginBannerDismissalStore.keyFor(pubkey)));
    });

    test("one account's dismissal does not hide another's banner", () async {
      final other = await storeFor('other_pubkey_hex');
      await (await storeFor(pubkey)).dismiss();

      expect(other.isDismissed(), isFalse);
    });
  });

  group('clearDismissedDivineLoginBannerForCurrentUser', () {
    test('clears the dismissal for an explicitly named account', () async {
      final store = await storeFor(pubkey);
      await store.dismiss();

      await clearDismissedDivineLoginBannerForCurrentUser(pubkey);

      expect(store.isDismissed(), isFalse);
    });

    test('falls back to the stored current-user pubkey', () async {
      SharedPreferences.setMockInitialValues({
        currentUserPubkeyHexPrefKey: pubkey,
      });
      final store = await storeFor(pubkey);
      await store.dismiss();

      await clearDismissedDivineLoginBannerForCurrentUser();

      expect(store.isDismissed(), isFalse);
    });

    test('explicit pubkey wins over the stored current-user pubkey', () async {
      SharedPreferences.setMockInitialValues({
        currentUserPubkeyHexPrefKey: 'signed_in_pubkey_hex',
      });
      final signedIn = await storeFor('signed_in_pubkey_hex');
      final target = await storeFor(pubkey);
      await signedIn.dismiss();
      await target.dismiss();

      await clearDismissedDivineLoginBannerForCurrentUser(pubkey);

      expect(target.isDismissed(), isFalse);
      expect(signedIn.isDismissed(), isTrue);
    });

    test('does nothing when no account is named or stored', () async {
      final store = await storeFor(pubkey);
      await store.dismiss();

      await clearDismissedDivineLoginBannerForCurrentUser();

      expect(store.isDismissed(), isTrue);
    });

    test('does nothing when the stored pubkey is empty', () async {
      SharedPreferences.setMockInitialValues({currentUserPubkeyHexPrefKey: ''});
      final store = await storeFor(pubkey);
      await store.dismiss();

      await clearDismissedDivineLoginBannerForCurrentUser();

      expect(store.isDismissed(), isTrue);
    });
  });
}
