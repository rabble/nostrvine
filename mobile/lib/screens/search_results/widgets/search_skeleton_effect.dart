import 'package:divine_ui/divine_ui.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Shared shimmer effect used by all search result skeleton loaders.
///
/// Matches the animation config from [CommentsSkeletonLoader]:
/// dark-green base with 60% alpha highlight, 1500ms sweep.
const searchSkeletonEffect = ShimmerEffect(
  baseColor: VineTheme.iconButtonBackground,
  highlightColor: Color(0x99032017),
  duration: Duration(milliseconds: 1500),
);

/// Surface color for skeleton placeholder shapes.
const Color searchSkeletonSurface = VineTheme.outlinedDisabled;
