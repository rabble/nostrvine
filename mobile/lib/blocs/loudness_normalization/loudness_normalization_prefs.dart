/// SharedPreferences key for the persisted loudness normalization toggle.
///
/// Shared between [LoudnessNormalizationCubit] and the cold-start apply
/// step in `main.dart` so both read and write the same key.
const String loudnessNormalizationPrefsKey = 'loudness_normalization_enabled';
