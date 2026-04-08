import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_import/video_import_bloc.dart';
import 'package:openvine/models/c2pa_import_result.dart';
import 'package:openvine/screens/import_verification/import_verification_page.dart';

class _MockVideoImportBloc extends MockBloc<VideoImportEvent, VideoImportState>
    implements VideoImportBloc {}

class _MockGoRouter extends Mock implements GoRouter {}

void main() {
  late _MockVideoImportBloc bloc;

  setUp(() {
    bloc = _MockVideoImportBloc();
  });

  Widget buildSubject({GoRouter? goRouter}) {
    final child = MaterialApp(
      home: BlocProvider<VideoImportBloc>.value(
        value: bloc,
        child: const ImportVerificationView(),
      ),
    );

    if (goRouter != null) {
      return InheritedGoRouter(goRouter: goRouter, child: child);
    }
    return child;
  }

  group(ImportVerificationView, () {
    testWidgets(
      'shows $CircularProgressIndicator when validating',
      (tester) async {
        when(() => bloc.state).thenReturn(
          const VideoImportState(status: VideoImportStatus.validating),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(
          find.text('Verifying Content Credentials...'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'shows $CircularProgressIndicator when importing',
      (tester) async {
        when(() => bloc.state).thenReturn(
          VideoImportState(
            status: VideoImportStatus.importing,
            filePath: '/path/to/video.mp4',
            validationResult: C2paImportResult.verified(
              claimGenerator: 'TestApp/1.0',
              digitalSourceType: C2paSourceClassification.humanCreated,
              digitalSourceTypeRaw: 'digitalCapture',
            ),
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(
          find.text('Importing to your library...'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'shows "Content Credentials Verified" when verified',
      (tester) async {
        when(() => bloc.state).thenReturn(
          VideoImportState(
            status: VideoImportStatus.verified,
            validationResult: C2paImportResult.verified(
              claimGenerator: 'Adobe Premiere Pro/1.0',
              digitalSourceType: C2paSourceClassification.humanCreated,
              digitalSourceTypeRaw: 'digitalCapture',
            ),
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(
          find.text('Content Credentials Verified'),
          findsOneWidget,
        );
        expect(find.text('Created with Adobe Premiere Pro'), findsOneWidget);
        expect(find.text('Continue to Publish'), findsOneWidget);
      },
    );

    testWidgets(
      'shows "No Content Credentials" when rejected with noCredentials',
      (tester) async {
        when(() => bloc.state).thenReturn(
          VideoImportState(
            status: VideoImportStatus.rejected,
            validationResult: C2paImportResult.noCredentials(),
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.text('No Content Credentials'), findsOneWidget);
      },
    );

    testWidgets(
      'shows "AI-Generated Content Detected" when rejected with aiGenerated',
      (tester) async {
        when(() => bloc.state).thenReturn(
          VideoImportState(
            status: VideoImportStatus.rejected,
            validationResult: C2paImportResult.aiGenerated(),
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.text('AI-Generated Content Detected'), findsOneWidget);
      },
    );

    testWidgets(
      'shows error state with rejection reason when status is error',
      (tester) async {
        when(() => bloc.state).thenReturn(
          VideoImportState(
            status: VideoImportStatus.error,
            validationResult: C2paImportResult.error('Import failed'),
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.text('No Content Credentials'), findsOneWidget);
        expect(find.text('Import failed'), findsOneWidget);
      },
    );

    testWidgets(
      'shows "No Content Credentials" for rejected with invalidSignature',
      (tester) async {
        when(() => bloc.state).thenReturn(
          VideoImportState(
            status: VideoImportStatus.rejected,
            validationResult: C2paImportResult.invalidSignature(),
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.text('No Content Credentials'), findsOneWidget);
      },
    );

    testWidgets(
      'dispatches $VideoImportConfirmed on Continue to Publish tap',
      (tester) async {
        when(() => bloc.state).thenReturn(
          VideoImportState(
            status: VideoImportStatus.verified,
            validationResult: C2paImportResult.verified(
              claimGenerator: 'TestApp/1.0',
              digitalSourceType: C2paSourceClassification.humanCreated,
              digitalSourceTypeRaw: 'digitalCapture',
            ),
          ),
        );

        await tester.pumpWidget(buildSubject());
        await tester.tap(find.text('Continue to Publish'));

        verify(
          () => bloc.add(const VideoImportConfirmed()),
        ).called(1);
      },
    );

    testWidgets(
      'Close button navigates to root on rejected state',
      (tester) async {
        final mockGoRouter = _MockGoRouter();
        when(() => mockGoRouter.go(any())).thenReturn(null);

        when(() => bloc.state).thenReturn(
          VideoImportState(
            status: VideoImportStatus.rejected,
            validationResult: C2paImportResult.noCredentials(),
          ),
        );

        await tester.pumpWidget(buildSubject(goRouter: mockGoRouter));
        await tester.tap(find.text('Close'));

        verify(() => mockGoRouter.go('/')).called(1);
      },
    );

    testWidgets(
      'navigates to video-metadata when status transitions to imported',
      (tester) async {
        final mockGoRouter = _MockGoRouter();
        when(() => mockGoRouter.go(any())).thenReturn(null);

        final stateController = StreamController<VideoImportState>();
        whenListen(
          bloc,
          stateController.stream,
          initialState: VideoImportState(
            status: VideoImportStatus.importing,
            filePath: '/path/to/video.mp4',
            validationResult: C2paImportResult.verified(
              claimGenerator: 'TestApp/1.0',
              digitalSourceType: C2paSourceClassification.humanCreated,
              digitalSourceTypeRaw: 'digitalCapture',
            ),
          ),
        );

        await tester.pumpWidget(buildSubject(goRouter: mockGoRouter));

        stateController.add(
          VideoImportState(
            status: VideoImportStatus.imported,
            filePath: '/path/to/video.mp4',
            validationResult: C2paImportResult.verified(
              claimGenerator: 'TestApp/1.0',
              digitalSourceType: C2paSourceClassification.humanCreated,
              digitalSourceTypeRaw: 'digitalCapture',
            ),
            draftId: 'draft-abc',
          ),
        );

        await tester.pump();

        verify(
          () => mockGoRouter.go('/video-metadata?draftId=draft-abc'),
        ).called(1);

        await stateController.close();
      },
    );
  });
}
