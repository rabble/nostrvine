import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/crosspost_settings/crosspost_settings_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';

class _MockCrosspostSettingsCubit extends MockCubit<CrosspostSettingsState>
    implements CrosspostSettingsCubit {}

void main() {
  group('BlueskySettingsScreen view', () {
    late _MockCrosspostSettingsCubit cubit;

    setUp(() {
      cubit = _MockCrosspostSettingsCubit();
    });

    Widget buildSubject() {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData.dark(),
        home: BlocProvider<CrosspostSettingsCubit>.value(
          value: cubit,
          child: Scaffold(
            body: BlocConsumer<CrosspostSettingsCubit, CrosspostSettingsState>(
              listener: (context, state) {
                if (state.status == CrosspostSettingsStatus.failure) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to update crosspost setting'),
                    ),
                  );
                }
              },
              builder: (context, state) {
                if (state.status == CrosspostSettingsStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ListView(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.cloud_upload),
                      title: const Text('Publish videos to Bluesky'),
                      subtitle: Text(
                        state.enabled
                            ? 'Your videos will be published to Bluesky'
                            : 'Your videos will not be published to Bluesky',
                      ),
                      value: state.enabled,
                      onChanged:
                          state.status == CrosspostSettingsStatus.toggling
                          ? null
                          : (value) => context
                                .read<CrosspostSettingsCubit>()
                                .toggleCrosspost(enabled: value),
                    ),
                    if (state.handle != null)
                      ListTile(
                        title: const Text('Bluesky Handle'),
                        subtitle: Text(state.handle!),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    }

    testWidgets('renders loading indicator when status is loading', (
      tester,
    ) async {
      when(() => cubit.state).thenReturn(
        const CrosspostSettingsState(status: CrosspostSettingsStatus.loading),
      );

      await tester.pumpWidget(buildSubject());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders toggle when loaded', (tester) async {
      when(() => cubit.state).thenReturn(
        const CrosspostSettingsState(
          status: CrosspostSettingsStatus.loaded,
          enabled: true,
          handle: 'testuser.divine.video',
          provisioningState: 'ready',
        ),
      );

      await tester.pumpWidget(buildSubject());

      expect(find.byType(SwitchListTile), findsOneWidget);
      expect(find.text('Publish videos to Bluesky'), findsOneWidget);
      expect(
        find.text('Your videos will be published to Bluesky'),
        findsOneWidget,
      );
    });

    testWidgets('renders handle when present', (tester) async {
      when(() => cubit.state).thenReturn(
        const CrosspostSettingsState(
          status: CrosspostSettingsStatus.loaded,
          enabled: true,
          handle: 'testuser.divine.video',
        ),
      );

      await tester.pumpWidget(buildSubject());

      expect(find.text('testuser.divine.video'), findsOneWidget);
    });

    testWidgets('calls toggleCrosspost when switch is tapped', (tester) async {
      when(() => cubit.state).thenReturn(
        const CrosspostSettingsState(
          status: CrosspostSettingsStatus.loaded,
          enabled: true,
          handle: 'testuser.divine.video',
        ),
      );
      when(
        () => cubit.toggleCrosspost(enabled: false),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byType(Switch));
      await tester.pump();

      verify(() => cubit.toggleCrosspost(enabled: false)).called(1);
    });

    testWidgets('shows disabled subtitle when crosspost is off', (
      tester,
    ) async {
      when(() => cubit.state).thenReturn(
        const CrosspostSettingsState(status: CrosspostSettingsStatus.loaded),
      );

      await tester.pumpWidget(buildSubject());

      expect(
        find.text('Your videos will not be published to Bluesky'),
        findsOneWidget,
      );
    });

    testWidgets('shows snackbar on failure', (tester) async {
      whenListen(
        cubit,
        Stream.fromIterable(const [
          CrosspostSettingsState(
            status: CrosspostSettingsStatus.failure,
            enabled: true,
          ),
        ]),
        initialState: const CrosspostSettingsState(
          status: CrosspostSettingsStatus.loaded,
          enabled: true,
        ),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.text('Failed to update crosspost setting'), findsOneWidget);
    });
  });
}
