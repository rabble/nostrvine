import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/loudness_normalization/loudness_normalization_prefs.dart';
import 'package:pooled_video_player/pooled_video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'loudness_normalization_state.dart';

/// Persists and applies the user's loudness-normalization preference.
///
/// Default OFF: creator audio fidelity (whispers, ASMR, intentional dynamic
/// range) is preserved unless the user opts in via Settings. When on, the
/// pool applies a single-pass `dynaudnorm` libmpv filter to every active
/// player so quiet and loud vines play at comparable perceived loudness.
///
/// Must NOT be folded into [VideoVolumeCubit] — they are orthogonal:
/// volume controls device output level, normalization controls per-clip
/// gain matching. They have different lifecycles, different persistence
/// keys, and different consumers.
class LoudnessNormalizationCubit extends Cubit<LoudnessNormalizationState> {
  /// Creates a cubit, seeding state from [sharedPreferences] synchronously.
  ///
  /// The cubit does NOT call [PlayerPool.setLoudnessNormalizationEnabled] in
  /// its constructor. Cold-start application happens in `main.dart` so the
  /// pool is in the correct state before any video plays, regardless of
  /// whether anything in the widget tree consumes this cubit. See
  /// state_management.md "BlocProvider is lazy by default".
  LoudnessNormalizationCubit({
    required SharedPreferences sharedPreferences,
    required PlayerPool playerPool,
  }) : _prefs = sharedPreferences,
       _playerPool = playerPool,
       super(
         LoudnessNormalizationState(
           isEnabled:
               sharedPreferences.getBool(loudnessNormalizationPrefsKey) ??
               false,
         ),
       );

  final SharedPreferences _prefs;
  final PlayerPool _playerPool;

  /// Toggles loudness normalization, persisting the new value and applying
  /// it to the pool. No-op when [enabled] matches the current state.
  Future<void> setEnabled({required bool enabled}) async {
    if (state.isEnabled == enabled) return;
    emit(LoudnessNormalizationState(isEnabled: enabled));
    await _playerPool.setLoudnessNormalizationEnabled(enabled: enabled);
    await _prefs.setBool(loudnessNormalizationPrefsKey, enabled);
  }
}
