// ABOUTME: Tests for pushToCameraWithPermission extension on BuildContext
// ABOUTME: Verifies pre-navigation permission check and bottom sheet flow

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/camera_permission/camera_permission_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/video_recorder_screen.dart';
import 'package:openvine/utils/camera_permission_check.dart';

import '../helpers/go_router.dart';

// 1×1 transparent PNG for DivineSticker asset loading in tests.
final _transparentPng = Uint8List.fromList(const <int>[
  0x89,
  0x50,
  0x4e,
  0x47,
  0x0d,
  0x0a,
  0x1a,
  0x0a,
  0x00,
  0x00,
  0x00,
  0x0d,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1f,
  0x15,
  0xc4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0a,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9c,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0d,
  0x0a,
  0x2d,
  0xb4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4e,
  0x44,
  0xae,
  0x42,
  0x60,
  0x82,
]);

class _TestAssetBundle extends CachingAssetBundle {
  _TestAssetBundle() {
    final manifest = <String, List<Map<String, Object>>>{
      for (final sticker in DivineStickerName.values)
        sticker.assetPath: [
          <String, Object>{'asset': sticker.assetPath},
        ],
    };
    _manifest = const StandardMessageCodec().encodeMessage(manifest)!;
  }

  late final ByteData _manifest;
  final ByteData _imageData = ByteData.sublistView(_transparentPng);

  @override
  Future<ByteData> load(String key) {
    if (key == 'AssetManifest.bin') {
      return SynchronousFuture<ByteData>(_manifest);
    }
    return SynchronousFuture<ByteData>(_imageData);
  }
}

class _FakeCameraPermissionBloc extends Fake implements CameraPermissionBloc {
  _FakeCameraPermissionBloc(CameraPermissionState initialState)
    : _state = initialState;

  final _controller = StreamController<CameraPermissionState>.broadcast();
  final addedEvents = <CameraPermissionEvent>[];
  CameraPermissionState _state;

  @override
  CameraPermissionState get state => _state;

  @override
  Stream<CameraPermissionState> get stream => _controller.stream;

  @override
  void add(CameraPermissionEvent event) {
    addedEvents.add(event);
  }

  void emitState(CameraPermissionState newState) {
    _state = newState;
    _controller.add(newState);
  }

  @override
  bool get isClosed => false;

  @override
  Future<void> close() async {
    await _controller.close();
  }
}

void main() {
  late MockGoRouter mockGoRouter;
  late _TestAssetBundle testBundle;

  setUp(() {
    mockGoRouter = MockGoRouter();
    testBundle = _TestAssetBundle();
    when(
      () => mockGoRouter.push<Object?>(any(), extra: any(named: 'extra')),
    ).thenAnswer((_) async => null);
  });

  Widget buildSubject(
    _FakeCameraPermissionBloc bloc, {
    ValueChanged<bool>? onResult,
  }) {
    return ProviderScope(
      child: MockGoRouterProvider(
        goRouter: mockGoRouter,
        child: BlocProvider<CameraPermissionBloc>.value(
          value: bloc,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) =>
                DefaultAssetBundle(bundle: testBundle, child: child!),
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    final result = await context.pushToCameraWithPermission();
                    onResult?.call(result);
                  },
                  child: const Text('Trigger'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('pushToCameraWithPermission', () {
    group('navigates directly', () {
      testWidgets('when permission is authorized', (tester) async {
        final bloc = _FakeCameraPermissionBloc(
          const CameraPermissionLoaded(CameraPermissionStatus.authorized),
        );
        bool? result;
        await tester.pumpWidget(
          buildSubject(bloc, onResult: (r) => result = r),
        );

        await tester.tap(find.text('Trigger'));
        await tester.pumpAndSettle();

        verify(
          () => mockGoRouter.push<Object?>(
            VideoRecorderScreen.path,
            extra: any(named: 'extra'),
          ),
        ).called(1);
        expect(result, isTrue);
      });

      testWidgets('when permission requires settings', (tester) async {
        final bloc = _FakeCameraPermissionBloc(
          const CameraPermissionLoaded(CameraPermissionStatus.requiresSettings),
        );
        bool? result;
        await tester.pumpWidget(
          buildSubject(bloc, onResult: (r) => result = r),
        );

        await tester.tap(find.text('Trigger'));
        await tester.pumpAndSettle();

        verify(
          () => mockGoRouter.push<Object?>(
            VideoRecorderScreen.path,
            extra: any(named: 'extra'),
          ),
        ).called(1);
        expect(result, isTrue);
      });
    });

    group('waits for permission status', () {
      testWidgets('adds $CameraPermissionRefresh when state is initial', (
        tester,
      ) async {
        final bloc = _FakeCameraPermissionBloc(const CameraPermissionInitial());
        await tester.pumpWidget(buildSubject(bloc));

        await tester.tap(find.text('Trigger'));
        await tester.pump();

        expect(bloc.addedEvents, contains(isA<CameraPermissionRefresh>()));

        // Unblock the stream wait
        bloc.emitState(
          const CameraPermissionLoaded(CameraPermissionStatus.authorized),
        );
        await tester.pumpAndSettle();
      });

      testWidgets('navigates when permission resolves to authorized', (
        tester,
      ) async {
        final bloc = _FakeCameraPermissionBloc(const CameraPermissionInitial());
        bool? result;
        await tester.pumpWidget(
          buildSubject(bloc, onResult: (r) => result = r),
        );

        await tester.tap(find.text('Trigger'));
        await tester.pump();

        bloc.emitState(
          const CameraPermissionLoaded(CameraPermissionStatus.authorized),
        );
        await tester.pumpAndSettle();

        verify(
          () => mockGoRouter.push<Object?>(
            VideoRecorderScreen.path,
            extra: any(named: 'extra'),
          ),
        ).called(1);
        expect(result, isTrue);
      });

      testWidgets('navigates directly when resolve times out after 10s', (
        tester,
      ) async {
        final bloc = _FakeCameraPermissionBloc(const CameraPermissionInitial());
        bool? result;
        await tester.pumpWidget(
          buildSubject(bloc, onResult: (r) => result = r),
        );

        await tester.tap(find.text('Trigger'));
        await tester.pump();

        // Stream never emits → 10s timeout fires → status is null
        // → navigates directly.
        await tester.pump(const Duration(seconds: 11));
        await tester.pumpAndSettle();

        verify(
          () => mockGoRouter.push<Object?>(
            VideoRecorderScreen.path,
            extra: any(named: 'extra'),
          ),
        ).called(1);
        expect(result, isTrue);
      });

      testWidgets('navigates when permission resolves to error', (
        tester,
      ) async {
        final bloc = _FakeCameraPermissionBloc(const CameraPermissionInitial());
        bool? result;
        await tester.pumpWidget(
          buildSubject(bloc, onResult: (r) => result = r),
        );

        await tester.tap(find.text('Trigger'));
        await tester.pump();

        bloc.emitState(const CameraPermissionError());
        await tester.pumpAndSettle();

        verify(
          () => mockGoRouter.push<Object?>(
            VideoRecorderScreen.path,
            extra: any(named: 'extra'),
          ),
        ).called(1);
        expect(result, isTrue);
      });
    });

    group('returns immediately for terminal states', () {
      testWidgets('navigates directly when state is $CameraPermissionDenied', (
        tester,
      ) async {
        final bloc = _FakeCameraPermissionBloc(const CameraPermissionDenied());
        bool? result;
        await tester.pumpWidget(
          buildSubject(bloc, onResult: (r) => result = r),
        );

        await tester.tap(find.text('Trigger'));
        await tester.pumpAndSettle();

        verify(
          () => mockGoRouter.push<Object?>(
            VideoRecorderScreen.path,
            extra: any(named: 'extra'),
          ),
        ).called(1);
        expect(result, isTrue);
        // Must not have dispatched any events.
        expect(bloc.addedEvents, isEmpty);
      });

      testWidgets('navigates directly when state is $CameraPermissionError', (
        tester,
      ) async {
        final bloc = _FakeCameraPermissionBloc(const CameraPermissionError());
        bool? result;
        await tester.pumpWidget(
          buildSubject(bloc, onResult: (r) => result = r),
        );

        await tester.tap(find.text('Trigger'));
        await tester.pumpAndSettle();

        verify(
          () => mockGoRouter.push<Object?>(
            VideoRecorderScreen.path,
            extra: any(named: 'extra'),
          ),
        ).called(1);
        expect(result, isTrue);
        expect(bloc.addedEvents, isEmpty);
      });
    });

    group('shows bottom sheet when canRequest', () {
      testWidgets('renders prompt with correct content', (tester) async {
        final bloc = _FakeCameraPermissionBloc(
          const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
        );
        await tester.pumpWidget(buildSubject(bloc));

        await tester.tap(find.text('Trigger'));
        await tester.pumpAndSettle();

        expect(find.text('Allow camera & microphone access'), findsOneWidget);
        expect(find.text('Continue'), findsOneWidget);
        expect(find.text('Not now'), findsOneWidget);
      });

      testWidgets('navigates after user grants permission', (tester) async {
        final bloc = _FakeCameraPermissionBloc(
          const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
        );
        bool? result;
        await tester.pumpWidget(
          buildSubject(bloc, onResult: (r) => result = r),
        );

        await tester.tap(find.text('Trigger'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        bloc.emitState(
          const CameraPermissionLoaded(CameraPermissionStatus.authorized),
        );
        await tester.pumpAndSettle();

        verify(
          () => mockGoRouter.push<Object?>(
            VideoRecorderScreen.path,
            extra: any(named: 'extra'),
          ),
        ).called(1);
        expect(result, isTrue);
      });

      testWidgets('adds $CameraPermissionRequest after user taps Continue', (
        tester,
      ) async {
        final bloc = _FakeCameraPermissionBloc(
          const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
        );
        await tester.pumpWidget(buildSubject(bloc));

        await tester.tap(find.text('Trigger'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        expect(bloc.addedEvents, contains(isA<CameraPermissionRequest>()));

        // Unblock the stream wait
        bloc.emitState(const CameraPermissionDenied());
        await tester.pumpAndSettle();
      });

      testWidgets('returns false when permission is denied', (tester) async {
        final bloc = _FakeCameraPermissionBloc(
          const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
        );
        bool? result;
        await tester.pumpWidget(
          buildSubject(bloc, onResult: (r) => result = r),
        );

        await tester.tap(find.text('Trigger'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        bloc.emitState(const CameraPermissionDenied());
        await tester.pumpAndSettle();

        verifyNever(
          () => mockGoRouter.push<Object?>(any(), extra: any(named: 'extra')),
        );
        expect(result, isFalse);
      });

      testWidgets('returns false when user taps Not now', (tester) async {
        final bloc = _FakeCameraPermissionBloc(
          const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
        );
        bool? result;
        await tester.pumpWidget(
          buildSubject(bloc, onResult: (r) => result = r),
        );

        await tester.tap(find.text('Trigger'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Not now'));
        await tester.pumpAndSettle();

        verifyNever(
          () => mockGoRouter.push<Object?>(any(), extra: any(named: 'extra')),
        );
        expect(result, isFalse);
      });

      testWidgets('returns false when permission request times out', (
        tester,
      ) async {
        final bloc = _FakeCameraPermissionBloc(
          const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
        );
        bool? result;
        await tester.pumpWidget(
          buildSubject(bloc, onResult: (r) => result = r),
        );

        await tester.tap(find.text('Trigger'));
        await tester.pumpAndSettle();

        // Tap Continue to dispatch CameraPermissionRequest.
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // Simulate timeout by using fakeAsync elapsed time.
        // The stream never emits, so the 30 s timeout fires.
        await tester.pump(const Duration(seconds: 31));
        await tester.pumpAndSettle();

        verifyNever(
          () => mockGoRouter.push<Object?>(any(), extra: any(named: 'extra')),
        );
        expect(result, isFalse);
      });
    });
  });
}
