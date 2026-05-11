import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_volume/video_volume_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/subtitle_providers.dart';
import 'package:openvine/screens/feed/feed_auto_advance_cubit.dart';
import 'package:openvine/widgets/video_feed_item/feed_playback_toggles_pill.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockVideoVolumeCubit extends MockCubit<VideoVolumeState>
    implements VideoVolumeCubit {}

void main() {
  group(FeedPlaybackTogglesPill, () {
    late FeedAutoAdvanceCubit autoAdvanceCubit;
    late VideoVolumeCubit volumeCubit;
    late SharedPreferences mockPrefs;

    final l10n = lookupAppLocalizations(const Locale('en'));

    setUp(() {
      autoAdvanceCubit = FeedAutoAdvanceCubit();
      volumeCubit = _MockVideoVolumeCubit();
      when(() => volumeCubit.state).thenReturn(const VideoVolumeState());
      mockPrefs = createMockSharedPreferences();
    });

    tearDown(() async {
      await autoAdvanceCubit.close();
    });

    Widget buildSubject({
      bool reducedMotion = false,
      bool provideAutoAdvance = true,
    }) {
      Widget pill = const Scaffold(body: FeedPlaybackTogglesPill());

      pill = provideAutoAdvance
          ? MultiBlocProvider(
              providers: [
                BlocProvider<FeedAutoAdvanceCubit>.value(
                  value: autoAdvanceCubit,
                ),
                BlocProvider<VideoVolumeCubit>.value(value: volumeCubit),
              ],
              child: pill,
            )
          : BlocProvider<VideoVolumeCubit>.value(
              value: volumeCubit,
              child: pill,
            );

      return ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reducedMotion),
            child: pill,
          ),
        ),
      );
    }

    testWidgets('renders all three toggles when cubits are in scope', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      expect(
        find.bySemanticsLabel(l10n.videoActionEnableAutoAdvance),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(l10n.videoPlayerMute), findsOneWidget);
      expect(
        find.bySemanticsLabel(l10n.videoSettingsCaptionsDisable),
        findsOneWidget,
      );
    });

    testWidgets('hides the compilations toggle under reduced motion', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(reducedMotion: true));
      expect(
        find.bySemanticsLabel(l10n.videoActionEnableAutoAdvance),
        findsNothing,
      );
      expect(
        find.bySemanticsLabel(l10n.videoActionDisableAutoAdvance),
        findsNothing,
      );
      expect(find.bySemanticsLabel(l10n.videoPlayerMute), findsOneWidget);
    });

    testWidgets('tapping the captions toggle flips subtitle visibility', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
      );
      addTearDown(container.dispose);
      // Keep the provider subscribed so auto-dispose timers don't fire
      // mid-test and trip the timer-pending invariant in testWidgets.
      container.listen(subtitleVisibilityProvider, (_, _) {});
      expect(container.read(subtitleVisibilityProvider), isTrue);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MultiBlocProvider(
              providers: [
                BlocProvider<FeedAutoAdvanceCubit>.value(
                  value: autoAdvanceCubit,
                ),
                BlocProvider<VideoVolumeCubit>.value(value: volumeCubit),
              ],
              child: const Scaffold(body: FeedPlaybackTogglesPill()),
            ),
          ),
        ),
      );

      await tester.tap(
        find.bySemanticsLabel(l10n.videoSettingsCaptionsDisable),
      );
      await tester.pump();
      expect(container.read(subtitleVisibilityProvider), isFalse);
    });

    testWidgets(
      'tapping the mute toggle calls VideoVolumeCubit.onPlaybackVolumeChanged',
      (tester) async {
        await tester.pumpWidget(buildSubject());

        await tester.tap(find.bySemanticsLabel(l10n.videoPlayerMute));
        await tester.pump();

        verify(() => volumeCubit.onPlaybackVolumeChanged(0)).called(1);
      },
    );

    testWidgets(
      'tapping the compilations toggle calls FeedAutoAdvanceCubit.toggle',
      (tester) async {
        expect(autoAdvanceCubit.state.enabled, isFalse);
        await tester.pumpWidget(buildSubject());

        await tester.tap(
          find.bySemanticsLabel(l10n.videoActionEnableAutoAdvance),
        );
        await tester.pump();

        expect(autoAdvanceCubit.state.enabled, isTrue);
      },
    );

    testWidgets('renders without the compilations toggle when '
        'FeedAutoAdvanceCubit is not provided', (tester) async {
      await tester.pumpWidget(buildSubject(provideAutoAdvance: false));

      expect(
        find.bySemanticsLabel(l10n.videoActionEnableAutoAdvance),
        findsNothing,
      );
      expect(find.bySemanticsLabel(l10n.videoPlayerMute), findsOneWidget);
    });
  });
}
