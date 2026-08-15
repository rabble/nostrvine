// ABOUTME: Tests for the post-close emit/add detector and its ceiling ratchet
// ABOUTME: (scripts/lib/post_close_emit_detector.dart, #7370).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports, scripts are outside lib/ and not importable through package:openvine.
import '../../scripts/lib/post_close_emit_detector.dart';

/// Pins the detector semantics behind `check_post_close_emit_ceiling.sh`
/// (#7370, prevention follow-up to #7293 / #7356).
///
/// The load-bearing distinction is which `emit` throws after `close()`:
/// `BlocBase.emit` does, an `on<Event>` handler's `Emitter.call` does not
/// (`Bloc.close()` cancels every live emitter first). Miscounting either way
/// makes the ratchet useless — too noisy to act on, or blind to the crash it
/// exists to stop.
void main() {
  group('post_close_emit_detector', () {
    late Directory tmp;

    List<PostCloseSite> scan(String source) {
      File('${tmp.path}/lib/subject.dart').writeAsStringSync(source);
      return findPostCloseSites(
        Directory('${tmp.path}/lib'),
        pathPrefix: tmp.path,
      );
    }

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('post_close_emit_test');
      Directory('${tmp.path}/lib').createSync(recursive: true);
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('counts a cubit emit that resumes after an await', () {
      final sites = scan('''
class FooCubit extends Cubit<int> {
  Future<void> load() async {
    final value = await _read();
    emit(value);
  }
}
''');

      expect(sites, hasLength(1));
      expect(sites.single.call, 'Cubit.emit');
      expect(sites.single.member, 'load');
      expect(sites.single.path, 'lib/subject.dart');
      expect(sites.single.line, 4);
    });

    test('does not count a synchronous emit', () {
      final sites = scan('''
class FooCubit extends Cubit<int> {
  void bump() => emit(state + 1);
}
''');

      expect(sites, isEmpty);
    });

    test('does not count an on<Event> handler emit (Emitter.call)', () {
      // Bloc.close() cancels live emitters before super.close(), so this
      // degrades to a no-op rather than throwing. Counting it would bury the
      // real sites under every async handler in the app.
      final sites = scan('''
class FooBloc extends Bloc<FooEvent, int> {
  Future<void> _onStarted(FooStarted event, Emitter<int> emit) async {
    final value = await _read();
    emit(value);
  }
}
''');

      expect(sites, isEmpty);
    });

    test('counts a bloc emit outside any handler', () {
      // No `emit` parameter in scope, so this is BlocBase.emit and it throws.
      final sites = scan('''
class FooBloc extends Bloc<FooEvent, int> {
  Future<void> _refresh() async {
    final value = await _read();
    emit(value);
  }
}
''');

      expect(sites, hasLength(1));
      expect(sites.single.call, 'Cubit.emit');
    });

    test('an isClosed early return after the await clears the site', () {
      final sites = scan('''
class FooCubit extends Cubit<int> {
  Future<void> load() async {
    final value = await _read();
    if (isClosed) return;
    emit(value);
  }
}
''');

      expect(sites, isEmpty);
    });

    test('an isClosed guard before the await does not clear the site', () {
      // The whole bug: the guard has to sit on the resumption side.
      final sites = scan('''
class FooCubit extends Cubit<int> {
  Future<void> load() async {
    if (isClosed) return;
    final value = await _read();
    emit(value);
  }
}
''');

      expect(sites, hasLength(1));
    });

    test('a guard that cleans up before returning still clears the site', () {
      // The shape the close-guard rule recommends when there is work to undo
      // on the closed path. The await inside the arm never runs on the path
      // that falls through, so it does not re-suspend the emit below.
      final sites = scan('''
class FooCubit extends Cubit<int> {
  Future<void> stop() async {
    final path = await _recorder.stop();
    if (isClosed) {
      await _deleteFile(path);
      return;
    }
    emit(1);
  }
}
''');

      expect(sites, isEmpty);
    });

    test('an isClosed guard with an else arm still clears the site', () {
      // Reaching past the `if` at all means the condition was false, so the
      // else arm does not stop this being a guard.
      final sites = scan('''
class FooCubit extends Cubit<int> {
  Future<void> load() async {
    final value = await _read();
    if (isClosed) {
      return;
    } else {
      _log('closed');
    }
    emit(value);
  }
}
''');

      expect(sites, isEmpty);
    });

    test('a guard inside a conditional arm does not clear the rest', () {
      // The arm may not run, so the await above it still reaches emit(2).
      final sites = scan('''
class FooCubit extends Cubit<int> {
  Future<void> load() async {
    await _read();
    if (flag) {
      if (isClosed) return;
      emit(1);
    }
    emit(2);
  }
}
''');

      expect(sites, hasLength(1));
      expect(sites.single.line, 8);
    });

    test('counts an emit above the await in a loop body', () {
      // The tail suspends before the head runs again, so from the second
      // iteration on this emit is reached across an await.
      final sites = scan('''
class FooCubit extends Cubit<int> {
  Future<void> load() async {
    for (final x in xs) {
      emit(x);
      await _read();
    }
  }
}
''');

      expect(sites, hasLength(1));
      expect(sites.single.line, 4);
    });

    test("another object's isClosed does not clear the site", () {
      // `_controller.isClosed` says nothing about whether this cubit is open.
      final sites = scan('''
class FooCubit extends Cubit<int> {
  Future<void> load() async {
    final value = await _read();
    if (_controller.isClosed) return;
    emit(value);
  }
}
''');

      expect(sites, hasLength(1));
    });

    test('counts an emit in a mixin on a cubit', () {
      // Scanning only classes would leave `mixin ... on Cubit` as a one-line
      // way past the ratchet.
      final sites = scan('''
mixin FooMixin on Cubit<int> {
  Future<void> load() async {
    final value = await _read();
    emit(value);
  }
}
''');

      expect(sites, hasLength(1));
      expect(sites.single.type, 'FooMixin');
    });

    test('emitIfOpen clears the site', () {
      final sites = scan('''
class FooCubit extends Cubit<int> with CloseGuardedEmit<int> {
  Future<void> load() async {
    final value = await _read();
    emitIfOpen(value);
  }
}
''');

      expect(sites, isEmpty);
    });

    test('counts a bloc add from a stream callback', () {
      final sites = scan('''
class FooBloc extends Bloc<FooEvent, int> {
  void watch() {
    _subscription = _stream.listen((value) => add(FooChanged(value)));
  }
}
''');

      expect(sites, hasLength(1));
      expect(sites.single.call, 'Bloc.add');
    });

    test('does not count a cascade add on a collection', () {
      final sites = scan('''
class FooBloc extends Bloc<FooEvent, int> {
  Future<void> _collect() async {
    final ids = await _read();
    final next = Set<String>.from(ids)..add('x');
    _ids = next;
  }
}
''');

      expect(sites, isEmpty);
    });

    test('does not count addError, which never throws after close', () {
      final sites = scan('''
class FooCubit extends Cubit<int> {
  Future<void> load() async {
    try {
      await _read();
    } catch (error, stackTrace) {
      addError(error, stackTrace);
    }
  }
}
''');

      expect(sites, isEmpty);
    });

    test('counts a catch emit after a guarded try body', () {
      // The guard only covers the try body. The catch can still run after the
      // awaited call fails, so its emit needs its own guard.
      final sites = scan('''
class FooCubit extends Cubit<int> {
  Future<void> load() async {
    try {
      final value = await _read();
      if (isClosed) return;
      emit(value);
    } catch (error) {
      emit(0);
    }
  }
}
''');

      expect(sites, hasLength(1));
      expect(sites.single.line, 8);
    });

    test('counts a finally emit after a guarded try body', () {
      // A try-body guard does not cover finally; the finally block still runs
      // after an awaited suspension and needs its own guard.
      final sites = scan('''
class FooCubit extends Cubit<int> {
  Future<void> load() async {
    try {
      final value = await _read();
      if (isClosed) return;
      emit(value);
    } finally {
      emit(0);
    }
  }
}
''');

      expect(sites, hasLength(1));
      expect(sites.single.line, 8);
    });

    test('an isClosed early return in a switch case clears that case', () {
      final sites = scan('''
class FooCubit extends Cubit<int> {
  Future<void> load(int value) async {
    await _read();
    switch (value) {
      case 1:
        if (isClosed) return;
        emit(1);
      default:
        emit(2);
    }
  }
}
''');

      expect(sites, hasLength(1));
      expect(sites.single.line, 9);
    });

    test('does not count emit( inside comments or string literals', () {
      final sites = scan('''
class FooCubit extends Cubit<int> {
  /// Was emit(value) before the close-guard pass.
  Future<void> load() async {
    await _read();
    /* emit(value) in a block comment */
    _log('emit(value) was skipped'); // emit(value)
  }
}
''');

      expect(sites, isEmpty);
    });

    test('ignores classes that are not blocs or cubits', () {
      final sites = scan('''
class FooService extends BaseService {
  Future<void> load() async {
    final value = await _read();
    emit(value);
  }
}
''');

      expect(sites, isEmpty);
    });

    test('reports sites sorted by path then line', () {
      File('${tmp.path}/lib/b_cubit.dart').writeAsStringSync('''
class BCubit extends Cubit<int> {
  Future<void> load() async {
    await _read();
    emit(1);
  }
}
''');
      File('${tmp.path}/lib/a_cubit.dart').writeAsStringSync('''
class ACubit extends Cubit<int> {
  Future<void> load() async {
    await _read();
    emit(1);
    emit(2);
  }
}
''');

      final sites = findPostCloseSites(
        Directory('${tmp.path}/lib'),
        pathPrefix: tmp.path,
      );

      expect(sites.map((s) => '${s.path}:${s.line}'), [
        'lib/a_cubit.dart:4',
        'lib/a_cubit.dart:5',
        'lib/b_cubit.dart:4',
      ]);
    });
  });

  group('post_close_emit_ceiling ratchet', () {
    late Directory tmp;
    late String scriptPath;
    late String baselinePath;

    void writeCubit(String name, int sites) {
      final emits = List.filled(sites, '    emit(value);').join('\n');
      File('${tmp.path}/lib/$name').writeAsStringSync('''
class ${name.split('.').first}Cubit extends Cubit<int> {
  Future<void> load() async {
    final value = await _read();
$emits
  }
}
''');
    }

    ProcessResult run({bool update = false}) {
      return Process.runSync(
        'bash',
        [scriptPath],
        environment: {
          'POST_CLOSE_EMIT_SCAN_DIR': '${tmp.path}/lib',
          'POST_CLOSE_EMIT_PATH_PREFIX': tmp.path,
          'POST_CLOSE_EMIT_BASELINE_FILE': baselinePath,
          'POST_CLOSE_EMIT_BASELINE_BASE_REF':
              'refs/heads/post-close-emit-test-no-base-ref',
          'POST_CLOSE_EMIT_CEILING_ALLOW_NO_BASE': '1',
          if (update) 'UPDATE_BASELINE': '1',
        },
      );
    }

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('post_close_emit_ratchet_test');
      Directory('${tmp.path}/lib').createSync(recursive: true);
      scriptPath = File(
        'scripts/check_post_close_emit_ceiling.sh',
      ).absolute.path;
      baselinePath = '${tmp.path}/baseline.txt';
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('UPDATE_BASELINE freezes the per-file count', () {
      writeCubit('a.dart', 2);
      writeCubit('b.dart', 0);

      final res = run(update: true);
      expect(res.exitCode, 0, reason: res.stderr.toString());

      final baseline = File(baselinePath)
          .readAsLinesSync()
          .where((l) => l.isNotEmpty && !l.startsWith('#'))
          .toList();
      expect(baseline, ['lib/a.dart\t2']);
    });

    test('fails when a baselined file gains a site', () {
      writeCubit('a.dart', 2);
      run(update: true);

      writeCubit('a.dart', 3);
      final res = run();
      expect(res.exitCode, 1);
      expect(res.stdout, contains('GREW past the frozen ceiling'));
    });

    test('passes when the count is unchanged', () {
      writeCubit('a.dart', 2);
      run(update: true);

      final res = run();
      expect(res.exitCode, 0, reason: res.stdout.toString());
      expect(res.stdout, contains('OK [post_close_emit_ceiling]'));
    });
  });
}
