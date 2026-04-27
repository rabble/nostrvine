// ABOUTME: Local hashtag lists — profile “saved” vs Following feed
// ABOUTME: Normalizes with hashtag_repository (divine-web parity)

import 'dart:async';

import 'package:hashtag_repository/hashtag_repository.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists two lists (alignment plan §5):
/// **Profile** — Saved tab, Explore “tracked” highlight.
/// **Following feed** — labels merged in Following home
/// via VideosRepository.
///
/// [separateFollowingFeedHashtagsEnabled]: when `false`, the feed list is kept
/// identical to the profile list (gated “Add to feed” / single combined UX).
class FollowedHashtagsRepository {
  /// Creates a repository for managing followed hashtags.
  ///
  /// The repository persists two separate lists:
  /// - Profile‑saved hashtags (Saved tab, Explore badges)
  /// - Following‑feed hashtags (merged into the Following home feed)
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
  FollowedHashtagsRepository({
    required SharedPreferences prefs,
    String? profileStorageKey,
    String? followingFeedStorageKey,
  }) : _prefs = prefs,
       _profileKey = profileStorageKey ?? preferencesKey,
       _feedKey = followingFeedStorageKey ?? followingFeedPreferencesKey,
       _profile = BehaviorSubject<List<String>>.seeded(
         const [],
         sync: true,
       ),
       _feed = BehaviorSubject<List<String>>.seeded(
         const [],
         sync: true,
       ) {
    unawaited(_bootstrapLists());
  }

  /// [SharedPreferences] key for profile-saved (Saved tab / Explore badges).
  static const preferencesKey = 'followed_hashtag_labels';

  /// [SharedPreferences] key for the Following feed merge.
  static const followingFeedPreferencesKey = 'following_feed_hashtag_labels';

  /// When `false`, feed and profile lists are kept in sync (no separate
  /// “Add to Following” product surface).
  static const bool separateFollowingFeedHashtagsEnabled = true;

  final SharedPreferences _prefs;
  final String _profileKey;
  final String _feedKey;
  final BehaviorSubject<List<String>> _profile;
  final BehaviorSubject<List<String>> _feed;

  Future<void> _bootstrapLists() async {
    await _migrateFeedFromProfileIfNeeded();
    final profile = _readNonEmptyList(_profileKey);
    if (!separateFollowingFeedHashtagsEnabled) {
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
    if (!separateFollowingFeedHashtagsEnabled) {
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
    if (!separateFollowingFeedHashtagsEnabled) {
      await _setFeedToMatchProfile(next, persist: true);
    }
  }

  // --- Following feed (home) ---

  /// Stream of hashtag labels that are merged into the Following home feed.
  ///
  /// Emits a new list whenever the feed list changes.
  Stream<List<String>> get followingFeedHashtagLabelsStream => _feed.stream;

  /// Current snapshot of hashtag labels that are merged into
  /// the Following feed.
  ///
  /// Returns an unmodifiable copy of the internal list.
  List<String> get followingFeedHashtagLabels =>
      List<String>.unmodifiable(_feed.value);

  /// Checks whether a hashtag is present in the Following‑feed list.
  ///
  /// The label is normalized before checking (leading `#` is stripped,
  /// case‑insensitive comparison).
  bool hasFollowingFeedHashtag(String rawLabel) {
    final tag = normalizeHashtagLabel(rawLabel);
    if (tag.isEmpty) return false;
    return _feed.value.contains(tag);
  }

  /// Adds a hashtag to the Following‑feed list.
  ///
  /// The label is normalized before addition. If the tag is already present,
  /// the operation is a no‑op.
  ///
  /// When [separateFollowingFeedHashtagsEnabled] is `false`, this method
  /// delegates to [addProfileSavedHashtag] (the feed list is kept in sync
  /// with the profile list).
  Future<void> addFollowingFeedHashtag(String rawLabel) async {
    if (!separateFollowingFeedHashtagsEnabled) {
      return addProfileSavedHashtag(rawLabel);
    }
    final tag = normalizeHashtagLabel(rawLabel);
    if (tag.isEmpty) return;
    if (_feed.value.contains(tag)) return;
    final next = List<String>.from(_feed.value)..add(tag);
    await _prefs.setStringList(_feedKey, next);
    _subjectFeed(next);
  }

  /// Removes a hashtag from the Following‑feed list.
  ///
  /// The label is normalized before removal. If the tag is not present,
  /// the operation is a no‑op.
  ///
  /// When [separateFollowingFeedHashtagsEnabled] is `false`, this method
  /// delegates to [removeProfileSavedHashtag] (the feed list is kept in sync
  /// with the profile list).
  Future<void> removeFollowingFeedHashtag(String rawLabel) async {
    if (!separateFollowingFeedHashtagsEnabled) {
      return removeProfileSavedHashtag(rawLabel);
    }
    final tag = normalizeHashtagLabel(rawLabel);
    if (tag.isEmpty) return;
    if (!_feed.value.contains(tag)) return;
    final next = List<String>.from(_feed.value)..remove(tag);
    await _prefs.setStringList(_feedKey, next);
    _subjectFeed(next);
  }

  // --- Backward compatible with single-list API (Profile only) ---

  /// Legacy stream of followed hashtags (profile‑saved list).
  ///
  /// This stream is identical to [profileSavedHashtagsStream] and exists for
  /// backward compatibility with older code that expects a single “followed”
  /// list.
  Stream<List<String>> get followedHashtagsStream => profileSavedHashtagsStream;

  /// Legacy snapshot of followed hashtags (profile‑saved list).
  ///
  /// This getter is identical to [profileSavedHashtags] and exists for
  /// backward compatibility.
  List<String> get followedHashtags => profileSavedHashtags;

  /// Legacy check for a followed hashtag (profile‑saved list).
  ///
  /// This method is identical to [hasProfileSavedHashtag] and exists for
  /// backward compatibility.
  bool hasFollowedHashtag(String rawLabel) => hasProfileSavedHashtag(rawLabel);

  /// Legacy addition of a followed hashtag (profile‑saved list).
  ///
  /// This method delegates to [addProfileSavedHashtag] and exists for
  /// backward compatibility.
  Future<void> addFollowedHashtag(String rawLabel) async {
    await addProfileSavedHashtag(rawLabel);
  }

  /// Legacy removal of a followed hashtag (profile‑saved list).
  ///
  /// This method delegates to [removeProfileSavedHashtag] and exists for
  /// backward compatibility.
  Future<void> removeFollowedHashtag(String rawLabel) async {
    await removeProfileSavedHashtag(rawLabel);
  }

  /// Forces a reload of both lists from persistent storage.
  ///
  /// Useful when external changes to SharedPreferences are suspected
  /// (e.g., after a migration or a debug‑tool modification).
  Future<void> reloadFromPrefs() async {
    final profile = _readNonEmptyList(_profileKey);
    _subjectProfile(profile);
    if (separateFollowingFeedHashtagsEnabled) {
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
    _profile.add(List<String>.unmodifiable(list));
  }

  void _subjectFeed(List<String> list) {
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
