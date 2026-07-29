import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/loop_restarts.dart';

void main() {
  group(loopRestarts, () {
    Future<int> countRestarts(List<int> positionsMs) async {
      final restarts = loopRestarts(
        Stream.fromIterable(
          positionsMs.map((ms) => Duration(milliseconds: ms)),
        ),
      );
      return restarts.length;
    }

    test('emits once per wrap back to the start', () async {
      // 0 → 5000, wrap, 0 → 5000, wrap: two loops of a five-second clip.
      expect(
        await countRestarts([0, 2500, 5000, 0, 2500, 5000, 0]),
        2,
      );
    });

    test('stays silent while the position only moves forward', () async {
      expect(await countRestarts([0, 1000, 2000, 3000, 4000]), 0);
    });

    test('ignores small backwards jitter from the native clock', () async {
      // Position updates are not monotonic to the millisecond; treating every
      // backwards tick as a restart would re-seek the backdrop constantly.
      expect(await countRestarts([1000, 990, 1005, 1002, 1100]), 0);
    });

    test('emits for a wrap even on a very short clip', () async {
      expect(await countRestarts([0, 400, 800, 0, 400]), 1);
    });

    test('emits nothing for a single position', () async {
      expect(await countRestarts([1234]), 0);
    });
  });
}
