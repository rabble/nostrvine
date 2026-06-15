// ABOUTME: Riverpod provider exposing the app's FeedRepository (#3383).
// ABOUTME: keepAlive so the fullscreen feed's source outlives launching widgets.

import 'package:feed_repository/feed_repository.dart';
import 'package:openvine/repositories/feed_repository_impl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'feed_repository_provider.g.dart';

/// The app-wide [FeedRepository].
///
/// keepAlive so the fullscreen feed it backs is decoupled from the lifetime of
/// whichever widget opened the route — the core fix in issue #3383.
@Riverpod(keepAlive: true)
FeedRepository feedRepository(Ref ref) => RiverpodFeedRepository(ref);
