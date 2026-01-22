// ABOUTME: Filter callback for parsed VideoEvent objects in the repository.
// ABOUTME: Used for content-based filtering (NSFW, etc.) after event parsing.

import 'package:models/models.dart';
import 'package:videos_repository/videos_repository.dart';

/// Filter callback for parsed video events.
///
/// Returns `true` if the [video] should be hidden from results.
///
/// This filter runs AFTER the event is parsed to [VideoEvent], allowing
/// inspection of video metadata like hashtags and tags. Use this for
/// content-based filtering (NSFW, content warnings, etc.).
///
/// For pubkey-based filtering (blocklists), use [BlockedVideoFilter] instead
/// which runs before parsing for efficiency.
typedef VideoContentFilter = bool Function(VideoEvent video);
