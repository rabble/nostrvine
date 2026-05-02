part of 'loudness_normalization_cubit.dart';

/// State for [LoudnessNormalizationCubit].
///
/// Single boolean — when `true`, the player pool applies a `dynaudnorm`
/// audio filter to every active and future player. Persisted via
/// [SharedPreferences].
class LoudnessNormalizationState extends Equatable {
  const LoudnessNormalizationState({this.isEnabled = false});

  /// Whether loudness normalization is currently active.
  final bool isEnabled;

  @override
  List<Object?> get props => [isEnabled];
}
