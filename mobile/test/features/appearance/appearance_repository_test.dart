// ABOUTME: Tests for the local appearance preference repository.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/features/appearance/models/appearance_mode.dart';
import 'package:openvine/features/appearance/repositories/appearance_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockSharedPreferences extends Mock implements SharedPreferences {}

void main() {
  group(AppearanceRepository, () {
    late _MockSharedPreferences prefs;
    late AppearanceRepository repository;

    setUp(() {
      prefs = _MockSharedPreferences();
      repository = AppearanceRepository(prefs);
    });

    test('loads the default mode when no preference is stored', () {
      when(
        () => prefs.getString('appearance_mode_preference'),
      ).thenReturn(null);

      expect(repository.load(), completion(equals(defaultAppearanceMode)));
    });

    test('loads a stored Light preference', () {
      when(
        () => prefs.getString('appearance_mode_preference'),
      ).thenReturn('light');

      expect(repository.load(), completion(equals(AppearanceMode.light)));
    });

    test('loads a stored System preference', () {
      when(
        () => prefs.getString('appearance_mode_preference'),
      ).thenReturn('system');

      expect(repository.load(), completion(equals(AppearanceMode.system)));
    });

    test('invalid stored values fall back to the default mode', () {
      when(
        () => prefs.getString('appearance_mode_preference'),
      ).thenReturn('sepia');

      expect(repository.load(), completion(equals(defaultAppearanceMode)));
    });

    test('saves the enum name', () async {
      when(
        () => prefs.setString('appearance_mode_preference', 'dark'),
      ).thenAnswer((_) async => true);

      await repository.save(AppearanceMode.dark);

      verify(
        () => prefs.setString('appearance_mode_preference', 'dark'),
      ).called(1);
    });

    test('reports a failed write', () async {
      when(
        () => prefs.setString('appearance_mode_preference', 'light'),
      ).thenAnswer((_) async => false);

      expect(
        () => repository.save(AppearanceMode.light),
        throwsA(isA<StateError>()),
      );
    });
  });
}
