// ABOUTME: Profile-saved vs feed-selector hashtag lists (home)
// ABOUTME: Normalizes via hashtag_repository (divine-web parity)
// ABOUTME: Sync prefs warm-read in ctor (getters ok before async bootstrap)

import 'dart:async';

import 'package:hashtag_repository/hashtag_repository.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists two lists (alignment plan §5):
/// **Profile** — Saved tab, Explore “tracked” highlight.
/// **Feed selector** — labels shown as their own home feed rows (top-left
/// switcher), loaded as single-tag streams — not merged into the Following
/// people feed.
///
/// [separateFollowingFeedHashtagsEnabled]: when `false`, the feed list is kept
/// identical to the profile list (gated “Add to feed” / single combined UX).
class FollowedHashtagsRepository {
  /// Creates a repository for managing followed hashtags.
  ///
  /// The repository persists two separate lists:
  /// - Profile‑saved hashtags (Saved tab, Explore badges)
  /// - Feed‑selector hashtags (own rows in the home feed mode sheet)
  ///
  /// When [separateFollowingFeedHashtagsEnabled] is `false`, the feed list is
  /// kept identical to the profile list (single‑list UX).
  ///
  /// Parameters:
  /// - [prefs]: SharedPreferences instance for persistent storage.
  /// - [profileStorageKey]: Custom key for profile‑saved hashtags.
  ///   Defaults to [preferencesKey] if not provided.
  /// - [followingFeedStorageKey]: Custom key for following‑feed hashtags.
  ///   Defaults to [followingFeedPreferencesKey] if not provided.
  /// - [separateFollowingFeedHashtagsEnabled]: when `false`, feed list tracks
  ///   profile list. Defaults to
  ///   [kDefaultSeparateFollowingFeedHashtagsEnabled].
  FollowedHashtagsRepository({
    required SharedPreferences prefs,
    String? profileStorageKey,
    String? followingFeedStorageKey,
    bool separateFollowingFeedHashtagsEnabled =
        kDefaultSeparateFollowingFeedHashtagsEnabled,
  }) : _prefs = prefs,
       _profileKey = profileStorageKey ?? preferencesKey,
       _feedKey = followingFeedStorageKey ?? followingFeedPreferencesKey,
       _separateFollowingFeedHashtagsEnabled =
           separateFollowingFeedHashtagsEnabled,
       _profile = BehaviorSubject<List<String>>.seeded(
         const [],
         sync: true,
       ),
       _feed = BehaviorSubject<List<String>>.seeded(
         const [],
         sync: true,
       ) {
    _syncLoadFromPrefs();
    unawaited(_bootstrapLists());
  }

  /// [SharedPreferences] key for profile-saved (Saved tab / Explore badges).
  static const preferencesKey = 'followed_hashtag_labels';

  /// [SharedPreferences] key for feed-selector hashtag labels (home sheet).
  static const followingFeedPreferencesKey = 'following_feed_hashtag_labels';

  /// App default when [separateFollowingFeedHashtagsEnabled] is omitted at
  /// construction. UI must read [separateFollowingFeedHashtagsEnabled] on the
  /// repository instance — not this constant alone — so DI/tests match
  /// persistence behaviour.
  static const bool kDefaultSeparateFollowingFeedHashtagsEnabled = true;

  /// Whether feed-selector hashtags are stored separately from profile saves.
  bool get separateFollowingFeedHashtagsEnabled =>
      _separateFollowingFeedHashtagsEnabled;

  final SharedPreferences _prefs;
  final String _profileKey;
  final String _feedKey;
  final bool _separateFollowingFeedHashtagsEnabled;
  final BehaviorSubject<List<String>> _profile;
  final BehaviorSubject<List<String>> _feed;
  bool _closed = false;

  /// Reads prefs synchronously and seeds both subjects.
  ///
  /// When [separateFollowingFeedHashtagsEnabled] is `true` and the feed prefs
  /// key is absent, mirrors the profile list in memory immediately — the same
  /// data [_migrateFeedFromProfileIfNeeded] will persist asynchronously. That
  /// avoids a cold-start window where [followingFeedHashtagLabels] was `[]`
  /// while consumers validated persisted `FeedMode.homeHashtag` against an
  /// empty sheet and cleared the saved mode.
  void _syncLoadFromPrefs() {
    final profile = _readNonEmptyList(_profileKey);
    final List<String> initialFeed;
    if (!_separateFollowingFeedHashtagsEnabled) {
      initialFeed = List<String>.from(profile);
    } else if (_prefs.containsKey(_feedKey)) {
      initialFeed = _readNonEmptyList(_feedKey);
    } else {
      initialFeed = List<String>.from(profile);
    }
    _subjectProfile(profile);
    _subjectFeed(initialFeed);
  }

  Future<void> _bootstrapLists() async {
    await _migrateFeedFromProfileIfNeeded();
    final profile = _readNonEmptyList(_profileKey);
    if (!_separateFollowingFeedHashtagsEnabled) {
      _subjectProfile(profile);
      await _setFeedToMatchProfile(profile, persist: true);
    } else {
      _subjectProfile(profile);
      _subjectFeed(_readNonEmptyList(_feedKey));
    }
  }

  // --- Profile ---

  /// Stream of profile‑saved hashtag labels (Saved tab, Explore badges).
  ///
  /// Emits a new list whenever the profile‑saved list changes.
  Stream<List<String>> get profileSavedHashtagsStream => _profile.stream;

  /// Current snapshot of profile‑saved hashtag labels.
  ///
  /// Returns an unmodifiable copy of the internal list.
  List<String> get profileSavedHashtags =>
      List<String>.unmodifiable(_profile.value);

  /// Checks whether a hashtag is present in the profile‑saved list.
  ///
  /// The label is normalized before checking (leading `#` is stripped,
  /// case‑insensitive comparison).
  bool hasProfileSavedHashtag(String rawLabel) {
    final tag = normalizeHashtagLabel(rawLabel);
    if (tag.isEmpty) return false;
    return _profile.value.contains(tag);
  }

  /// Adds a hashtag to the profile‑saved list.
  ///
  /// The label is normalized before addition. If the tag is already present,
  /// the operation is a no‑op.
  ///
  /// When [separateFollowingFeedHashtagsEnabled] is `false`, the feed list is
  /// automatically updated to match the new profile list.
  Future<void> addProfileSavedHashtag(String rawLabel) async {
    final tag = normalizeHashtagLabel(rawLabel);
    if (tag.isEmpty) return;
    if (_profile.value.contains(tag)) return;
    final next = List<String>.from(_profile.value)..add(tag);
    await _prefs.setStringList(_profileKey, next);
    _subjectProfile(next);
    if (!_separateFollowingFeedHashtagsEnabled) {
      await _setFeedToMatchProfile(next, persist: true);
    }
  }

  /// Removes a hashtag from the profile‑saved list.
  ///
  /// The label is normalized before removal. If the tag is not present,
  /// the operation is a no‑op.
  ///
  /// When [separateFollowingFeedHashtagsEnabled] is `false`, the feed list is
  /// automatically updated to match the new profile list.
  Future<void> removeProfileSavedHashtag(String rawLabel) async {
    final tag = normalizeHashtagLabel(rawLabel);
    if (tag.isEmpty) return;
    if (!_profile.value.contains(tag)) return;
    final next = List<String>.from(_profile.value)..remove(tag);
    await _prefs.setStringList(_profileKey, next);
    _subjectProfile(next);
    if (!_separateFollowingFeedHashtagsEnabled) {
      await _setFeedToMatchProfile(next, persist: true);
    }
  }

  // --- Feed selector list (home) ---

  /// Stream of hashtag labels offered as separate home feeds (feed mode sheet).
  ///
  /// Emits a new list whenever the feed list changes.
  Stream<List<String>> get followingFeedHashtagLabelsStream => _feed.stream;

  /// Current snapshot of hashtag labels for feed-selector home rows.
  ///
  /// Returns an unmodifiable copy of the internal list.
  List<String> get followingFeedHashtagLabels =>
      List<String>.unmodifiable(_feed.value);

  /// Checks whether a hashtag is present in the feed-selector list.
  ///
  /// The label is normalized before checking (leading `#` is stripped,
  /// case‑insensitive comparison).
  bool hasFollowingFeedHashtag(String rawLabel) {
    final tag = normalizeHashtagLabel(rawLabel);
    if (tag.isEmpty) return false;
    return _feed.value.contains(tag);
  }

  /// Adds a hashtag to the feed-selector list.
  ///
  /// The label is normalized before addition. If the tag is already present,
  /// the operation is a no‑op.
  ///
  /// When [separateFollowingFeedHashtagsEnabled] is `false`, this method
  /// delegates to [addProfileSavedHashtag] (the feed list is kept in sync
  /// with the profile list).
  Future<void> addFollowingFeedHashtag(String rawLabel) async {
    if (!_separateFollowingFeedHashtagsEnabled) {
      return addProfileSavedHashtag(rawLabel);
    }
    final tag = normalizeHashtagLabel(rawLabel);
    if (tag.isEmpty) return;
    if (_feed.value.contains(tag)) return;
    final next = List<String>.from(_feed.value)..add(tag);
    await _prefs.setStringList(_feedKey, next);
    _subjectFeed(next);
  }

  /// Removes a hashtag from the feed-selector list.
  ///
  /// The label is normalized before removal. If the tag is not present,
  /// the operation is a no‑op.
  ///
  /// When [separateFollowingFeedHashtagsEnabled] is `false`, this method
  /// delegates to [removeProfileSavedHashtag] (the feed list is kept in sync
  /// with the profile list).
  Future<void> removeFollowingFeedHashtag(String rawLabel) async {
    if (!_separateFollowingFeedHashtagsEnabled) {
      return removeProfileSavedHashtag(rawLabel);
    }
    final tag = normalizeHashtagLabel(rawLabel);
    if (tag.isEmpty) return;
    if (!_feed.value.contains(tag)) return;
    final next = List<String>.from(_feed.value)..remove(tag);
    await _prefs.setStringList(_feedKey, next);
    _subjectFeed(next);
  }

  /// Forces a reload of both lists from persistent storage.
  ///
  /// Useful when external changes to SharedPreferences are suspected
  /// (e.g., after a migration or a debug‑tool modification).
  Future<void> reloadFromPrefs() async {
    final profile = _readNonEmptyList(_profileKey);
    _subjectProfile(profile);
    if (_separateFollowingFeedHashtagsEnabled) {
      _subjectFeed(_readNonEmptyList(_feedKey));
    } else {
      await _setFeedToMatchProfile(profile, persist: true);
    }
  }

  /// Closes the internal streams and releases resources.
  ///
  /// Call this method when the repository is no longer needed (e.g., during
  /// app shutdown or when swapping dependencies).
  Future<void> dispose() async {
    _closed = true;
    await _profile.close();
    await _feed.close();
  }

  // --- Internals ---

  List<String> _readNonEmptyList(String key) {
    final raw = _prefs.getStringList(key);
    if (raw == null) return const [];
    return List<String>.from(raw).where((e) => e.isNotEmpty).toList();
  }

  void _subjectProfile(List<String> list) {
    if (_closed) return;
    _profile.add(List<String>.unmodifiable(list));
  }

  void _subjectFeed(List<String> list) {
    if (_closed) return;
    _feed.add(List<String>.unmodifiable(list));
  }

  Future<void> _migrateFeedFromProfileIfNeeded() async {
    if (_prefs.containsKey(_feedKey)) return;
    final p = _prefs.getStringList(_profileKey);
    if (p == null || p.isEmpty) return;
    final copy = p.where((e) => e.isNotEmpty).toList();
    if (copy.isNotEmpty) {
      await _prefs.setStringList(_feedKey, copy);
    }
  }

  Future<void> _setFeedToMatchProfile(
    List<String> profile, {
    required bool persist,
  }) async {
    if (persist) {
      await _prefs.setStringList(_feedKey, List<String>.from(profile));
    }
    _subjectFeed(profile);
  }
}
