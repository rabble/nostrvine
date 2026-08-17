// ABOUTME: Tests for the ungrouped-test detector and its ceiling ratchet
// ABOUTME: (scripts/lib/ungrouped_test_detector.dart, #3615).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports, scripts are outside lib/ and not importable through package:openvine.
import '../../scripts/lib/ungrouped_test_detector.dart';

/// Pins the detector semantics behind `check_ungrouped_tests.sh` (#3615,
/// test-org epic #4337).
///
/// Two things are load-bearing. Nesting: a declaration inside a `group(...)`
/// closure must not count at any depth, or the ratchet flags files that are
/// already correct. File selection: a scan rooted at a relative `test` yields
/// paths with no leading slash, and an earlier `contains('/test/')` filter
/// silently matched none of them — a guard that reports zero looks exactly like
/// a guard that passes.
void main() {
  group('findUngroupedTestsInSource', () {
    List<UngroupedTest> scan(String source) =>
        findUngroupedTestsInSource(source, path: 'test/subject_test.dart');

    group('counts a declaration outside any group', () {
      test('a bare test at the top of main', () {
        final sites = scan('''
void main() {
  test('does a thing', () {});
}
''');

        expect(sites, hasLength(1));
        expect(sites.single.declaration, 'test');
        expect(sites.single.path, 'test/subject_test.dart');
        expect(sites.single.line, 2);
        expect(sites.single.description, "'does a thing'");
      });

      test('every declaration flavour the runner picks up', () {
        final sites = scan(r'''
void main() {
  test('a', () {});
  testWidgets('b', (tester) async {});
  blocTest<FooBloc, FooState>('c', build: () => FooBloc());
  patrolTest('d', ($) async {});
}
''');

        expect(sites.map((s) => s.declaration), [
          'test',
          'testWidgets',
          'blocTest',
          'patrolTest',
        ]);
      });

      test('a declaration that trails a group', () {
        final sites = scan('''
void main() {
  group('grouped', () {
    test('inside', () {});
  });

  test('left behind', () {});
}
''');

        expect(sites, hasLength(1));
        expect(sites.single.description, "'left behind'");
        expect(sites.single.line, 6);
      });

      test('a test-declaring helper, counted at its call site', () {
        final sites = scan('''
void testWidgetsWithSurfaceSize(String description, dynamic callback) {
  testWidgets(description, (tester) async {});
}

void main() {
  testWidgetsWithSurfaceSize('loose', (tester) async {});
}
''');

        expect(sites, hasLength(1));
        expect(sites.single.declaration, 'testWidgetsWithSurfaceSize');
        expect(sites.single.description, "'loose'");
        expect(sites.single.line, 6);
      });

      test('a helper wrapping a helper, resolved to a fixpoint', () {
        final sites = scan('''
void inner(String description) {
  testWidgets(description, (tester) async {});
}

void outer(String description) {
  inner(description);
}

void main() {
  outer('loose');
}
''');

        expect(sites, hasLength(1));
        expect(sites.single.declaration, 'outer');
      });

      test('one same-file helper call counts as one site', () {
        final sites = scan('''
void allLoose() {
  test('one', () {});
  test('two', () {});
  test('three', () {});
}

void main() {
  allLoose();
}
''');

        expect(sites, hasLength(1));
        expect(sites.single.declaration, 'allLoose');
      });
    });

    group('does not count a grouped declaration', () {
      test('directly inside a group', () {
        final sites = scan('''
void main() {
  group('FooRepository', () {
    test('resolves', () {});
    testWidgets('renders', (tester) async {});
  });
}
''');

        expect(sites, isEmpty);
      });

      test('inside a nested group', () {
        final sites = scan('''
void main() {
  group('FooRepository', () {
    group('resolve', () {
      group('matched', () {
        test('returns the pubkey', () {});
      });
    });
  });
}
''');

        expect(sites, isEmpty);
      });

      test('a test-declaring helper whose call sites are all grouped', () {
        // The three repo files with a testWidgetsWithSurfaceSize wrapper are
        // fully grouped in main(); counting the wrapper's body would flag them
        // forever with nothing to fix.
        final sites = scan('''
void testWidgetsWithSurfaceSize(String description, dynamic callback) {
  testWidgets(description, (tester) async {});
}

void main() {
  group('renders', () {
    testWidgetsWithSurfaceSize('at phone size', (tester) async {});
  });
}
''');

        expect(sites, isEmpty);
      });

      test('a helper that declares a whole group, called from main', () {
        // `_authenticityTests()` in relay_discovery_service_test.dart is this
        // shape: everything it registers is already inside a group, so calling
        // it at main level is correct and must not report.
        final sites = scan('''
void _authenticityTests() {
  group('queryIndexerDirect authenticity', () {
    test('rejects a forged event', () {});
  });
}

void main() {
  _authenticityTests();
}
''');

        expect(sites, isEmpty);
      });

      test('a setUp or helper at main level alongside groups', () {
        final sites = scan('''
void main() {
  late Foo foo;

  setUp(() {
    foo = Foo();
  });

  group('FooRepository', () {
    test('resolves', () {});
  });
}
''');

        expect(sites, isEmpty);
      });
    });

    group('ignores calls the runner would not see', () {
      test('a qualified test call on another object', () {
        final sites = scan('''
void main() {
  harness.test('not a declaration', () {});
}
''');

        expect(sites, isEmpty);
      });

      test('a qualified group call does not shield its body', () {
        // `harness.group(...)` is somebody else's method, so a declaration
        // inside it is still loose. Treating it as a group would be a way past
        // the guard.
        final sites = scan('''
void main() {
  harness.group('not a group', () {
    test('still loose', () {});
  });
}
''');

        expect(sites, hasLength(1));
        expect(sites.single.description, "'still loose'");
      });
    });

    test('a file with a syntax error is not silently dropped', () {
      // The parser recovers rather than bailing, so a half-written file still
      // reports. That direction is the safe one: dropping a file would read to
      // the ratchet as a file somebody had cleaned up.
      final sites = scan('void main() { test(');

      expect(sites, hasLength(1));
      expect(sites.single.declaration, 'test');
    });
  });

  group('isTestFile', () {
    test('accepts a relative path rooted at test/', () {
      // Regression: an earlier `contains("/test/")` filter missed every file
      // under a relative scan root, so the guard reported an empty repo.
      expect(isTestFile(File('test/services/foo_test.dart')), isTrue);
      expect(isTestFile(File('test/foo_test.dart')), isTrue);
    });

    test('accepts absolute paths and package test dirs', () {
      expect(isTestFile(File('/repo/mobile/test/foo_test.dart')), isTrue);
      expect(
        isTestFile(File('packages/db_client/test/src/foo_test.dart')),
        isTrue,
      );
      expect(isTestFile(File('integration_test/auth/foo_test.dart')), isTrue);
    });

    test('rejects library code that merely ends in _test.dart', () {
      expect(
        isTestFile(File('packages/nostr_sdk/lib/signer/signer_test.dart')),
        isFalse,
      );
    });

    test('rejects the driver entry point outside a test dir', () {
      expect(isTestFile(File('test_driver/integration_test.dart')), isFalse);
    });

    test('rejects build output and other worktrees', () {
      expect(isTestFile(File('.dart_tool/build/x/foo_test.dart')), isFalse);
      expect(isTestFile(File('build/x/test/foo_test.dart')), isFalse);
      expect(
        isTestFile(File('.worktrees/other/mobile/test/foo_test.dart')),
        isFalse,
      );
    });

    test('rejects a non-test file inside a test dir', () {
      expect(isTestFile(File('test/helpers/fixtures.dart')), isFalse);
    });
  });

  group('findUngroupedTests', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('ungrouped_test_detector');
      Directory('${tmp.path}/test/services').createSync(recursive: true);
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('reports one line per file, path-relative and sorted', () {
      File('${tmp.path}/test/a_test.dart').writeAsStringSync('''
void main() {
  test('one', () {});
  test('two', () {});
}
''');
      File('${tmp.path}/test/services/b_test.dart').writeAsStringSync('''
void main() {
  group('B', () {
    test('grouped', () {});
  });
}
''');

      final sites = findUngroupedTests([
        Directory('${tmp.path}/test'),
      ], pathPrefix: tmp.path);

      expect(sites.map((s) => s.path), [
        'test/a_test.dart',
        'test/a_test.dart',
      ]);
      expect(sites.map((s) => s.description), ["'one'", "'two'"]);
    });

    test('does not resolve test-declaring helpers from imported files', () {
      Directory('${tmp.path}/test/helpers').createSync(recursive: true);
      File('${tmp.path}/test/helpers/shared_helpers.dart').writeAsStringSync('''
void sharedTests() {
  test('one', () {});
  test('two', () {});
}
''');
      File('${tmp.path}/test/imported_helper_test.dart').writeAsStringSync('''
import 'helpers/shared_helpers.dart';

void main() {
  sharedTests();
}
''');

      final sites = findUngroupedTests([
        Directory('${tmp.path}/test'),
      ], pathPrefix: tmp.path);

      expect(sites, isEmpty);
    });
  });
}
