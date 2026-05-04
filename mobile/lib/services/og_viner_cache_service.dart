// ABOUTME: Local positive-only cache of pubkeys known to be OG Viners.
// ABOUTME: Learns from archive-backed VideoEvent data without per-user lookups.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

const ogVinerPubkeysCacheKey = 'og_viner_pubkeys_v1';

class OgVinerCacheService extends ChangeNotifier {
  OgVinerCacheService({SharedPreferences? prefs}) : _prefs = prefs {
    _load();
  }

  final SharedPreferences? _prefs;
  final Set<String> _pubkeys = {};

  Set<String> get knownPubkeys => Set.unmodifiable(_pubkeys);

  bool isOgViner(String pubkey) {
    final normalized = _normalizePubkey(pubkey);
    return normalized != null && _pubkeys.contains(normalized);
  }

  /// Observe a batch of [videos] and learn the pubkeys of any that are
  /// archive Vine reposts. Non-archive videos are silently ignored, so this
  /// method is safe to call from any feed surface — only `isOriginalVine`
  /// videos contribute new pubkeys to the cache.
  ///
  /// Returns the number of newly-added pubkeys (0 if everything was already
  /// known or no archive videos were present).
  Future<int> learnFromVideos(Iterable<VideoEvent> videos) async {
    var added = 0;

    for (final video in videos) {
      if (!video.isOriginalVine) continue;

      final pubkey = _normalizePubkey(video.pubkey);
      if (pubkey == null) continue;

      if (_pubkeys.add(pubkey)) {
        added++;
      }
    }

    if (added == 0) return 0;

    await _save();
    notifyListeners();
    return added;
  }

  void _load() {
    final stored = _prefs?.getString(ogVinerPubkeysCacheKey);
    if (stored == null || stored.isEmpty) return;

    try {
      final decoded = jsonDecode(stored);
      if (decoded is! List) return;

      for (final value in decoded) {
        if (value is! String) continue;
        final pubkey = _normalizePubkey(value);
        if (pubkey != null) {
          _pubkeys.add(pubkey);
        }
      }
    } catch (_) {
      _pubkeys.clear();
    }
  }

  Future<void> _save() async {
    final prefs = _prefs;
    if (prefs == null) return;

    final sortedPubkeys = _pubkeys.toList()..sort();
    try {
      await prefs.setString(ogVinerPubkeysCacheKey, jsonEncode(sortedPubkeys));
    } catch (_) {
      // Keep in-memory discoveries even if local persistence fails.
    }
  }

  String? _normalizePubkey(String pubkey) {
    final normalized = pubkey.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    return normalized;
  }
}
