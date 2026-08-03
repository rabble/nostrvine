import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/blocs/storage/storage_cubit.dart';
import 'package:openvine/constants/storage_cache_constants.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/screens/settings/storage/storage_management_page.dart';
import 'package:openvine/services/storage_management_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart' as editor;

class _MockService extends Mock implements StorageManagementService {}

DivineVideoClip _clip(String id) => DivineVideoClip(
  id: id,
  video: editor.EditorVideo.file(File('/tmp/$id.mp4')),
  duration: const Duration(seconds: 3),
  recordedAt: DateTime(2024),
  targetAspectRatio: model.AspectRatio.square,
  originalAspectRatio: 1,
);

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  Widget wrap(StorageCubit cubit) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider.value(
      value: cubit,
      child: const StorageManagementView(),
    ),
  );

  late _MockService service;

  setUpAll(() => registerFallbackValue(<DivineVideoClip>[]));

  setUp(() {
    service = _MockService();
    when(service.cacheSizeBytes).thenAnswer((_) async => 3 * 1024 * 1024);
    when(service.cacheLimitBytes).thenReturn(kCacheLimitDefaultBytes);
  });

  testWidgets('shows the cache size and both action buttons', (tester) async {
    final cubit = StorageCubit(service: service)..loadCacheSize();
    addTearDown(cubit.close);

    await tester.pumpWidget(wrap(cubit));
    await tester.pumpAndSettle();

    expect(
      find.text(l10n.settingsStorageCacheInUse('3.0 MB')),
      findsOneWidget,
    );
    expect(find.text(l10n.settingsStorageClearButton), findsOneWidget);
    expect(find.text(l10n.settingsStorageScanButton), findsOneWidget);
  });

  testWidgets('shows the cache-limit slider and approximate video count', (
    tester,
  ) async {
    final cubit = StorageCubit(service: service)..loadCacheSize();
    addTearDown(cubit.close);

    await tester.pumpWidget(wrap(cubit));
    await tester.pumpAndSettle();

    expect(find.text(l10n.settingsStorageMaxSizeLabel), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    // Default 2 GB budget / ~4 MB per video ≈ 512 videos.
    expect(
      find.text(l10n.settingsStorageApproxVideos(512)),
      findsOneWidget,
    );
  });

  testWidgets('a scan with no broken clips reports a healthy library', (
    tester,
  ) async {
    when(service.findBrokenClips).thenAnswer((_) async => []);
    final cubit = StorageCubit(service: service)..loadCacheSize();
    addTearDown(cubit.close);

    await tester.pumpWidget(wrap(cubit));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.settingsStorageScanButton));
    await tester.pumpAndSettle();

    expect(find.text(l10n.settingsStorageLibraryHealthy), findsOneWidget);
  });

  testWidgets('a scan with broken clips offers and performs removal', (
    tester,
  ) async {
    when(service.findBrokenClips).thenAnswer((_) async => [_clip('a')]);
    when(() => service.removeBrokenClips(any())).thenAnswer((_) async {});
    final cubit = StorageCubit(service: service)..loadCacheSize();
    addTearDown(cubit.close);

    await tester.pumpWidget(wrap(cubit));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.settingsStorageScanButton));
    await tester.pumpAndSettle();

    expect(
      find.text(l10n.settingsStorageBrokenClipsFound(1)),
      findsOneWidget,
    );

    await tester.tap(find.text(l10n.settingsStorageRemoveBrokenButton));
    await tester.pumpAndSettle();

    // A confirmation sheet gates the permanent removal.
    expect(
      find.text(l10n.settingsStorageRemoveBrokenConfirmTitle),
      findsOneWidget,
    );
    verifyNever(() => service.removeBrokenClips(any()));

    await tester.tap(find.text(l10n.commonDelete));
    await tester.pumpAndSettle();

    verify(() => service.removeBrokenClips(any())).called(1);
  });

  testWidgets('dragging the cache-size slider commits a new limit', (
    tester,
  ) async {
    when(() => service.setCacheLimit(any())).thenAnswer((_) async {});
    final cubit = StorageCubit(service: service)..loadCacheSize();
    addTearDown(cubit.close);

    await tester.pumpWidget(wrap(cubit));
    await tester.pumpAndSettle();

    // Drag ends -> onChangeEnd -> commitCacheLimit -> setCacheLimit.
    await tester.drag(find.byType(Slider), const Offset(120, 0));
    await tester.pumpAndSettle();

    verify(() => service.setCacheLimit(any())).called(1);
  });

  /// Scrolls the repair button into view and opens its confirmation sheet.
  Future<void> openRepairSheet(WidgetTester tester) async {
    final repair = find.text(l10n.settingsStorageRepairButton);
    await tester.scrollUntilVisible(repair, 200);
    await tester.ensureVisible(repair);
    await tester.pumpAndSettle();
    await tester.tap(repair);
    await tester.pumpAndSettle();
  }

  testWidgets('the repair wipe is gated behind a confirmation', (
    tester,
  ) async {
    var recovered = false;
    final cubit = StorageCubit(
      service: service,
      recoverAllCaches: () async {
        recovered = true;
        return true;
      },
      measureRecoveryFootprint: () async => 42 * 1024 * 1024,
    )..loadCacheSize();
    addTearDown(cubit.close);

    await tester.pumpWidget(wrap(cubit));
    await tester.pumpAndSettle();
    await openRepairSheet(tester);

    expect(find.text(l10n.settingsStorageRepairConfirmTitle), findsOneWidget);
    expect(recovered, isFalse);

    await tester.tap(find.text(l10n.settingsStorageRepairConfirmAction));
    await tester.pumpAndSettle();

    expect(recovered, isTrue);
    expect(find.text(l10n.settingsStorageRepairSuccess), findsOneWidget);
  });

  testWidgets('the confirmation sheet reports what the repair frees', (
    tester,
  ) async {
    final cubit = StorageCubit(
      service: service,
      measureRecoveryFootprint: () async => 42 * 1024 * 1024,
    )..loadCacheSize();
    addTearDown(cubit.close);

    await tester.pumpWidget(wrap(cubit));
    await tester.pumpAndSettle();

    // The size belongs to the decision, not to the screen — nothing is
    // measured or shown until the sheet opens.
    expect(
      find.text(l10n.settingsStorageRepairFootprint('42 MB')),
      findsNothing,
    );

    await openRepairSheet(tester);

    expect(
      find.text(l10n.settingsStorageRepairFootprint('42 MB')),
      findsOneWidget,
    );
  });

  testWidgets('a failed measurement leaves the sheet usable without a size', (
    tester,
  ) async {
    var recovered = false;
    final cubit = StorageCubit(
      service: service,
      recoverAllCaches: () async {
        recovered = true;
        return true;
      },
      measureRecoveryFootprint: () async => throw Exception('boom'),
    )..loadCacheSize();
    addTearDown(cubit.close);

    await tester.pumpWidget(wrap(cubit));
    await tester.pumpAndSettle();
    await openRepairSheet(tester);

    expect(find.text(l10n.settingsStorageRepairConfirmTitle), findsOneWidget);
    expect(find.text(l10n.settingsStorageMeasuring), findsNothing);

    await tester.tap(find.text(l10n.settingsStorageRepairConfirmAction));
    await tester.pumpAndSettle();

    expect(recovered, isTrue);
  });

  testWidgets('a failed repair says so on the screen', (tester) async {
    final cubit = StorageCubit(
      service: service,
      recoverAllCaches: () async => false,
      measureRecoveryFootprint: () async => 0,
    )..loadCacheSize();
    addTearDown(cubit.close);

    await tester.pumpWidget(wrap(cubit));
    await tester.pumpAndSettle();
    await openRepairSheet(tester);

    await tester.tap(find.text(l10n.settingsStorageRepairConfirmAction));
    await tester.pumpAndSettle();

    expect(find.text(l10n.settingsStorageRepairFailure), findsOneWidget);
  });
}
