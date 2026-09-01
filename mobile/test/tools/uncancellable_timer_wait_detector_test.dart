// ABOUTME: Tests for the detector behind check_uncancellable_timer_wait.sh
// ABOUTME: (scripts/lib/uncancellable_timer_wait_detector.dart, #8457).

import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports, scripts are outside lib/ and not importable through package:openvine.
import '../../scripts/lib/uncancellable_timer_wait_detector.dart';

/// Pins the detector that freezes uncancellable timer-backed waits at zero.
///
/// The boundaries carry the weight. The counted shape — a discarded `Timer`
/// settling a `Completer` somebody awaits — is `await Future.delayed(d)` with
/// the ratchet-visible name filed off. But a timer somebody *holds* is
/// cancellable by that holder, and a discarded timer that settles nothing
/// cannot strand an awaiting caller; flagging either would make the zero floor
/// unreachable and the guard would be turned off rather than obeyed.
void main() {
  group('findUncancellableTimerWaitsInSource', () {
    List<UncancellableTimerWait> scan(String source) =>
        findUncancellableTimerWaitsInSource(source, path: 'lib/subject.dart');

    group('counted', () {
      test('flags a discarded Timer handed a complete tear-off', () {
        final sites = scan('''
Future<void> wait(Duration delay) async {
  final completer = Completer<void>();
  Timer(delay, completer.complete);
  await completer.future;
}
''');

        expect(sites, hasLength(1));
        expect(sites.single.line, 3);
        expect(sites.single.snippet, 'Timer(delay, completer.complete);');
      });

      test('flags a closure body that completes the completer', () {
        final sites = scan('''
void wait() {
  Timer(delay, () => completer.complete(null));
  Timer(delay, (  ) { completer.completeError(StateError('x')); });
}
''');

        expect(sites, hasLength(2));
      });

      test('flags a discarded Timer.periodic', () {
        final sites = scan('''
void poll() {
  Timer.periodic(interval, (_) => completer.complete(true));
}
''');

        expect(sites, hasLength(1));
      });

      test('flags the explicit `new Timer` form', () {
        final sites = scan('''
void wait() {
  new Timer(delay, completer.complete);
}
''');

        expect(sites, hasLength(1));
      });

      test('flags however dart format wrapped the call', () {
        // The Timer and the completer it settles routinely land on different
        // lines once the argument list is long enough to wrap, which is what
        // defeats a line-oriented scan.
        final sites = scan('''
void wait() {
  Timer(
    const Duration(milliseconds: 250),
    () {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    },
  );
}
''');

        expect(sites, hasLength(1));
        expect(sites.single.line, 2);
      });

      test('flags a named callback that completes a completer', () {
        final sites = scan('''
Future<void> wait(Duration delay) {
  final completer = Completer<void>();
  void completeWait() => completer.complete();
  Timer(delay, completeWait);
  return completer.future;
}
''');

        expect(sites, hasLength(1));
        expect(sites.single.line, 4);
      });

      test('flags a closure that settles through a same-file helper', () {
        final sites = scan('''
Future<void> wait(Duration delay) {
  final completer = Completer<void>();
  void tryComplete() => completer.complete();
  Timer(delay, () {
    if (!completer.isCompleted) tryComplete();
  });
  return completer.future;
}
''');

        expect(sites, hasLength(1));
        expect(sites.single.line, 4);
      });

      test('flags a class-method tear-off that completes a completer', () {
        final sites = scan('''
class Owner {
  final Completer<void> _c = Completer<void>();
  void _fire() => _c.complete();
  Future<void> wait(Duration delay) {
    Timer(delay, _fire);
    return _c.future;
  }
}
''');

        expect(sites, hasLength(1));
        expect(sites.single.line, 5);
      });

      test('flags a class method that takes the completer as an argument', () {
        final sites = scan('''
class Owner {
  void _finish(Completer<void> c) => c.complete();
  Future<void> wait(Duration delay) {
    final c = Completer<void>();
    Timer(delay, () => _finish(c));
    return c.future;
  }
}
''');

        expect(sites, hasLength(1));
        expect(sites.single.line, 5);
      });

      test('flags a class method invoked with only a named argument', () {
        final sites = scan('''
class Owner {
  final Completer<void> _c = Completer<void>();
  void _settle({bool ok = true}) => _c.complete();
  Future<void> wait(Duration delay) {
    Timer(delay, () => _settle(ok: true));
    return _c.future;
  }
}
''');

        expect(sites, hasLength(1));
        expect(sites.single.line, 5);
      });

      test('flags a closure that settles through a class method', () {
        final sites = scan('''
class Owner {
  final Completer<void> _c = Completer<void>();
  void _fire() => _c.complete();
  Future<void> wait(Duration delay) {
    Timer(delay, () => _fire());
    return _c.future;
  }
}
''');

        expect(sites, hasLength(1));
        expect(sites.single.line, 5);
      });
    });

    group('not counted', () {
      test('ignores a Timer assigned to a variable', () {
        final sites = scan('''
void wait() {
  final timer = Timer(delay, completer.complete);
  timer.cancel();
}
''');

        expect(sites, isEmpty);
      });

      test('ignores a Timer assigned to a field', () {
        final sites = scan('''
class Owner {
  Timer? _timer;
  void wait() {
    _timer = Timer(delay, completer.complete);
  }
  void dispose() => _timer?.cancel();
}
''');

        expect(sites, isEmpty);
      });

      test('ignores a Timer kept in a collection', () {
        final sites = scan('''
void wait() {
  timers.add(Timer(delay, completer.complete));
}
''');

        expect(sites, isEmpty);
      });

      test('ignores a returned Timer', () {
        final sites = scan('''
Timer wait() {
  return Timer(delay, completer.complete);
}
''');

        expect(sites, isEmpty);
      });

      test(
        'ignores a discarded Timer that only calls a method with arguments',
        () {
          // Fire-and-forget reconnect: the callback invokes real work, and that
          // work may mention `x.complete()` elsewhere in the class. Following
          // every method would make the zero floor unattainable.
          final sites = scan('''
class Owner {
  void reconnect() {
    Timer(delay, () {
      subscribeToFeed(limit: 50);
    });
  }
  Future<void> subscribeToFeed({int? limit}) async {
    final c = Completer<void>();
    c.complete();
  }
}
''');

          expect(sites, isEmpty);
        },
      );

      test('ignores a discarded Timer that settles no completer', () {
        // Ordinary fire-and-forget deferral. It cannot strand an awaiting
        // caller, and counting it would flag dozens of benign sites.
        final sites = scan('''
void defer() {
  Timer(delay, () => Log.debug('late'));
  Timer(delay, _onTick);
}
''');

        expect(sites, isEmpty);
      });

      test('ignores Timer text inside comments and string literals', () {
        final sites = scan('''
void wait() {
  // Timer(delay, completer.complete);
  /// Replaces `Timer(delay, completer.complete);`.
  Log.debug('Timer(delay, completer.complete);');
}
''');

        expect(sites, isEmpty);
      });

      test('ignores an unrelated discarded call', () {
        final sites = scan('''
void go() {
  unawaited(sync());
  scheduleMicrotask(completer.complete);
}
''');

        expect(sites, isEmpty);
      });
    });

    group('robustness', () {
      test('returns nothing for unparseable source', () {
        expect(scan('class {{{ not dart'), isEmpty);
      });

      test('reports every site in a file', () {
        // The shape #8457 actually removed: two independent waits in one file.
        final sites = scan('''
Future<void> retry() async {
  try {
    await op();
  } catch (_) {
    final completer = Completer<void>();
    Timer(delay, completer.complete);
    await completer.future;
  }
}

Future<void> rateLimit() async {
  final completer = Completer<void>();
  Timer(remaining, completer.complete);
  await completer.future;
}
''');

        expect(sites.map((s) => s.line), [6, 13]);
      });
    });
  });

  group('shouldScanUncancellableTimerWaitFile', () {
    test('includes app and package production libraries', () {
      expect(
        shouldScanUncancellableTimerWaitFile('lib/services/example.dart'),
        isTrue,
      );
      expect(
        shouldScanUncancellableTimerWaitFile(
          'packages/nostr_sdk/lib/relay/example.dart',
        ),
        isTrue,
      );
    });

    test('excludes package tests and integration tests', () {
      expect(
        shouldScanUncancellableTimerWaitFile(
          'packages/nostr_sdk/test/relay/example_test.dart',
        ),
        isFalse,
      );
      expect(
        shouldScanUncancellableTimerWaitFile(
          'packages/nostr_sdk/integration_test/example_test.dart',
        ),
        isFalse,
      );
      expect(
        shouldScanUncancellableTimerWaitFile(
          'packages/nostr_sdk/tool/generate_fixture.dart',
        ),
        isFalse,
      );
    });
  });
}
