// ABOUTME: Persists pre-save staged profile avatar/banner media URLs.
// ABOUTME: Keeps Blossom upload URLs recoverable across editor recreation.

import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class StagedProfileMedia {
  const StagedProfileMedia({
    required this.stagedAt,
    this.pictureUrl,
    this.bannerUrl,
  });

  final String? pictureUrl;
  final String? bannerUrl;
  final DateTime stagedAt;

  bool get isEmpty =>
      (pictureUrl == null || pictureUrl!.isEmpty) &&
      (bannerUrl == null || bannerUrl!.isEmpty);
}

abstract interface class StagedProfileMediaStore {
  StagedProfileMedia? load(String pubkey);

  Future<void> save(String pubkey, {String? pictureUrl, String? bannerUrl});

  Future<void> clear(String pubkey);
}

class SharedPreferencesStagedProfileMediaStore
    implements StagedProfileMediaStore {
  SharedPreferencesStagedProfileMediaStore({
    required SharedPreferences preferences,
    DateTime Function()? now,
    Duration ttl = defaultTtl,
  }) : _preferences = preferences,
       _now = now ?? DateTime.now,
       _ttl = ttl;

  static const Duration defaultTtl = Duration(days: 7);
  static const int _schemaVersion = 1;
  static const String _keyPrefix = 'staged_profile_media_v1_';

  final SharedPreferences _preferences;
  final DateTime Function() _now;
  final Duration _ttl;

  @override
  StagedProfileMedia? load(String pubkey) {
    final raw = _preferences.getString(_keyFor(pubkey));
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) return _clearInvalid(pubkey);
      if (decoded['version'] != _schemaVersion) return _clearInvalid(pubkey);

      final stagedAtMillis = decoded['stagedAt'] as int?;
      if (stagedAtMillis == null) return _clearInvalid(pubkey);

      final stagedAt = DateTime.fromMillisecondsSinceEpoch(stagedAtMillis);
      if (_now().difference(stagedAt) > _ttl) return _clearInvalid(pubkey);

      final media = StagedProfileMedia(
        pictureUrl: _nonEmptyString(decoded['pictureUrl']),
        bannerUrl: _nonEmptyString(decoded['bannerUrl']),
        stagedAt: stagedAt,
      );
      if (media.isEmpty) return _clearInvalid(pubkey);
      return media;
    } on Object {
      return _clearInvalid(pubkey);
    }
  }

  @override
  Future<void> save(
    String pubkey, {
    String? pictureUrl,
    String? bannerUrl,
  }) async {
    try {
      final trimmedPicture = _nonEmptyString(pictureUrl);
      final trimmedBanner = _nonEmptyString(bannerUrl);
      if (trimmedPicture == null && trimmedBanner == null) {
        await clear(pubkey);
        return;
      }

      await _preferences.setString(
        _keyFor(pubkey),
        jsonEncode(<String, Object?>{
          'version': _schemaVersion,
          'pictureUrl': trimmedPicture,
          'bannerUrl': trimmedBanner,
          'stagedAt': _now().millisecondsSinceEpoch,
        }),
      );
    } on Object {
      return;
    }
  }

  @override
  Future<void> clear(String pubkey) async {
    try {
      await _preferences.remove(_keyFor(pubkey));
    } on Object {
      return;
    }
  }

  StagedProfileMedia? _clearInvalid(String pubkey) {
    unawaited(clear(pubkey));
    return null;
  }

  static String _keyFor(String pubkey) => '$_keyPrefix$pubkey';

  static String? _nonEmptyString(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
