import 'dart:async';

import 'package:flutter/foundation.dart';

/// Adapts a [Stream] to a [Listenable] for GoRouter refreshes.
class RouterRefreshListenable implements Listenable {
  RouterRefreshListenable(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => refresh());
  }

  final Set<VoidCallback> _listeners = <VoidCallback>{};
  late final StreamSubscription<dynamic> _subscription;

  @override
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void refresh() {
    for (final listener in List<VoidCallback>.of(_listeners)) {
      listener();
    }
  }

  void dispose() {
    _subscription.cancel();
    _listeners.clear();
  }
}
