import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/loudness_normalization/loudness_normalization_cubit.dart';
import 'package:openvine/blocs/loudness_normalization/loudness_normalization_prefs.dart';
import 'package:pooled_video_player/pooled_video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockPlayerPool extends Mock implements PlayerPool {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(LoudnessNormalizationCubit, () {
    late SharedPreferences prefs;
    late _MockPlayerPool playerPool;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
      playerPool = _MockPlayerPool();
      when(
        () => playerPool.setLoudnessNormalizationEnabled(
          enabled: any(named: 'enabled'),
        ),
      ).thenAnswer((_) async {});
    });

    LoudnessNormalizationCubit buildCubit() => LoudnessNormalizationCubit(
      sharedPreferences: prefs,
      playerPool: playerPool,
    );

    group('initial state', () {
      test('defaults isEnabled to false', () {
        final cubit = buildCubit();
        addTearDown(cubit.close);

        expect(cubit.state.isEnabled, isFalse);
      });

      test('reads persisted true from SharedPreferences', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          loudnessNormalizationPrefsKey: true,
        });
        final prefsWithValue = await SharedPreferences.getInstance();

        final cubit = LoudnessNormalizationCubit(
          sharedPreferences: prefsWithValue,
          playerPool: playerPool,
        );
        addTearDown(cubit.close);

        expect(cubit.state.isEnabled, isTrue);
      });

      test('reads persisted false from SharedPreferences', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          loudnessNormalizationPrefsKey: false,
        });
        final prefsWithValue = await SharedPreferences.getInstance();

        final cubit = LoudnessNormalizationCubit(
          sharedPreferences: prefsWithValue,
          playerPool: playerPool,
        );
        addTearDown(cubit.close);

        expect(cubit.state.isEnabled, isFalse);
      });

      test('does not call PlayerPool in the constructor', () {
        final cubit = buildCubit();
        addTearDown(cubit.close);

        verifyNever(
          () => playerPool.setLoudnessNormalizationEnabled(
            enabled: any(named: 'enabled'),
          ),
        );
      });
    });

    group('setEnabled', () {
      blocTest<LoudnessNormalizationCubit, LoudnessNormalizationState>(
        'emits new state when toggled on',
        build: buildCubit,
        act: (cubit) => cubit.setEnabled(enabled: true),
        expect: () => const [LoudnessNormalizationState(isEnabled: true)],
      );

      blocTest<LoudnessNormalizationCubit, LoudnessNormalizationState>(
        'does not emit when state is unchanged',
        build: buildCubit,
        act: (cubit) => cubit.setEnabled(enabled: false),
        expect: () => const <LoudnessNormalizationState>[],
      );

      test('persists new value to SharedPreferences', () async {
        final cubit = buildCubit();
        addTearDown(cubit.close);

        await cubit.setEnabled(enabled: true);

        expect(prefs.getBool(loudnessNormalizationPrefsKey), isTrue);
      });

      test('applies to PlayerPool', () async {
        final cubit = buildCubit();
        addTearDown(cubit.close);

        await cubit.setEnabled(enabled: true);

        verify(
          () => playerPool.setLoudnessNormalizationEnabled(enabled: true),
        ).called(1);
      });

      test('no-op skips PlayerPool and prefs writes', () async {
        // Seed prefs with existing value.
        SharedPreferences.setMockInitialValues(<String, Object>{
          loudnessNormalizationPrefsKey: true,
        });
        final seededPrefs = await SharedPreferences.getInstance();
        final cubit = LoudnessNormalizationCubit(
          sharedPreferences: seededPrefs,
          playerPool: playerPool,
        );
        addTearDown(cubit.close);

        // Toggling to the already-enabled state must be a no-op.
        await cubit.setEnabled(enabled: true);

        verifyNever(
          () => playerPool.setLoudnessNormalizationEnabled(
            enabled: any(named: 'enabled'),
          ),
        );
      });

      test('toggling off persists false and applies to pool', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          loudnessNormalizationPrefsKey: true,
        });
        final seededPrefs = await SharedPreferences.getInstance();
        final cubit = LoudnessNormalizationCubit(
          sharedPreferences: seededPrefs,
          playerPool: playerPool,
        );
        addTearDown(cubit.close);

        await cubit.setEnabled(enabled: false);

        expect(seededPrefs.getBool(loudnessNormalizationPrefsKey), isFalse);
        verify(
          () => playerPool.setLoudnessNormalizationEnabled(enabled: false),
        ).called(1);
      });
    });
  });
}
