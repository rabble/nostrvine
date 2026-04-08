import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_import/video_import_bloc.dart';
import 'package:openvine/models/c2pa_import_result.dart';
import 'package:openvine/screens/import_verification/import_verification_page.dart';

class _MockVideoImportBloc extends MockBloc<VideoImportEvent, VideoImportState>
    implements VideoImportBloc {}

void main() {
  late _MockVideoImportBloc bloc;

  setUp(() {
    bloc = _MockVideoImportBloc();
  });

  Widget buildSubject() {
    return MaterialApp(
      home: BlocProvider<VideoImportBloc>.value(
        value: bloc,
        child: const ImportVerificationView(),
      ),
    );
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
  });
}
