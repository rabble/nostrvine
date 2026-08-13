// ABOUTME: Tests for the package-local compute() shim that replaced Flutter's.
// ABOUTME: Pins the result, error propagation, and real off-isolate execution.

import 'package:dm_repository/src/compute.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mutated by [_setFlagAndDouble] to prove the callback ran somewhere that does
/// not share this isolate's memory.
int _mainIsolateWitness = 0;

int _setFlagAndDouble(int value) {
  _mainIsolateWitness = value;
  return value * 2;
}

Future<String> _asyncEcho(String message) async {
  await null;
  return 'echo:$message';
}

int _alwaysThrows(int value) => throw StateError('boom $value');

void main() {
  group('compute', () {
    setUp(() => _mainIsolateWitness = 0);

    test('returns the callback result for the given message', () async {
      expect(await compute(_setFlagAndDouble, 21), 42);
    });

    test('awaits a callback that returns a Future', () async {
      expect(await compute(_asyncEcho, 'hi'), 'echo:hi');
    });

    test('runs the callback off this isolate', () async {
      await compute(_setFlagAndDouble, 7);

      // The callback assigned 7 to _mainIsolateWitness. Seeing 0 here is the
      // only observable proof it ran in a separate memory space rather than
      // inline — the assertion that fails if the shim stops using Isolate.run.
      expect(_mainIsolateWitness, 0);
    });

    test('propagates an error thrown by the callback', () async {
      await expectLater(
        compute(_alwaysThrows, 3),
        throwsA(
          isA<StateError>().having((e) => e.message, 'message', 'boom 3'),
        ),
      );
    });
  });
}
