// ABOUTME: Tests showNewPeopleListSheet's curatedLists gate.
// ABOUTME: The sheet reads the lazily-registered global PeopleListsBloc.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/profile/new_people_list_sheet.dart';

class _MockPeopleListsBloc extends MockBloc<PeopleListsEvent, PeopleListsState>
    implements PeopleListsBloc {}

void main() {
  group('showNewPeopleListSheet', () {
    late _MockPeopleListsBloc bloc;

    setUp(() {
      bloc = _MockPeopleListsBloc();
      whenListen(
        bloc,
        const Stream<PeopleListsState>.empty(),
        initialState: const PeopleListsState(),
      );
    });

    tearDown(() async {
      await bloc.close();
    });

    // The global PeopleListsBloc is registered unconditionally in main.dart
    // (a conditional entry re-inflated the Navigator on every flag flip), so
    // BlocProvider laziness is what keeps it unbuilt while curated lists are
    // off. `create` firing means a repository and relay subscription started
    // for a disabled feature.
    testWidgets(
      'does not open or construct $PeopleListsBloc when curatedLists is off',
      (tester) async {
        var blocCreated = false;

        await tester.pumpWidget(
          _buildSubject(
            curatedListsEnabled: false,
            createBloc: () {
              blocCreated = true;
              return bloc;
            },
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(blocCreated, isFalse);
        expect(find.text('New people list'), findsNothing);
      },
    );

    testWidgets('opens when curatedLists is on', (tester) async {
      await tester.pumpWidget(
        _buildSubject(curatedListsEnabled: true, createBloc: () => bloc),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('New people list'), findsOneWidget);
    });
  });
}

/// Mirrors the app shell: a lazy `BlocProvider` above the navigator, so
/// [createBloc] only runs if something below actually reads the bloc.
Widget _buildSubject({
  required bool curatedListsEnabled,
  required PeopleListsBloc Function() createBloc,
}) {
  return ProviderScope(
    overrides: [
      isFeatureEnabledProvider(
        FeatureFlag.curatedLists,
      ).overrideWithValue(curatedListsEnabled),
    ],
    child: BlocProvider<PeopleListsBloc>(
      create: (_) => createBloc(),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showNewPeopleListSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}
