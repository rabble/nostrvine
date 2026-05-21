// ABOUTME: Riverpod provider for test-only overlay policy injection.
// ABOUTME: Lives in lib/providers/ so overlay behavior overrides follow the
// ABOUTME: same DI boundary as the rest of the Riverpod graph.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/ui/overlay_policy.dart';

final overlayPolicyProvider = Provider<OverlayPolicy>(
  (_) => OverlayPolicy.auto,
);
