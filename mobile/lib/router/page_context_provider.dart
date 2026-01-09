// ABOUTME: Reactive provider that parses router location into structured context
// ABOUTME: Single source of truth for "what page are we on?"

import 'dart:async';
import 'package:riverpod/riverpod.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/router/route_utils.dart';

/// Provider that exposes the raw router location stream.
///
/// Exposed separately for test overrides - tests can inject mock location streams.
final routerLocationStreamProvider = Provider<Stream<String>>((ref) {
  final router = ref.read(goRouterProvider);
  final ctrl = StreamController<String>(sync: true);

  void emit() {
    final location = router.routeInformationProvider.value.uri.toString();
    if (!ctrl.isClosed) ctrl.add(location);
  }

  // Emit initial location immediately
  emit();

  // Listen for location changes
  final delegate = router.routerDelegate;
  delegate.addListener(emit);

  ref.onDispose(() {
    delegate.removeListener(emit);
    ctrl.close();
  });

  return ctrl.stream;
});

/// StreamProvider that emits structured page context on route changes.
///
/// Derives RouteContext from router location stream.
///
/// Example:
/// ```dart
/// final context = ref.watch(pageContextProvider);
/// context.when(
///   data: (ctx) {
///     if (ctx.type == RouteType.home) {
///       // Show home feed videos
///     }
///   },
///   loading: () => CircularProgressIndicator(),
///   error: (e, s) => ErrorWidget(e),
/// );
/// ```
final pageContextProvider = StreamProvider<RouteContext>((ref) async* {
  final locations = ref.watch(routerLocationStreamProvider);

  await for (final loc in locations) {
    yield parseRoute(loc);
  }
});
