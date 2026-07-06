// ABOUTME: Tests for CameraPermissionGate's direct-request permission behavior
// ABOUTME: Fires the native dialog directly, no in-app "Continue" priming screen

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/camera_permission/camera_permission_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/camera_permission_gate.dart';

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
  void add(CameraPermissionEvent event) => addedEvents.add(event);

  void emitState(CameraPermissionState newState) {
    _state = newState;
    _controller.add(newState);
  }

  @override
  bool get isClosed => false;

  @override
  Future<void> close() async => _controller.close();
}

void main() {
  Widget buildSubject(
    _FakeCameraPermissionBloc bloc,
    MockGoRouter goRouter,
  ) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MockGoRouterProvider(
        goRouter: goRouter,
        child: BlocProvider<CameraPermissionBloc>.value(
          value: bloc,
          child: const CameraPermissionGate(child: Text('CAMERA')),
        ),
      ),
    );
  }

  group(CameraPermissionGate, () {
    testWidgets(
      'auto-fires the native request for a requestable permission with no '
      'in-app priming screen',
      (tester) async {
        final bloc = _FakeCameraPermissionBloc(
          const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
        );
        addTearDown(bloc.close);

        await tester.pumpWidget(buildSubject(bloc, MockGoRouter()));
        await tester.pump();

        // The dialog is fired directly; the old "Continue" priming screen is
        // gone and a spinner covers the brief window while it's up.
        expect(bloc.addedEvents, contains(isA<CameraPermissionRequest>()));
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.cameraPermissionContinue), findsNothing);
      },
    );

    testWidgets(
      'pops back when the request is denied but stays requestable',
      (tester) async {
        final bloc = _FakeCameraPermissionBloc(
          const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
        );
        addTearDown(bloc.close);
        final goRouter = MockGoRouter();
        when(goRouter.canPop).thenReturn(true);

        await tester.pumpWidget(buildSubject(bloc, goRouter));
        await tester.pump();

        // The bloc emits the transient Loading before resolving back to a
        // still-requestable status, mirroring a back-dismissed native dialog.
        bloc.emitState(const CameraPermissionLoading());
        await tester.pump();
        bloc.emitState(
          const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
        );
        await tester.pump();

        verify(goRouter.pop).called(1);
      },
    );

    testWidgets(
      'renders the child when already authorized without requesting',
      (
        tester,
      ) async {
        final bloc = _FakeCameraPermissionBloc(
          const CameraPermissionLoaded(CameraPermissionStatus.authorized),
        );
        addTearDown(bloc.close);

        await tester.pumpWidget(buildSubject(bloc, MockGoRouter()));
        await tester.pump();

        expect(find.text('CAMERA'), findsOneWidget);
        expect(bloc.addedEvents, isEmpty);
      },
    );
  });
}
