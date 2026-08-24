// ABOUTME: Tests for the skipped-test detector behind check_skip_ceiling.sh
// ABOUTME: (scripts/lib/skipped_test_detector.dart, #3340 / #4836).

import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports, scripts are outside lib/ and not importable through package:openvine.
import '../../scripts/lib/skipped_test_detector.dart';

/// Pins the detector that replaced the regex `[(, ]skip: (true|'|")`.
///
/// Four behaviours are load-bearing, and the regex got each of them wrong:
///
///  * `blocTest`'s `skip:` is an `int` — the number of leading states to ignore
///    before matching `expect` — so counting it would flag 40+ correct tests.
///    Excluding it by CALLEE keeps that true for a named constant too.
///  * A `skip:` argument to the function under test is not a test skip. The
///    regex needed `main_video_cache_startup_test.dart` excluded by filename.
///  * `dart format` wraps a long reason onto its own line, which put the value
///    out of the regex's reach and hid two live skips.
///  * Comments and string literals are prose, not code.
void main() {
  group('findSkippedTestsInSource', () {
    List<SkippedTest> scan(String source) =>
        findSkippedTestsInSource(source, path: 'test/subject_test.dart');

    group('counts a disabled test', () {
      test('skip: true on each declaration flavour', () {
        final sites = scan(r'''
void main() {
  test('a', () {}, skip: true);
  testWidgets('b', (tester) async {}, skip: true);
  patrolTest('c', ($) async {}, skip: true);
  group('d', () {}, skip: true);
}
''');

        expect(
          sites.map((site) => site.declaration),
          ['test', 'testWidgets', 'patrolTest', 'group'],
        );
        expect(sites.first.path, 'test/subject_test.dart');
        expect(sites.first.line, 2);
        expect(sites.first.description, "'a'");
      });

      test('a reason string, however dart format wrapped it', () {
        // The regex required the value on the same line as `skip:`, so the
        // wrapped form below was invisible — two live sites hid there.
        final sites = scan('''
void main() {
  test('inline', () {}, skip: 'still flaky');
  test(
    'wrapped',
    () {},
    skip:
        'a reason long enough that dart format moved it '
        'onto its own line',
  );
}
''');

        expect(sites, hasLength(2));
        expect(sites.first.skipValue, "'still flaky'");
        expect(sites.last.description, "'wrapped'");
      });

      test('a file-level @Skip annotation, which the regex could not see', () {
        final sites = scan('''
@Skip('whole suite is broken')
library;

void main() {
  test('a', () {});
}
''');

        expect(sites, hasLength(1));
        expect(sites.single.declaration, '@Skip');
        expect(sites.single.skipValue, "'whole suite is broken'");
        expect(sites.single.description, '<whole file>');
      });

      test('a named constant, which is an unconditional skip in disguise', () {
        final sites = scan('''
const _blockedOnCi = true;

void main() {
  test('a', () {}, skip: _blockedOnCi);
}
''');

        expect(sites, hasLength(1));
        expect(sites.single.skipValue, '_blockedOnCi');
      });
    });

    group('does not count', () {
      test("blocTest's skip:, which is an assertion offset", () {
        // bloc_test declares `int skip = 0`: the number of leading states to
        // ignore. Excluding by callee keeps a named int constant safe too.
        final sites = scan('''
void main() {
  blocTest<FooBloc, FooState>('a', build: () => FooBloc(), skip: 2);
  blocTest<FooBloc, FooState>('b', build: () => FooBloc(), skip: _leading);
}
''');

        expect(sites, isEmpty);
      });

      test('a skip: passed to the function under test', () {
        // This is main_video_cache_startup_test.dart's shape. The regex needed
        // that file excluded by NAME; the parser attributes the argument to its
        // own callee, so no exclusion list is required.
        final sites = scan('''
void main() {
  test('skips cache configuration when skip is true', () async {
    await configureVideoCache(skip: true);
  });
}
''');

        expect(sites, isEmpty);
      });

      test('a skip: inside a comment or a string literal', () {
        final sites = scan('''
void main() {
  // skip: true — left here while we decide
  test('a', () {
    expect(log, contains('skip: true'));
  });
}
''');

        expect(sites, isEmpty);
      });

      test('skip: false, which disables nothing', () {
        final sites = scan('''
void main() {
  test('a', () {}, skip: false);
}
''');

        expect(sites, isEmpty);
      });

      test('a platform gate, which restricts rather than disables', () {
        final sites = scan('''
void main() {
  test('a', () {}, skip: !kIsWeb);
  test('b', () {}, skip: !(Platform.isIOS || Platform.isAndroid));
  test('c', () {}, skip: defaultTargetPlatform == TargetPlatform.macOS);
}
''');

        expect(sites, isEmpty);
      });

      test('a skip: on a method of some other object', () {
        final sites = scan('''
void main() {
  harness.test('a', () {}, skip: true);
}
''');

        expect(sites, isEmpty);
      });
    });

    group('disablesTest', () {
      test('a platform predicate mixed with anything else counts', () {
        // Conservative on purpose: an expression the detector cannot prove is
        // a pure platform gate is debt. Under-counting would leave a bypass.
        final sites = scan('''
void main() {
  test('a', () {}, skip: !kIsWeb && _featureOff);
}
''');

        expect(sites, hasLength(1));
      });
    });
  });
}
