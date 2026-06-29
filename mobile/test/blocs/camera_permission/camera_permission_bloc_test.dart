import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/camera_permission/camera_permission_bloc.dart';
import 'package:permissions_service/permissions_service.dart';

class _MockPermissionsService extends Mock implements PermissionsService {}

void main() {
  group('CameraPermissionBloc', () {
    late _MockPermissionsService mockPermissionsService;

    setUp(() {
      mockPermissionsService = _MockPermissionsService();
    });

    group('initial state', () {
      test('is CameraPermissionInitial', () {
        final bloc = CameraPermissionBloc(
          permissionsService: mockPermissionsService,
        );
        expect(bloc.state, isA<CameraPermissionInitial>());
      });
    });

    group('CameraPermissionRequest', () {
      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'does nothing when state is CameraPermissionInitial',
        build: () => CameraPermissionBloc(
          permissionsService: mockPermissionsService,
          skipMacOSBypass: true,
        ),
        act: (bloc) => bloc.add(const CameraPermissionRequest()),
        expect: () => <CameraPermissionState>[],
      );

      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'does nothing when state is CameraPermissionLoading',
        build: () => CameraPermissionBloc(
          permissionsService: mockPermissionsService,
          skipMacOSBypass: true,
        ),
        seed: () => const CameraPermissionLoading(),
        act: (bloc) => bloc.add(const CameraPermissionRequest()),
        expect: () => <CameraPermissionState>[],
      );

      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'does nothing when status is authorized',
        build: () => CameraPermissionBloc(
          permissionsService: mockPermissionsService,
          skipMacOSBypass: true,
        ),
        seed: () =>
            const CameraPermissionLoaded(CameraPermissionStatus.authorized),
        act: (bloc) => bloc.add(const CameraPermissionRequest()),
        expect: () => <CameraPermissionState>[],
        verify: (_) {
          verifyNever(() => mockPermissionsService.requestCameraPermission());
        },
      );

      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'does nothing when status is requiresSettings',
        build: () => CameraPermissionBloc(
          permissionsService: mockPermissionsService,
          skipMacOSBypass: true,
        ),
        seed: () => const CameraPermissionLoaded(
          CameraPermissionStatus.requiresSettings,
        ),
        act: (bloc) => bloc.add(const CameraPermissionRequest()),
        expect: () => <CameraPermissionState>[],
        verify: (_) {
          verifyNever(() => mockPermissionsService.requestCameraPermission());
        },
      );

      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'emits [Loaded(authorized)] when both permissions granted',
        setUp: () {
          when(
            () => mockPermissionsService.requestCameraPermission(),
          ).thenAnswer((_) async => PermissionStatus.granted);
          when(
            () => mockPermissionsService.requestMicrophonePermission(),
          ).thenAnswer((_) async => PermissionStatus.granted);
          when(
            () => mockPermissionsService.requestGalleryPermission(),
          ).thenAnswer((_) async => PermissionStatus.granted);
        },
        build: () => CameraPermissionBloc(
          permissionsService: mockPermissionsService,
          skipMacOSBypass: true,
        ),
        seed: () =>
            const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
        act: (bloc) => bloc.add(const CameraPermissionRequest()),
        expect: () => [
          const CameraPermissionLoaded(CameraPermissionStatus.authorized),
        ],
      );

      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'stays on Loaded(canRequest) when camera request stays requestable',
        setUp: () {
          when(
            () => mockPermissionsService.requestCameraPermission(),
          ).thenAnswer((_) async => PermissionStatus.canRequest);
        },
        build: () => CameraPermissionBloc(
          permissionsService: mockPermissionsService,
          skipMacOSBypass: true,
        ),
        seed: () =>
            const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
        act: (bloc) => bloc.add(const CameraPermissionRequest()),
        // Mapped status equals the seeded state, so no new state is emitted —
        // the gate keeps showing the canRequest prompt for a retry.
        expect: () => <CameraPermissionState>[],
        verify: (_) {
          verify(
            () => mockPermissionsService.requestCameraPermission(),
          ).called(1);
          verifyNever(
            () => mockPermissionsService.requestMicrophonePermission(),
          );
        },
      );

      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'stays on Loaded(canRequest) when microphone request stays requestable',
        setUp: () {
          when(
            () => mockPermissionsService.requestCameraPermission(),
          ).thenAnswer((_) async => PermissionStatus.granted);
          when(
            () => mockPermissionsService.requestMicrophonePermission(),
          ).thenAnswer((_) async => PermissionStatus.canRequest);
        },
        build: () => CameraPermissionBloc(
          permissionsService: mockPermissionsService,
          skipMacOSBypass: true,
        ),
        seed: () =>
            const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
        act: (bloc) => bloc.add(const CameraPermissionRequest()),
        expect: () => <CameraPermissionState>[],
        verify: (_) {
          verify(
            () => mockPermissionsService.requestCameraPermission(),
          ).called(1);
          verify(
            () => mockPermissionsService.requestMicrophonePermission(),
          ).called(1);
        },
      );

      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'emits [Loaded(authorized)] when gallery permission denied '
        '(gallery is optional)',
        setUp: () {
          when(
            () => mockPermissionsService.requestCameraPermission(),
          ).thenAnswer((_) async => PermissionStatus.granted);
          when(
            () => mockPermissionsService.requestMicrophonePermission(),
          ).thenAnswer((_) async => PermissionStatus.granted);
          when(
            () => mockPermissionsService.requestGalleryPermission(),
          ).thenAnswer((_) async => PermissionStatus.canRequest);
        },
        build: () => CameraPermissionBloc(
          permissionsService: mockPermissionsService,
          skipMacOSBypass: true,
        ),
        seed: () =>
            const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
        act: (bloc) => bloc.add(const CameraPermissionRequest()),
        expect: () => [
          const CameraPermissionLoaded(CameraPermissionStatus.authorized),
        ],
      );

      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'emits Loaded(requiresSettings) when camera permission is blocked',
        setUp: () {
          when(
            () => mockPermissionsService.requestCameraPermission(),
          ).thenAnswer((_) async => PermissionStatus.requiresSettings);
        },
        build: () => CameraPermissionBloc(
          permissionsService: mockPermissionsService,
          skipMacOSBypass: true,
        ),
        seed: () =>
            const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
        act: (bloc) => bloc.add(const CameraPermissionRequest()),
        expect: () => [
          const CameraPermissionLoaded(CameraPermissionStatus.requiresSettings),
        ],
        verify: (_) {
          verifyNever(
            () => mockPermissionsService.requestMicrophonePermission(),
          );
        },
      );

      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'emits Loaded(requiresSettings) when microphone permission is blocked',
        setUp: () {
          when(
            () => mockPermissionsService.requestCameraPermission(),
          ).thenAnswer((_) async => PermissionStatus.granted);
          when(
            () => mockPermissionsService.requestMicrophonePermission(),
          ).thenAnswer((_) async => PermissionStatus.requiresSettings);
        },
        build: () => CameraPermissionBloc(
          permissionsService: mockPermissionsService,
          skipMacOSBypass: true,
        ),
        seed: () =>
            const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
        act: (bloc) => bloc.add(const CameraPermissionRequest()),
        expect: () => [
          const CameraPermissionLoaded(CameraPermissionStatus.requiresSettings),
        ],
      );

      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'drops a duplicate request dispatched while one is in flight',
        setUp: () {
          when(
            () => mockPermissionsService.requestCameraPermission(),
          ).thenAnswer((_) async {
            await Future<void>.delayed(const Duration(milliseconds: 10));
            return PermissionStatus.granted;
          });
          when(
            () => mockPermissionsService.requestMicrophonePermission(),
          ).thenAnswer((_) async => PermissionStatus.granted);
          when(
            () => mockPermissionsService.requestGalleryPermission(),
          ).thenAnswer((_) async => PermissionStatus.granted);
        },
        build: () => CameraPermissionBloc(
          permissionsService: mockPermissionsService,
          skipMacOSBypass: true,
        ),
        seed: () =>
            const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
        act: (bloc) {
          bloc
            ..add(const CameraPermissionRequest())
            ..add(const CameraPermissionRequest());
        },
        wait: const Duration(milliseconds: 20),
        expect: () => [
          const CameraPermissionLoaded(CameraPermissionStatus.authorized),
        ],
        verify: (_) {
          verify(
            () => mockPermissionsService.requestCameraPermission(),
          ).called(1);
        },
      );

      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'emits [Loaded(authorized)] when gallery permission requires settings '
        '(gallery is optional)',
        setUp: () {
          when(
            () => mockPermissionsService.requestCameraPermission(),
          ).thenAnswer((_) async => PermissionStatus.granted);
          when(
            () => mockPermissionsService.requestMicrophonePermission(),
          ).thenAnswer((_) async => PermissionStatus.granted);
          when(
            () => mockPermissionsService.requestGalleryPermission(),
          ).thenAnswer((_) async => PermissionStatus.requiresSettings);
        },
        build: () => CameraPermissionBloc(
          permissionsService: mockPermissionsService,
          skipMacOSBypass: true,
        ),
        seed: () =>
            const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
        act: (bloc) => bloc.add(const CameraPermissionRequest()),
        expect: () => [
          const CameraPermissionLoaded(CameraPermissionStatus.authorized),
        ],
      );

      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'emits [Error] when camera request throws',
        setUp: () {
          when(
            () => mockPermissionsService.requestCameraPermission(),
          ).thenThrow(Exception('Platform error'));
        },
        build: () => CameraPermissionBloc(
          permissionsService: mockPermissionsService,
          skipMacOSBypass: true,
        ),
        seed: () =>
            const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
        act: (bloc) => bloc.add(const CameraPermissionRequest()),
        expect: () => [const CameraPermissionError()],
      );

      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'emits [Error] when microphone request throws',
        setUp: () {
          when(
            () => mockPermissionsService.requestCameraPermission(),
          ).thenAnswer((_) async => PermissionStatus.granted);
          when(
            () => mockPermissionsService.requestMicrophonePermission(),
          ).thenThrow(Exception('Platform error'));
        },
        build: () => CameraPermissionBloc(
          permissionsService: mockPermissionsService,
          skipMacOSBypass: true,
        ),
        seed: () =>
            const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
        act: (bloc) => bloc.add(const CameraPermissionRequest()),
        expect: () => [const CameraPermissionError()],
      );

      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'emits [Error] when gallery request throws',
        setUp: () {
          when(
            () => mockPermissionsService.requestCameraPermission(),
          ).thenAnswer((_) async => PermissionStatus.granted);
          when(
            () => mockPermissionsService.requestMicrophonePermission(),
          ).thenAnswer((_) async => PermissionStatus.granted);
          when(
            () => mockPermissionsService.requestGalleryPermission(),
          ).thenThrow(Exception('Platform error'));
        },
        build: () => CameraPermissionBloc(
          permissionsService: mockPermissionsService,
          skipMacOSBypass: true,
        ),
        seed: () =>
            const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
        act: (bloc) => bloc.add(const CameraPermissionRequest()),
        expect: () => [const CameraPermissionError()],
      );
    });

    group('CameraPermissionRefresh', () {
      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'drops a duplicate refresh while a permission check is in flight',
        setUp: () {
          when(() => mockPermissionsService.checkCameraStatus()).thenAnswer((
            _,
          ) async {
            await Future<void>.delayed(const Duration(milliseconds: 10));
            return PermissionStatus.canRequest;
          });
          when(
            () => mockPermissionsService.checkMicrophoneStatus(),
          ).thenAnswer((_) async => PermissionStatus.canRequest);
        },
        build: () => CameraPermissionBloc(
          permissionsService: mockPermissionsService,
          skipMacOSBypass: true,
        ),
        act: (bloc) {
          bloc
            ..add(const CameraPermissionRefresh())
            ..add(const CameraPermissionRefresh());
        },
        wait: const Duration(milliseconds: 20),
        expect: () => [
          const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
        ],
        verify: (_) {
          verify(() => mockPermissionsService.checkCameraStatus()).called(1);
          verify(
            () => mockPermissionsService.checkMicrophoneStatus(),
          ).called(1);
        },
      );

      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'emits [Loaded(canRequest)] when permissions can be requested',
        setUp: () {
          when(
            () => mockPermissionsService.checkCameraStatus(),
          ).thenAnswer((_) async => PermissionStatus.canRequest);
          when(
            () => mockPermissionsService.checkMicrophoneStatus(),
          ).thenAnswer((_) async => PermissionStatus.canRequest);
          when(
            () => mockPermissionsService.checkGalleryStatus(),
          ).thenAnswer((_) async => PermissionStatus.canRequest);
        },
        build: () => CameraPermissionBloc(
          permissionsService: mockPermissionsService,
          skipMacOSBypass: true,
        ),
        act: (bloc) => bloc.add(const CameraPermissionRefresh()),
        expect: () => [
          const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
        ],
      );

      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'emits [Loaded(authorized)] when all permissions granted',
        setUp: () {
          when(
            () => mockPermissionsService.checkCameraStatus(),
          ).thenAnswer((_) async => PermissionStatus.granted);
          when(
            () => mockPermissionsService.checkMicrophoneStatus(),
          ).thenAnswer((_) async => PermissionStatus.granted);
          when(
            () => mockPermissionsService.checkGalleryStatus(),
          ).thenAnswer((_) async => PermissionStatus.granted);
        },
        build: () => CameraPermissionBloc(
          permissionsService: mockPermissionsService,
          skipMacOSBypass: true,
        ),
        act: (bloc) => bloc.add(const CameraPermissionRefresh()),
        expect: () => [
          const CameraPermissionLoaded(CameraPermissionStatus.authorized),
        ],
      );

      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'emits [Loaded(requiresSettings)] when permission requires settings',
        setUp: () {
          when(
            () => mockPermissionsService.checkCameraStatus(),
          ).thenAnswer((_) async => PermissionStatus.requiresSettings);
          when(
            () => mockPermissionsService.checkMicrophoneStatus(),
          ).thenAnswer((_) async => PermissionStatus.granted);
          when(
            () => mockPermissionsService.checkGalleryStatus(),
          ).thenAnswer((_) async => PermissionStatus.granted);
        },
        build: () => CameraPermissionBloc(
          permissionsService: mockPermissionsService,
          skipMacOSBypass: true,
        ),
        act: (bloc) => bloc.add(const CameraPermissionRefresh()),
        expect: () => [
          const CameraPermissionLoaded(CameraPermissionStatus.requiresSettings),
        ],
      );

      // Gallery permission is now optional - doesn't affect refresh status

      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'emits [Error] when checkPermissions throws',
        setUp: () {
          when(
            () => mockPermissionsService.checkCameraStatus(),
          ).thenThrow(Exception('Platform error'));
          when(
            () => mockPermissionsService.checkMicrophoneStatus(),
          ).thenAnswer((_) async => PermissionStatus.granted);
          when(
            () => mockPermissionsService.checkGalleryStatus(),
          ).thenAnswer((_) async => PermissionStatus.granted);
        },
        build: () => CameraPermissionBloc(
          permissionsService: mockPermissionsService,
          skipMacOSBypass: true,
        ),
        act: (bloc) => bloc.add(const CameraPermissionRefresh()),
        expect: () => [const CameraPermissionError()],
      );
    });

    group('CameraPermissionOpenSettings', () {
      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'calls openAppSettings',
        setUp: () {
          when(
            () => mockPermissionsService.openAppSettings(),
          ).thenAnswer((_) async => true);
        },
        build: () => CameraPermissionBloc(
          permissionsService: mockPermissionsService,
          skipMacOSBypass: true,
        ),
        act: (bloc) => bloc.add(const CameraPermissionOpenSettings()),
        expect: () => <CameraPermissionState>[],
        verify: (_) {
          verify(() => mockPermissionsService.openAppSettings()).called(1);
        },
      );
    });

    group('checkPermissions', () {
      test(
        'returns authorized when camera, microphone and gallery are granted',
        () async {
          when(
            () => mockPermissionsService.checkCameraStatus(),
          ).thenAnswer((_) async => PermissionStatus.granted);
          when(
            () => mockPermissionsService.checkMicrophoneStatus(),
          ).thenAnswer((_) async => PermissionStatus.granted);
          when(
            () => mockPermissionsService.checkGalleryStatus(),
          ).thenAnswer((_) async => PermissionStatus.granted);

          final bloc = CameraPermissionBloc(
            permissionsService: mockPermissionsService,
            skipMacOSBypass: true,
          );
          final result = await bloc.checkPermissions();

          expect(result, CameraPermissionStatus.authorized);
        },
      );

      test('returns requiresSettings when camera requires settings', () async {
        when(
          () => mockPermissionsService.checkCameraStatus(),
        ).thenAnswer((_) async => PermissionStatus.requiresSettings);
        when(
          () => mockPermissionsService.checkMicrophoneStatus(),
        ).thenAnswer((_) async => PermissionStatus.granted);
        when(
          () => mockPermissionsService.checkGalleryStatus(),
        ).thenAnswer((_) async => PermissionStatus.granted);

        final bloc = CameraPermissionBloc(
          permissionsService: mockPermissionsService,
        );
        final result = await bloc.checkPermissions();

        expect(result, CameraPermissionStatus.requiresSettings);
      });

      test(
        'returns requiresSettings when microphone requires settings',
        () async {
          when(
            () => mockPermissionsService.checkCameraStatus(),
          ).thenAnswer((_) async => PermissionStatus.granted);
          when(
            () => mockPermissionsService.checkMicrophoneStatus(),
          ).thenAnswer((_) async => PermissionStatus.requiresSettings);
          when(
            () => mockPermissionsService.checkGalleryStatus(),
          ).thenAnswer((_) async => PermissionStatus.granted);

          final bloc = CameraPermissionBloc(
            permissionsService: mockPermissionsService,
            skipMacOSBypass: true,
          );
          final result = await bloc.checkPermissions();

          expect(result, CameraPermissionStatus.requiresSettings);
        },
      );

      // Gallery permission is now optional - doesn't affect checkPermissions

      test('returns canRequest when permissions can be requested', () async {
        when(
          () => mockPermissionsService.checkCameraStatus(),
        ).thenAnswer((_) async => PermissionStatus.canRequest);
        when(
          () => mockPermissionsService.checkMicrophoneStatus(),
        ).thenAnswer((_) async => PermissionStatus.canRequest);
        when(
          () => mockPermissionsService.checkGalleryStatus(),
        ).thenAnswer((_) async => PermissionStatus.canRequest);

        final bloc = CameraPermissionBloc(
          permissionsService: mockPermissionsService,
        );
        final result = await bloc.checkPermissions();

        expect(result, CameraPermissionStatus.canRequest);
      });

      test(
        'returns canRequest when one permission granted and other can request',
        () async {
          when(
            () => mockPermissionsService.checkCameraStatus(),
          ).thenAnswer((_) async => PermissionStatus.granted);
          when(
            () => mockPermissionsService.checkMicrophoneStatus(),
          ).thenAnswer((_) async => PermissionStatus.canRequest);
          when(
            () => mockPermissionsService.checkGalleryStatus(),
          ).thenAnswer((_) async => PermissionStatus.granted);

          final bloc = CameraPermissionBloc(
            permissionsService: mockPermissionsService,
            skipMacOSBypass: true,
          );
          final result = await bloc.checkPermissions();

          expect(result, CameraPermissionStatus.canRequest);
        },
      );
    });
  });

  group('CameraPermissionState equality', () {
    test('CameraPermissionInitial instances are equal', () {
      expect(
        const CameraPermissionInitial(),
        equals(const CameraPermissionInitial()),
      );
    });

    test('CameraPermissionLoading instances are equal', () {
      expect(
        const CameraPermissionLoading(),
        equals(const CameraPermissionLoading()),
      );
    });

    test('CameraPermissionLoaded instances with same status are equal', () {
      expect(
        const CameraPermissionLoaded(CameraPermissionStatus.authorized),
        equals(const CameraPermissionLoaded(CameraPermissionStatus.authorized)),
      );
    });

    test(
      'CameraPermissionLoaded instances with different status are not equal',
      () {
        expect(
          const CameraPermissionLoaded(CameraPermissionStatus.authorized),
          isNot(
            equals(
              const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
            ),
          ),
        );
      },
    );

    test('CameraPermissionError instances are equal', () {
      expect(
        const CameraPermissionError(),
        equals(const CameraPermissionError()),
      );
    });
  });

  group('CameraPermissionEvent equality', () {
    test('CameraPermissionRequest instances are equal', () {
      expect(
        const CameraPermissionRequest(),
        equals(const CameraPermissionRequest()),
      );
    });

    test('CameraPermissionRefresh instances are equal', () {
      expect(
        const CameraPermissionRefresh(),
        equals(const CameraPermissionRefresh()),
      );
    });

    test('CameraPermissionOpenSettings instances are equal', () {
      expect(
        const CameraPermissionOpenSettings(),
        equals(const CameraPermissionOpenSettings()),
      );
    });
  });
}
