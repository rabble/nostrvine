import 'package:divine_ui/divine_ui.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Default shimmer effect for skeleton loaders across the app.
///
/// Uses the dark-green base with 60 % alpha highlight and a 1 500 ms sweep
/// matching the design-system skeleton spec.
const vineSkeletonEffect = ShimmerEffect(
  baseColor: VineTheme.skeletonBase,
  highlightColor: VineTheme.skeletonHighlight,
  duration: VineTheme.skeletonDuration,
);
