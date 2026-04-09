// ABOUTME: Shared loading-more sliver for profile tab grids
// ABOUTME: Shows a spinner at the bottom of the grid during pagination

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

/// A [SliverToBoxAdapter] spinner displayed at the bottom of a profile
/// tab grid while more items are being fetched.
class ProfileTabLoadingMoreSliver extends StatelessWidget {
  const ProfileTabLoadingMoreSliver({super.key});

  @override
  Widget build(BuildContext context) => const SliverToBoxAdapter(
    child: Padding(
      padding: .all(16),
      child: Center(
        child: CircularProgressIndicator(color: VineTheme.primary),
      ),
    ),
  );
}
