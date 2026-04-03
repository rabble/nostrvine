import 'package:shared_preferences/shared_preferences.dart';

const Duration divineLoginBannerDismissalTtl = Duration(days: 30);
const _dismissedDivineLoginBannerPrefix = 'dismissed_divine_login_banner_';

String divineLoginBannerDismissalKey(String userIdHex) =>
    '$_dismissedDivineLoginBannerPrefix$userIdHex';

bool isDivineLoginBannerDismissed(
  SharedPreferences prefs,
  String userIdHex, {
  DateTime? now,
}) {
  final rawValue = prefs.get(divineLoginBannerDismissalKey(userIdHex));
  if (rawValue is! int) {
    return false;
  }

  final dismissedAt = DateTime.fromMillisecondsSinceEpoch(rawValue);
  final comparisonTime = now ?? DateTime.now();
  return comparisonTime.difference(dismissedAt) < divineLoginBannerDismissalTtl;
}

Future<void> dismissDivineLoginBanner(
  SharedPreferences prefs,
  String userIdHex, {
  DateTime? now,
}) {
  final dismissedAt = now ?? DateTime.now();
  return prefs.setInt(
    divineLoginBannerDismissalKey(userIdHex),
    dismissedAt.millisecondsSinceEpoch,
  );
}

Future<void> clearDivineLoginBannerDismissal(
  SharedPreferences prefs,
  String userIdHex,
) {
  return prefs.remove(divineLoginBannerDismissalKey(userIdHex));
}
