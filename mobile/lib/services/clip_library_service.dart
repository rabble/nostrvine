// ABOUTME: Service for persisting video clips to the clip library
// ABOUTME: Handles save, load, delete operations with JSON serialization

import 'dart:convert';

import 'package:openvine/models/saved_clip.dart';
import 'package:openvine/services/file_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ClipLibraryService {
  ClipLibraryService(this._prefs);

  final SharedPreferences _prefs;
  static const String _storageKey = 'clip_library';

  /// Save a clip to the library. Updates existing clip if ID matches.
  Future<void> saveClip(SavedClip clip) async {
    final clips = await getAllClips();

    final existingIndex = clips.indexWhere((c) => c.id == clip.id);

    if (existingIndex != -1) {
      clips[existingIndex] = clip;
    } else {
      clips.add(clip);
    }

    await _saveClips(clips);
  }

  /// Get all clips from the library, sorted by creation date (newest first)
  Future<List<SavedClip>> getAllClips() async {
    try {
      final String? jsonString = _prefs.getString(_storageKey);

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
      final clips = jsonList
          .map((json) => SavedClip.fromJson(json as Map<String, dynamic>))
          .toList();

      // Sort by creation date, newest first
      clips.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return clips;
    } catch (e) {
      // If storage is corrupted, return empty list
      return [];
    }
  }

  /// Get a single clip by ID
  Future<SavedClip?> getClipById(String id) async {
    final clips = await getAllClips();
    try {
      return clips.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Delete a clip by ID and remove associated files if not referenced
  Future<void> deleteClip(String id) async {
    final clips = await getAllClips();
    final clipIndex = clips.indexWhere((clip) => clip.id == id);

    if (clipIndex != -1) {
      final clip = clips[clipIndex];
      clips.removeAt(clipIndex);

      // Save first, then delete files (so reference check sees updated state)
      await _saveClips(clips);

      // Delete files only if not referenced by drafts
      await FileCleanupService.deleteSavedClipFiles(clip);
      return;
    }

    await _saveClips(clips);
  }

  /// Clear all clips from the library and delete associated files
  Future<void> clearAllClips() async {
    final clips = await getAllClips();

    // Clear storage first, then delete files (so reference check sees updated state)
    await _prefs.remove(_storageKey);

    // Delete files only if not referenced by drafts
    await FileCleanupService.deleteSavedClipsFiles(clips);
  }

  /// Internal helper to save clips list to storage
  Future<void> _saveClips(List<SavedClip> clips) async {
    final jsonList = clips.map((clip) => clip.toJson()).toList();
    final jsonString = json.encode(jsonList);
    await _prefs.setString(_storageKey, jsonString);
  }

  /// Get all clips grouped by session ID
  /// Returns Map<sessionId, List<SavedClip>>
  /// Clips without sessionId are grouped under 'ungrouped'
  Future<Map<String, List<SavedClip>>> getClipsGroupedBySession() async {
    final clips = await getAllClips();
    final grouped = <String, List<SavedClip>>{};

    for (final clip in clips) {
      final key = clip.sessionId ?? 'ungrouped';
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(clip);
    }

    return grouped;
  }

  /// Get clips for a specific session
  /// Use 'ungrouped' to retrieve clips with null sessionId
  Future<List<SavedClip>> getClipsBySession(String sessionId) async {
    final clips = await getAllClips();
    if (sessionId == 'ungrouped') {
      return clips.where((c) => c.sessionId == null).toList();
    }
    return clips.where((c) => c.sessionId == sessionId).toList();
  }

  /// Generate a unique session ID for grouping clips
  static String generateSessionId() {
    return 'session_${DateTime.now().millisecondsSinceEpoch}';
  }
}
