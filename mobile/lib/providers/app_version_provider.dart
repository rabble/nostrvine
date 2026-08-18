// ABOUTME: Provides the bootstrap-resolved app version to account containers.

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The shipped app version resolved during bootstrap.
///
/// Every account container receives an override from `DeviceScope`; reading
/// this provider without that override is a wiring error.
final appVersionProvider = Provider<String>(
  (_) => throw StateError('appVersionProvider must be overridden'),
);
