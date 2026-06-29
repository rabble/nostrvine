// ABOUTME: Tests for pushToCameraWithPermission extension on BuildContext
// ABOUTME: Verifies pre-navigation permission checks route to the recorder gate

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/camera_permission/camera_permission_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/video_recorder_screen.dart';
import 'package:openvine/utils/camera_permission_check.dart';

import '../helpers/go_router.dart';

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

  setUp(() {
    mockGoRouter = MockGoRouter();
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

        // Stream never emits → 10s timeout fires → navigates anyway and lets
        // the gate render the loading/error UI.
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

    group('routes requestable permissions to the recorder gate', () {
      testWidgets(
        'navigates without dispatching $CameraPermissionRequest when canRequest',
        (tester) async {
          final bloc = _FakeCameraPermissionBloc(
            const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
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
          expect(
            bloc.addedEvents,
            isNot(contains(isA<CameraPermissionRequest>())),
          );
          expect(result, isTrue);
        },
      );
    });
  });
}
