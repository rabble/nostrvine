// ABOUTME: Widget tests for the upload failure bottom sheet.
// ABOUTME: Verifies retry, save-to-drafts actions and UI rendering.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/services/video_publish/video_publish_service.dart';
import 'package:openvine/widgets/divine_primary_button.dart';
import 'package:openvine/widgets/divine_secondary_button.dart';
import 'package:openvine/widgets/upload_failure_sheet.dart';

class _MockDivineVideoDraft extends Mock implements DivineVideoDraft {}

class _MockDivineVideoClip extends Mock implements DivineVideoClip {}

class _MockBackgroundPublishBloc
    extends MockBloc<BackgroundPublishEvent, BackgroundPublishState>
    implements BackgroundPublishBloc {}

void main() {
  late _MockDivineVideoDraft mockDraft;
  late _MockDivineVideoClip mockClip;
  late _MockBackgroundPublishBloc mockBloc;

  setUp(() {
    mockDraft = _MockDivineVideoDraft();
    mockClip = _MockDivineVideoClip();
    mockBloc = _MockBackgroundPublishBloc();

    when(() => mockDraft.id).thenReturn('draft-1');
    when(() => mockDraft.title).thenReturn('Test Video');
    when(() => mockDraft.clips).thenReturn([mockClip]);

    when(() => mockClip.thumbnailPath).thenReturn(null);
    when(
      () => mockClip.targetAspectRatio,
    ).thenReturn(model.AspectRatio.vertical);
  });

  Widget buildSubject({required BackgroundUpload upload}) {
    return MaterialApp(
      home: BlocProvider<BackgroundPublishBloc>.value(
        value: mockBloc,
        child: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showUploadFailureSheet(context, upload),
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      ),
    );
  }

  group('showUploadFailureSheet', () {
    group('renders', () {
      testWidgets('Upload Failed title', (tester) async {
        final upload = BackgroundUpload(
          draft: mockDraft,
          progress: 1,
          result: const PublishError('Something went wrong'),
        );

        await tester.pumpWidget(buildSubject(upload: upload));
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        expect(find.text('Upload Failed'), findsOneWidget);
      });

      testWidgets('error message from $PublishError', (tester) async {
        final upload = BackgroundUpload(
          draft: mockDraft,
          progress: 1,
          result: const PublishError('Network connection lost'),
        );

        await tester.pumpWidget(buildSubject(upload: upload));
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        expect(find.text('Network connection lost'), findsOneWidget);
      });

      testWidgets('no error message when result is not $PublishError', (
        tester,
      ) async {
        final upload = BackgroundUpload(
          draft: mockDraft,
          progress: 1,
          result: null,
        );

        await tester.pumpWidget(buildSubject(upload: upload));
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        expect(find.text('Upload Failed'), findsOneWidget);
        // Only the title, no additional error text
        expect(
          find.byType(Text),
          findsNWidgets(
            // 'Open Sheet' button + 'Upload Failed' title + button labels
            4,
          ),
        );
      });

      testWidgets('$DivinePrimaryButton with Try Again label', (tester) async {
        final upload = BackgroundUpload(
          draft: mockDraft,
          progress: 1,
          result: const PublishError('Error'),
        );

        await tester.pumpWidget(buildSubject(upload: upload));
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        expect(find.byType(DivinePrimaryButton), findsOneWidget);
        expect(find.text('Try Again'), findsOneWidget);
      });

      testWidgets('$DivineSecondaryButton with Save to Drafts label', (
        tester,
      ) async {
        final upload = BackgroundUpload(
          draft: mockDraft,
          progress: 1,
          result: const PublishError('Error'),
        );

        await tester.pumpWidget(buildSubject(upload: upload));
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        expect(find.byType(DivineSecondaryButton), findsOneWidget);
        expect(find.text('Save to Drafts'), findsOneWidget);
      });

      testWidgets('fallback image when clip has no thumbnail', (tester) async {
        when(() => mockClip.thumbnailPath).thenReturn(null);

        final upload = BackgroundUpload(
          draft: mockDraft,
          progress: 1,
          result: const PublishError('Error'),
        );

        await tester.pumpWidget(buildSubject(upload: upload));
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        expect(find.byType(Image), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets(
        'tapping Try Again dispatches $BackgroundPublishRetryRequested',
        (tester) async {
          final upload = BackgroundUpload(
            draft: mockDraft,
            progress: 1,
            result: const PublishError('Error'),
          );

          await tester.pumpWidget(buildSubject(upload: upload));
          await tester.tap(find.text('Open Sheet'));
          await tester.pumpAndSettle();

          await tester.tap(find.text('Try Again'));
          await tester.pumpAndSettle();

          // Sheet should be dismissed
          expect(find.text('Upload Failed'), findsNothing);

          // Snackbar shown
          expect(find.text('Retrying upload…'), findsOneWidget);

          // Bloc received retry event
          verify(
            () => mockBloc.add(
              BackgroundPublishRetryRequested(draftId: 'draft-1'),
            ),
          ).called(1);
        },
      );

      testWidgets(
        'tapping Save to Drafts dispatches $BackgroundPublishVanished',
        (tester) async {
          final upload = BackgroundUpload(
            draft: mockDraft,
            progress: 1,
            result: const PublishError('Error'),
          );

          await tester.pumpWidget(buildSubject(upload: upload));
          await tester.tap(find.text('Open Sheet'));
          await tester.pumpAndSettle();

          await tester.tap(find.text('Save to Drafts'));
          await tester.pumpAndSettle();

          // Sheet should be dismissed
          expect(find.text('Upload Failed'), findsNothing);

          // Snackbar shown with View action
          expect(find.text('Saved to drafts'), findsOneWidget);
          expect(find.text('View'), findsOneWidget);

          // Bloc received vanish event
          verify(
            () => mockBloc.add(
              BackgroundPublishVanished(draftId: 'draft-1'),
            ),
          ).called(1);
        },
      );
    });
  });
}
