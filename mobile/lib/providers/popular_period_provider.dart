// ABOUTME: Selected time-window for the Explore → Popular tab.
// ABOUTME: null = "Right Now" (sort=watching). Non-null hits the leaderboard.

import 'package:flutter_riverpod/legacy.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';

/// Currently-selected period filter on the Popular tab.
///
/// `null` means "Right Now" — the historical Popular default backed by
/// `/api/videos?sort=watching`. Any non-null value swaps the data source
/// to `/api/leaderboard/videos?period=…` for that window.
///
/// The URL is the source of truth: `ExploreScreen` watches
/// `GoRouterState.uri.queryParameters['period']` and writes the parsed
/// value here on every navigation.
final popularPeriodProvider = StateProvider<LeaderboardPeriod?>((_) => null);
