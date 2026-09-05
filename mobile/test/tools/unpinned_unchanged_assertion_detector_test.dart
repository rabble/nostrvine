// ABOUTME: Tests for the detector behind check_unpinned_unchanged_assertions.sh
// ABOUTME: (scripts/lib/unpinned_unchanged_assertion_detector.dart, #8617).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports, scripts are outside lib/ and not importable through package:openvine.
import '../../scripts/lib/unpinned_unchanged_assertion_detector.dart';

/// Pins the detector that freezes unpinned "unchanged" assertions at zero.
///
/// The boundaries matter more than the hits. A pin anywhere in the test body
/// — on the local, on the expression it was read from, or on a member of
/// either — clears the site, because the test can then fail when the method
/// under test is inert. Strict mode additionally requires the pair to be the
/// test's only assertion, so a pair sitting beside a real assertion is
/// reported only under `--all`.
void main() {
  group('findUnpinnedUnchangedAssertionsInSource', () {
    List<UnpinnedUnchangedAssertion> scan(String source) =>
        findUnpinnedUnchangedAssertionsInSource(
          source,
          path: 'test/subject_test.dart',
        );

    group('flags', () {
      test('the #8617 shape: read, act, re-read, compare, never pinned', () {
        final sites = scan('''
void main() {
  test('markAuthShellReady is idempotent', () async {
    final service = StartupPerformanceService.instance;
    await service.initialize();
    service.markAuthShellReady();
    final firstTime = service.authShellReadyTime;
    service.markAuthShellReady();
    expect(service.authShellReadyTime, equals(firstTime));
  });
}
''');

        expect(sites, hasLength(1));
        expect(sites.single.line, 8);
        expect(sites.single.baseline, 'firstTime');
        expect(sites.single.read, 'service.authShellReadyTime');
        expect(sites.single.test, "'markAuthShellReady is idempotent'");
        expect(sites.single.sole, isTrue);
      });

      test('a bare local, same(), and reversed operands', () {
        final sites = scan('''
void main() {
  test('bare', () {
    final before = counter.value;
    act();
    expect(counter.value, before);
  });
  test('same', () {
    final first = host.controller;
    act();
    expect(host.controller, same(first));
  });
  test('reversed', () {
    final first = host.controller;
    act();
    expect(first, equals(host.controller));
  });
}
''');

        expect(sites.map((site) => site.line), [5, 10, 15]);
        expect(sites.every((site) => site.sole), isTrue);
      });

      test('an awaited read and a method-call read', () {
        final sites = scan('''
void main() {
  test('awaited', () async {
    final rows = await dao.getAll();
    await service.collect();
    expect(await dao.getAll(), equals(rows));
  });
  test('call', () {
    final calls = harness.countCalls('setClips');
    pump();
    expect(harness.countCalls('setClips'), calls);
  });
}
''');

        expect(sites.map((site) => site.read), [
          'dao.getAll()',
          "harness.countCalls('setClips')",
        ]);
      });

      test('however dart format wrapped the call', () {
        final sites = scan('''
void main() {
  test('wrapped', () {
    final baseline =
        someVeryLongObjectName.someVeryLongPropertyName.length;
    act();
    expect(
      someVeryLongObjectName.someVeryLongPropertyName.length,
      equals(
        baseline,
      ),
    );
  });
}
''');

        expect(sites, hasLength(1));
        expect(sites.single.line, 6);
      });

      test('inside testWidgets and patrolTest bodies too', () {
        final sites = scan(r'''
void main() {
  testWidgets('w', (tester) async {
    final size = tester.getSize(find.byType(Row));
    await tester.pump();
    expect(tester.getSize(find.byType(Row)), size);
  });
  patrolTest('p', ($) async {
    final count = store.count;
    await $.pump();
    expect(store.count, count);
  });
}
''');

        expect(sites, hasLength(2));
      });

      test('two unpinned pairs with nothing else are both sole', () {
        final sites = scan('''
void main() {
  test('two', () {
    final a = db.drafts;
    final b = db.clips;
    collect();
    expect(db.drafts, a);
    expect(db.clips, b);
  });
}
''');

        expect(sites, hasLength(2));
        expect(sites.every((site) => site.sole), isTrue);
      });
    });

    group('treats as pinned', () {
      test('an expect on the local before the act', () {
        final sites = scan('''
void main() {
  test('pinned', () {
    final firstTime = service.authShellReadyTime;
    expect(firstTime, isNotNull);
    service.markAuthShellReady();
    expect(service.authShellReadyTime, equals(firstTime));
  });
}
''');

        expect(sites, isEmpty);
      });

      test('an expect on the local after the re-read', () {
        final sites = scan('''
void main() {
  test('pinned late', () {
    final count = harness.countCalls('setClips');
    pump();
    expect(harness.countCalls('setClips'), count);
    expect(count, greaterThan(0));
  });
}
''');

        expect(sites, isEmpty);
      });

      test('an expect on a member of the local', () {
        final sites = scan('''
void main() {
  test('member', () {
    final seeded = manager['tgt'].value;
    expect(seeded, hasLength(2));
    manager.sync();
    expect(manager['tgt'].value, equals(seeded));
  });
  test('member access', () {
    final rows = dao.rows;
    expect(rows.length, 3);
    collect();
    expect(dao.rows, rows);
  });
}
''');

        expect(sites, isEmpty);
      });

      test('an expect on a member of the read expression', () {
        final sites = scan('''
void main() {
  test('polling stopped', () {
    expect(cubit.state.status, UploadStatus.readyToPublish);
    final lastState = cubit.state;
    async.elapse(const Duration(milliseconds: 500));
    expect(cubit.state, lastState);
  });
}
''');

        expect(sites, isEmpty);
      });

      test('an expect on the collection a derived read came from', () {
        final sites = scan('''
void main() {
  test('receiver pinned exactly', () {
    final count = service.discoveryVideos.length;
    expect(service.discoveryVideos, isNotEmpty);
    service.reset();
    expect(service.discoveryVideos.length, count);
  });
  test('receiver pinned through a member', () {
    final before = cubit.state.videos.length;
    expect(cubit.state.videos.map((v) => v.id), ['b', 'a']);
    cubit.add(duplicate);
    expect(cubit.state.videos.length, before);
  });
}
''');

        expect(sites, isEmpty);
      });

      test('but not an expect on the receiver of ordinary state', () {
        final sites = scan('''
void main() {
  test('receiver is not the value', () {
    final first = service.readyTime;
    expect(service, isNotNull);
    service.markReady();
    expect(service.readyTime, first);
  });
}
''');

        expect(sites, hasLength(1));
      });

      test('a null check on the local', () {
        final sites = scan('''
void main() {
  test('bang', () {
    final first = service.readyTime;
    service.markReady();
    expect(service.readyTime, equals(first));
    expect(first!.inMilliseconds, greaterThan(0));
  });
}
''');

        expect(sites, isEmpty);
      });
    });

    group('does not count', () {
      test('a baseline the test chose itself', () {
        final sites = scan('''
void main() {
  test('literal', () {
    final expected = 3;
    act();
    expect(counter.value, expected);
  });
  test('constructed', () {
    final expected = const Duration(seconds: 1);
    act();
    expect(clock.elapsed, expected);
  });
}
''');

        expect(sites, isEmpty);
      });

      test('a copyWith or constructor call, which constructs', () {
        final sites = scan('''
void main() {
  test('copyWith', () {
    final overridden = frame.copyWith(holdOverridden: true);
    expect(frame.copyWith(holdOverridden: true), equals(overridden));
  });
  test('constructor', () {
    final expected = Snapshot(pubkeys: pubkeys, count: 42);
    expect(Snapshot(pubkeys: pubkeys, count: 42), equals(expected));
  });
  test('named constructor', () {
    final expected = Snapshot.empty(count: 0);
    expect(Snapshot.empty(count: 0), equals(expected));
  });
}
''');

        expect(sites, isEmpty);
      });

      test('a re-read of a different expression', () {
        final sites = scan('''
void main() {
  test('different', () {
    final before = service.a;
    act();
    expect(service.b, before);
  });
}
''');

        expect(sites, isEmpty);
      });

      test('a changed-assertion on the pair', () {
        final sites = scan('''
void main() {
  test('changed', () {
    final before = service.a;
    act();
    expect(service.a, isNot(before));
  });
}
''');

        expect(sites, isEmpty);
      });

      test('the shape outside a test body', () {
        final sites = scan('''
void main() {
  late int before;
  setUp(() {
    before = counter.value;
    act();
    expect(counter.value, before);
  });
  test('real', () {
    expect(counter.value, 1);
  });
}
''');

        expect(sites, isEmpty);
      });

      test('the shape quoted in a string or a comment', () {
        final sites = scan('''
void main() {
  test('quoted', () {
    // final before = counter.value; expect(counter.value, before);
    Log.info('final before = counter.value; expect(counter.value, before);');
    expect(counter.value, 1);
  });
}
''');

        expect(sites, isEmpty);
      });
    });

    group('sole', () {
      test('is false when a real assertion sits beside the pair', () {
        final sites = scan('''
void main() {
  test('beside expect', () {
    final count = harness.countCalls('setClips');
    pump();
    expect(find.byType(ErrorView), findsOneWidget);
    expect(harness.countCalls('setClips'), count);
  });
  test('beside verify', () {
    final count = loadCount;
    cubit.close();
    expect(loadCount, count);
    verifyNever(() => repository.load());
  });
}
''');

        expect(sites, hasLength(2));
        expect(sites.any((site) => site.sole), isFalse);
      });
    });
  });

  group('isTestFile', () {
    test('accepts suites under test and integration_test', () {
      expect(isTestFile(File('test/foo_test.dart')), isTrue);
      expect(isTestFile(File('integration_test/foo_test.dart')), isTrue);
      expect(isTestFile(File('packages/x/test/src/foo_test.dart')), isTrue);
    });

    test('rejects library code, drivers and build output', () {
      expect(isTestFile(File('lib/foo_test.dart')), isFalse);
      expect(isTestFile(File('test/foo.dart')), isFalse);
      expect(isTestFile(File('test_driver/integration_test.dart')), isFalse);
      expect(isTestFile(File('.dart_tool/test/foo_test.dart')), isFalse);
      expect(isTestFile(File('.worktrees/x/test/foo_test.dart')), isFalse);
    });
  });
}
