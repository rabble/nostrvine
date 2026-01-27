// ABOUTME: Loading widget shown when NostrClient doesn't have keys yet
// ABOUTME: Used as a placeholder while waiting for authentication to complete

import 'package:flutter/material.dart';

/// Widget displayed when NostrClient is not ready (keys not loaded yet).
///
/// Shows a loading indicator centered on screen. Use this instead of
/// duplicating the Scaffold + CircularProgressIndicator pattern.
class NostrNotReadyWidget extends StatelessWidget {
  const NostrNotReadyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
