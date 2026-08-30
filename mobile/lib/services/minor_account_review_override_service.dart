// ABOUTME: Developer-only local override service for simulating parental
// ABOUTME: consent / minor-account review states without backend wiring.

import 'dart:convert';

import 'package:openvine/models/minor_account_review_status.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MinorAccountReviewOverrideService {
  MinorAccountReviewOverrideService({required SharedPreferences prefs})
    : _prefs = prefs;

  static const _prefsKey = 'minor_account_review_override';

  final SharedPreferences _prefs;

  MinorAccountReviewStatus? getOverride() {
    final raw = _prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return MinorAccountReviewStatus.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> setOverride(MinorAccountReviewStatus status) async {
    await _prefs.setString(_prefsKey, jsonEncode(status.toJson()));
  }

  Future<void> clearOverride() async {
    await _prefs.remove(_prefsKey);
  }
}
