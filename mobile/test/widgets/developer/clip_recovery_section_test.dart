// ABOUTME: Widget tests for the developer clip-recovery section.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/clip_recovery/clip_recovery_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/clip_recovery.dart';
import 'package:openvine/services/clip_recovery_service.dart';
import 'package:openvine/widgets/developer/clip_recovery_section.dart';

class _MockService extends Mock implements ClipRecoveryService {}

const _hiddenOwner =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  late _MockService service;

  setUp(() => service = _MockService());

  Widget wrap(ClipRecoveryCubit cubit) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: BlocProvider.value(
        value: cubit,
        child: const SingleChildScrollView(child: ClipRecoveryView()),
      ),
    ),
  );

  testWidgets('shows a hidden owner with its untruncated pubkey', (
    tester,
  ) async {
    when(service.scanRecoverableClips).thenAnswer(
      (_) async => const ClipRecoveryReport(
        currentOwnerPubkey: 'bb',
        ownedClipCount: 0,
        ownedDraftCount: 0,
        foreignGroups: [
          ClipOwnerGroup(
            ownerPubkey: _hiddenOwner,
            clipCount: 12,
            draftCount: 2,
          ),
        ],
        orphanFiles: [],
      ),
    );
    final cubit = ClipRecoveryCubit(service: service);
    addTearDown(cubit.close);

    await tester.pumpWidget(wrap(cubit));
    await tester.tap(find.text(l10n.devOptionsClipRecoveryScan));
    await tester.pumpAndSettle();

    expect(find.text(l10n.devOptionsClipRecoveryOtherAccounts), findsOneWidget);
    // The operator hands another account's rows over based on this value, so
    // it has to be readable in full.
    expect(find.text(_hiddenOwner), findsOneWidget);
    expect(find.text(l10n.devOptionsClipRecoveryCounts(12, 2)), findsOneWidget);
    expect(find.text(l10n.devOptionsClipRecoveryClaim), findsOneWidget);
  });

  testWidgets('offers a rebuild for unreferenced files', (tester) async {
    when(service.scanRecoverableClips).thenAnswer(
      (_) async => ClipRecoveryReport(
        currentOwnerPubkey: 'bb',
        ownedClipCount: 0,
        ownedDraftCount: 0,
        foreignGroups: const [],
        orphanFiles: [
          OrphanClipFile(
            path: '/documents/VID_1755400000000.mp4',
            sizeBytes: 2 * 1024 * 1024,
            modifiedAt: DateTime(2026, 8, 17),
          ),
        ],
      ),
    );
    when(() => service.importOrphanFiles(any())).thenAnswer((_) async => []);
    final cubit = ClipRecoveryCubit(service: service);
    addTearDown(cubit.close);

    await tester.pumpWidget(wrap(cubit));
    await tester.tap(find.text(l10n.devOptionsClipRecoveryScan));
    await tester.pumpAndSettle();

    expect(find.text('VID_1755400000000.mp4'), findsOneWidget);

    await tester.tap(find.text(l10n.devOptionsClipRecoveryImport));
    await tester.pumpAndSettle();

    verify(() => service.importOrphanFiles(any())).called(1);
  });

  testWidgets('says so when there is nothing to recover', (tester) async {
    when(service.scanRecoverableClips).thenAnswer(
      (_) async => const ClipRecoveryReport(
        currentOwnerPubkey: 'bb',
        ownedClipCount: 4,
        ownedDraftCount: 1,
        foreignGroups: [],
        orphanFiles: [],
      ),
    );
    final cubit = ClipRecoveryCubit(service: service);
    addTearDown(cubit.close);

    await tester.pumpWidget(wrap(cubit));
    await tester.tap(find.text(l10n.devOptionsClipRecoveryScan));
    await tester.pumpAndSettle();

    expect(find.text(l10n.devOptionsClipRecoveryEmpty), findsOneWidget);
    expect(find.text(l10n.devOptionsClipRecoveryVisible(4, 1)), findsOneWidget);
  });
}
