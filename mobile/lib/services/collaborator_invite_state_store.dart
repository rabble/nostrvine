// ABOUTME: Persists local collaborator invite response state for UX.
// ABOUTME: Stores non-authoritative state scoped by video, creator, user.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum CollaboratorInviteState {
  pending,
  accepting,
  accepted,
  ignored,
  failed,
}

class CollaboratorInviteStateStore {
  const CollaboratorInviteStateStore({
    required SharedPreferences prefs,
  }) : _prefs = prefs;

  static const storageKey = 'collaborator_invite_states_v1';

  final SharedPreferences _prefs;

  CollaboratorInviteState getState({
    required String videoAddress,
    required String creatorPubkey,
    required String collaboratorPubkey,
  }) {
    final states = _readStates();
    final value =
        states[_key(
          videoAddress: videoAddress,
          creatorPubkey: creatorPubkey,
          collaboratorPubkey: collaboratorPubkey,
        )];
    return CollaboratorInviteState.values.firstWhere(
      (state) => state.name == value,
      orElse: () => CollaboratorInviteState.pending,
    );
  }

  Future<void> setState({
    required String videoAddress,
    required String creatorPubkey,
    required String collaboratorPubkey,
    required CollaboratorInviteState state,
  }) async {
    final states = _readStates();
    states[_key(
          videoAddress: videoAddress,
          creatorPubkey: creatorPubkey,
          collaboratorPubkey: collaboratorPubkey,
        )] =
        state.name;
    await _prefs.setString(storageKey, jsonEncode(states));
  }

  Map<String, String> _readStates() {
    final raw = _prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return <String, String>{};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, String>{};
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    } on FormatException {
      return <String, String>{};
    }
  }

  String _key({
    required String videoAddress,
    required String creatorPubkey,
    required String collaboratorPubkey,
  }) {
    return '$videoAddress|$creatorPubkey|$collaboratorPubkey';
  }
}
