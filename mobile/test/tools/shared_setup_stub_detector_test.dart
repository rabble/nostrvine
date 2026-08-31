// ABOUTME: Tests for the shared-setUp stub detector and its ceiling ratchet
// ABOUTME: (scripts/lib/shared_setup_stub_detector.dart, #8399).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports, scripts are outside lib/ and not importable through package:openvine.
import '../../scripts/lib/shared_setup_stub_detector.dart';

/// Pins the detector semantics behind `check_shared_setup_stubs.sh` (#8399).
///
/// The load-bearing distinction is REACH: a stub in a setUp that spans
/// descendant groups is inherited by tests that never mention it and cannot see
/// it, which is how #7324 stayed green across a whole file. A stub in a leaf
/// group's setUp governs tests written a few lines below it. Counting the
/// second would make the ratchet noise; missing the first would make it blind.
void main() {
  group('shared_setup_stub_detector', () {
    late Directory tmp;

    List<SharedSetupStub> scan(String source) {
      File('${tmp.path}/t/subject_test.dart').writeAsStringSync(source);
      return findSharedSetupStubs(
        Directory('${tmp.path}/t'),
        pathPrefix: tmp.path,
      );
    }

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('shared_setup_stub_test');
      Directory('${tmp.path}/t').createSync(recursive: true);
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    group('counts', () {
      test('a file-level setUp stub inherited by a group with tests', () {
        final sites = scan('''
void main() {
  setUp(() {
    when(() => dao.foo()).thenAnswer((_) async => true);
  });
  group('a', () {
    test('x', () {});
  });
}
''');
        expect(sites, hasLength(1));
        expect(sites.single.setUpName, 'setUp');
      });

      test('an outermost-group setUp inherited by child groups', () {
        final sites = scan('''
void main() {
  group(Repo, () {
    setUp(() {
      when(() => dao.foo()).thenAnswer((_) async => true);
      when(() => dao.bar()).thenAnswer((_) async => false);
    });
    group('child', () {
      test('x', () {});
    });
  });
}
''');
        expect(sites, hasLength(2));
      });

      test('setUpAll as well as setUp', () {
        final sites = scan('''
void main() {
  setUpAll(() {
    when(() => dao.foo()).thenAnswer((_) async => true);
  });
  group('a', () {
    test('x', () {});
  });
}
''');
        expect(sites.single.setUpName, 'setUpAll');
      });

      test('whenListen, which stubs a bloc stream the same way', () {
        final sites = scan('''
void main() {
  setUp(() {
    whenListen(bloc, Stream.value(1));
  });
  group('a', () {
    test('x', () {});
  });
}
''');
        expect(sites, hasLength(1));
      });
    });

    group('does not count', () {
      test("a leaf group's own setUp — the stub sits beside its tests", () {
        final sites = scan('''
void main() {
  group('leaf', () {
    setUp(() {
      when(() => dao.foo()).thenAnswer((_) async => true);
    });
    test('x', () {});
  });
}
''');
        expect(sites, isEmpty);
      });

      test('a stub inside a test body — already local', () {
        final sites = scan('''
void main() {
  group('a', () {
    test('x', () {
      when(() => dao.foo()).thenAnswer((_) async => true);
    });
  });
}
''');
        expect(sites, isEmpty);
      });

      test('a setUp whose scope has child groups but no tests in them', () {
        final sites = scan('''
void main() {
  setUp(() {
    when(() => dao.foo()).thenAnswer((_) async => true);
  });
  test('top level only', () {});
}
''');
        expect(sites, isEmpty);
      });

      test('setUp bodies with no stub at all', () {
        final sites = scan('''
void main() {
  setUp(() {
    dao = MockDao();
    registerFallbackValue(FakeEvent());
  });
  group('a', () {
    test('x', () {});
  });
}
''');
        expect(sites, isEmpty);
      });

      test('a setUp nested two groups deep', () {
        final sites = scan('''
void main() {
  group('outer', () {
    group('inner', () {
      setUp(() {
        when(() => dao.foo()).thenAnswer((_) async => true);
      });
      group('leaf', () {
        test('x', () {});
      });
    });
  });
}
''');
        expect(sites, isEmpty);
      });

      test('when() as a method on some other target', () {
        final sites = scan('''
void main() {
  setUp(() {
    harness.when(() => dao.foo());
  });
  group('a', () {
    test('x', () {});
  });
}
''');
        expect(sites, isEmpty);
      });
    });

    group('is an AST, not a text scan', () {
      test('ignores when( in comments and string literals', () {
        final sites = scan('''
void main() {
  setUp(() {
    // when(() => dao.foo()).thenAnswer((_) async => true);
    log('when(() => dao.bar())');
  });
  group('a', () {
    test('x', () {});
  });
}
''');
        expect(sites, isEmpty);
      });

      test('counts a stub whose call dart format wrapped across lines', () {
        final sites = scan('''
void main() {
  setUp(() {
    when(
      () => dao.foo(
        ownerPubkey: any(named: 'ownerPubkey'),
      ),
    ).thenAnswer((_) async => true);
  });
  group('a', () {
    test('x', () {});
  });
}
''');
        expect(sites, hasLength(1));
      });
    });
  });
}
