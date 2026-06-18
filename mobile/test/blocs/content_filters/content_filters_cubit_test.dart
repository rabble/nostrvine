// ABOUTME: Unit tests for ContentFiltersCubit — load snapshot, persistence,
// ABOUTME: and the re-read-after-write age-gate semantics.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/content_filters/content_filters_cubit.dart';
import 'package:openvine/blocs/content_filters/content_filters_state.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/services/content_filter_service.dart';

class _MockContentFilterService extends Mock implements ContentFilterService {}

class _MockAgeVerificationService extends Mock
    implements AgeVerificationService {}

void main() {
  setUpAll(() {
    registerFallbackValue(ContentLabel.nudity);
    registerFallbackValue(ContentFilterPreference.show);
  });

  group(ContentFiltersState, () {
    test('locks always-filtered labels regardless of age verification', () {
      expect(
        const ContentFiltersState(
          isAgeVerified: true,
        ).isLabelLocked(ContentLabel.porn),
        isTrue,
      );
    });

    test('locks age-restricted labels only until age verified', () {
      expect(
        const ContentFiltersState().isLabelLocked(ContentLabel.gambling),
        isTrue,
      );
      expect(
        const ContentFiltersState(
          isAgeVerified: true,
        ).isLabelLocked(ContentLabel.gambling),
        isFalse,
      );
    });

    test('does not lock unrestricted visible labels', () {
      expect(
        const ContentFiltersState().isLabelLocked(ContentLabel.flashingLights),
        isFalse,
      );
    });
  });

  group(ContentFiltersCubit, () {
    late _MockContentFilterService filterService;
    late _MockAgeVerificationService ageService;

    setUp(() {
      filterService = _MockContentFilterService();
      ageService = _MockAgeVerificationService();
      when(filterService.initialize).thenAnswer((_) async {});
      when(ageService.initialize).thenAnswer((_) async {});
      when(
        () => filterService.getPreference(any()),
      ).thenReturn(ContentFilterPreference.show);
      when(
        () => filterService.setPreference(any(), any()),
      ).thenAnswer((_) async {});
      when(() => ageService.isAdultContentVerified).thenReturn(false);
    });

    ContentFiltersCubit buildCubit() => ContentFiltersCubit(
      contentFilterService: filterService,
      ageVerificationService: ageService,
    );

    blocTest<ContentFiltersCubit, ContentFiltersState>(
      'load initializes both services and snapshots every label',
      setUp: () {
        when(() => ageService.isAdultContentVerified).thenReturn(true);
        when(
          () => filterService.getPreference(ContentLabel.flashingLights),
        ).thenReturn(ContentFilterPreference.hide);
      },
      build: buildCubit,
      act: (cubit) => cubit.load(),
      expect: () => [
        const ContentFiltersState(),
        isA<ContentFiltersState>()
            .having((s) => s.status, 'status', ContentFiltersStatus.ready)
            .having((s) => s.isAgeVerified, 'isAgeVerified', true)
            .having(
              (s) => s.preferenceFor(ContentLabel.flashingLights),
              'flashingLights',
              ContentFilterPreference.hide,
            )
            .having(
              (s) => s.preferences.length,
              'all labels snapshotted',
              ContentLabel.values.length,
            ),
      ],
      verify: (_) {
        verify(filterService.initialize).called(1);
        verify(ageService.initialize).called(1);
      },
    );

    blocTest<ContentFiltersCubit, ContentFiltersState>(
      'setPreference persists then emits the re-read stored value',
      seed: () => ContentFiltersState(
        status: ContentFiltersStatus.ready,
        isAgeVerified: true,
        preferences: {
          for (final label in ContentLabel.values)
            label: ContentFilterPreference.show,
        },
      ),
      setUp: () {
        when(
          () => filterService.getPreference(ContentLabel.flashingLights),
        ).thenReturn(ContentFilterPreference.hide);
      },
      build: buildCubit,
      act: (cubit) => cubit.setPreference(
        ContentLabel.flashingLights,
        ContentFilterPreference.hide,
      ),
      expect: () => [
        isA<ContentFiltersState>().having(
          (s) => s.preferenceFor(ContentLabel.flashingLights),
          'flashingLights',
          ContentFilterPreference.hide,
        ),
      ],
      verify: (_) {
        verify(
          () => filterService.setPreference(
            ContentLabel.flashingLights,
            ContentFilterPreference.hide,
          ),
        ).called(1);
      },
    );

    blocTest<ContentFiltersCubit, ContentFiltersState>(
      'setPreference emits nothing when the re-read stored value is unchanged',
      seed: () => ContentFiltersState(
        status: ContentFiltersStatus.ready,
        preferences: {
          for (final label in ContentLabel.values)
            label: ContentFilterPreference.show,
        },
      ),
      setUp: () {
        // Age gate rejects enabling adult content: stored value stays "show".
        when(
          () => filterService.getPreference(ContentLabel.porn),
        ).thenReturn(ContentFilterPreference.show);
      },
      build: buildCubit,
      act: (cubit) =>
          cubit.setPreference(ContentLabel.porn, ContentFilterPreference.hide),
      // The re-read value (show) equals current state, so no new state emits —
      // proving the Cubit emits the stored value, not the requested one.
      expect: () => const <ContentFiltersState>[],
      verify: (_) {
        verify(
          () => filterService.setPreference(
            ContentLabel.porn,
            ContentFilterPreference.hide,
          ),
        ).called(1);
      },
    );
  });
}
