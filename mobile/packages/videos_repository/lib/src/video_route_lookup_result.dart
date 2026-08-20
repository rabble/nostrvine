// ABOUTME: Outcome of resolving a /video/<route-id> deep link.
// ABOUTME: Separates "no source had it" from "a source had it, filters hid it".

import 'package:models/models.dart';

/// Result of a route-id video lookup.
///
/// A plain `VideoEvent?` cannot express the difference between a video that
/// no source could supply and one that every source supplied but the
/// viewer's content filters removed. Both render as "video not found",
/// which is a lie for the second case and leaves the viewer with no way to
/// act — the video exists, plays, and is often their own.
sealed class VideoRouteLookupResult {
  const VideoRouteLookupResult();
}

/// A playable video the viewer is allowed to see.
final class VideoRouteFound extends VideoRouteLookupResult {
  const VideoRouteFound(this.video);

  final VideoEvent video;
}

/// A video that resolved and parsed, then was removed by the viewer's
/// content preferences.
///
/// Carries [video] so the presentation layer can explain *which* preference
/// is responsible (for example by checking the media host against the
/// "only show Divine-hosted videos" setting) without this package having to
/// know what the app's filters mean.
final class VideoRouteHiddenByFilter extends VideoRouteLookupResult {
  const VideoRouteHiddenByFilter(this.video);

  final VideoEvent video;
}

/// No source supplied the video.
final class VideoRouteMissing extends VideoRouteLookupResult {
  const VideoRouteMissing();
}
