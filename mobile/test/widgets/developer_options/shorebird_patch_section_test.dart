import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/shorebird_patch/shorebird_patch_cubit.dart';
import 'package:openvine/blocs/shorebird_patch/shorebird_patch_state.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/developer_options/shorebird_patch_section.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockShorebirdPatchCubit extends MockCubit<ShorebirdPatchState>
    implements ShorebirdPatchCubit {}

void main() {
  group(ShorebirdPatchView, () {
    late _MockShorebirdPatchCubit cubit;
    late AppLocalizations l10n;

    setUp(() {
      cubit = _MockShorebirdPatchCubit();
      when(() => cubit.checkStagingTrack()).thenAnswer((_) async {});
      when(() => cubit.applyStagedPatch()).thenAnswer((_) async {});
      l10n = lookupAppLocalizations(const Locale('en'));
    });

    Future<void> pumpWith(
      WidgetTester tester,
      ShorebirdPatchState state,
    ) async {
      whenListen(
        cubit,
        const Stream<ShorebirdPatchState>.empty(),
        initialState: state,
      );
      await tester.pumpWidget(
        testMaterialApp(
          home: BlocProvider<ShorebirdPatchCubit>.value(
            value: cubit,
            child: const Scaffold(body: ShorebirdPatchView()),
          ),
        ),
      );
    }

    testWidgets('says so plainly when the build has no updater', (
      tester,
    ) async {
      await pumpWith(
        tester,
        const ShorebirdPatchState(status: ShorebirdPatchStatus.unavailable),
      );

      expect(find.text(l10n.devOptionsShorebirdUnavailable), findsOneWidget);
      expect(
        find.text(l10n.devOptionsShorebirdUnavailableSubtitle),
        findsOneWidget,
      );
    });

    testWidgets('neither action fires when the updater is unavailable', (
      tester,
    ) async {
      await pumpWith(
        tester,
        const ShorebirdPatchState(status: ShorebirdPatchStatus.unavailable),
      );

      await tester.tap(find.text(l10n.devOptionsShorebirdCheck));
      await tester.tap(find.text(l10n.devOptionsShorebirdApply));
      await tester.pump();

      verifyNever(() => cubit.checkStagingTrack());
      verifyNever(() => cubit.applyStagedPatch());
    });

    testWidgets('shows the running patch number so it can be reported', (
      tester,
    ) async {
      await pumpWith(tester, const ShorebirdPatchState(currentPatchNumber: 4));

      expect(
        find.text(l10n.devOptionsShorebirdCurrentPatch(4)),
        findsOneWidget,
      );
    });

    testWidgets('shows no-patch when the release is running unpatched', (
      tester,
    ) async {
      await pumpWith(tester, const ShorebirdPatchState());

      expect(find.text(l10n.devOptionsShorebirdNoPatch), findsOneWidget);
    });

    testWidgets('checking the staging track targets staging', (tester) async {
      await pumpWith(tester, const ShorebirdPatchState());

      await tester.tap(find.text(l10n.devOptionsShorebirdCheck));
      await tester.pump();

      verify(() => cubit.checkStagingTrack()).called(1);
    });

    testWidgets('applying a staged patch asks the cubit to apply', (
      tester,
    ) async {
      await pumpWith(
        tester,
        const ShorebirdPatchState(
          status: ShorebirdPatchStatus.updateAvailable,
        ),
      );

      await tester.tap(find.text(l10n.devOptionsShorebirdApply));
      await tester.pump();

      verify(() => cubit.applyStagedPatch()).called(1);
    });

    testWidgets('both actions are inert while work is in flight', (
      tester,
    ) async {
      await pumpWith(
        tester,
        const ShorebirdPatchState(status: ShorebirdPatchStatus.checking),
      );

      await tester.tap(find.text(l10n.devOptionsShorebirdCheck));
      await tester.tap(find.text(l10n.devOptionsShorebirdApply));
      await tester.pump();

      verifyNever(() => cubit.checkStagingTrack());
      verifyNever(() => cubit.applyStagedPatch());
    });

    testWidgets('tells the tester a restart is needed after applying', (
      tester,
    ) async {
      await pumpWith(
        tester,
        const ShorebirdPatchState(status: ShorebirdPatchStatus.applied),
      );

      expect(find.text(l10n.devOptionsShorebirdApplied), findsOneWidget);
    });
  });
}
