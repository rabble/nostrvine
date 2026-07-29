// ABOUTME: Reads FeatureFlag.curatedLists off a BuildContext.
// ABOUTME: Backstop gate for entry points that would construct PeopleListsBloc.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';

/// Whether curated lists are enabled for the current user.
///
/// The global `PeopleListsBloc` is registered unconditionally in `main.dart`
/// — a conditional entry changed the provider chain's shape and re-inflated
/// the Navigator on every flag flip. `BlocProvider` laziness gates it
/// instead, which only holds while every entry point that would read the
/// bloc checks the flag first.
///
/// Widgets that can rebuild on a flip should `ref.watch` the flag directly;
/// this is for imperative call sites (`show...Sheet` helpers) that only need
/// a one-shot read.
bool curatedListsEnabled(BuildContext context) {
  return ProviderScope.containerOf(
    context,
    listen: false,
  ).read(isFeatureEnabledProvider(FeatureFlag.curatedLists));
}
