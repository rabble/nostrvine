// ABOUTME: Permanent per-account dismissal state for the secure-account prompt.
// ABOUTME: Keeps "Maybe later" from resurfacing on profile rebuilds or launches.

import 'package:shared_preferences/shared_preferences.dart';

const _dismissedSecureAccountPromptPrefix = 'dismissed_secure_account_prompt_';

/// Whether one account permanently dismissed the secure-account profile prompt.
class SecureAccountPromptDismissalStore {
  const SecureAccountPromptDismissalStore({
    required SharedPreferences prefs,
    required String userIdHex,
  }) : _prefs = prefs,
       _userIdHex = userIdHex;

  final SharedPreferences _prefs;
  final String _userIdHex;

  static String keyFor(String userIdHex) =>
      '$_dismissedSecureAccountPromptPrefix$userIdHex';

  String get key => keyFor(_userIdHex);

  bool isDismissed() => _prefs.get(key) == true;

  Future<void> dismiss() => _prefs.setBool(key, true);
}
