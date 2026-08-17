// ABOUTME: Tests for ClipRecoveryCubit — scan, claim, and rebuild flows.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/clip_recovery/clip_recovery_cubit.dart';
import 'package:openvine/models/clip_recovery.dart';
import 'package:openvine/services/clip_recovery_service.dart';

class _MockService extends Mock implements ClipRecoveryService {}

class _FakeOwnerGroup extends Fake implements ClipOwnerGroup {}

const _group = ClipOwnerGroup(
  ownerPubkey:
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  clipCount: 3,
  draftCount: 1,
);

const _found = ClipRecoveryReport(
  currentOwnerPubkey:
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
  ownedClipCount: 0,
  ownedDraftCount: 0,
  foreignGroups: [_group],
  orphanFiles: [],
);

final _firstOrphan = OrphanClipFile(
  path: '/documents/VID_1755400000000.mp4',
  sizeBytes: 2048,
  modifiedAt: DateTime(2026, 8, 17),
  duration: const Duration(seconds: 6),
  previewPath: '/documents/VID_1755400000000.mp4.jpg',
);

final _secondOrphan = OrphanClipFile(
  path: '/documents/VID_1755400000001.mp4',
  sizeBytes: 4096,
  modifiedAt: DateTime(2026, 8, 16),
  duration: const Duration(seconds: 3),
  previewPath: '/documents/VID_1755400000001.mp4.jpg',
);

final _withOrphans = ClipRecoveryReport(
  currentOwnerPubkey: _found.currentOwnerPubkey,
  ownedClipCount: 0,
  ownedDraftCount: 0,
  foreignGroups: const [],
  orphanFiles: [_firstOrphan, _secondOrphan],
);

final _afterClaim = ClipRecoveryReport(
  currentOwnerPubkey: _found.currentOwnerPubkey,
  ownedClipCount: 3,
  ownedDraftCount: 1,
  foreignGroups: const [],
  orphanFiles: const [],
);

void main() {
  setUpAll(() => registerFallbackValue(_FakeOwnerGroup()));

  group(ClipRecoveryCubit, () {
    late _MockService service;

    setUp(() => service = _MockService());

    blocTest<ClipRecoveryCubit, ClipRecoveryState>(
      'scan surfaces the groups the current account cannot see',
      build: () {
        when(
          service.scanRecoverableClips,
        ).thenAnswer((_) async => _found);
        return ClipRecoveryCubit(service: service);
      },
      act: (cubit) => cubit.scan(),
      expect: () => [
        const ClipRecoveryState(status: ClipRecoveryStatus.scanning),
        const ClipRecoveryState(
          status: ClipRecoveryStatus.scanned,
          report: _found,
        ),
      ],
    );

    blocTest<ClipRecoveryCubit, ClipRecoveryState>(
      'scan reports failure rather than an empty report',
      build: () {
        when(service.scanRecoverableClips).thenThrow(StateError('no db'));
        return ClipRecoveryCubit(service: service);
      },
      act: (cubit) => cubit.scan(),
      expect: () => [
        const ClipRecoveryState(status: ClipRecoveryStatus.scanning),
        const ClipRecoveryState(status: ClipRecoveryStatus.failure),
      ],
      errors: () => [isA<StateError>()],
    );

    blocTest<ClipRecoveryCubit, ClipRecoveryState>(
      'claiming re-scans so the group disappears from the report',
      build: () {
        var scans = 0;
        when(
          service.scanRecoverableClips,
        ).thenAnswer((_) async => scans++ == 0 ? _found : _afterClaim);
        when(() => service.claimOwnerGroup(any())).thenAnswer((_) async => 3);
        return ClipRecoveryCubit(service: service);
      },
      act: (cubit) async {
        await cubit.scan();
        await cubit.claimOwnerGroup(_group);
      },
      skip: 2,
      expect: () => [
        const ClipRecoveryState(
          status: ClipRecoveryStatus.claiming,
          report: _found,
        ),
        ClipRecoveryState(
          status: ClipRecoveryStatus.claimed,
          report: _afterClaim,
          lastRecoveredCount: 3,
        ),
      ],
    );

    blocTest<ClipRecoveryCubit, ClipRecoveryState>(
      'rebuilding restores only the file the operator picked',
      build: () {
        when(
          service.scanRecoverableClips,
        ).thenAnswer((_) async => _withOrphans);
        when(
          () => service.importOrphanFiles(any()),
        ).thenAnswer((_) async => const []);
        return ClipRecoveryCubit(service: service);
      },
      act: (cubit) async {
        await cubit.scan();
        await cubit.importOrphanFile(_secondOrphan);
      },
      skip: 3,
      verify: (_) => verify(
        () => service.importOrphanFiles([_secondOrphan]),
      ).called(1),
    );
  });
}
