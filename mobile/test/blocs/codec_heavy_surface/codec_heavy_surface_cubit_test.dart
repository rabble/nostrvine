import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/codec_heavy_surface/codec_heavy_surface_cubit.dart';

void main() {
  group(CodecHeavySurfaceCubit, () {
    late CodecHeavySurfaceCubit cubit;

    setUp(() => cubit = CodecHeavySurfaceCubit());
    tearDown(() => cubit.close());

    test('starts inactive', () {
      expect(cubit.state.activeCount, equals(0));
      expect(cubit.state.isActive, isFalse);
    });

    test('becomes active on enter and inactive again on exit', () {
      cubit.enter();
      expect(cubit.state.isActive, isTrue);

      cubit.exit();
      expect(cubit.state.isActive, isFalse);
    });

    test('stays active until the last nested surface leaves', () {
      cubit
        ..enter()
        ..enter();
      expect(cubit.state.activeCount, equals(2));
      expect(cubit.state.isActive, isTrue);

      cubit.exit();
      // One surface still open — stays asserted.
      expect(cubit.state.isActive, isTrue);

      cubit.exit();
      expect(cubit.state.isActive, isFalse);
    });

    test('exit below zero is clamped and a later enter still activates', () {
      cubit.exit();
      expect(cubit.state.activeCount, equals(0));
      expect(cubit.state.isActive, isFalse);

      cubit.enter();
      expect(cubit.state.isActive, isTrue);
    });
  });
}
