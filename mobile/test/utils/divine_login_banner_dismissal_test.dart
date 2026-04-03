import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/divine_login_banner_dismissal.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const pubkey = 'test_pubkey_hex';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('dismissal remains active within 30 days', () async {
    final prefs = await SharedPreferences.getInstance();

    await dismissDivineLoginBanner(
      prefs,
      pubkey,
      now: DateTime(2026, 3, 22),
    );

    expect(
      isDivineLoginBannerDismissed(
        prefs,
        pubkey,
        now: DateTime(2026, 4, 20),
      ),
      isTrue,
    );
  });

  test('dismissal expires after 30 days', () async {
    final prefs = await SharedPreferences.getInstance();

    await dismissDivineLoginBanner(
      prefs,
      pubkey,
      now: DateTime(2026, 3, 22),
    );

    expect(
      isDivineLoginBannerDismissed(
        prefs,
        pubkey,
        now: DateTime(2026, 4, 22),
      ),
      isFalse,
    );
  });

  test('returns false when no dismissal stored', () async {
    final prefs = await SharedPreferences.getInstance();

    expect(isDivineLoginBannerDismissed(prefs, pubkey), isFalse);
  });

  test('clearDivineLoginBannerDismissal removes the key', () async {
    final prefs = await SharedPreferences.getInstance();

    await dismissDivineLoginBanner(prefs, pubkey);
    expect(isDivineLoginBannerDismissed(prefs, pubkey), isTrue);

    await clearDivineLoginBannerDismissal(prefs, pubkey);
    expect(isDivineLoginBannerDismissed(prefs, pubkey), isFalse);
  });

  test('dismissalKey includes user pubkey', () {
    expect(
      divineLoginBannerDismissalKey(pubkey),
      equals('dismissed_divine_login_banner_$pubkey'),
    );
  });
}
