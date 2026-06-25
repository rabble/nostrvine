part of 'codec_heavy_surface_cubit.dart';

/// State for [CodecHeavySurfaceCubit].
class CodecHeavySurfaceState extends Equatable {
  const CodecHeavySurfaceState({this.activeCount = 0});

  /// Number of codec-heavy surfaces currently on screen.
  ///
  /// Reference-counted so nested surfaces (e.g. an export screen pushed over
  /// the editor) keep [isActive] asserted until the last one leaves.
  final int activeCount;

  /// Whether at least one codec-heavy surface is open.
  bool get isActive => activeCount > 0;

  @override
  List<Object?> get props => [activeCount];
}
